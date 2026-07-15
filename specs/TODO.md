---
next_project_number: 873
---

# TODO


## Tasks

### 872. /distill review/revise (dream) mode
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: Task 869, Task 870, Task 871
- **Research**: [872_distill_review_revise_dream_mode/reports/01_dream_mode_research.md]
- **Plan**: [872_distill_review_revise_dream_mode/plans/01_distill-dream-mode.md]
- **Summary**: [872_distill_review_revise_dream_mode/summaries/01_distill-dream-mode-summary.md]

**Description**: Add a new review/revise (dream) mode to the existing /distill command (NOT a separate /dream command) that ingests the unified store, re-reviews and revises ALL memories in light of the captured logs, and synthesizes concrete agent-system improvement proposals (which may become tasks or documentation edits). Reuse /distill's existing score/merge/compress/refine/purge/gc primitives internally and the skill-memory distill sub_mode dispatch; this is the loop-closing consumer. Depends on the store plus both capture layers so it operates over real captured data. Keep the memory EXTENSION.md, manifest.json, index-entries.json, and distill-usage context in sync (CLAUDE.md is auto-generated).

---

### 871. Completion-time reflective harvest (/todo + /learn)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: Task 869, Task 870
- **Research**: [871_completion_time_reflective_harvest/reports/01_completion_time_reflective_harvest.md]
- **Plan**: [871_completion_time_reflective_harvest/plans/01_reflective-harvest.md]
- **Summary**: [871_completion_time_reflective_harvest/summaries/01_reflective-harvest-summary.md]

**Description**: Add a structured reflective capture at task completion (what worked / what was hard / what was missed / successes) by extending the existing skill-todo Stage 7/9 harvest and the /learn --task flow rather than replacing them. Persist the reflection as a new field alongside memory_candidates/completion_summary in the task's state.json entry, written at the orchestrator-postflight.sh completion seam, and surface it via the existing AskUserQuestion interactive prompt; the reflection also lands in the unified store for distillation. Depends on the store contract. This task shares orchestrator-postflight.sh and the core EXTENSION.md/manifest.json surfaces with the hook-logging task, so it is intentionally serialized after it (user chose the serialized/safe ordering). Keep the memory and core EXTENSION.md / manifest / index-entries in sync (CLAUDE.md is auto-generated).

---

### 870. Automatic hook-based lifecycle event logging
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: Task 869
- **Research**: [870_automatic_hook_event_logging/reports/01_automatic-hook-event-logging.md]
- **Plan**: [870_automatic_hook_event_logging/plans/01_hook-event-instrumentation.md]
- **Summary**: [870_automatic_hook_event_logging/summaries/01_hook-event-instrumentation-summary.md]

**Description**: Emit structured events into the unified store automatically: instrument the four skill-base.sh lifecycle stage functions (preflight/context_injection/verification/postflight) for timings and success milestones, and add a PostToolUse plus Stop/SubagentStop logger hook capturing command/agent lifecycle events, deviations, and blockers, cross-linked with errors.json via the shared session_id/task keys. Reuse the existing provides.hooks + settings.json wiring convention; note there is currently no live functioning top-level lifecycle hook, so this also establishes that pattern for real. Handle the lazy absence of errors.json gracefully (do not assume it exists). Depends on the store contract for its append helper. Keep the core EXTENSION.md, manifest.json, and index-entries.json in sync (CLAUDE.md is auto-generated).

---

### 869. Unified event/reflection JSONL store + schema + reader API
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: memory-improvement-loop
- **Dependencies**: None
- **Research**: [869_unified_event_reflection_store/reports/01_event-store-schema-design.md]
- **Plan**: [869_unified_event_reflection_store/plans/01_event-store-plumbing.md]
- **Summary**: [869_unified_event_reflection_store/plans/01_event-store-plumbing.md]

**Description**: Define the append-only JSONL store (proposed specs/events.jsonl, created lazily like errors.json) that both capture layers write and the memory distillation reads. Specify the event schema (event_type, timestamp, duration, session_id, task, checkpoint, category for deviation/blocker/milestone/success, and cross-link to errors.json), and ship a shared append helper plus a query/reader helper so no subsystem hand-rolls jq. This is the foundational contract and is sequenced first (build inversion of the runtime data flow) so the producer layers have a validated write target and the distillation consumer has a stable reader; it implements only the store plumbing and its documented format, no agent-behavioral capture itself. Reuse the errors.json entry-schema conventions and the shared session_id/task cross-link keys. Keep the core EXTENSION.md, manifest.json, and index-entries.json in sync (CLAUDE.md is auto-generated, never hand-edited).

---

### 868. Typst segmentation evaluation
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 866
- **Research**: [868_typst_segmentation_evaluation/reports/01_typst-segmentation-decision.md]
- **Plan**: [868_typst_segmentation_evaluation/plans/01_markdown-retention-decision.md]
- **Summary**: [868_typst_segmentation_evaluation/summaries/01_markdown-retention-decision-summary.md]

**Description**: Evaluate whether Typst segmentation is "superior AND just as convenient" versus the current markdown chunking, and implement conditionally. Current pipeline is markdown-only: literature-convert.sh emits {doc_id}.md (pdftotext + PyMuPDF; marker/pandoc explicitly evaluated and rejected), literature-chunk.sh does markdown-heading-driven ('# ## ###') two-pass hierarchical chunking into chunk_NNNN.md + chunks.json, indexed via literature-schema.sql / literature-build-index.sh (SQLite FTS5). The typst extension is authoring-only (no scripts, no converter, no chunker). The FTS5 index is largely format-agnostic (a source_format column already exists; .typ chunks are feasible with minor chunk-file glob and --read path changes), but a PDF->typst converter and a typst-aware segmenter (typst '=' / '==' headings and #heading[] / #theorem[] functions) would be NEW greenfield work. Deliverables: (a) a clear decision -- is typst superior and just-as-convenient for segmentation? If NO, record a durable decision (referencing durable anchors, no task-number citations) to keep markdown, with rationale; (b) if YES, implement a typst conversion/segmentation path and make the ingest pipeline (especially the task 866 bridge plus literature-convert.sh / literature-chunk.sh) format-configurable, with minimal index-schema changes. A "no format change" outcome is valid and expected if convenience parity is not met. Depends on task 866 (modifies the same convert/chunk stage the bridge uses).

---

### 867. Sparse lit detection stage4a
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 866
- **Research**: [867_sparse_lit_detection_stage4a/reports/01_sparse-lit-detection-design.md]
- **Plan**: [867_sparse_lit_detection_stage4a/plans/01_sparse-lit-stage4a-wiring.md]
- **Summary**: [867_sparse_lit_detection_stage4a/summaries/01_sparse-lit-stage4a-wiring-summary.md]

**Description**: Add sparse-literature detection to --lit and reconcile the drifted Stage 4a flow so that when a run "does not find much" literature it offers to search online and ingest (via the task 866 bridge). Current gaps: literature-lit-flag-resolve.sh classifies purely on file existence (5 directives: LIT_DISABLED / SUBINDEX_PRESENT / GLOBAL_MISSING / PROMPT_NEEDED / AUTONOMOUS_GLOBAL) with NO count or threshold; literature-briefing.sh computes an internal seg_count but never surfaces it to callers; and the deployed skills' Stage 4a is DRIFTED -- skill-researcher and its peers do not actually call literature-lit-flag-resolve.sh and never offer the designed "Use global corpus now" option. This task: (1) surface a machine-readable coverage/segment count and a `sparse` signal from literature-briefing.sh, following the established loud-banner precedent (never silent); (2) add a configurable sparsity threshold with a sensible default; (3) introduce a new directive (e.g. SPARSE_PROMPT_NEEDED) that fires on sparse-OR-absent coverage on BOTH the SUBINDEX_PRESENT path (sub-index exists but returns few relevant chunks) AND the global-search path; (4) reconcile and complete the Stage 4a wiring across ALL SIX --lit skills (skill-researcher / skill-planner / skill-implementer and their -hard variants) so they call the resolver and present a new interactive option "Search online to ingest" that invokes the task 866 bridge; (5) preserve the autonomous/orchestrator contract with a deterministic, visible [lit:auto] fallback -- never a silent no-op. Keep EXTENSION.md / merge-source docs in sync (CLAUDE.md is auto-generated). Depends on task 866 (the "search online" option must invoke the ingest bridge).

---

### 866. Online ingest zotero pdf bridge
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [866_online_ingest_zotero_pdf_bridge/reports/01_online-ingest-zotero-bridge.md]
- **Plan**: [866_online_ingest_zotero_pdf_bridge/plans/01_online-ingest-zotero-bridge.md]
- **Summary**: [866_online_ingest_zotero_pdf_bridge/summaries/01_online-ingest-zotero-bridge-summary.md]

**Description**: Build the online-discovery -> Zotero+PDF -> ingest bridge for the literature extension so a --lit run can ingest a newly found online source end-to-end. Wire literature-discover.sh Tier-3 online results (Semantic Scholar / Unpaywall / arXiv; statuses open_access / paywall / arxiv / in_zotero_no_pdf) into the existing ingest pipeline. For a user-selected discovered source: (1) resolve and download the PDF for open-access/arXiv hits; (2) add the source to Zotero WITH the PDF attached -- this requires a NEW create-item capability (Zotero Web API POST /items via the `zot` CLI, or the local API at 127.0.0.1:23119), since zotero-write.sh today supports ONLY note-add / tag-add / tag-remove / attach-file against an EXISTING item and has no create-item path; (3) run the existing convert -> chunk -> build-index pipeline (literature-ingest.sh, literature-convert.sh, literature-chunk.sh, literature-build-index.sh) and register the new doc in the global index and, when appropriate, the per-repo sub-index (specs/literature-index.json). Paywalled/no-PDF sources MUST be surfaced honestly with no fabricated downloads, mirroring the existing assisted-export UX (zotero-export-status.sh directives) in commands/literature.md. Preferred shape: a new entry point (e.g. literature-ingest-online.sh) or an extension of literature-ingest.sh that accepts a discovery record. This is the foundation task; tasks 867 and 868 build on it. Keep the literature EXTENSION.md / merge-source docs in sync (CLAUDE.md is auto-generated).

---

### 865. Make .claude/ wipe lossless and one-keystroke regenerable
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: extensions
- **Dependencies**: Task 863
- **Research**: [865_make_claude_wipe_lossless_and_regenerable/reports/01_wipe-lossless-regenerable-research.md]
- **Plan**: [865_make_claude_wipe_lossless_and_regenerable/plans/01_wipe-lossless-regenerable.md]
- **Summary**: [865_make_claude_wipe_lossless_and_regenerable/summaries/01_wipe-lossless-regenerable-summary.md]

**Description**: Make a .claude/ wipe lossless and one-keystroke regenerable by lifting all wipe-surviving state OUT of .claude/. Depends on the store-relocation task (the deploy/target model); can land in parallel with or after the drift-check-hardening task.

CONTEXT: Selection/state is currently written INSIDE the deployed tree, so a wipe destroys it. get_state_path = project_dir .. "/" .. config.base_dir .. "/" .. config.state_file = $CWD/.claude/extensions.json (state.lua:71). settings.json and logs/ also currently live under .claude/ but are input/runtime, not build output. specs/ is already correctly at project root and is the model to follow.

REQUIRED: (1) Move the selection manifest extensions.json from $CWD/.claude/extensions.json to a project-root location that survives a wipe (candidate: $CWD/.agent-extensions.json; research to confirm the name) so regenerate can skip re-picking, and so a project can optionally commit the file to pin its extension set. (2) Move settings.json and logs/ out of .claude/ (they are input/runtime, not output). (3) Update state.lua get_state_path and ALL readers/writers of the moved state. (4) Include a headless-nvim verification that constructs a FAKE project dir in the scratchpad, deploys, deletes .claude/, and regenerates identically from the surviving selection.

TESTING SAFETY (mandatory): NEVER run destructive testing against the real ~/.config/nvim/.claude tree. This loader had a live data-loss bug recently; ALL destructive testing is scratch-only, against fake project dirs constructed in the scratchpad.

CROSS-CUTTING CONSTRAINTS: Copy-deploy only, no symlink farm. Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**. Build on (do not recreate) the already-landed check_deployed_rule_drift and the symlink-safe remove path in loader.lua. DESIRED END STATE: after a .claude/ wipe, nothing hand-authored or stateful is lost; regenerate from the surviving selection reproduces .claude/ identically, upholding `.claude/ == deploy(store, selection)`.

---

### 864. Enforce every deployed file has a source (hard drift gate)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 863
- **Research**: [864_enforce_every_deployed_file_has_a_source/reports/01_enforce-every-deployed-file-source.md]
- **Plan**: [864_enforce_every_deployed_file_has_a_source/plans/01_deployed-file-source-hard-gate.md]
- **Summary**: [864_enforce_every_deployed_file_has_a_source/summaries/01_deployed-file-source-hard-gate-summary.md]

**Description**: Enforce the invariant "every deployed file has a source" by extending the deployed-vs-source drift check into a hard gate, and by giving every deployed-only orphan a real source home in the core extension. Order this AFTER the store-relocation task (the check compares deployed output against the relocated store).

CONTEXT: The existing rule-drift check (check_deployed_rule_drift in .claude/scripts/check-extension-docs.sh) currently covers only provides.rules. Deployed-only ORPHANS with no source exist today and would vanish on a clean rebuild: .claude/rules/no-task-references-in-deliverables.md (declared in core manifest but no source file under core/rules/), .claude/commands/README.md, and ~4 standalone scripts under .claude/scripts/.

REQUIRED: (1) Extend the deployed-vs-source drift check in .claude/scripts/check-extension-docs.sh beyond provides.rules to ALL provides categories (agents, commands, context, scripts), following the per-category convention divergences already documented: agents needs an agents_subdir parameter; context needs recursive directory comparison. (2) Give the deployed-only orphans a source home in the core extension so nothing deployed is unsourced: no-task-references-in-deliverables.md, commands/README.md, and the ~4 standalone scripts. (3) Make the check a HARD gate (exit non-zero on any unsourced deployed file), proving the disposable-output invariant holds.

DUAL-WRITE HAZARD (mandatory): check-extension-docs.sh has a dual copy at .claude/extensions/core/scripts/check-extension-docs.sh and the script lints itself. Every edit must land BYTE-IDENTICAL in both .claude/scripts/check-extension-docs.sh and .claude/extensions/core/scripts/check-extension-docs.sh.

CROSS-CUTTING CONSTRAINTS: Copy-deploy only, no symlink farm. All destructive loader testing in the scratchpad against fake project dirs, never against the real .claude tree. Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**. Build on (do not recreate) the already-landed check_deployed_rule_drift and the symlink-safe remove path in loader.lua.

---

### 863. Relocate extension source store out of .claude/
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [863_relocate_extension_source_store_out_of_claude/reports/01_relocate-extension-source-store.md]
- **Plan**: [863_relocate_extension_source_store_out_of_claude/plans/01_relocate-extension-store.md]
- **Summary**: [863_relocate_extension_source_store_out_of_claude/summaries/01_relocate-extension-store-summary.md]

**Description**: Relocate the extension source store OUT of any deployed .claude/ tree so that .claude/ can become a pure, disposable copy-deploy build artifact regenerable from the <leader>al picker after deletion. This is the UNLOCKING change and must land FIRST.

CONTEXT: The loader already deploys into the current working directory (lua/neotex/plugins/ai/shared/extensions/init.lua:238 `local project_dir = opts.project_dir or vim.fn.getcwd()`; deploy target = project_dir .. "/" .. config.base_dir = $CWD/.claude, init.lua:79). Sources are read from a GLOBAL root `global_extensions_dir` defaulting to ~/.config/nvim/.claude/extensions (config.lua:55 in the M.claude preset; global_dir defaults to vim.fn.expand("~/.config/nvim")). The picker `list_extensions` reads from config.global_extensions_dir and returns empty if that dir is absent (manifest.lua:171-178). The ONLY reason ~/.config/nvim cannot self-rebuild today is that its source store (.claude/extensions/) physically lives INSIDE its own deploy target; every OTHER working directory can already delete-and-regenerate because source and target are different trees.

REQUIRED: Physically move .claude/extensions/ to a sibling location NOT under any deployed .claude/ (candidate: ~/.config/nvim/agent-system/extensions/, or another non-.claude path the research phase should evaluate). Repoint global_extensions_dir in config.lua:55 (M.claude preset) to the new store. Adjust how manifest.lua and init.lua resolve the store ONLY if needed. Verify: (1) the picker lists extensions from the new location; (2) deploying into an arbitrary $CWD/.claude still works; (3) ~/.config/nvim itself now rebuilds like any other project (its .claude/ is a disposable deploy target with no source inside it).

FILE SCOPE centers on lua/neotex/plugins/ai/shared/extensions/config.lua plus the physical relocation of the store; touches manifest.lua/init.lua store-resolution only if required.

CROSS-CUTTING CONSTRAINTS: Copy-deploy only, NO symlink farm (the user explicitly rejected symlinks; absolute source paths would also leak across arbitrary project directories). All destructive loader testing happens in the scratchpad against fake project dirs, NEVER against the real ~/.config/nvim/.claude tree (this loader had a live data-loss bug recently). Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.

DESIRED END STATE (shared across this sequence): .claude/ in any CWD is 100% disposable build output (nothing hand-authored, no source, no state, no orphans); one global source store lives OUTSIDE any .claude/; the invariant `.claude/ == deploy(store, selection)` holds. Foundation already landed and MUST be built on, not recreated: a deployed-vs-source rule drift check (check_deployed_rule_drift) and a symlink-safe remove path in loader.lua.

---

### 862. Fix loader symlink delete data loss
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [862_fix_loader_symlink_delete_data_loss/reports/01_loader-symlink-delete-data-loss.md]
- **Plan**: [862_fix_loader_symlink_delete_data_loss/plans/01_loader-symlink-delete-data-loss.md]
- **Summary**: [862_fix_loader_symlink_delete_data_loss/summaries/01_loader-symlink-delete-data-loss-summary.md]

**Description**: Fix data loss in the extension loader: remove_installed_files() deletes through symlinks, destroying tracked extension-source files.

OBSERVED DATA LOSS: an extension reload deleted .claude/extensions/literature/skills/skill-literature/SKILL.md (2265 lines, git-tracked). Evidence: a check-extension-docs.sh run immediately before the reload recorded "literature PASS"; immediately after, "literature FAIL: manifest skill entry missing on disk: skills/skill-literature/SKILL.md". The extension-source directory mtime matched the reload timestamp to the second. The file was recovered from git HEAD; /literature was broken until then.

ROOT CAUSE: deployed skills are symlinks into extension sources, e.g. .claude/skills/skill-literature -> ../extensions/literature/skills/skill-literature. The unload step in lua/neotex/plugins/ai/shared/extensions/loader.lua (remove_installed_files, approx lines 755-784) iterates installed_files and calls vim.fn.delete(filepath) on the DEPLOYED path. Because the deployed path resolves through the symlink, the delete lands on the real extension-source file. The subsequent copy step then has nothing to copy and leaves an empty directory. Deployed and source are the same inode, so "remove the deployed copy" means "destroy the source".

STILL LIVE: the symlink is unchanged, so another reload destroys the file again. Nine other deployed skills are symlinks into extension sources and are exposed whenever their extension unloads: skill-cslib-implementation, skill-cslib-implementation-hard, skill-cslib-research, skill-cslib-research-hard, skill-cslib-vet, skill-pr-implementation, skill-pr-review-implementation, skill-pr-review-research, skill-zotero.

SECOND GAP: remove_installed_files() takes no protected_paths argument, so .syncprotect does not guard the delete path at all. copy_file() honors protected_paths; the removal path does not. A user who lists a file in .syncprotect is protected on sync but not on unload.

THIRD SYMPTOM (same interaction, lower severity): the reload replaced .claude/agents/literature-agent.md and .claude/commands/literature.md, which are mode 120000 (symlinks) in HEAD, with regular files. Content was preserved but the symlink setup was silently flattened; these show as typechanges (T) in git status.

REQUIRED: make the removal path symlink-aware so it never deletes through a symlink into an extension source -- e.g. skip paths where the deployed entry is a symlink (or resolves outside the deployed tree), or unlink the symlink itself rather than its target. Decide and document whether the symlink deploy mode is supported: if supported, both copy and remove must handle it; if not, the loader should refuse to install over a symlink rather than silently destroying it. Also thread protected_paths/.syncprotect through remove_installed_files() so protection is symmetric across copy and remove. Verify with nvim --headless: reload an extension whose deployed skill is a symlink and assert the source file survives.

---

### 861. Add rule drift check to extension lint
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [861_add_rule_drift_check_to_extension_lint/reports/01_rule-drift-check-lint.md]
- **Plan**: [861_add_rule_drift_check_to_extension_lint/plans/01_rule-drift-check-lint.md]
- **Summary**: [861_add_rule_drift_check_to_extension_lint/summaries/01_rule-drift-check-lint-summary.md]

**Description**: Add a deployed-vs-source content drift check for extension rules in check-extension-docs.sh. The script's check_deployed_script_drift covers manifest.provides.scripts only, comparing the deployed .claude/scripts/<name> against the extension source <ext>/scripts/<name>. There is no equivalent check for provides.rules, so a rule file whose deployed .claude/rules/<name>.md has diverged from its extension source is invisible to lint.

This is not hypothetical. core/rules/pr-prohibition.md had silently accumulated 35 lines in its deployed copy (the "/pr --review Workflow" section) that were absent from the extension source. The divergence survived precisely because the rule was unregistered in provides.rules, so the loader never overwrote the deployed copy. Once registered, the loader's byte-for-byte copy_file() overwrite would have destroyed that content -- the reconciliation had to be performed by hand first. A drift check would have surfaced this years earlier.

Implement check_deployed_rule_drift mirroring check_deployed_script_drift: for each manifest.provides.rules entry where BOTH the deployed .claude/rules/<name> and the extension source <ext>/rules/<name> exist, fail on content mismatch; skip with an info note (never fail) when the deployed copy is absent, since an extension's rules are not deployed in every consuming repo.

Also evaluate whether the same deployed-vs-source asymmetry applies to provides.agents, provides.commands, and provides.context, and whether a single drift helper parameterized by category is warranted rather than adding a fourth near-duplicate function.

Note: check-extension-docs.sh is itself declared in core's provides.scripts, so any edit must be written to BOTH .claude/scripts/ and .claude/extensions/core/scripts/ or the drift check will flag the change itself.

---

### 860. Enforce plan compliance rule
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [860_enforce_plan_compliance_rule/reports/01_plan-compliance-rule.md]
- **Plan**: [860_enforce_plan_compliance_rule/plans/01_plan-compliance-rule.md]
- **Summary**: [860_enforce_plan_compliance_rule/summaries/01_plan-compliance-rule-summary.md]

**Description**: Add a .claude/rules/ rule enforcing strict plan compliance for lean-implementation-agent and other formal implementation agents. The rule should: (1) Prohibit agents from "assessing what's truly minimal" or inventing alternative approaches when a plan exists. (2) Require agents to follow the plan's exact task sequence step-by-step, in order. (3) Explicitly ban common divergence patterns: skipping intermediate theorems, inlining proofs instead of following the plan's decomposition, routing through different helper lemmas than specified, and "cleaner approach" rationalizations. (4) Be auto-applied via glob pattern to formal proof files (e.g. Theories/**, **/*.lean); the glob must generalize across consuming repos rather than hard-coding one project's layout. (5) Reference the repeated failures in BimodalLogic task 157 (8 plan versions, agents diverging every time) as motivation. The rule should be concise but firm -- agents must treat the plan as a contract, not a suggestion.

Provenance: relocated from BimodalLogic task 162 (2026-07-14). Authored here in the agent-system source of truth so the rule syncs out to consuming repos, rather than living only in BimodalLogic/.claude/.

---

### 859. Fix generate-task-order.sh: dependency tree renders flat for non-lowercase topic strings (topic-key case mismatch)
- **Effort**: low
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [859_fix_task_order_topic_case_indentation/reports/01_topic-standardization.md]
- **Plan**: [859_fix_task_order_topic_case_indentation/plans/01_topic-normalization.md]
- **Summary**: [859_fix_task_order_topic_case_indentation/summaries/01_topic-normalization-summary.md]

**Description**: generate-task-order.sh renders the Grouped-by-Topic dependency tree FLAT (no indented '└─' children) for any topic whose raw string is not already all-lowercase. ROOT CAUSE: topic sections are grouped under a LOWERCASED key (`_current_section_topic` = the lowercased topic, set from the grouping key at generate_grouped_section), but the two guards that decide child recursion / cross-topic annotation compare that lowercased key against the RAW topic string from state.json. In .claude/extensions/core/scripts/generate-task-order.sh: line 578 `"$dep_topic" != "$_current_section_topic"` (successor-skip in _print_topic_node) and line 553 `"$task_topic_val" != "$_current_section_topic"` (cross-topic 'see above' annotation). For a task with topic 'Modal Logic', dep_topic='Modal Logic' but _current_section_topic='modal logic', so the strings never match, every successor is skipped, and the tree collapses to a flat list. Only all-lowercase topics (e.g. 'modal-logic') ever showed the tree; Title-Case topics ('Modal Logic', 'Code Hygiene', etc.) always rendered flat. FIX (already validated live in the deployed Projects/cslib copy): lowercase both sides of both comparisons — line 578 -> `"${dep_topic,,}" != "$_current_section_topic"` and line 553 -> `"${task_topic_val,,}" != "$_current_section_topic"`. After the fix the 491->495->496->484 chain indents correctly under a single Modal Logic heading. APPLY TO: (1) source-of-truth .claude/extensions/core/scripts/generate-task-order.sh (lines 553, 578); (2) mirror the same two-line change to .opencode/scripts/generate-task-order.sh (lines 481, 506) for OpenCode parity. The deployed .claude/scripts/generate-task-order.sh is regenerated from the core extension on load, so editing the core source is what persists; do not rely on the standalone .claude/scripts copy. VERIFY: after editing, run `bash .claude/scripts/generate-todo.sh` (or a fixture) on a state.json containing a Title-Case topic with an intra-topic dependency chain and confirm the '└─' indentation appears. RELATED REFINEMENT (optional, same file): the topic grouping key lowercases but does NOT normalize separators, so 'Modal Logic' and 'modal-logic' hash to different keys ('modal logic' vs 'modal-logic') and produce TWO identical-looking '### Modal Logic' headings. Consider normalizing hyphen<->space (and maybe collapsing whitespace) in the grouping key so case- and separator-variant topic strings collapse into one section, preventing duplicate headings. CONTEXT: discovered in Projects/cslib while normalizing kebab-case topic values to Title-Case, which merged two duplicate Modal Logic sections but exposed this latent case-sensitivity bug.

---

### 858. Fast, responsive, non-failing <leader>me aerc launch
- **Effort**: medium
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**:
  - [858_mail_launch_gate_performance/reports/01_launch-gate-performance-diagnosis.md]
  - [858_mail_launch_gate_performance/reports/02_hard-research-fast-responsive-launch.md]
- **Plan**: [858_mail_launch_gate_performance/plans/02_fast-responsive-aerc-launch.md]
- **Summary**: [858_mail_launch_gate_performance/summaries/02_fast-responsive-aerc-launch-summary.md]

**Description**: The <leader>me aerc launch workflow in lua/neotex/plugins/tools/mail.lua has become slow and now permanently refuses to open aerc. A single press triggers THREE overlapping sync layers -- (1) a himalaya-plugin inbox sync, (2) mail.lua sync_all_mail running the forbidden all-channels `mbsync -a` (which syncs Gmail All_Mail ~64k messages and fails code 1 on a pre-existing duplicate-UID collision), and (3) run_notmuch_new calling hook-ful `notmuch new`, whose preNew hook is now `mail-sync both` (dotfiles task 109), recursively driving a full serialized gmail+logos mbsync -- plus two email-census scans. All of it runs synchronously on the launch-blocking critical path, so the user waits for the slowest full sync before anything appears. The gate then refuses to open aerc because it conflates "mbsync succeeded" with "index is safe to read": the primary barrier requires mbsync -a + notmuch new to exit 0 (impossible while the duplicate-UID persists -- a manual data repair, not a sync fix), and the census fallback honestly reports [STALE]. Net effect: a sync-independent data fault permanently denies the mail client even though, after notmuch new reconciles the index, opening aerc would be safe. GOAL: redesign <leader>me for fast, responsive, non-failing launch -- open aerc promptly on a cheaply-reconciled index (notmuch new --no-hooks) with mbsync deferred/backgrounded and never on the launch-blocking path; decouple launch from mbsync exit code (warn, do not block); eliminate the redundant sync layers (route through the single mail-sync wrapper, use --no-hooks to avoid recursive re-sync, reconcile/suppress the himalaya double-sync); never use mbsync -a; keep the full explicit sync on <leader>mN. Must remain safe against opening onto a genuinely stale/mid-write Xapian index (no return of "could not get MessageInfo" races). Non-goal: the one-time duplicate-UID-15 maildir data repair, but the fix must make <leader>me usable despite an unrepaired collision. See reports/01_launch-gate-performance-diagnosis.md for the seed diagnosis; deep study to be produced by a fable --hard researcher.

---

### 857. Reindex-on-failure for the aerc launch gate
- **Effort**: small
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**: [857_mail_reindex_on_failure_gate/reports/01_reindex-on-failure-gate.md]
- **Plan**: [857_mail_reindex_on_failure_gate/plans/01_reindex-on-failure-gate.md]
- **Summary**: [857_mail_reindex_on_failure_gate/summaries/01_reindex-on-failure-gate-summary.md]

**Description**: Harden the <leader>me aerc launch gate in lua/neotex/plugins/tools/mail.lua so a failed `mbsync -a` no longer leaves notmuch stale before the freshness decision, providing a minimal, durable fix without unnecessary complexity.

CURRENT BEHAVIOR (verified in mail.lua): sync_all_mail() runs `notmuch new` ONLY when `mbsync -a` exits 0; on mbsync failure it notifies the error and returns via on_done(false) WITHOUT reindexing. The gate itself already refuses-and-reports rather than failing open -- it opens aerc only on a clean sync+reindex, or when census_freshness_ok() reads [ok] on BOTH accounts, otherwise it refuses with remediation guidance. That refuse-and-report barrier is sound and must be preserved.

GAP TO FIX (the real durable change): on the mbsync-failure path, run `notmuch new` BEFORE the freshness decision, so maildir files that already landed on disk -- or mailboxes that synced before an abort such as a duplicate-UID collision -- get reconciled into the index. Then let the existing authoritative barrier make the launch decision against a freshly reindexed state instead of a stale one.

SCOPE CONSTRAINTS:
- Keep the change minimal and cohesive (one function/gate); do not duplicate freshness logic that belongs in the external census wrapper.
- Preserve the existing refuse-and-report barrier and its remediation messaging.
- The fallback signal census_freshness_ok() reads the "INBOX freshness ... [ok]" line, a count-with-tolerance proxy that cannot detect flag-renames or phantom drift -- this is what produced the false green. Making that signal authoritative is an EXTERNAL follow-up in ~/.dotfiles modules/home/email/agent-tools/census.nix (rename/deletion-aware freshness) and is intentionally OUT OF SCOPE here. Document the dependency in the gate's comment so a future reader knows the barrier's trustworthiness rests on that external signal.

OUT OF SCOPE (context only, no repo change, no commit): one-time ~/Mail data repair for the duplicate UID 15 collision in Gmail/.All_Mail, and the one-time `notmuch new` index reconciliation of the ~38-file INBOX phantom drift. These are manual mail-data operations, not code.

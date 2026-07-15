---
next_project_number: 866
---

# TODO


## Tasks

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

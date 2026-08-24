# Change Log

All notable changes to the OpenCode system.

## Format

Each entry includes:
- Date
- Task number and name
- Type of change
- Brief description

---

### 2026-08-24

**Deploy: `agent-system/extensions/**` source store resynced to `.claude/` (16 files, 4 previously-completed fixes made live)**
- Status: completed
- Type: meta
- Summary: Ran `deploy-headless.sh` after 12 commits / 16 files of accumulated drift under
  `agent-system/`. All 16 files reconcile byte-identical between source and deployed tree
  post-deploy. The following work was authored earlier (in separately completed task directories)
  but only became **live at this deploy** — recorded here so a future reader does not misdate
  when these fixes actually took effect in the running system:
  - **`skill_orchestrate_mint_dispatch_seq` persisted-counter fix** in `scripts/skill-base.sh` —
    now derives the new dispatch sequence via `jq -r '(.dispatch_seq_counter // 0) + 1'` read back
    from the loop-guard file, instead of an ambient shell variable that collapsed to empty under
    `set -u` in a fresh shell/subprocess. Regression suite `scripts/tests/test-mint-dispatch-seq.sh`
    went from 4 failing cases (B, C, D, E, F) pre-deploy to 14/14 passing post-deploy.
  - **Literature conversion quality-gate hardening** (`literature-convert.sh`,
    `literature_quality_gate.py`) against control-character/mojibake PDF-extraction output —
    **HIGH severity**, a corpus-corruption vector on the pymupdf fallback conversion tier that
    could previously let unextractable PDFs pass silently into the global corpus and FTS index.
  - **Discovery tier-starvation and silent Tier-3-failure fix** in `literature-discover.sh` —
    Tier 3 (Semantic Scholar) failures were previously swallowed silently, and Tier 1 local-corpus
    hits could starve Tiers 2/3 under the default result limit; now surfaces failure notices and
    reserves per-tier quotas.
  - **Validate-mode directory-path false-positive fix** (the `-d` vs `-f` branch) in
    `skill-literature` validate mode, plus a `--dry-run` flag/doc mismatch fix in
    `literature-normalize-authors.sh`.
- Post-deploy `verify-deploy.sh` comparison against the pre-deploy baseline (captured verbatim
  before the deploy ran) found zero net functional regressions from this deploy: 29 findings
  resolved (the drift/missing-script findings above and the mint-dispatch-seq case failures); the
  10 pre-existing gate3 index-entries.json line-count mismatches and the pre-existing gate8
  single-source-assertion cluster survived unchanged, as expected. One additional finding newly
  appeared (`gate3` Rule S: `context/project/literature/patterns/shared-module-extraction-for-gate-checks.md`
  has no `index-entries.json` registration) but investigation traced it to the source store itself
  (the entry is also missing in `agent-system/extensions/literature/index-entries.json`, predating
  this deploy) — the same defect class as the already-known, out-of-scope
  `return-meta-artifacts-template.md` Rule S gap, made visible only because this deploy was the
  file's first-ever deployment. Not fixed here; belongs to a future source-store pass.

**Hand-edit: removed stale `mcp__lean-lsp__*` grant from the deployed `.claude/settings.json`**
- Status: completed
- Type: meta
- Summary: `.claude/settings.json` deploys under **install-once** semantics
  (`INSTALL_ONCE_ROOT_FILES` in `loader.lua`; copy-skip on existing target; unload-exclusion in
  `init.lua`), so once a project has its own copy, no redeploy ever overwrites it — the deploy
  above confirmed this empirically (the grant survived the full resync untouched). This makes
  `settings.json` effectively **user state**, not a regenerable deploy artifact, which is why
  hand-editing it here is the single sanctioned exception to the general rule that `.claude/**` is
  a disposable, source-store-regenerated tree. Removed the single `"mcp__lean-lsp__*"` array
  element (structure-aware edit; it was the last element of its array, so a bare line deletion
  would have left a trailing comma and produced invalid JSON — verified with `jq empty` and an
  exact element-count check, 24 to 23). The source copy
  (`agent-system/extensions/core/root-files/settings.json`) was already correct and was left
  untouched throughout. Note: the `validate-meta-write.sh` advisory hook, expected to fire and
  flag this as a boundary-rule warning, did **not** fire — its `is_meta_path` path-pattern list
  covers only `.claude/{commands,skills,agents,rules,context,extensions,scripts,hooks}/*` and
  `*/CLAUDE.md`, which does not include root-level files like `settings.json`. This is a real
  coverage gap in the advisory layer for install-once root files, observed but not fixed here
  (fixing the hook is out of scope for this deploy-and-remediate work).

---

### 2026-05-12

**Task 556: literature_awareness_planner_research**
- Status: completed
- Type: meta
- Summary: Added literature awareness to planner-agent.md (Stage 4.5), lean-research-agent.md (Literature Extraction Protocol), lean4.md (Literature Fidelity section)

**Task 555: update_proof_workflow_literature**
- Status: completed
- Type: meta
- Summary: Added literature-first stages to lean-implementation-flow.md, end-to-end-proof-workflow.md, and proof-construction.md

**Task 554: literature_fidelity_formal_policy**
- Status: completed
- Type: meta
- Summary: Created literature-fidelity-policy.md (257 lines) for formal extension with 5 anti-patterns, escalation protocol, domain guidance for logic/math/physics

**Task 553: literature_fidelity_lean_policy**
- Status: completed
- Type: meta
- Summary: Created literature-fidelity-policy.md (126 lines) for Lean extension with 4 anti-patterns, escalation protocol, usage checklist

**Task 551: fix_discord_link_session_discovery**
- Status: completed
- Type: neovim
- Summary: Fixed discord-link.lua session discovery to use correct opencode CLI field names

**Task 550: unify_ctrl_cr_toggle_and_agent_picker**
- Status: completed
- Type: neovim
- Summary: Fixed C-CR toggle for ClaudeCode, added leader-ac agent picker keymap

**Task 549: audit_relocate_temp_files**
- Status: completed
- Type: meta
- Summary: Relocated ~50 /tmp/ path references to specs/tmp/ across 14 files

**Task 547: research_mobile_agent_management**
- Status: completed
- Type: meta
- Summary: Implemented Neovim-side Discord integration with session linking and Telescope session picker

Memory harvest: 2 memories created (1 CONFIG, 1 INSIGHT) from task 547

---

### 2026-03-06

**Task OC_150: fix_todo_orphan_detection_completed_tasks**
- Status: completed
- Type: meta
- Summary: Fixed /todo orphan detection to properly handle completed tasks that appear in TODO.md but have been removed from state.json

**Artifacts:**
- specs/archive/OC_150_fix_todo_orphan_detection/reports/research-001.md - Analysis of orphan detection gap
- specs/archive/OC_150_fix_todo_orphan_detection/reports/research-002.md - Comparative analysis of .claude/ vs .opencode/ implementations
- specs/archive/OC_150_fix_todo_orphan_detection/plans/implementation-002.md - 5-phase implementation plan
- specs/archive/OC_150_fix_todo_orphan_detection/summaries/implementation-summary-20260305.md - Implementation summary

**Task OC_149: review_update_opencode_documentation_readme_files**
- Status: completed
- Type: meta
- Summary: Created 183 new README.md files achieving 100% coverage across 197 directories in .opencode/

**Artifacts:**
- specs/archive/OC_149_review_update_opencode_documentation_readme_files/reports/research-001.md - Comprehensive audit
- specs/archive/OC_149_review_update_opencode_documentation_readme_files/plans/implementation-001.md - 6-phase plan
- specs/archive/OC_149_review_update_opencode_documentation_readme_files/summaries/implementation-summary-20260305.md - Implementation summary

**Task OC_140: document_progressive_disclosure_patterns (TODO.md orphan)**
- Status: completed
- Type: meta
- Summary: Documentation task for progressive disclosure patterns from OC_137

**Artifacts:**
- specs/archive/OC_140_document_progressive_disclosure_patterns/reports/research-001.md - Documentation requirements

**Task OC_139: implement_stage_progressive_loading_demo (TODO.md orphan)**
- Status: completed
- Type: meta
- Summary: Research on stage-progressive loading for 40-50% context reduction

**Artifacts:**
- specs/archive/OC_139_implement_stage_progressive_loading_demo/reports/research-001.md - POC for progressive context loading
- specs/archive/OC_139_implement_stage_progressive_loading_demo/reports/research-002.md - Systematic review of 11 skills
- specs/archive/OC_139_implement_stage_progressive_loading_demo/plans/implementation-001.md - 3-phase implementation plan

**Task OC_138: fix_plan_metadata_status_synchronization (TODO.md orphan)**
- Status: completed
- Type: meta
- Summary: Research on three-way status synchronization gap between state.json, TODO.md, and plan files

**Artifacts:**
- specs/archive/OC_138_fix_plan_metadata_status_synchronization/reports/research-001.md - Root cause analysis

**Task OC_145: restore_settings_json_and_state_sync (ORPHAN)**
- Status: orphan_deleted
- Type: meta
- Summary: Empty orphaned directory with no state.json entry, removed during archival

**Directory Operations:**
- Moved 5 task directories to specs/archive/
- Deleted 1 empty orphaned directory (OC_145)

---

### 2026-03-05

**Task OC_142: implement_knowledge_capture_system**
- Status: completed
- Type: meta
- Summary: Implemented comprehensive knowledge capture system with three integrated features

**Changes:**
1. **Renamed /learn to /fix** (clean-break, NO backwards compatibility)
   - Removed: .opencode/commands/learn.md
   - Removed: .opencode/skills/skill-learn/
   - Created: .opencode/commands/fix.md
   - Created: .opencode/skills/skill-fix/
   - Updated: All documentation references across codebase
   - Migration: Use `/fix` instead of `/learn`

2. **Added task mode to /remember**
   - New syntax: `/remember --task OC_N`
   - Scans task artifacts (reports/, plans/, summaries/, code/)
   - Interactive artifact selection with multiSelect
   - 5-category classification taxonomy:
     * [TECHNIQUE] - Reusable method or approach
     * [PATTERN] - Design or implementation pattern  
     * [CONFIG] - Configuration or setup knowledge
     * [WORKFLOW] - Process or procedure
     * [INSIGHT] - Key learning or understanding
     * [SKIP] - Not valuable for memory

3. **Enhanced /todo with skill-todo**
   - Extracted embedded logic into dedicated skill
   - Added automatic CHANGE_LOG.md updates on archival
   - Added memory harvest suggestions from completed task artifacts
   - Interactive memory creation from task insights

**Breaking Changes:**
- `/learn` command completely removed (use `/fix` instead)
- No aliases, fallbacks, or backwards compatibility
- Muscle memory will need retraining

**Artifacts:**
- .opencode/commands/fix.md - New command (renamed from learn.md)
- .opencode/skills/skill-todo/SKILL.md - New skill definition
- .opencode/skills/skill-fix/SKILL.md - New skill (renamed from skill-learn)
- .opencode/commands/remember.md - Updated with --task mode
- .opencode/skills/skill-remember/SKILL.md - Updated with task mode
- specs/CHANGE_LOG.md - New changelog file

**Documentation Updated:**
- .opencode/commands/README.md
- .opencode/README.md
- .opencode/docs/guides/user-guide.md
- .opencode/docs/guides/component-selection.md
- .opencode/docs/guides/documentation-audit-checklist.md

---

### 2026-03-05

**Task OC_143: fix_skill_researcher_todo_linking**
- Status: completed
- Type: meta
- Summary: Fixed regression in skill-researcher where research reports were not being linked in TODO.md

**Root Cause:**
Missing `metadata_file_path` parameter in Stage 3 delegation prompt. The general-research-agent requires this parameter to know where to write its `.return-meta.json` file.

**Fix Applied:**
Added JSON delegation context to skill-researcher/SKILL.md Stage 3 including:
- `task_context` with task number, name, and language
- `metadata` with session_id, delegation_depth, and delegation_path
- `metadata_file_path` pointing to expected metadata file location

**Files Modified:**
- .opencode/skills/skill-researcher/SKILL.md - Added metadata_file_path parameter (lines 78-108)

**Memories Harvested:**
- [PATTERN] Metadata Delegation Pattern with .return-meta.json

---

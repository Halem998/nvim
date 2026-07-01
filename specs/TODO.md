---
next_project_number: 803
---

# TODO

## Task Order

*Updated 2026-07-01. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,772,777,778,780,782,783,787,791,795,796,802 | -- | agent-system, literature, email integration, ... |
| 2 | 773,774,779,781,785 | 772,778,780 | agent-system |
| 3 | 786 | 785 | agent-system |
| 4 | 788 | 786,787 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

772 [NOT STARTED] — [--hard IMPLEMENTATION leg: focus each agent round on an INDIVIDU
  └─ 773 [NOT STARTED] — The anti-analysis contract (H2, .claude/context/contracts/anti-an
777 [NOT STARTED] — [--hard RESEARCH leg: more effort, higher standards for quality, 
778 [NOT STARTED] — [--hard CORE EFFECT: relax the zero-debt policy to permit STRATEG
  └─ 774 [NOT STARTED] — [--hard PLANNING leg: make phases SMALLER and divide work into a 
  └─ 779 [NOT STARTED] — [--hard recovery discipline] Define an unambiguous recovery contr
780 [NOT STARTED] — [Working-tree preservation] Prevent agents from destroying uncomm
  └─ 779 [NOT STARTED] — [--hard recovery discipline] Define an unambiguous recovery contr (see above)
  └─ 781 [NOT STARTED] — [Context-overflow safety] Dispatched agents must detect context p
  └─ 785 [NOT STARTED] — Replace the repo-wide `git add -A` in the task commit pipeline wi
    └─ 786 [NOT STARTED] — Sweep the 40+ remaining `git add -A` references across the agent 
      └─ 788 [NOT STARTED] — Prevent concurrent sessions from clobbering a shared working tree
782 [NOT STARTED] — [Formal-domain context hygiene] Reduce the context that lean4/for
783 [NOT STARTED] — Fix the sorry-census methodology in the review/vet agent tooling 
787 [NOT STARTED] — Make multi-task creation declare dependencies based on FILE FOOTP
  └─ 788 [NOT STARTED] — Prevent concurrent sessions from clobbering a shared working tree (see above)
791 [PR READY] — Fix the <leader>al 'Load Core' loader so WezTerm lifecycle tab co
795 [NOT STARTED] — Reserve [PR READY]/pr_ready for type=pr tasks only. Fix a status-
796 [NOT STARTED] — Make topic assignment mandatory across ALL task-creation paths so

### Literature

802 [NOT STARTED] — [LITERATURE AUTHORS RESOLVER TRUNCATION -- latent footgun, follow

### Terminal Ui

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 802. Guard skill-literature authors resolver against string-to-first-char truncation
- **Effort**: 30 minutes
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None

**Description**: [LITERATURE AUTHORS RESOLVER TRUNCATION -- latent footgun, follow-up to task 801] In .claude/skills/skill-literature/SKILL.md at line ~1696 (per-repo sub-index Resolve operation), the authors resolver uses `(.authors // []) | first // "?"`. Because jq `first` on a JSON STRING returns its first CHARACTER (e.g. `"Yde Venema" | first` -> `"Y"`) rather than erroring, a string-typed `.authors` value is silently truncated to a single character instead of yielding the author name. `.authors // []` only substitutes on null/false, not on a string, so it does not protect this path. This is a DIFFERENT code path from the one task 799 fixed in literature-briefing.sh. The global corpus is currently normalized to arrays (task 801, ~/Projects/Literature commit c6eccfb), so this will not trigger in practice today, but any string-typed authors reaching this line (a source that bypasses migrate-from-repo.sh, or a not-yet-normalized index) would silently corrupt output. FIX: make the resolver type-aware, e.g. `if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end`. Scope: single line in .claude/skills/skill-literature/SKILL.md; small, self-contained. CONTEXT: flagged during task 801 research (report 01_authors-schema-normalization.md) and deferred as out-of-scope.

---

### 801. Normalize authors schema in Literature index generation (defense-in-depth)
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [801_literature_index_authors_schema_normalization/reports/01_authors-schema-normalization.md]
- **Plan**: [801_literature_index_authors_schema_normalization/plans/01_authors-schema-normalization.md]
- **Summary**: [801_literature_index_authors_schema_normalization/summaries/01_authors-schema-normalization-summary.md]

**Description**: [LITERATURE INDEX SCHEMA NORMALIZATION -- optional/defense-in-depth] The global Literature index (~/Projects/Literature/index.json) stores `authors` INCONSISTENTLY: 210 entries as an array, 12 as a plain string, and some arrays are malformed one-element comma-joined strings (e.g. ["Patrick Blackburn, Maarten de Rijke, Yde Venema"]). This inconsistency is the UPSTREAM root cause of the briefing crash (task 799). Consumer tolerance (task 799) is the SUFFICIENT functional fix; this task prevents recurrence at the source. FIX: audit the index-writing scripts -- literature-build-index.sh, literature-discover.sh, and any converter (literature-convert.sh / literature-chunk.sh) that writes an `authors` field -- and standardize on a SINGLE representation (RECOMMEND: array of individual author strings, splitting comma-joined values). Consider a one-time normalization pass over the existing index.json plus a validation check so future writes stay consistent. Scope: Literature-corpus tooling in .claude/scripts/, NOT the --lit dispatch path; genuinely optional relative to tasks 799-800. CONTEXT: authors-type histogram over ~/Projects/Literature/index.json = 210 array / 12 string; the 12 string-typed entries (burgess/venema/gabbay/reynolds/rabinovich/caleiro/hodkinson/goldblatt families) are exactly what the cslib sub-index references, triggering the task-799 crash.

---

### 800. Surface --lit briefing-generation failures in skill consumers (no silent no-op)
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [800_lit_briefing_failure_surfacing/reports/01_lit-briefing-failure-surfacing.md]
- **Plan**: [800_lit_briefing_failure_surfacing/plans/01_lit-briefing-failure-surfacing.md]
- **Summary**: [800_lit_briefing_failure_surfacing/summaries/01_lit-briefing-failure-surfacing-summary.md]

**Description**: [--lit FAILURE SURFACING] When literature-briefing.sh crashes, the --lit consumers cannot distinguish a script CRASH from a legitimately EMPTY briefing, so they silently proceed as if no literature exists -- violating CLAUDE.md's repeated `--lit is never a silent no-op` contract. ROOT CAUSE: skill Stage 4b captures briefing output as `LIT bytes: N` and treats 0 bytes as 'no literature'; literature-briefing.sh exits 0 on a legitimate empty result but NON-ZERO (e.g. 5) on crash, and the consumers ignore the exit status. FIX: update the --lit consumers -- skill-researcher, skill-planner, skill-implementer and their -hard variants (skill-researcher-hard, skill-planner-hard, skill-implementer-hard) -- so that when literature-briefing.sh exits NON-ZERO they emit a VISIBLE `[lit] briefing generation failed (exit N)` notice to the transcript (distinct from the legitimate empty case) instead of silently continuing with no literature. Prefer a single shared pattern/helper so all six skills stay consistent. Scope: error-surfacing only in the Stage 4b invocation of each skill; does NOT fix the underlying script (task 799 does that), but the two are complementary. CONTEXT: transcript .claude/output/lit.md -- the empty result was only caught because a human-driven researcher agent manually diagnosed it; an autonomous run (e.g. /orchestrate) would have silently lost all literature context.

---

### 799. Fix literature-briefing.sh authors-type crash + harden per-entry resilience
- **Effort**: 1-3 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [799_literature_briefing_authors_type_crash_fix/reports/01_authors-type-crash-fix.md]
- **Plan**: [799_literature_briefing_authors_type_crash_fix/plans/01_authors-type-crash-fix.md]
- **Summary**: [799_literature_briefing_authors_type_crash_fix/summaries/01_authors-type-crash-fix-summary.md]

**Description**: [--lit BRIEFING CRASH] literature-briefing.sh silently produces an EMPTY <literature-briefing> for any repo whose sub-index references a string-typed authors entry, so --lit injects nothing. ROOT CAUSE: line 144 runs `(.authors // []) | join(", ")`, which is a jq RUNTIME ERROR (exit 5) when .authors is a plain string. The global Literature index (~/Projects/Literature/index.json) stores authors INCONSISTENTLY (210 array vs 12 string entries; some arrays are one-element comma-joined strings like ["A, B, C"]). With `set -euo pipefail` (line 41) and the `jq ... | head -1` pipeline (pipefail surfaces jq's non-zero status), the failed command substitution aborts the ENTIRE script on the very first entry (e.g. burgess_1982_i). FIX: (1) normalize authors for BOTH array and string types at line 144, mirroring the tolerant pattern already present in literature-discover.sh:281 (`.authors // [] | if type == "array" then . else [.] end | join(", ")`); (2) harden the per-entry metadata-extraction loop so a single malformed/failing entry WARNS to stderr and is SKIPPED, rather than aborting the whole briefing via set -e (guard the per-entry jq extractions so pipefail/set -e cannot kill the run, or use defensive jq that never errors); (3) VERIFY by regenerating a briefing against the cslib sub-index (all 12 doc_ids: burgess_1982_i, burgess_1982_ii, reynolds_2001, venema_1993_since_until, venema_1993_anti_axioms, gabbay_1993, blackburn_2001, goldblatt_2003, rabinovich_2014, caleiro_2013, hodkinson_2006, blackburn_2002_book) and confirming a populated block with correct author rendering for both string- and array-typed entries. NOTE: this script is shared .claude/ infrastructure; the config-repo copy (~/.config/nvim/.claude/scripts/literature-briefing.sh) is the source of truth and the fix must stay consistent with any child-project copies (e.g. ~/Projects/cslib/.claude/scripts/). CONTEXT: transcript .claude/output/lit.md -- /research 464 --lit returned `LIT bytes: 0`; the researcher agent manually diagnosed exit 5 and hand-built the briefing inline as a workaround.

---

### 798. Literature zotero datadir and retry fixes
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [798_literature_zotero_datadir_and_retry_fixes/reports/01_zotero-datadir-retry-fixes.md]
- **Plan**: [798_literature_zotero_datadir_and_retry_fixes/plans/01_zotero-datadir-retry-fixes.md]

**Description**: Two follow-up fixes to task-797 assisted Zotero export generation, surfaced by user testing /literature 55 in ~/Projects/Logos/Hardware. PRIMARY FILES (task-793 dual-copy model: edit canonical under .claude/extensions/literature/scripts/, then byte-identical re-sync to .claude/scripts/): zotero-generate-export.sh, zotero-export-status.sh, and the /literature wiring in .claude/extensions/literature/commands/literature.md.

FIX 1 (dataDir auto-detection) -- BUG: both zotero-export-status.sh (classifier, Path 3 viability probe) and zotero-generate-export.sh (Path 3 sqlite reconstruction) hardcode the sqlite default to ${HOME}/Zotero/zotero.sqlite (only overridable via the ZOTERO_SQLITE_PATH env var). On any machine with a custom Zotero data directory this reads the wrong DB. Confirmed on this machine: the real library is /home/benjamin/Documents/Zotero/zotero.sqlite (878 bibliographic items, 92MB, set via extensions.zotero.dataDir + useDataDir=true in ~/.zotero/zotero/*/prefs.js), while the hardcoded ~/Zotero/zotero.sqlite is a stale EMPTY profile (0 items, 1.1MB). Because the empty file EXISTS, the classifier returns ZOTERO_EXPORT_MISSING_NOT_RUNNING and the generator writes a silently-EMPTY zotero-library.json -- no error, useless result. REQUIRED: before falling back to the ${HOME}/Zotero default, auto-detect Zoteros configured data directory by parsing extensions.zotero.dataDir (only when extensions.zotero.useDataDir is true) from the Zotero profile prefs.js (search ~/.zotero/zotero/*/prefs.js and ~/.mozilla/zotero/*/prefs.js; pick the default profile). Resolution order for the Path 3 sqlite: (1) $ZOTERO_SQLITE_PATH explicit override; (2) <dataDir>/zotero.sqlite from prefs.js when useDataDir=true; (3) ${HOME}/Zotero/zotero.sqlite default. Apply the SAME resolution in BOTH scripts (share via a helper function so they cannot drift). Verified working manually: ZOTERO_SQLITE_PATH=/home/benjamin/Documents/Zotero/zotero.sqlite zotero-generate-export.sh produced 1819 valid Better-CSL-JSON entries with synthesized citation-keys -- the reconstruction logic is correct; only the path resolution is wrong.

FIX 2 (open-Zotero-and-retry interactive branch) -- ENHANCEMENT: currently when Zotero is closed (ZOTERO_EXPORT_MISSING_NOT_RUNNING) the /literature offer goes straight to a Path 3 sqlite snapshot. Because Path 1 (live Zotero local API) is data-dir-agnostic and always reads the true open library, the primary interactive choice for the NOT_RUNNING case should instead be "Open Zotero, then retry": on that choice the /literature workflow re-runs zotero-export-status.sh and, once it flips to ZOTERO_EXPORT_MISSING_RUNNING, generates via Path 1. Requirements: (a) cap retries (~2-3) so an unopened/unreachable Zotero does not loop forever; (b) when the API stays non-200 even though the user says Zotero is open, surface the SPECIFIC fix -- enable Settings -> Advanced -> "Allow other applications on this computer to communicate with Zotero" (match zotero-search.sh wording style); (c) KEEP the Path 3 sqlite snapshot as an explicit SECONDARY choice ("generate an offline snapshot without opening Zotero") -- do not remove it (it is now correct once FIX 1 lands); (d) non-interactive/orchestrator-mode: do NOT loop or prompt -- fail with a VISIBLE logged error instructing the user to open Zotero (never write an empty file, never silent no-op). HONEST SCOPE NOTE: this does NOT guarantee success (API-disabled-while-running, genuinely-empty library, and non-interactive contexts still fail) -- the goal is to convert the dangerous silent-empty-snapshot failure into a clear, actionable, retryable error.

VERIFICATION: bash -n on all edited scripts; byte-identical diff between each canonical and flat copy; prefs.js parsing tested against this machine (must resolve to /home/benjamin/Documents/Zotero/zotero.sqlite and reconstruct 1819 entries); classifier must still emit exactly one directive token on stdout with rationale on stderr; literature-discover.sh pure-JSON-array stdout contract unchanged. OUT OF SCOPE: Tier 3 / Semantic Scholar; three-tier pipeline architecture; the literature.md whole-script 2>/dev/null capture; the orphaned zot-CLI subsystem.

---

### 797. Literature zotero export assisted setup
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [797_literature_zotero_export_assisted_setup/reports/01_zotero-export-assisted-generation.md]
- **Plan**: [797_literature_zotero_export_assisted_setup/plans/01_assisted-zotero-export-generation.md]
- **Summary**: [797_literature_zotero_export_assisted_setup/summaries/01_assisted-zotero-export-generation-summary.md]

**Description**: PRIMARY GOAL (assisted Zotero export generation, supersedes task-794 FIX 2 print-only hint per user direction "actually generate the zotero-library.json"): when $LITERATURE_DIR/zotero-library.json is MISSING, literature-discover.sh Tier 2 must present an INTERACTIVE AskUserQuestion offering to GENERATE the export automatically, and on agreement ACTUALLY create $LITERATURE_DIR/zotero-library.json in the Better CSL JSON shape that tier2_search / zotero-search.sh already consume. Feasibility confirmed on this machine: ~/Zotero/zotero.sqlite exists (1.1MB library), zotero-library.json absent, Zotero not running at check time. Generation paths use LOCAL Zotero only (these are the user's own Zotero on localhost -- NOT a remote/third-party API), in preference order: (1) Zotero 7 built-in local API http://127.0.0.1:23119/api/users/0/items?format=csljson when Zotero is running (no plugin, returns CSL-JSON directly); (2) Better BibTeX JSON-RPC at localhost:23119/better-bibtex/ when the BBT plugin is installed + Zotero running; (3) direct read of ~/Zotero/zotero.sqlite reconstructing CSL-JSON as a fallback when Zotero is CLOSED (the DB is locked while Zotero runs). Design must handle: Zotero-not-running detection (prompt the user to open Zotero, or use the sqlite fallback), and the snapshot-vs-keep-updated tradeoff (a one-time API/sqlite pull is a snapshot, NOT the auto-refreshing manual "Keep updated" export -- provide re-pull-on-demand or a clear staleness note). Non-interactive/orchestrator contexts: take a visible logged default, never a silent no-op. Match zotero-search.sh wording for any manual-steps fallback text. TIER 3 SCOPE LIMIT (per explicit user direction "I do not want to assume API access or anything more than web search for Tier 3; nothing fancy"): DO NOT build API-dependent Tier 3 handling. Specifically DROPPED from the earlier draft of this task: the Semantic Scholar 429/.message loud-failure detection and the top-N query-term-capping-for-Semantic-Scholar item -- both are out of scope. Do not assume Semantic Scholar (or any online) API access; Tier 3 should rely on nothing beyond web search. Leave existing Tier 3 behavior as-is unless a trivial web-search-only adjustment is warranted; invest no effort in SS-API-specific logic. CONTEXT: surfaced by user testing /literature 55 in ~/Projects/Logos/Hardware after tasks 793/794; the two 794 fixes (slug->description query, loud Tier 2 print hint) verified working -- this task upgrades ONLY the Tier 2 hint to assisted generation. PRIMARY FILES: .claude/extensions/literature/scripts/literature-discover.sh (canonical) + .claude/scripts/literature-discover.sh (byte-identical flat re-sync, task-793 dual-copy model); reference .claude/extensions/literature/scripts/zotero-search.sh for wording and the CSL-JSON shape. OUT OF SCOPE: three-tier pipeline architecture changes; Semantic Scholar API keys or any API-dependent Tier 3 enhancement; the literature.md whole-script 2>/dev/null stderr capture (separate follow-up).

---

### 796. Mandatory topic assignment
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Make topic assignment mandatory across ALL task-creation paths so tasks never land in Uncategorized. Root problem: three escape hatches produce topicless tasks — (1) the one-click Skip (no topic) option in Mode A pickers (/meta, /task create, /project-overview); (2) Mode B silent no-op when a parent task has no topic (topic-assignment-pattern.md:113 says no fallback, but /spawn, --expand, --review implementations DO have fallbacks — doc/impl divergence); (3) Mode C silent no-op when the /review and /fix-it path heuristic hits the other branch (:134). Plus /task --recover has zero topic handling and the meta-builder path can be bypassed entirely. FIX (source tree /home/benjamin/.config/nvim/.claude/, redeployed via <leader>al): rewrite canonical context/patterns/topic-assignment-pattern.md to drop Skip and make Mode A the universal fallback whenever no obvious topic exists (parent none / heuristic miss / batch null), keeping New topic always available; then update all callers to remove Skip and wire the fallback: agents/meta-builder-agent.md Stage 4.5, commands/task.md (create, --expand, --review, --recover which currently has none), commands/review.md and skills/skill-fix-it (Mode C other -> prompt), skills/skill-spawn, skills/skill-project-overview (errors.md inherits via /task). Reconcile the pattern-doc-vs-implementation divergence on Mode B fallback. Research/plan decisions: (a) remove Skip entirely vs keep a hard-to-reach explicit skip; (b) whether to add a defense-in-depth gate (generate-task-order.sh warns on topicless active tasks, or a validation check) so bypasses surface loudly. Out of scope: backfilling existing topicless tasks (/task --sync already does that).

---

### 795. Pr ready guard type pr
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Reserve [PR READY]/pr_ready for type=pr tasks only. Fix a status-lifecycle leak where cslib implementation tasks reach [PR READY] instead of [COMPLETED]. Three coordinated source-tree edits in /home/benjamin/.config/nvim/.claude/: (1) runtime guard in .claude/scripts/update-task-status.sh — reject preflight:pr_ready and postflight:pr_ready unless task_type==pr; (2) skill-cslib-implementation Stage 6 (extensions/cslib/skills/skill-cslib-implementation/SKILL.md) — spell out explicit postflight implement -> COMPLETED call mirroring skill-pr-implementation:95; (3) doc reconciliation in extensions/core/merge-sources/claudemd.md:36-37 — mark [PR READY] as type=pr-only, not the universal implementation terminus. Design decision for research/plan: guard in core update-task-status.sh (keyed on task_type==pr) vs pushing pr_ready/PR READY fully into the cslib extension; core doc must end up consistent with the choice. Out of scope: repairing the 5 already-mislabeled deployed tasks (447/404/407/438/453) in /home/benjamin/Projects/cslib/ state.json — separate manual data-repair after redeploy via <leader>al.

---

### 794. Fix /literature N discovery to query task description+title instead of the slug, and hint on missing Zotero export
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [794_literature_discover_query_from_description/reports/01_discover-query-fix.md]
- **Plan**: [794_literature_discover_query_from_description/plans/01_discover-query-fix.md]
- **Summary**: [794_literature_discover_query_from_description/summaries/01_discover-query-fix-summary.md]

**Description**: Improve /literature N source discovery quality by fixing two issues in literature-discover.sh (both surfaced by testing /literature 55 in ~/Projects/Logos/Hardware/ after task 793). Both changes edit the CANONICAL extension source .claude/extensions/literature/scripts/literature-discover.sh AND must re-sync the flat deployed copy .claude/scripts/literature-discover.sh to byte-identical (follow the task-793 dual-copy / provides.scripts flat-deploy model; do NOT touch other repos). FIX 1 (PRIMARY DEFECT -- useless slug query): For the --task N form, literature-discover.sh:105-132 builds the search query ONLY from .project_name (the task slug), converting underscores/hyphens to spaces (line 112-118). The slug describes the task ("collect_literature_sources_task_54" -> "collect literature sources task") not the subject matter, so Tier 1/3 match nothing and discovery returns []. FIX: derive query terms from the task .description AND .title fields in specs/state.json (read both via jq), apply stopword filtering and drop terms under 3 chars (reuse/extend the existing FILTERED_TERMS logic around line 454), and DROP the slug/.project_name entirely from the query (user decision: description+title only, slug is noise). Preserve the existing "--task N \"extra terms\"" behavior (extra terms still append). Keep graceful fallback if description is empty (then title; if both empty, error clearly). Confirm the /literature "free text query" path is unaffected. FIX 2 (UX GAP -- silent missing Zotero export): tier2_search (literature-discover.sh:334-336) silently returns 0 when $LITERATURE_DIR/zotero-library.json is absent, so the user never learns Tier 2 is disabled or how to enable it. FIX: when the export file is missing, print (once per run, to stderr so it does not corrupt the JSON results on stdout) a concise one-time setup hint: in Zotero, File -> Export Library -> format "Better CSL JSON" -> check "Keep updated" -> save to ~/Projects/Literature/zotero-library.json (or $LITERATURE_DIR/zotero-library.json). Do not error or change exit status; Tier 2 still no-ops. Match the wording already used by zotero-search.sh (which prints setup instructions on exit code 1) for consistency. VERIFICATION: (a) with a real task that has a topical description, /literature N now yields a query containing subject-matter terms (not "collect/literature/sources/task") and returns hits where the free-text form does; (b) confirm the missing-zotero-library.json hint prints to stderr and JSON stdout stays valid; (c) assert flat/canonical byte parity for literature-discover.sh; (d) run check-extension-docs.sh (must still PASS). OUT OF SCOPE: creating the zotero-library.json export (user action); changing the three-tier pipeline architecture; Semantic Scholar API behavior. PRIMARY FILES: .claude/extensions/literature/scripts/literature-discover.sh (canonical), .claude/scripts/literature-discover.sh (flat re-sync).

---

### 793. Fix literature extension script packaging so <leader>al deploys a working extension to all repos
- **Effort**: 2-4 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [793_literature_extension_script_packaging/reports/01_script-packaging-research.md]
- **Plan**: [793_literature_extension_script_packaging/plans/01_script-packaging-plan.md]
- **Summary**: [793_literature_extension_script_packaging/summaries/01_script-packaging-summary.md]

**Description**: Fix incomplete literature extension script packaging so the <leader>al "Load Core"/extension loader deploys a fully working literature extension to every repo, not just this source repo. ROOT CAUSE (confirmed): the picker deploys extensions via loader.copy_scripts() (lua/neotex/plugins/ai/shared/extensions/loader.lua:308-342), which copies ONLY the scripts named in manifest.provides.scripts, reading them from the extension's own scripts/ directory, and silently skips any not physically present there (filereadable guard, line 331). The literature extension's command/skill/agent reference several scripts that are NEITHER in manifest.provides.scripts NOR in .claude/extensions/literature/scripts/ -- they live only in this repo's deployed .claude/scripts/. So loading literature into another repo (e.g. ~/Projects/Logos/Hardware) omits them and /literature N fails (missing literature-discover.sh). SCOPE: (1) Migrate the referenced-but-unpackaged scripts into .claude/extensions/literature/scripts/ and add each to manifest.provides.scripts. Candidates (verify each is genuinely referenced by the literature command/skill/agent before packaging): literature-discover.sh (608), literature-ingest.sh (363), literature-search.sh (688), literature-build-index.sh (323), literature-convert.sh (364), literature-chunk.sh (423), literature-audit.sh (417). (2) Package literature-schema.sql (88 lines) correctly -- it is a .sql data file, NOT caught by copy_scripts or the sync *.sh glob; determine the right mechanism (likely manifest.provides.data or a data-copy path). literature-ingest.sh depends on it. (3) Fix inter-script path references broken by relocation -- e.g. literature-discover.sh:341-342 resolves zotero-search.sh via "$SCRIPT_DIR/../extensions/literature/scripts/..." which breaks once the script lives INSIDE the extension; audit all migrated scripts for $SCRIPT_DIR-relative and cross-directory .sh references and correct them for their new colocated location. (4) Resolve source-of-truth duplication with .claude/scripts/: after migration remove the now-orphaned copies from .claude/scripts/ (extension becomes source of truth) while ensuring THIS repo's own /literature still works (re-apply the extension to this repo if needed). Leave core-owned literature-retrieve.sh untouched. (5) Add an automated safeguard to .claude/scripts/check-extension-docs.sh (or a new lint) that flags any .sh referenced by an extension's commands/skills/agents but missing from that extension's manifest.provides.scripts, so this class of packaging bug is caught going forward; must exit non-zero on violation. (6) Document LITERATURE_DIR in the extension README (literature-discover.sh:36 already defaults it to ~/Projects/Literature, so no settings entry is required). VERIFICATION: simulate loader.copy_scripts + manifest against a clean target and confirm every script the literature command references is carried; run check-extension-docs.sh and confirm it passes for literature and would fail if a reference were removed from the manifest. PRIMARY FILES: .claude/extensions/literature/manifest.json, .claude/extensions/literature/scripts/, .claude/scripts/literature-*.sh, .claude/scripts/check-extension-docs.sh, lua/neotex/plugins/ai/shared/extensions/loader.lua (reference only). OUT OF SCOPE: redesigning the discovery pipeline logic; changing LITERATURE_DIR resolution.

---

### 791. Fix Load Core loader so WezTerm lifecycle tab coloring propagates to all synced repos
- **Effort**: 3-5 hours
- **Status**: [PR READY]
- **Task Type**: neovim
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [791_loader_wezterm_status_hook_merge/reports/01_loader-settings-merge.md]
- **Plan**: [791_loader_wezterm_status_hook_merge/plans/01_loader-settings-merge-plan.md]
- **Summary**: [791_loader_wezterm_status_hook_merge/summaries/01_loader-settings-merge-summary.md]

**Description**: Fix the <leader>al 'Load Core' loader so WezTerm lifecycle tab coloring works in every repo the agent system is copied into, not just this one. ROOT CAUSE (confirmed): lifecycle tab coloring (researching/planning/implementing/completed/blocked, etc.) is driven by the CLAUDE_STATUS WezTerm user variable, read in ~/.config/wezterm/wezterm.lua's format-tab-title handler (lines ~316-338). CLAUDE_STATUS is only set when a status-emitting hook fires (wezterm-notify.sh / wezterm-preflight-status.sh / wezterm-clear-status.sh). A hook fires only if (a) its script is present under .claude/hooks/ AND (b) it is REGISTERED in .claude/settings.json. Load Core syncs the hook SCRIPTS but NOT the registration: in lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua (scan_all_artifacts, lines ~894-910), settings.json uses install-only semantics -- copy if absent, replace only if a settings.json.managed marker exists, otherwise SKIP. So any target repo that already has a .claude/settings.json never receives the status-hook registrations, CLAUDE_STATUS is never emitted, and inactive tabs keep the default gray. This repo works only because its settings.json already registers the status hook. FIX DIRECTION (validate/refine during /research): instead of skipping settings.json wholesale, MERGE the core wezterm status-hook registrations into the target's existing settings.json without clobbering project-specific permissions/MCP servers. Infrastructure already exists: merge.lua provides merge_settings()/unmerge_settings() (lines ~229-263), and the core manifest (.claude/extensions/core/manifest.json:7-17) already declares merge_targets for claudemd and index but NOT settings. Add a merge_targets.settings fragment (core hook registrations) and wire the loader to merge it on Load Core, idempotently. Ensure the loader change also propagates to the synced .opencode tree if applicable, and keep the two synced .claude/ trees (dotfiles + nvim) consistent. Verify end-to-end: after Load Core into a repo with a pre-existing settings.json, the wezterm status hooks are registered and lifecycle tab coloring works. OUT OF SCOPE: redesigning the wezterm.lua color palette; the TASK_NUMBER title mechanism (already works). PRIMARY FILES: lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua, lua/neotex/plugins/ai/shared/extensions/merge.lua, .claude/extensions/core/manifest.json, .claude/extensions/core/root-files/settings.json.

---

### 788. Concurrent-session protection: task lock + mandatory commit-per-green-substep
- **Effort**: 4-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 786, Task 787

**Description**: Prevent concurrent sessions from clobbering a shared working tree (the 427 failure: an uncommitted in-progress task wiped by a concurrent session). USER-SELECTED SCOPE: lock + commit-per-step, NO git-worktree integration (keep the single shared tree; worktree isolation explicitly deferred). ROOT CAUSE: no concurrency protection exists -- manage-topics.sh assumes 'single-threaded sessions', state.json is last-write-wins, and nothing reserves a task for one session. Scope: (1) TASK LOCK: a session must reserve a task before working it -- a lock (lockfile under specs/{NNN}_{SLUG}/.lock or a state.json lock field) recording session_id + heartbeat timestamp; /orchestrate and /implement acquire on entry and REFUSE (with clear guidance) if a fresh lock is held by another session, with a stale-lock override threshold and release on completion/abort. (2) COMMIT-PER-GREEN-SUBSTEP: mandate an incremental commit at every green sub-step so in-progress work lives in git, not only the working tree -- align with checkpoint discipline and the scoped-staging contract from 785/786. (3) Coordinate with the 779/780/781 git-safety + checkpoint cluster (snapshot-before-rollback, checkpoint-before-overflow) so locking + commit cadence compose. OUT OF SCOPE: git worktree isolation (deferred). Depends on 786 (edits orchestrate.md/implement.md) and 787 (shared state schema + uses file_scope for lock granularity). Goal: a concurrent session can never silently destroy another session's uncommitted progress.

---

### 787. File-footprint-aware task dependency declaration (serialize same-file tasks)
- **Effort**: 3-5 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Make multi-task creation declare dependencies based on FILE FOOTPRINT OVERLAP, not just logical sequencing, so two tasks that will edit the same files are never dispatched in the same wave / run concurrently. ROOT CAUSE: dependencies[] exists in the schema but is used only for Kahn topo-ordering; task creation (multi-task-creation-standard Component 4) asks only about logical ordering, and territory/file-ownership (H7, context/contracts/territory.md) is hard-mode-only, per-phase, and declarative. Scope: (1) Add an optional task-level 'file_scope' (anticipated owned paths) field to the state.json task schema (.claude/rules/state-management.md + .claude/context/reference/state-management-schema.md), promoting H7 territory to a lightweight task-level declaration. (2) Extend multi-task-creation-standard.md Component 4 so creators capture each proposed task's file footprint and AUTO-ADD a dependency (or surface a conflict warning) when two footprints overlap. (3) Wire this into meta-builder-agent, skill-fix-it, and skill-spawn. (4) Document that /orchestrate and --team wave assignment must treat file-footprint overlap as a serialization edge. Goal: when the system proposes multiple tasks touching the same files, it declares the dependency automatically instead of leaving them parallelizable. This is the gap that let two same-file tasks run concurrently.

---

### 786. Propagate scoped-staging convention across all agent/command/skill templates
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 785

**Description**: Sweep the 40+ remaining `git add -A` references across the agent system to the canonical scoped-staging pattern established in task 785, so no template re-introduces repo-wide staging. SITES (from audit): implementation agents (general-implementation-agent.md:435, general-implementation-hard-agent.md:214, neovim:364, nix:384, python:116, web:432, founder, cslib-implementation-hard:261); commands (implement.md:187,192; plan.md:500; research.md:473; orchestrate.md:250,258,375,382; errors.md:197); skills (skill-implementer + extension implement/research skills); and doc/command templates (creating-commands.md:127, command-template.md, checkpoint-commit.md:10, checkpoint-execution.md:114, subagent-continuation-loop.md:127, workflow-interruptions.md:217, research-flow-example.md, creating-skills.md:403). Update the command/skill generator TEMPLATES so newly-created components inherit scoped staging by default. Leave cslib/pr.md's deliberate 'git add -A then exclude' flow alone unless it can be made scoped safely. Goal: scoped staging is uniform -- 'grep -rn "git add -A" .claude/' returns only intentional, documented exceptions. Depends on 785 (canonical pattern). Coordinate with the 779/781 hard-mode cluster on shared agent files (e.g. general-implementation-hard-agent.md).

---

### 785. Scoped git staging: eliminate `git add -A` in the commit pipeline
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 780

**Description**: Replace the repo-wide `git add -A` in the task commit pipeline with targeted, work-scoped staging so commits contain only files the operation actually produced. ROOT CAUSE: .claude/scripts/orchestrator-postflight.sh:322 runs 'git add -A && git commit', and agents track nothing about which files they modified -- so every research/plan/implement commit sweeps the entire working tree (including a concurrent session's stray edits). This contradicts the system's own policy: .claude/rules/git-workflow.md 'Commit Scope' (lines 51-62) and shared-core .claude/context/core/standards/git-safety.md (lines 182-195) already forbid 'git add -A'/'git commit -am' and prescribe targeted staging. Scope: (1) Define a commit-scope contract -- operation-type scope (research/plan -> specs/TODO.md + specs/state.json + specs/{NNN}_{SLUG}/; implement -> task dir + the source files the agent reports it modified) read from agent return-meta (modified_files) or a COMMIT_SCOPE param. (2) Rewrite orchestrator-postflight.sh (project + shared copy) to stage only those paths via 'git add <paths>', with 'git status --short'/'git diff --staged' review per the git-safety.md flow. (3) Harden git-workflow.md to explicitly FORBID 'git add -A'/'git commit -am' and reference the targeted-staging procedure. (4) Establish skill-git-workflow as the canonical scoped-commit helper. Goal: a commit reflects only the work actually accomplished, and a concurrent session's uncommitted changes can never be swept into this task's commit. Depends on 780 (also edits git-workflow.md, so serialized to avoid clobber).

---

### 783. Fix sorry-census to exclude comment/docstring lines (count only live proof debt)
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Fix the sorry-census methodology in the review/vet agent tooling so it stops counting Lean comment/docstring lines as proof debt. Root cause surfaced by cslib task 431 (origin repo: ~/Projects/cslib): the health-review census is a raw grep for 'sorry' over Cslib/**.lean, which swept up 7 docstring/comment occurrences (e.g. 'sorry-free', 'removing the sorry') plus a commented-out TODO stub, producing false 'unowned foundational sorry' findings. Moving to word-boundary 'sorry' did not help -- it still matches inside docstrings. Fix: make the census count only live proof debt -- strip Lean line comments (--) and block comments (/- -/) before matching, and/or cross-check against the compiler 'declaration uses sorry' warnings or #print axioms sorryAx. Update whichever shared agent-system tooling performs the census (the /review and/or /vet skills/scripts under .claude/). Evidence: cslib specs/431_audit_unowned_foundational_sorries/reports/01_unowned-sorries-audit.md, specs/reviews/review-2026-06-30.md, review-2026-06-30-2.md. Moved here from cslib (was task 437) because it is an agent-system change.

---

### 782. Formal-domain context hygiene: minimize goal-state context for lean4 agents
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [Formal-domain context hygiene] Reduce the context that lean4/formal-proof agents consume per step so enormous goal states do not overflow the window. MOTIVATING FAILURE: five dispatches on Lean tableau proofs overflowed because goal states are enormous and were repeatedly pulled into context. Scope (lean4 / formal domains -- applies to lean-*/cslib-* and formal hard agents and their context/contracts): (1) Goal-state query discipline: prefer TARGETED lean-lsp queries (lean_goal at a specific position, lean_minimal_hypotheses, lean_term_goal) over dumping full goal states; do NOT paste entire goal states into reasoning repeatedly; summarize the goal in a few lines and re-query precisely when needed. (2) File-read discipline: avoid re-reading whole large proof files; read only the region around the active proof; use lean_file_outline / targeted offset reads. (3) Hypothesis pruning: work from minimal hypotheses; avoid carrying large unused contexts forward. (4) Encode these as a formal-domain CONTEXT CONTRACT (an extension context file analogous to the lean4 override of anti-analysis.md) consumed by the lean/formal research + implementation hard agents. (5) Combine with checkpoint-before-overflow (task 781): hygiene lowers the baseline context; checkpointing handles the residual. SCOPE NOTE: this is domain-specific. If the lean/cslib extension lives in a separate repo, author the contract here and FLAG it for sync to that extension (do not assume the shared repo is the only consumer). Pairs with task 781. Goal: a single large goal state is handled by targeted querying and summarization rather than overflowing the agent's context.

---

### 781. Agent context-overflow safety: checkpoint + handoff before the hard limit
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 780

**Description**: [Context-overflow safety] Dispatched agents must detect context pressure and CHECKPOINT before hitting the hard context limit, instead of crashing mid-work. MOTIVATING FAILURE: five agent dispatches on Lean tableau proofs (enormous goal states) hit 'Prompt is too long'; on overflow an agent crashes WITHOUT writing a handoff, leaving a stale handoff and a RED working tree -- which then triggers the revert/work-loss failure (the next agent sees RED and reverts). Scope (general -- all dispatched implementation/research agents): (1) Wire the existing context-exhaustion-detection.md into the dispatched implementation and research agents (general-implementation-hard-agent, general-research-hard-agent, and base variants), not just the orchestrator -- they must monitor context-pressure signals (large tool outputs, repeated reads, growing goal states, high tool-call count) and treat approaching the limit as a STOP condition. (2) Define the CHECKPOINT-BEFORE-OVERFLOW procedure: at the pressure threshold, STOP taking new work -> commit the current green state (or snapshot via task 780 if RED) -> write a complete H9 handoff (.orchestrator-handoff.json + continuation markdown) naming the exact next action -> terminate cleanly. Never crash mid-edit; never leave a stale handoff. (3) Ensure the handoff captures enough for a FRESH agent to resume with minimal context (the continuation-handoff markdown already specifies this), so work is divided across agents by CONTEXT BUDGET, not lost. (4) Coordinate with the small-phase/skeleton work (774/778): if a phase's single goal state is too large to fit, the agent lands a strategic-sorry skeleton (778) and hands off rather than overflowing. Pairs with task 780 (snapshot) and task 779 (resume must fix-forward, not revert). Goal: context overflow degrades gracefully to a clean handoff + recoverable checkpoint, never a crash that loses uncommitted progress. Depends on task 780 (snapshot mechanism for the RED-checkpoint path).

---

### 780. Agent git-safety: preserve uncommitted work, guard destructive git ops
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [Working-tree preservation] Prevent agents from destroying uncommitted progress via destructive git operations, and require a recoverable snapshot before any rollback. MOTIVATING FAILURE: an implementation agent ran a revert-to-last-green-commit that discarded uncommitted forward progress (FreshAbove scaffolding + an 8->4 sorry reduction); the work existed only in the working tree and was lost. Two layers: (1) RULE (behavioral): extend .claude/rules/git-workflow.md with a 'no destructive git on uncommitted work' rule -- agents MUST NOT run git operations that discard working-tree changes (git reset --hard, git checkout -- <path>, git checkout/switch that would overwrite changes, git restore <path>, git clean -fd, git stash drop/clear) while uncommitted changes exist, UNLESS a snapshot was just taken. Before any intentional rollback the agent MUST snapshot recoverably: a WIP commit on a scratch/throwaway branch, OR a .patch artifact under specs/{NNN}_{SLUG}/ (e.g. working-progress-{ts}.patch), OR at minimum git stash (without drop). (2) HOOK (enforced): add a PreToolUse hook (registered via settings.json / the hooks system, e.g. .claude/scripts/guard-destructive-git.sh) that intercepts Bash tool calls, detects the destructive git patterns above, and BLOCKS them (deny / non-zero) with corrective context UNLESS (a) the working tree is clean, or (b) a snapshot marker shows a snapshot was just created. The hook returns guidance pointing to the snapshot-first procedure. Model it after the existing PostToolUse validators (e.g. validate-meta-write.sh) and the hooks registration pattern in .claude/. (3) Provide a tiny helper the agent calls to snapshot (write the .patch + record the marker the hook checks). Scope: applies to ALL agents (not just hard-mode) -- accidental destruction is universal -- but keep it lightweight so legitimate clean-tree operations (e.g. checkout on a clean tree) are not blocked. Pairs with task 779 (snapshot-before-rollback is rung c of the recovery ladder). Goal: a misread or mistaken instruction can never irreversibly destroy uncommitted agent work.

---

### 779. Hard-mode: fix-forward recovery contract (disambiguate 'restore green')
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 778, Task 780

**Description**: [--hard recovery discipline] Define an unambiguous recovery contract so 'reach green' / 'restore green' / 'get back to green' ALWAYS means FIX FORWARD (make the current working tree green by adding/correcting code) and NEVER means revert/reset/checkout to a prior green commit. MOTIVATING FAILURE: an orchestrator instruction 'if RED, first restore green' was misread by an implementation agent as 'revert to last green commit', discarding uncommitted forward progress (new FreshAbove scaffolding AND an 8->4 sorry reduction); the working tree was reset to the committed baseline and the progress was lost. Scope of changes: (1) Create/extend a recovery contract (e.g. .claude/context/contracts/recovery.md, or a section in wrap-up.md) stating: 'green' is reached by FIXING FORWARD only; an agent MUST NOT discard uncommitted work to reach green. (2) Define the canonical RECOVERY LADDER for a RED state: (a) fix forward; (b) if a sub-goal is genuinely blocked, land a documented STRATEGIC-SORRY skeleton (task 778) so the build goes green WITHOUT losing structure; (c) only if a rollback is truly required, SNAPSHOT first (task 780) then roll back, preferring the smallest revert scope. (3) Bake this into the hard-mode implementation contract (anti-analysis / wrap-up, consumed by general-implementation-hard-agent and skill-implementer-hard) and into skill-orchestrate-hard's dispatch prompt construction, so the orchestrator emits the disambiguated phrasing BY DEFAULT and does not rely on ad-hoc wording. (4) Align error-handling.md Build Error Recovery ('Keep source unchanged' / 'Never lose completed work') with the fix-forward language so guidance is consistent across docs. Scope: hard-mode primarily, but the fix-forward phrasing must be safe for standard mode too. Depends on task 778 (strategic-sorry skeleton = ladder rung b) and task 780 (snapshot-before-rollback = ladder rung c). Goal: a single ambiguous recovery instruction can never again be read as 'destroy uncommitted progress.'

---

### 778. Hard-mode: relax zero-debt for strategic-sorry skeletons (division mechanism)
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [--hard CORE EFFECT: relax the zero-debt policy to permit STRATEGIC SORRIES forming a SKELETON that divides the task into parts.] A primary effect of --hard is that the standard zero-debt / build-green completeness requirement is RELAXED to allow deliberately-placed, documented 'strategic' sorries (placeholder stubs) that scaffold a skeleton of the overall objective. The skeleton's strategic sorries are the DIVISION POINTS: each becomes a discrete part / follow-up task. This is the mechanism that connects the planning leg (task 774: skeleton + follow-up tasks) to the implementation leg (task 772: one phase per round). Scope of changes (hard-mode ONLY): (1) Relax zero-debt enforcement under --hard -- update the wrap-up build-green invariant (.claude/context/contracts/wrap-up.md, 'No leftover scaffolding' clause) and the anti-analysis Sub-Sorry Policy (.claude/context/contracts/anti-analysis.md) so a documented strategic-sorry skeleton is an ACCEPTABLE dispatch outcome under --hard. Under STANDARD mode, zero-debt still holds unchanged. (2) Define what makes a sorry 'strategic' and acceptable: a deliberate division boundary on the skeleton (NOT an abandoned proof), tightly scoped, documented with (a) what it assumes, (b) why deferred, (c) which follow-up task/part will discharge it. (3) Require every strategic sorry to map to a TRACKED part -- a follow-up task (created by planner-hard, task 774) or a sub-phase -- so relaxed zero-debt is VISIBLE and TRACKED, never silently abandoned. (4) Update the hard implementer/agent verification (skill-implementer-hard / general-implementation-hard-agent) and the handoff sorry_inventory so a documented strategic-sorry skeleton is reported as 'implemented (skeleton)' rather than 'failed/partial', while the sorry_inventory MUST enumerate every strategic sorry and its owning follow-up task. (5) Build-green still holds: the skeleton with strategic sorries must still compile/typecheck (sorries are valid placeholders), so 'green build with tracked strategic sorries' is the hard-mode skeleton-completion bar. Domain note: Lean4 'sorry' is the canonical strategic placeholder; the same idea applies to other domains (stubbed functions, 'admit', NotImplemented). CONTEXT: on task 305 the zero-debt expectation (no incomplete proofs) combined with an oversized phase pushed the orchestrator to try to fully prove a research-grade lemma in one round, driving burnout; allowing a strategic-sorry skeleton would have let it land the structure and divide the remaining proof obligations into tracked parts. Foundational --hard policy that the planning leg (774) and implementation leg (772) build on.

---

### 777. Hard-mode research: more effort, higher quality and verification standards
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [--hard RESEARCH leg: more effort, higher standards for quality, consistency, and verification of findings.] Strengthen hard-mode research (skill-researcher-hard / general-research-hard-agent, and domain research-hard agents where applicable) so --hard research is materially more rigorous than standard research, not just a relabel. (1) Raise the effort/coverage bar: require broader source coverage and deeper investigation before concluding (more searches, cross-checking multiple independent sources, no single-source conclusions). (2) Higher quality + consistency standards: require findings to be internally consistent and cross-validated; surface and RESOLVE contradictions rather than reporting them flatly. (3) Harden VERIFICATION of findings: extend the existing H4 adversarial self-verification and H3 reference grounding so every load-bearing claim is verified against a concrete source or counterexample before it ships, and uncertain claims are explicitly marked with confidence levels. (4) Encode the higher standard as enforceable CONTRACT language (analogous to the anti-analysis contract), in the research-hard skill/agent and any research-hard contract file, not just prose. Scope: hard-mode only; do NOT change standard research. CONTEXT: completes the three-leg --hard model alongside the implementation leg (task 772) and the planning leg (task 774). Motivating evidence: in transcript .claude/output/lit.md a hasty inline (non-hard) research conclusion was later found UNSOUND by a more careful standard-mode audit -- hard research should make that level of verification the default, raising confidence in the findings that drive planning and implementation.

---

### 776. Make --lit navigation work for ad-hoc dispatch and sync stale CLAUDE.md docs
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 775
- **Research**: [776_lit_adhoc_dispatch_navigation_doc_sync/reports/01_lit-adhoc-dispatch-doc-sync.md]
- **Plan**: [776_lit_adhoc_dispatch_navigation_doc_sync/plans/01_lit-adhoc-navigation-doc-sync.md]
- **Summary**: [776_lit_adhoc_dispatch_navigation_doc_sync/summaries/01_lit-adhoc-navigation-doc-sync-summary.md]

**Description**: Two coupled fixes so --lit works outside the formal /research N --lit command path and is documented accurately. (1) Ad-hoc dispatch directive: create a reusable 'literature navigation directive' that the primary/orchestrator agent injects when the user asks for --lit conversationally (not via skill Stage 4a). When no per-repo sub-index exists, this path must surface the SAME interactive question defined in task 775 (create curation task vs use global now) -- it must NOT silently inject nothing and must NOT silently auto-search. Once a path is chosen, the dispatched agent receives the <literature-briefing> navigation instructions (run literature-search.sh against the chosen corpus, Read the relevant segmented chunk files). Reference how Stage 4a generates lit_context. (2) CLAUDE.md doc sync: the 'Literature Mode (--lit)' section still describes the DEPRECATED static-dump model (literature-retrieve.sh, <literature-context>, 'reads all .md and .txt files from specs/literature/', TOKEN_BUDGET=4000/MAX_FILES=10). Rewrite the 'What --lit Does' and 'Interactive Sub-Index Setup Detection' subsections to describe (i) the live navigate-on-demand briefing (literature-briefing.sh -> <literature-briefing>) against the global segmented corpus, and (ii) the interactive no-silent-fallback behavior from task 775 (create-curation-task vs use-global-now). Reconcile the token-budget drift (literature-retrieve.sh header 8000, CLAUDE.md 4000, global index.json 8000). Root causes: G3 (navigation reachable only from skill Stage 4a), G4 (stale CLAUDE.md misdocuments --lit). Depends on task 775 (documents the interactive behavior 775 implements).

---

### 775. --lit: interactive prompt when no per-repo sub-index (no silent fallback)
- **Effort**: 3-6 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [775_lit_global_corpus_fallback_briefing/reports/01_lit-no-silent-fallback.md]
- **Plan**: [775_lit_global_corpus_fallback_briefing/plans/01_lit-global-corpus-briefing.md]
- **Summary**: [775_lit_global_corpus_fallback_briefing/summaries/01_lit-global-corpus-briefing-summary.md]

**Description**: [--lit, NO SILENT FALLBACK] When --lit is used but no per-repo specs/literature-index.json sub-index exists, the system MUST present an INTERACTIVE question (AskUserQuestion) -- never silently do nothing, and never silently auto-search. The question asks the user to choose between: (a) CREATE A TASK to curate a per-repo sub-index (so future --lit runs use a focused, repo-specific selection from the global corpus), or (b) POINT TO THE GLOBAL corpus now (run a relevance search against the global ~/Projects/Literature FTS5 index via literature-search.sh, keyed by the task description, and build a <literature-briefing> from the top-N matching segments for this run). (1) literature-briefing.sh must accept the task description/query (it currently takes no arguments) and support a global-corpus briefing mode used by option (b). (2) Wire the interactive prompt into the skill Stage 4a callers (skill-researcher, skill-researcher-hard, skill-planner, skill-planner-hard, skill-implementer, skill-implementer-hard) -- reconcile with / replace the existing 3-option Stage 4a flow (Skip / Create setup task / Create+run) so the choice is clearly 'create curation task' vs 'use global now', and NO branch silently yields an empty briefing. (3) Either briefing path always carries the 'How to Use' footer directing the agent to run literature-search.sh and Read the relevant segmented chunk files. (4) DESIGN QUESTION to resolve during /plan: define the default for autonomous contexts (e.g. /orchestrate) where AskUserQuestion cannot prompt -- it must be a VISIBLE, logged choice (e.g. default to global with a logged notice, or create-and-defer), never a silent no-op. Root causes: G1 (hard gate + silent empty exit), G2 (no global-corpus option). SUPERSEDES the earlier non-interactive auto-fallback design per user direction: 'I don't like fallbacks which are silent.' CONTEXT: transcript .claude/output/lit.md -- no sub-index existed, briefing silently exited empty, the agent got nothing from --lit and fell back to web/training knowledge; the segmented global corpus (222 entries + queryable FTS5 .literature.db via literature-search.sh) was never explored.

---

### 774. Hard-mode planning: smaller phases + skeleton plan with follow-up tasks
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 778

**Description**: [--hard PLANNING leg: make phases SMALLER and divide work into a SKELETON plan + follow-up tasks.] Revise hard-mode planning (skill-planner-hard / planner-hard-agent) so that under --hard the plan is decomposed into genuinely small phases, each completable in one bounded agent round, rather than one large open-ended plan ('Phase 1 strike 3: prove merge_forward_succ' was research-grade). (1) Tighten H8 phase sizing so each phase is a minimal bounded unit (e.g. one lemma / one checklist sub-item / ~100-300 lines output), not a multi-part objective. (2) Add a SKELETON-PLUS-FOLLOW-UP decomposition: when the full objective exceeds what a few small phases can cover, planner-hard produces a SKELETON plan covering the core/critical path and SPAWNS follow-up tasks (via the task-spawn / multi-task-creation mechanism) for the remaining work, instead of inflating phases. The skeleton plan and its follow-up tasks are linked via state.json dependencies. (3) The SKELETON is realized with STRATEGIC SORRIES per the relaxed zero-debt policy (task 778): planner-hard plans the skeleton so that deliberately-placed, documented sorries sit at the DIVISION BOUNDARIES, and EACH strategic sorry maps to a follow-up task/part. The division into follow-up tasks is therefore concretely driven by where strategic sorries are placed on the skeleton -- each sorry's deferral comment names the follow-up task that will discharge it. (4) Ensure the resulting small phases feed the implementation leg (task 772) so each implement round handles exactly one phase. (5) Extend the handoff schema (.claude/context/contracts/wrap-up.md) as needed to track skeleton-vs-follow-up status and the strategic-sorry-to-task mapping, and update skill-implementer-hard Stage 3b to consume the smaller phases. Root cause: RC4 (phases not regimented; oversized open-ended phases drove orchestrator burnout on task 305). Scope: hard-mode only. CONTEXT: part of making --hard proceed in regimented bounded chunks (transcript /orchestrate 305 --hard --lit, .claude/output/hard.md). This is the PLANNING leg of the three-leg --hard model (research=task 777, planning=this task, implementation=task 772), built on the relaxed zero-debt / strategic-sorry policy (task 778). Depends on task 778.

---

### 773. Add orchestrator-role discipline contract and burnout circuit-breaker
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 772

**Description**: The anti-analysis contract (H2, .claude/context/contracts/anti-analysis.md) is injected only into IMPLEMENT dispatches via build_hard_mode_prompt_context -- the orchestrator ROLE itself is ungoverned, which is why burnout happened in the orchestrator's own context. Create a new contract (e.g. .claude/context/contracts/orchestrator-discipline.md) binding the orchestrator role: NO inline design/proof analysis, NO reading implementation source, NO running builds, NO strategy reconsideration; when a phase cannot complete in a bounded dispatch, the only allowed responses are (a) dispatch a fresh research/audit agent, or (b) escalate via the blocker ladder -- NEVER absorb the work. Wire this contract into skill-orchestrate-hard so it is referenced/enforced at the top of the state-machine loop (analogous to anti-analysis.md injection into implement dispatches). Add a burnout circuit-breaker: detect orchestrator context-exhaustion signals (repeated re-reads of the same file, multiple consecutive inline-reasoning turns with no Agent dispatch, mid-analysis strategy reversal) and force a handoff/dispatch instead of continuing inline. Reference existing context-exhaustion-detection.md if present. Root causes: RC2 (orchestrator role ungoverned by H2), RC5 (no burnout circuit-breaker). Scope: hard-mode only. CONTEXT: burnout signatures in transcript -- circular reconsideration (built renameNF_eval_dup -> doubted it -> abandoned -> re-added -> stripped -> re-added a hypothesis), explicit 'before I concede... ONE more time' (line 2009); ended marking phase BLOCKED with an UNSOUND inline conclusion later caught by a standard-mode audit.

---

### 772. Make hard-mode orchestrator a pure dispatcher (strip implementation capability)
- **Effort**: 3-6 hours
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: [--hard IMPLEMENTATION leg: focus each agent round on an INDIVIDUAL PHASE, never the entire plan.] Make skill-orchestrate-hard structurally incapable of doing implementation work itself, forcing per-phase delegation. (1) Remove `Edit` from skill-orchestrate-hard `allowed-tools` (currently `Agent, Bash, Read, Edit`) so the orchestrator cannot directly modify source files -- it used Update ~10 times on task 305. (2) Constrain Bash to orchestration-only operations (jq/state.json reads, git status/log, status-sync scripts) and explicitly forbid build/test/compiler invocations (lake build, lean-lsp, etc.) in the orchestrator context. (3) Require BLOCKING, foreground single-phase dispatch: exactly one Agent call per cycle, wait for its handoff return, never interleave the orchestrator's own work -- forbid background/parallel dispatch of implementation agents (root cause: transcript line 92 'launched it in the background and will continue the orchestration'). (4) Restrict orchestrator Reads to handoff JSON, state.json, and plan files ONLY -- forbid reading implementation source files. (5) Under the relaxed zero-debt policy (task 778), a VALID outcome of an implementation round is a green-building strategic-sorry SKELETON for the phase -- each strategic sorry documented and mapped to a tracked follow-up part -- rather than a fully complete phase; the orchestrator must ACCEPT and route such skeleton handoffs (reading the sorry_inventory) as progress, not demand completeness in one round. Root causes: RC1 (orchestrator had Edit + unrestricted Bash), RC3 (H1 not enforced as a hard loop boundary; background dispatch). Scope: hard-mode only; do NOT modify base skill-orchestrate. CONTEXT: /orchestrate 305 --hard --lit (transcript .claude/output/hard.md) -- the orchestrator became the implementation agent (lines 954-2700: zero implementation dispatches, only inline proof reasoning + ~10 direct Update/lake-build/lean-lsp calls). Goal: each --hard implementation round dispatches exactly ONE phase to a bounded sub-agent; the orchestrator never takes the plan as a whole. Pairs with the planning leg (task 774), which produces the small phases / strategic-sorry skeleton this leg consumes, and the relaxed-debt policy (task 778).

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Task Type**: neovim
- **Topic**: Email Integration
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted. The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

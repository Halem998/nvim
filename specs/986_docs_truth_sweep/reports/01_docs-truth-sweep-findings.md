# Research Report: Task #986

**Task**: 986 - Docs truth sweep: retire dispatch-agent fiction, dead-script refs, doc consolidation
**Started**: 2026-08-09
**Completed**: 2026-08-09
**Effort**: Large (9-item inventory, cross-cutting docs/context sweep)
**Dependencies**: 951, 960, 961, 962, 963, 969, 980, 982, 983, 984, 985, 987, 989, 992 (all landed this session per task description)
**Sources/Inputs**: Codebase grep/read against `agent-system/extensions/**` (source store), `git log` for predecessor-task fallout, `specs/reviews/review-2026-07-29-agent-system.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- All 9 inventory items were re-verified against current source-store files. **7 of 9 remain live and actionable as described**; **item 8 (skill-lifecycle.md) is fully resolved already and should be dropped from scope**; **item 6's severity/target-size estimate needs correction** (deploy-gap narrative is accurate, not obsolete; ~60-line target is unrealistic — ~110-115 lines is achievable).
- Two genuinely **new findings** surfaced beyond the original inventory: (a) a stray `settings.local.json` permission-allowlist entry referencing the now-deleted `self-healing-implementation-details.md`; (b) a predecessor task (989 phase 1) already updated one of the two agent-template.md files' frontmatter guidance but not the other, making the two-template split (item 7) *newly inconsistent* rather than merely duplicative.
- Recommended approach: scope this task's plan around the 8 live items (1-7, 9), explicitly excise item 8, and use this report's exact file:line evidence to bound edits tightly (avoid re-scanning).

## Context & Scope

Task 986 is the final task in a 14-task dependency chain, all of which landed earlier in this session and changed the documentation ground truth the original review (`specs/reviews/review-2026-07-29-agent-system.md`) was written against. This research re-verifies every one of the review's 9 docs/context findings against **current** file state rather than trusting the task description's line numbers, which the task description itself flags as potentially stale.

All investigation was split across three parallel fork agents (items 1-2, items 3/4/7/8, items 5/6/9), each grepping/reading the source store directly. Findings below are consolidated and cross-checked for internal consistency.

## Findings

### Item 1 — Dispatch-agent fiction: VERIFIED-CURRENT, unchanged

- `agent-system/extensions/core/docs/architecture/system-overview.md:7` still asserts: *"This document describes the **current** architecture including skill-base.sh lifecycle functions, command gate scripts, dispatch-agent.sh, the /orchestrate autonomous state machine..."*
- `agent-system/extensions/core/docs/architecture/architecture-spec.md` is still exactly 599 lines. `dispatch-agent` hits at lines 10, 32, 263, 265, 270, 273, 306, 526, 551, including a full "Component 4: dispatch_agent() Function" section (line 263) and `**File location**: .claude/scripts/dispatch-agent.sh` (line 265).
- `agent-system/extensions/core/docs/fork-patterns.md:55` already admits it's obsolete: *"The `FORK_SUBAGENT` env var mechanism (referenced in the old `dispatch-agent.sh`) is no longer..."*
- `dispatch-agent.sh` does not exist anywhere under `agent-system/extensions/**` (confirmed via `find`).
- `dispatch-agent-spec.md` does not exist; cited exactly 4 times as the task claimed: `architecture-spec.md:10`, `architecture-spec.md:306`, `docs/guides/creating-agents.md:685`, `docs/templates/README.md:339`.

**Action for planner**: retire or rewrite `architecture-spec.md` (599 lines describing a non-existent component in detail — largest single fiction surface), fix `system-overview.md:7`, remove all 4 `dispatch-agent-spec.md` citations.

### Item 2 — Nonexistent script references: VERIFIED-CURRENT (8/8), plus a severity correction

All 8 named scripts confirmed absent from `agent-system/extensions/**`, and **none** appear in either quarantine `deprecated/` directory (`core/scripts/deprecated/`, `literature/scripts/deprecated/` both checked) — none were legitimized by the recent quarantine sweep; all 8 remain genuinely dangling:

| Script | Location(s) | Line(s) |
|---|---|---|
| `postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh` | `context/patterns/jq-escaping-workarounds.md` | 272-274, 278 |
| `postflight-workflow.sh` | `docs/architecture/architecture-spec.md` | 148, 511, 549 |
| `nix-postflight.sh`, `nix-verify.sh` | `docs/architecture/architecture-spec.md` | 369, 370 |
| `cleanup-stale-sessions.sh` | `context/orchestration/sessions.md` | 118 |
| `validate-context-refs.sh`, `update-context-refs.sh` | `docs/guides/context-loading-best-practices.md` | 749, 756, 844, 888, 889 (5 hits, more than task implied) |
| `validate-all-standards.sh` | `context/standards/postflight-tool-restrictions.md` | 208 |
| `test-implement-pipeline.sh` | `context/standards/shell-script-testing.md` | 16 |

**Correction to task's severity claim**: `context/patterns/jq-escaping-workarounds.md` is **not** "always-loaded." Its `index-entries.json` entry has `load_when.agents: [meta-builder-agent, general-implementation-agent, general-implementation-hard-agent]` and `load_when.commands: [/errors, /meta]` — no `always: true` flag. It's reachable only via an `@`-pointer at `merge-sources/claudemd.md:634` ("Full documentation: @.claude/context/patterns/jq-escaping-workarounds.md"), and `@`-references in CLAUDE.md are not auto-expanded into every prompt. The dead recipes still need fixing, but the task's "ships in every prompt" framing overstates blast radius — it's agent/command-scoped, not universal.

**New findings (predecessor-task fallout)**:
- `state-template.json`: zero references remain anywhere in `agent-system/extensions/**` — the state-schema predecessor task's deletion left no dangling citations. Clean, no action needed.
- `self-healing-implementation-details.md`: one stale reference, not doc prose — a leftover Bash permission-allowlist entry at `agent-system/extensions/core/root-files/settings.local.json:14`: `"Bash(mv .claude/context/project/repo/self-healing-implementation-details.md .claude/context/repo/)"`. Low-severity historical permission grant for a one-time `mv` that already happened. Worth a one-line cleanup, outside the original inventory.

### Item 3 — Consolidate four validation docs: VERIFIED-CURRENT

All four files exist at claimed paths/sizes, unchanged by predecessor tasks:

| File | Lines |
|---|---|
| `context/orchestration/validation.md` | 698 |
| `context/orchestration/subagent-validation.md` | 313 |
| `context/orchestration/orchestration-validation.md` | 233 |
| `context/validation.md` | 46 |

Heading overlap is genuine: all three `orchestration/`-directory files share a near-identical "Step 1: Validate JSON Structure → Step 2: Validate Required Fields → Step 3: Validate Status → Step 4: Validate Session ID → Step 5: Validate Artifacts (CRITICAL)" sequence (`validation.md:423-562`, `subagent-validation.md:22-254`, `orchestration-validation.md:39-139`). `validation.md` (698L) is itself already a merge of three sub-concerns (Validation Strategy L1-161, `/task` flag validation L161-380, a "Validation Rules Standard" L382-692 nearly duplicating `subagent-validation.md`).

**New finding, stronger than the task's framing**: per `index-entries.json`, both `orchestration-validation.md` and `orchestration/validation.md` are in `load_when.agents: ["meta-builder-agent"]` simultaneously — meta-builder-agent currently loads 931 overlapping lines at once. `subagent-validation.md` loads for `/orchestrate`. `context/validation.md` (46L, "Skill Validation Context" — return schema/idempotency) is `on_demand` only and is the least duplicative of the four — a distinct skill-contract concern, not part of the orchestration-doc overlap.

**Recommendation**: consolidate `orchestration/validation.md` + `subagent-validation.md` + `orchestration-validation.md` into one file; update `index-entries.json` load_when for `meta-builder-agent`/`/orchestrate` to point at the single result. Leave `context/validation.md` separate.

### Item 4 — Fold docs/README.md into docs-README.md: VERIFIED-CURRENT, sharper finding

`agent-system/extensions/core/docs/README.md` is titled **"Version: 3.0"** (line 3) and restates root-level content (command tables, architecture diagram, extensions table, state management) rather than indexing docs/.

**New finding**: it has ~13 **broken relative links** — every internal link is prefixed `docs/...` (e.g. `docs/README.md:31` → `[docs/guides/user-guide.md](docs/guides/user-guide.md)`, plus lines 65, 136, 138, 188-206, 210-211, 250) despite already living inside `docs/`; `agent-system/extensions/core/docs/docs/` does not exist, so every one of these links 404s. `docs-README.md` uses correct same-directory-relative links (e.g. `docs-README.md:5` → `[architecture/system-overview.md](architecture/system-overview.md)`) and is the accurate directory map. This confirms `docs/README.md` was copy-pasted from a different directory level without path adjustment — strengthens the case for folding unique content into `docs-README.md` and deleting `docs/README.md`.

### Item 5 — Move `## Literature Mode (--lit)` out of core merge-sources: VERIFIED-CURRENT, exact match

`agent-system/extensions/core/merge-sources/claudemd.md` is 645 lines. The `## Literature Mode (\`--lit\`)` section spans **lines 335-496 = exactly 162 lines** (next heading `## Rules References` at line 497) — task's 162-line estimate is exact.

`agent-system/extensions/literature/merge-sources/` **does not exist at all** — item 5 requires *creating* this directory/file, not editing an existing one.

Literature's `EXTENSION.md` is currently 33 lines. Rule U (hard gate per `check-extension-docs.sh:757-778` and `extension-slim-standard.md`) caps `EXTENSION.md` at 60 lines. Dropping 162 lines in (→195 lines) would blow the cap by 135 lines — the task's warning against parking content there is correct and binding, confirmed via direct read of the gate script.

Other "restates always-loaded context" candidate sections in `claudemd.md`, each with a confirmed durable home already existing:

| Section | Lines | Span | Durable home | Home size |
|---|---|---|---|---|
| State Synchronization | 46 | 139-184 | `rules/state-management.md` | 86 |
| Context Discovery | 30 | 518-547 | `context/patterns/context-discovery.md` | 375 |
| jq Command Safety | 16 | 620-635 | `context/patterns/jq-escaping-workarounds.md` | 286 |
| Context Architecture | 33 | 548-580 | `context/architecture/context-layers.md` | 99 |
| Multi-Task Creation Standards | 25 | 589-613 | `docs/reference/standards/multi-task-creation-standard.md` | 469 |

The last two (Context Architecture, Multi-Task Creation Standards) are **new candidates found during this verification**, not pre-named in the task's "~300 lines" estimate — they fit the same "restates an always-loaded file" pattern. Sum of all five (146) + Literature Mode (162) = 308 lines, closely matching the task's "~300 lines" figure. The verification bar's "shrinks by >=250 lines" target is achievable via the literature move alone (162) plus any subset of the other four.

### Item 6 — Trim rules/no-task-references-in-deliverables.md: PARTIALLY STALE, correct the estimates

Source-store file is **166 lines** total. Narrative block line ranges (current):
- "Discovered during Phase 5 purge" — lines 76-83 (8 lines)
- "Discovered during Phase 10 purge" — lines 85-93 (9 lines)
- "Resolved test case" — lines 95-102 (8 lines)
- "Deploy-mechanism note" + "second, related class of symptom" — lines 140-166 (27 lines, runs to EOF)

Total narrative = **52 lines**, not the task's "~90 lines" estimate — the task's figure appears to have included the Exemption Taxonomy table (lines 50-74, ~25 lines), which is core actionable reference content and should **not** move (it's the enforcement mechanism the rule depends on, not narrative). Moving only the 52 true-narrative lines out leaves **~114 lines**, well above the task's "~60-line" target. **Correction for planner**: treat ~110-115 lines as the realistic post-trim floor unless the exemption table itself is separately condensed; ~60 lines is not achievable without cutting actionable content.

**Correction to task's claim about the deploy-gap narrative being "obsolete" / containing "the wrong Lua path"**: directly verified against current code — `neotex.plugins.ai.shared.extensions.init` exists at `lua/neotex/plugins/ai/shared/extensions/init.lua` and defines `manager.load` (line 269), `manager.resync_all` (line 901), `manager.wipe` (line 1200), exactly as the narrative describes; the root-files/settings.json skip-on-existing behavior is also still present (init.lua ~536, 771, 1115-1140 region). **This part of the narrative is accurate and current, not obsolete or wrong, as of this verification.** The task description's assumption should be re-checked against whatever the "deploy consolidation" predecessor task actually changed — based on current file state, no Lua-path correction is needed. The narrative should still move to a decision record under `specs/` per the task's structural goal (readability), but not because it's factually wrong.

### Item 7 — Two agent templates: VERIFIED-CURRENT, freshly worsened by a predecessor task

`docs/templates/agent-template.md` (94L) and `context/templates/agent-template.md` (118L) are a **deliberate two-tier split by design**, not accidental duplication — the context/ version's own text states it is "the Canonical agent structure used by `meta-builder-agent`" and explicitly points to the docs/ version as "the user-facing tutorial version" (`context/templates/agent-template.md:1-5`).

**New finding**: predecessor task 989 phase 1 (`git log`: commit `9e978b26d` "task 989 phase 1: rewrite frontmatter standard to real field set") rewrote `context/templates/agent-template.md`'s frontmatter section to add `tools`/`disallowedTools`/`mcpServers` field documentation and an explicit forbidden-fields list (`mode`, `version`, `temperature`, `max_tokens`, `timeout`, `allowed-tools:`, `mcp-servers:`, `return_format`), but left `docs/templates/agent-template.md` untouched — it still shows only old `model: sonnet` + tier-comment frontmatter (lines 1-8) with none of the new field guidance. **The two templates are now inconsistent with each other, not merely duplicative.**

**Recommendation**: this is not a "keep one, redirect the other" situation as the task description assumed — it's a deliberate canonical/tutorial split that needs re-syncing, not consolidation. Sync `docs/templates/agent-template.md`'s frontmatter block to match `agent-frontmatter-standard.md` (289L, `docs/reference/standards/agent-frontmatter-standard.md`) and `context/templates/agent-template.md`'s updated content, preserving the two-tier structure.

### Item 8 — skill-lifecycle.md prescribed section layout: STALE, ALREADY FIXED — drop from scope

`context/patterns/skill-lifecycle.md` was fully rewritten by predecessor task 983 phase 11 (`git log`: commit `3d02e7921` "task 983 phase 11: rewrite skill-lifecycle.md, index it, and satisfy the full verification bar" — 983 is in 986's dependency list). The current doc's own "Division of Labor" section (lines 286-299) describes in past tense: "a stale Stage-0-through-6 layout here that matched zero actual skills" — i.e. it is already narrating the fix to the exact problem item 8 describes.

The current Stage-N table (lines 43-64) matches real skill files, verified against `skills/skill-researcher/SKILL.md`, `skills/skill-planner/SKILL.md`, `skills/skill-implementer/SKILL.md` — all three use matching stage headings (`### Stage 1: Input Validation`, `### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker`, etc.).

No "skill-skeleton" string exists anywhere under `agent-system/extensions/` (grep returned zero hits) — the task description's "coordinate with the skill-skeleton task which owns the replacement content" pointer is itself stale/orphaned.

**Recommendation: drop item 8 entirely from this task's plan.** Nothing to rewrite.

### Item 9 — context-discovery.md jq recipe bug: VERIFIED-CURRENT, bug still present

File: `agent-system/extensions/core/context/patterns/context-discovery.md`, "Adaptive Context Loading (Recommended Pattern)" section. Line 196 declares `--arg lang "meta"` but line 203 references `$task_type`:

```
195:  jq -r --arg agent "general-implementation-agent" \
196:        --arg lang "meta" \
197:        --arg cmd "/implement" '
...
203:      any(.load_when.task_types[]?; . == $task_type) or
```

`$task_type` is never declared as a jq `--arg` — only `$agent`, `$lang`, `$cmd` exist. Copy-pasting this block produces `jq: error: $task_type is not defined at <top-level>`.

**New finding**: the deployed `.claude/CLAUDE.md` (visible in this session's own system context) contains a *different*, already-correct version of the same query pattern (`--arg task_type "meta"` matching `$task_type` correctly) in its inline "Context Discovery" section — i.e. two divergent copies of the "recommended pattern" exist across the docs surface: one broken (`context-discovery.md`), one fixed (`claudemd.md`'s inline copy, lines 518-547, which item 5 slates for removal/relocation). **Sequencing note for planner**: fix `context-discovery.md`'s copy using `claudemd.md`'s already-correct wording as the reference, before item 5 deletes that section from `claudemd.md`.

## Decisions

- Item 8 is dropped from the task's actionable scope — already resolved by task 983 phase 11.
- Item 6's target line count is revised from "~60 lines" to "~110-115 lines" (realistic floor after moving only true narrative, keeping the Exemption Taxonomy table).
- Item 6's "wrong Lua path" claim is not corroborated by current code; treat the deploy-gap narrative as accurate-but-verbose (move for readability, not correctness).
- Item 7 is reframed from "pick a canonical template, redirect the other" to "re-sync the deliberate two-tier canonical/tutorial split," since task 989 already established the split is intentional and merely left one side stale.
- Two out-of-inventory items are recommended for inclusion in the plan: (a) the `settings.local.json:14` stale `self-healing-implementation-details.md` mv-permission entry; (b) the `context-discovery.md`/`claudemd.md` jq-recipe fix-before-delete sequencing dependency between items 9 and 5.

## Risks & Mitigations

- **Risk**: Item 5's move creates a new `agent-system/extensions/literature/merge-sources/` directory from scratch — no existing file to diff against, so the plan must specify the merge-source file's exact target filename/shape (likely `claudemd.md` matching core's naming convention) and confirm the extension loader's merge mechanism picks up new merge-source files automatically (not verified in this research pass — recommend a quick check during planning).
- **Risk**: Item 3's consolidation touches `index-entries.json` `load_when` wiring for `meta-builder-agent` and `/orchestrate` — a plan must include the index update as an explicit step, not just the file merge, or the dangling old-file references will silently persist in the loader.
- **Risk**: Item 7's frontmatter re-sync depends on `docs/reference/standards/agent-frontmatter-standard.md` (289L) being the authoritative source — confirm no further predecessor-task drift there before writing the sync.
- **Mitigation**: this report's file:line evidence is exhaustive enough that the planner should not need to re-grep for items 1-5, 7, 9; only item 6 (exact final line count) and item 3 (post-merge structure) require light exploration during planning.

## Context Extension Recommendations

- None required — this is itself a documentation-truth task; no new context files are needed to support the sweep. The consolidated validation doc (item 3) and the relocated `--lit` merge-source (item 5) are themselves the context-file changes this task produces.

## Appendix

### Search methodology

Three parallel research forks partitioned the 9-item inventory:
- Fork A: items 1-2 (dispatch-agent fiction, dead script refs) — `grep -rn`, `find -iname`, deprecated/ directory checks
- Fork B: items 3, 4, 7, 8 (validation docs, README fold, templates, skill-lifecycle) — `wc -l`, heading extraction, `diff`, `git log` for predecessor-task attribution
- Fork C: items 5, 6, 9 (--lit move, no-task-refs trim, jq bug) — line-range extraction, `find` for literature merge-sources, direct Lua source verification

### Key commit references discovered

- `9e978b26d` — task 989 phase 1: rewrote frontmatter standard, updated `context/templates/agent-template.md` but not `docs/templates/agent-template.md` (item 7 fallout)
- `3d02e7921` — task 983 phase 11: rewrote `skill-lifecycle.md`, resolving item 8 entirely

### Files verified to NOT need action

- `state-template.json` — zero dangling references (clean deletion by predecessor task)
- `context/patterns/skill-lifecycle.md` — item 8, already fixed

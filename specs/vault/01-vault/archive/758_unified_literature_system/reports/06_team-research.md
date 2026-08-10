# Research Report: Task #758 — Team Research Synthesis

**Task**: 758 - Unified Literature System
**Date**: 2026-06-23
**Mode**: Team Research (4 teammates)
**Session**: sess_1750720000_research758

## Summary

This team research round addressed two expanded requirements added after the initial plan: (1) --lit flag lifecycle wiring for the briefing+tools pattern, and (2) a source discovery and acquisition pipeline. Four teammates investigated complementary angles. The findings reveal that the --lit wiring is a surgical change (high confidence), the source discovery pipeline has strong existing infrastructure but needs a new front-end script, and the current plan has critical gaps that must be addressed before implementation.

## Key Findings

### --lit Flag Lifecycle (Teammate A)

The current --lit wiring is clean and consistent. `parse-command-args.sh` already parses `--lit` correctly (line 112-114) and exports `LIT_FLAG`. All three skills (researcher, planner, implementer) have identical Stage 4a injection logic calling `literature-retrieve.sh`. The orchestrate skill already threads `lit_flag` through all dispatch contexts.

**Recommended change**: Surgical swap in Stage 4a of six SKILL.md files (three standard + three hard variants): replace `literature-retrieve.sh` with `literature-briefing.sh` and change `<literature-context>` tags to `<literature-briefing>`. No changes needed to parse-command-args.sh, skill-orchestrate dispatch chain, or agent definitions.

**Critical tool**: `literature-search.sh` is already fully implemented with FTS5 search, `--read`, `--toc`, `--refs`, `--next/--prev` subcommands. Agents invoke via Bash and access chunks via Read at known paths.

### Source Discovery Pipeline (Teammate B)

The existing pipeline handles everything after a PDF arrives (convert, chunk, index, inject). What's entirely missing is the front-end: discovering which papers exist, checking system membership, and acquiring PDFs.

**Three-tier lookup chain** (recommended):
1. Global `~/Projects/Literature/index.json` (fast, offline)
2. Zotero CSL-JSON / live `zot` CLI (local, comprehensive)
3. Online APIs (Semantic Scholar, CrossRef, Unpaywall, arXiv)

**Four free APIs** cover academic discovery:
- **Semantic Scholar** (api.semanticscholar.org) — 200M papers, returns openAccessPdf URL, no auth
- **CrossRef** (api.crossref.org) — title-to-DOI resolution, no auth
- **Unpaywall** (api.unpaywall.org) — legal open-access PDF URL for any DOI, email-only auth
- **arXiv** — direct PDF URLs for preprints

**SOURCES.md design**: Per-repo `specs/literature/SOURCES.md` tracking title, DOI, status (`[PENDING]`, `[PAYWALL]`, `[FOUND]`, `[RESOLVED]`), and acquisition path. Mirrors existing `~/Projects/Literature/FIND_SOURCES.md`.

**Deliverable**: New `literature-discover.sh` script with tier subcommands, wired into `/literature --discover`.

### Critical Gaps (Teammate C)

Four serious problems identified:

1. **Plan contradicts task description**: Task explicitly requires "a literature-agent that autonomously explores" and "design the literature-agent tool interface." The plan lists the literature-agent as a Non-Goal without explanation. The synthesis silently dropped this recommendation from Report 04.

2. **Source discovery pipeline absent from plan**: The plan has no phase covering discovery/acquisition — this was added after planning.

3. **Bash permission gap**: The briefing+tools pattern requires agents to call `bash .claude/scripts/literature-search.sh`, but no settings file grants this permission. Without adding an allow rule, the pattern fails silently in orchestrate mode.

4. **Token savings claim may reverse**: A single `literature-search.sh` call returns ~3,000 tokens of JSON. Three exploratory searches = ~9,000 tokens, exceeding the 8,000-token injection budget. Briefing+tools is better for targeted retrieval, not uniformly cheaper.

### Strategic Horizons (Teammate D)

1. **Briefing+tools is a system-level pattern**: The same injection-vs-tools tension applies to `memory-retrieve.sh` (same score-inject approach). After task 758, memory should get the same treatment.

2. **Global-repo + per-repo-pointer is the standard**: The Literature/ architecture should become the template for all cross-project knowledge (memory vault, shared research).

3. **SOURCES.md is the first async resource-acquisition pattern**: Agents flag missing resources, humans provide them, agents resume. This is an architectural primitive worth documenting alongside BLOCKED status.

4. **Token economics permanently favor tool-call richness**: Injection must be processed before reasoning begins; tool calls demonstrate selective understanding. No "revert to injection" escape hatch needed.

## Synthesis

### Conflicts Resolved

| Conflict | Resolution |
|----------|-----------|
| Literature-agent vs briefing+tools | The critic correctly identifies the plan deviates from the task description. However, the user's latest message frames the requirement as "--lit should provide literature support" without mandating a separate agent type. The briefing+tools approach (teammate A) achieves the goal with less complexity. The plan should be revised to acknowledge this design decision explicitly rather than listing it as a silent non-goal. |
| Token savings direction | Teammate A claims savings; teammate C demonstrates they reverse under heavy search. Both are correct for different usage patterns. Resolution: the briefing is always injected (~300 tokens, strictly cheaper than injection), but total session cost depends on how many follow-up searches the agent makes. This should be documented as a trade-off, not claimed as a uniform win. |
| SOURCES.md location | Teammate B recommends `specs/literature/SOURCES.md` per-repo; teammate D notes `~/Projects/Literature/FIND_SOURCES.md` already exists globally. Resolution: both are needed — global FIND_SOURCES.md for the corpus-level wishlist, per-repo SOURCES.md for project-specific needs that feed into the global one once resolved. |

### Gaps Requiring Plan Revision

The current 6-phase plan must be revised to address:

1. **Add source discovery phase**: New `literature-discover.sh` script with three-tier lookup, SOURCES.md generation, and `/literature --discover` wiring
2. **Add Bash permission rule**: Allow `literature-search.sh` in settings for autonomous agent use
3. **Clarify literature-agent non-goal**: Document why briefing+tools was chosen over a dedicated agent type
4. **Address hard-variant skills**: Stage 4a changes apply to 6 SKILL.md files, not 3
5. **Token economics documentation**: Frame as a selectivity improvement, not a cost reduction

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|-----------------|
| A | --lit wiring | completed | high | Traced exact wiring, identified surgical 6-file change |
| B | Source discovery | completed | high | Three-tier lookup chain, four free APIs, SOURCES.md design |
| C | Critic | completed | high | Plan-vs-description contradiction, Bash permission gap |
| D | Horizons | completed | medium | System-level pattern recognition, memory extension opportunity |

## Recommendations

1. **Revise the plan** (`/revise 758`) to incorporate source discovery pipeline and address the critic's findings before implementation
2. **Add Bash permission** for `literature-search.sh` to `.claude/settings.json` as a prerequisite
3. **Create `literature-briefing.sh`** as the compact metadata generator (~300 tokens)
4. **Create `literature-discover.sh`** as the source acquisition front-end
5. **Update all 6 SKILL.md files** (3 standard + 3 hard variants) with the new Stage 4a
6. **Document the briefing+tools pattern** as a reusable architectural pattern for future application to memory retrieval

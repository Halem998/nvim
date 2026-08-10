# Research Report: Unified Literature System — Horizons (Teammate D)

**Task**: 758 - Unified Literature System
**Role**: Horizons — Long-term alignment and strategic direction
**Started**: 2026-06-23
**Completed**: 2026-06-23
**Effort**: ~1 hour
**Sources/Inputs**: reports/05_research-synthesis.md, plans/05_unified-literature-plan.md, reports/02_agent-design-patterns.md, reports/03_storage-architecture.md, specs/ROADMAP.md, .claude/ codebase exploration

---

## Executive Summary

- The briefing+tools pattern (Pattern 3C) is the single most strategically significant decision in task 758 — it generalizes beyond literature to every context-injection mechanism in the system
- The global Literature/ repo pattern is a template for cross-project knowledge infrastructure; memory, shared research corpora, and documentation indexes should follow the same global-with-per-repo-pointer design
- The source discovery pipeline (FIND_SOURCES.md + SOURCES.md flag) is the first explicit human-in-the-loop acquisition workflow in the system; it should be recognized as an architectural primitive, not a literature-specific feature
- Extension mergers follow a consolidation-when-sharing-storage principle; the literature+zotero merger reveals a general rule for when to merge vs. split extensions
- Token economics favor briefing+tools now and in all plausible model-cost futures; the correct long-term bet is on tool-call richness, not context-window abundance
- The SOURCES.md human-in-the-loop pattern appears in embryonic form in several other parts of the system and should be elevated to a documented pattern

---

## Key Findings

### Finding 1: The Briefing+Tools Shift Is a System-Level Pattern

The synthesis report frames the move from static injection to briefing+tools as an implementation detail of the `--lit` flag. It is more than that. The same injection-vs-tools tension applies to every `<X-context>` block currently injected into agents:

| Current injection | Block name | Budget |
|---|---|---|
| `memory-retrieve.sh` | `<memory-context>` | 2,000 tokens |
| `literature-retrieve.sh` | `<literature-context>` | 8,000 tokens |
| `zotero-retrieve.sh` | `<zotero-context>` | 8,000 tokens |
| Extension context files | (inline in prompt) | varies |

All three follow the same pattern: score entries by keyword overlap, select greedily within a token budget, inject full content whether the agent uses it or not. The literature refactor demonstrates that this is fixable at the architectural level. Once `literature-retrieve.sh` is replaced by `literature-briefing.sh`, memory-retrieve.sh will stand as the only remaining injection script operating on this old pattern.

**Strategic implication**: After task 758, the next logical step is a `memory-briefing.sh` that generates a compact `<memory-briefing>` listing available memory entries (title, keywords, path, token count) rather than injecting content. This would cut the memory injection from 2,000 tokens per invocation to ~100-200 tokens, with agents reading specific memory files on demand via the Read tool. The memory vault already stores files in `.memory/10-Memories/` with predictable paths — the Read-on-demand pattern would work identically.

### Finding 2: The Global Repo Pattern Should Be the Standard for Cross-Project Knowledge

The Literature/ repo at `~/Projects/Literature/` introduces a pattern: a globally shared knowledge repository with per-project lightweight pointer files (`specs/literature-index.json`). The repo is git-tracked, content is browsable, and the FTS5 database is a derived search cache.

The memory vault (`.memory/`) currently follows a per-project model: each repo has its own `.memory/` directory with no sharing mechanism. This is appropriate for project-specific learned facts. But some categories of memory are cross-project:

- **Tool behavior patterns** (how Claude Code handles certain edge cases)
- **Agent orchestration patterns** (distilled from experience across many tasks)
- **Shared vocabulary** (terms and definitions that apply across projects)

A global memory vault at `~/.config/.memory/` (or `~/Projects/Memory/`) following the same pattern as Literature/ — with per-project pointer files — would provide cross-project learning. The CLAUDE.md already notes that `auto-memory` lives at `~/.claude/projects/` but this is Claude Code's internal mechanism, not a user-controlled global vault.

**Strategic implication**: Establish `~/Projects/Memory/` as a sibling to `~/Projects/Literature/` with the same design: global JSON index, per-project `.memory-index.json` pointer files, and a `memory-briefing.sh` that generates compact briefings. This extends the pattern established in task 758 to the full knowledge infrastructure.

### Finding 3: Source Discovery as an Architectural Primitive

The FIND_SOURCES.md file in `~/Projects/Literature/` documents a workflow for finding paper PDFs that are in the index but not yet converted. The plan summary notes a `SOURCES.md` flag concept — where an agent flags missing sources for human follow-up. This is the first explicit human-in-the-loop acquisition pipeline in the system.

This pattern generalizes:

| Domain | Missing resource | Human action | Agent flag file |
|---|---|---|---|
| Literature | Paper PDF not in Zotero | Obtain PDF, import to Zotero | `SOURCES.md` |
| GitHub repos | Private repo or URL not accessible | Grant access or provide alternative | `REPOS.md` |
| API docs | Behind auth wall or paywall | Provide credentials or alternative | `ACCESS.md` |
| Project context | Undocumented conventions | Document them in `.context/` | `GAPS.md` (already exists as "context extension recommendations" in research reports) |

The `SOURCES.md` pattern already exists implicitly in research reports (the "Context Extension Recommendations" section flags gaps for human follow-up). Task 758 formalizes it as a file that persists across agent runs.

**Strategic implication**: Document `SOURCES.md` (and analogous `REPOS.md`, `ACCESS.md`) as a documented architectural pattern in `.claude/context/patterns/human-in-the-loop-acquisition.md`. The pattern is: agent flags a missing resource with enough context for a human to act, human acquires it, agent re-runs and consumes it. This is distinct from `BLOCKED` task status — it is a lightweight async handoff within a running task.

### Finding 4: Extension Consolidation Reveals a Merge Criterion

The literature+zotero merger is justified by a specific condition: the two extensions share the same storage layer (same chunk files, same doc_ids) but maintain incompatible indexes over it. This is the consolidation criterion: merge extensions when they share a storage layer and their separation creates index divergence.

Examining the existing extensions for this pattern:

| Extension pair | Shared storage? | Index divergence? | Merge candidate? |
|---|---|---|---|
| `literature` + `zotero` | Yes (Literature/ chunks) | Yes (index.json vs zotero-index.json) | Yes (task 758) |
| `memory` + any other | No | N/A | No |
| `lean` + `formal` | Possibly (both use .lean files) | Possibly | Investigate |
| `latex` + `typst` | No (different output formats) | N/A | No |
| `nix` + core | No | N/A | No |

The lean and formal extensions are the most likely candidates for similar investigation. Both deal with formal verification, both may reference the same Lean 4 codebase, and if they maintain separate context indexes over the same Lean files, the consolidation argument applies.

**Strategic implication**: Add a maintenance check to `/review` or `check-extension-docs.sh` that identifies extensions sharing storage roots and flags them for consolidation review. This prevents the literature+zotero situation from recurring silently.

### Finding 5: Token Economics Favor Tool-Call Richness Permanently

The report (02_agent-design-patterns.md) notes that briefing+tools saves ~6,000 tokens per invocation compared to full injection. The question of whether this trade-off remains favorable as models get cheaper and context windows grow deserves direct analysis.

The argument for reverting to injection when context is abundant: "if context is free, inject everything — the agent doesn't have to make tool calls." This argument fails for three reasons:

1. **Latency, not cost, is the real constraint at scale.** Tool calls add round-trips but these are parallel with the agent's reasoning. Full injection adds tokens that must be processed before any reasoning begins, increasing time-to-first-token. As tasks grow more complex, injection latency compounds while tool-call latency does not.

2. **Selectivity is intrinsically valuable.** An agent that reads only what it needs demonstrates that it understood the task well enough to know what it needs. An agent receiving pre-injected content has no such signal. The briefing+tools approach is epistemically richer — the agent's tool calls are a record of its reasoning.

3. **Context saturation is model-dependent.** Even with 1M token context windows, models degrade on long-context tasks. Injecting 8,000 tokens of literature when 2,000 would suffice wastes attentional capacity that is not simply restored by adding more context capacity. The research literature on long-context model performance (as of 2025) consistently shows degradation on tasks requiring attention to specific parts of very long contexts.

**Strategic implication**: The briefing+tools pattern should be treated as a permanent architectural commitment, not a cost-saving measure to revisit. The system should not include a `--inject` flag as a future escape hatch. If specific agents or tasks have unusual needs, those should be handled by extension hooks or custom skills, not by reverting the general pattern.

### Finding 6: SOURCES.md and the Human-in-the-Loop Workflow

The existing system has several points where agents currently stop and wait for human input:

1. **BLOCKED task status** — formal, task-scoped, requires `/spawn` or manual unblocking
2. **AskUserQuestion tool** — synchronous, in-conversation, immediate
3. **Research report "context extension recommendations"** — async, file-based, survives across sessions
4. **SOURCES.md** (proposed in task 758) — async, file-based, resource-acquisition specific

These form a spectrum from most-synchronous to most-asynchronous. The system currently lacks a general pattern for the middle of this spectrum: "I found something I need a human to provide, I am writing it down, I am continuing where I can, and I expect the human to provide it before the next run."

The SOURCES.md approach is exactly this pattern. It should be generalized and documented alongside existing patterns like `BLOCKED` status and `AskUserQuestion`.

**Strategic implication**: Create `.claude/context/patterns/async-resource-requests.md` documenting the full spectrum, with SOURCES.md as the canonical example of the async-file-based pattern. Define a lightweight schema for resource request files: `type` (pdf, repo, api-key, documentation), `description`, `blocking` (boolean — is this blocking or can the agent proceed?), `acquired` (boolean — has the human provided it?), `path` (where to put it when acquired).

---

## Recommended Approach

### Near-term (task 758 scope)

The plan in `05_unified-literature-plan.md` is sound and complete. No changes recommended to the 6-phase plan. The strategic findings above inform how to document the new patterns in a way that enables future generalization.

Specifically, in Phase 6 (documentation), the following should be added beyond what the plan currently lists:

1. Add a note to `.claude/context/patterns/` linking to the briefing+tools pattern as a generalized approach for context injection (not just for literature)
2. Document SOURCES.md in `.claude/context/patterns/` as a human-in-the-loop resource acquisition pattern
3. In the literature extension EXTENSION.md, explicitly state the "global repo + per-repo pointer file" as a design pattern so it is recognizable when other cross-project systems are built

### Medium-term (next 2-3 tasks)

1. **Memory briefing system**: Apply Pattern 3C to memory-retrieve.sh. Replace static memory injection with a `memory-briefing.sh` + on-demand Read pattern. Estimated effort: 2 hours (much simpler than literature because the memory vault structure is already clean and the briefing pattern is now proven).

2. **lean+formal extension audit**: Investigate whether the lean and formal extensions share storage in a way that warrants consolidation. If they do, the merger playbook from task 758 applies directly.

3. **Cross-project memory architecture**: Design `~/Projects/Memory/` as a global memory vault parallel to `~/Projects/Literature/`. This completes the knowledge infrastructure: Literature/ for academic papers, Memory/ for learned facts and patterns, with consistent global-repo + per-project-pointer architecture throughout.

### Long-term (roadmap items)

4. **Async resource request protocol**: Add `SOURCES.md` support to `/implement` and `/research` commands so agents can flag missing resources without blocking. Document in CLAUDE.md as a first-class pattern alongside BLOCKED status.

5. **Context injection audit**: Run a sweep of all `<X-context>` injection patterns across skills and agents, converting each to briefing+tools. Target: zero static content injection in skill preflights by end of roadmap Phase 2.

6. **Extension health check for storage sharing**: Add a check to `check-extension-docs.sh` that identifies extension pairs sharing the same storage root and flags them for consolidation review.

---

## Evidence and Examples

### Evidence for Finding 1 (injection pattern generality)

From `skill-researcher/SKILL.md`:
```bash
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
fi
```

From `memory-retrieve.sh`:
```bash
# Phase 2: Read selected memory files, format as <memory-context> block
# Exit 0 with content on stdout when memories found
```

Both follow the identical score-select-inject pattern. The structural similarity is direct evidence that the solution generalizes.

### Evidence for Finding 5 (token economics)

From report 02_agent-design-patterns.md:
| Approach | Tokens consumed |
|---|---|
| Current `--lit` injection | 4,000-8,000 (always) |
| Briefing + on-demand | 200-500 (briefing) + N×(chunk) as needed |

The 10-20x reduction in baseline token cost, combined with improved selectivity, dominates any plausible future where context becomes cheaper.

### Evidence for Finding 4 (merge criterion)

From report 05_research-synthesis.md:
> "Dual incompatible indexes — index.json (16 fields) vs zotero-index.json (20 fields) for the same chunks"

This is the canonical form of the merge criterion: two indexes over the same storage.

---

## Confidence Level

| Finding | Confidence | Basis |
|---|---|---|
| Briefing+tools generalizes to memory | High | Direct structural analogy; same injection pattern, same file-based storage |
| Global repo pattern for cross-project memory | Medium | Pattern is proven for literature; cross-project memory has additional design questions (conflict resolution, vault separation) |
| Source discovery as architectural primitive | High | Pattern already exists in multiple forms; task 758 formalizes it |
| Merge criterion for extensions | High | The literature+zotero case cleanly illustrates the principle; lean+formal is speculative |
| Token economics favor tools permanently | High | Three independent arguments (latency, selectivity, attention degradation) all point the same direction |
| SOURCES.md as documented pattern | High | Human-in-the-loop async acquisition is a real gap in current documentation |

---

## Appendix: Files Examined

- `specs/758_unified_literature_system/reports/05_research-synthesis.md`
- `specs/758_unified_literature_system/plans/05_unified-literature-plan.md`
- `specs/758_unified_literature_system/reports/02_agent-design-patterns.md`
- `specs/758_unified_literature_system/reports/03_storage-architecture.md`
- `specs/ROADMAP.md`
- `.claude/extensions/memory/manifest.json`
- `.claude/extensions/core/manifest.json`
- `.claude/extensions/nix/manifest.json` (hooks example)
- `.claude/skills/skill-researcher/SKILL.md` (injection integration point)
- `.claude/scripts/memory-retrieve.sh` (injection pattern reference)
- `.claude/scripts/` directory listing (injection scripts inventory)
- `.claude/extensions/` directory listing (all 20 extensions)
- `.memory/memory-index.json` (memory vault current state)

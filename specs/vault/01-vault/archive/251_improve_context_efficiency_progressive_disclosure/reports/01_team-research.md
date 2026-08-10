# Research Report: Task #251

**Task**: Improve context efficiency via progressive disclosure and lazy loading
**Date**: 2026-03-20
**Mode**: Team Research (2 teammates)

## Summary

The Claude Code agent system loads ~24,276 tokens of always-on context before any task work begins -- ~12% of a 200k window. The overhead comes from 4 CLAUDE.md files (14,266 tokens) and 5 auto-applied rules files (10,010 tokens). Four high-impact optimizations could reduce this by ~32% (~7,846 tokens): stripping redundant Quick Reference inline content from root CLAUDE.md, consolidating duplicate system CLAUDE.md files, splitting the oversized state-management rule, and externalizing worktree metadata.

---

## Key Findings

### 1. Always-Loaded Context Baseline (Teammate A)

**CLAUDE.md files** (4 files, all auto-loaded):

| File | Tokens |
|------|--------|
| `~/.config/CLAUDE.md` | ~6,961 |
| `nvim/.claude/CLAUDE.md` | ~3,309 |
| `nvim/CLAUDE.md` | ~2,289 |
| `.claude/CLAUDE.md` | ~1,707 |
| **Total** | **~14,266** |

**Rules files** (auto-applied via path glob):

| File | Tokens | Trigger |
|------|--------|---------|
| `state-management.md` | ~4,536 | `specs/**/*` |
| `artifact-formats.md` | ~1,818 | `specs/**/*` |
| `workflows.md` | ~1,510 | `.claude/**/*` |
| `error-handling.md` | ~1,200 | `.claude/**/*` |
| `git-workflow.md` | ~946 | always |
| **Total** | **~10,010** |

**Grand total: ~24,276 tokens always loaded.**

### 2. Root CLAUDE.md Quick Reference Bloat (Teammate A)

9 sections embed "Quick Reference" blocks (200-900 tokens each) alongside pointers to authoritative docs. The inline content duplicates the linked documents.

| Section | Current Tokens | Reducible To |
|---------|---------------|-------------|
| Code Standards | 580 | ~40 |
| Non-Interactive Testing | 334 | ~40 |
| Code Quality Enforcement | 465 | ~40 |
| Error Logging Standards | 472 | ~40 |
| Concurrent Execution Safety | 434 | ~40 |
| Plan Metadata Standard | 278 | ~40 |
| Hierarchical Agent Architecture | 918 | ~40 |
| Skills Architecture | 391 | ~40 |
| Documentation Policy | 568 | ~40 |
| **Total** | **4,440** | **~360** |

11 other sections already use the correct pointer-only pattern (74-88 tokens each), proving the approach works.

**Savings: ~4,080 tokens (59% reduction in root CLAUDE.md).**

### 3. System CLAUDE.md Duplication (Teammate A)

`.claude/CLAUDE.md` (1,707 tokens) is a legacy version of `nvim/.claude/CLAUDE.md` (3,309 tokens). They share 12 section titles with 39-94% content similarity. Both load every session.

**Savings: ~1,581 tokens by consolidating or eliminating the legacy file.**

### 4. Rules Content Type Mismatch (Teammate B)

Rules files mix three distinct content categories:

- **Category A -- Behavioral Constraints** (~20% of content): Status transition rules, two-phase update pattern, git safety. *Should stay auto-loaded.*
- **Category B -- Reference Schemas** (~60% of content): state.json field schemas (237 lines), TODO.md entry format, artifact naming. *Should be on-demand context.*
- **Category C -- Process Diagrams** (~20% of content): ASCII workflow flowcharts, resume pattern. *Should move to docs.*

The path-pattern model is a blunt instrument: `/implement` triggers `specs/**/*` rules because it reads from `specs/` to find the plan, loading 787 lines of state/artifact schemas it never uses.

### 5. State-Management Schema Duplication (Teammate B)

`rules/state-management.md` contains a 237-line "Task Entry Format" section documenting state.json field-by-field. `context/core/reference/state-json-schema.md` has 245 lines covering the same schema. Both have ~140 unique lines but only 38 lines overlap, meaning they've diverged.

**This is the highest-confidence finding: 300+ lines of reference schema that should exist once, loaded on demand.**

### 6. Command-Skill Routing Repetition (Teammate B)

Language-to-skill routing tables appear in `/research`, `/plan`, and `/implement` commands (~150 lines each), plus `context/core/routing.md`. Same information repeated 3-4 times across always-loaded content.

### 7. index.json Underuse (Teammate B)

`spawn-agent` and `code-reviewer-agent` have zero entries in `context/index.json`. The discovery mechanism requires agents to voluntarily query it -- not enforced.

### 8. Existing Infrastructure Already Supports Progressive Disclosure (Both)

- `context/index.json`: 73 entries, only 1 always-loaded
- Skills/agents use `@-references` for lazy loading
- The problem is confined to CLAUDE.md files and rules -- they bypass the existing infrastructure

---

## Synthesis

### Conflicts Resolved

No conflicts between teammates. Findings were complementary:
- Teammate A provided precise token measurements and identified specific redundant sections
- Teammate B provided structural analysis (content taxonomy) and alternative approaches

### Gaps Identified

1. **No measurement of agent file sizes**: Large agent files (meta-builder-agent: 1504 lines) were noted by Teammate B but not measured for token impact
2. **No testing of @-reference behavior**: Whether Claude Code follows @-references in stripped CLAUDE.md sections was not verified experimentally

### Prioritized Recommendations

**Priority 1: Strip Quick Reference from Root CLAUDE.md** (High confidence, Low risk)
- Edit 9 sections to pointer-only format
- Savings: ~4,080 tokens
- Zero infrastructure changes needed
- Template: existing lean sections (Testing Protocols, Dev Philosophy)

**Priority 2: Split State-Management Rule** (High confidence, Medium risk)
- Keep ~60 lines of behavioral constraints in auto-loaded rule
- Move ~300 lines of schemas to on-demand context file
- Consolidate with existing state-json-schema.md (eliminate diverged duplicate)
- Savings: ~2,000-4,000 tokens for non-state operations

**Priority 3: Consolidate Legacy .claude/CLAUDE.md** (High confidence, Low risk)
- Replace with pointer to nvim/.claude/CLAUDE.md or delete
- Savings: ~1,581 tokens

**Priority 4: Externalize Worktree Metadata** (Medium confidence, Low risk)
- Move worktree task header out of always-loaded CLAUDE.md
- Savings: ~185 tokens

**Priority 5: Reduce Artifact-Formats and Workflows Rules** (Medium confidence, Medium risk)
- Apply same Category A/B/C split to remaining rules files
- Move format templates and process diagrams to on-demand context
- Additional savings: ~1,500-2,000 tokens

**Deferred: Alternative Approaches** (from Teammate B)
- Command-scope rules (requires system changes or discipline)
- Tiered agent files (high complexity, medium benefit)
- Summary-first context files (too much new machinery)
- Operation context bundles (organizational, no content reduction)

---

## Token Budget Summary

```
Current baseline: ~24,276 tokens always loaded

Priority 1 (QR stripping):           ~4,080 tokens saved
Priority 2 (state-mgmt split):       ~2,000 tokens saved (conservative)
Priority 3 (CLAUDE.md consolidation): ~1,581 tokens saved
Priority 4 (worktree header):          ~185 tokens saved
Priority 5 (other rules split):      ~1,500 tokens saved (estimated)
                                     ───────────────────
Total potential savings:              ~9,346 tokens (~38% reduction)
Target baseline:                      ~14,930 tokens
```

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|-----------------|
| A | Token analysis and patterns | completed | High | Precise measurements, identified QR bloat |
| B | Alternative approaches and prior art | completed | High | Content taxonomy, schema duplication |

## References

- `.claude/context/index.json` - Context discovery infrastructure
- `.claude/docs/guides/context-loading-best-practices.md` - Loading strategies
- `.claude/context/core/reference/state-json-schema.md` - Duplicate schema source

## Next Steps

1. `/plan 251` to create phased implementation plan
2. Start with Priority 1 (root CLAUDE.md) -- highest ROI, lowest risk
3. Measure actual token counts before/after

# Teammate D (Horizons): Strategic Direction for Hard-Mode Routing

- **Task**: 669 — hard_mode_agent_system
- **Date**: 2026-06-12
- **Teammate**: D (Horizons)
- **Focus**: Long-term alignment, trajectory analysis, unconventional approaches

---

## Key Findings

### 1. Hard Mode Is Really "Orchestration Mode" — and the System Needs a Mode Abstraction

The nine techniques from report 01 (H1–H9) are not uniformly about "trying harder." They fall into three distinct categories:

| Category | Techniques | What They Actually Do |
|----------|-----------|----------------------|
| **Dispatch geometry** | H1, H7, H8 | Change _how work is divided_ (per-phase, parallel territories, phase-sized plans) |
| **Prompt contracts** | H2, H3, H9 | Change _what rules agents follow_ (anti-analysis, transcription mandates, handoff discipline) |
| **Feedback loops** | H4, H5, H6 | Change _how the orchestrator reacts_ (adversarial verify, divergence audit, churn detection) |

This matters because the three categories have different implementation costs and different reuse profiles. A per-phase dispatch loop (H1) is a skill-orchestrate structural change. A prompt contract (H2) is a context fragment any skill can inject. A churn detector (H6) is state-machine logic in the orchestrator. Bundling all nine under a single `--hard` flag is the right v1 UX, but the underlying implementation should keep these categories separate so they can be mixed later.

**Confidence**: High

### 2. The Third Axis Problem: Modes Will Multiply

The system currently has two dispatch modifiers:
- **Team mode** (`--team`): changes _who works_ (1 agent → N agents in parallel)
- **Effort mode** (`--fast`/`--hard`): currently changes reasoning depth; proposed to also change _routing_

These are orthogonal axes. Adding hard mode creates a combinatorial space:

```
normal × single-agent          (current default)
normal × team                  (--team)
hard × single-agent            (--hard, proposed)
hard × team                    (--hard --team, ??)
fast × single-agent            (--fast)
fast × team                    (--fast --team)
```

If each combination requires its own skill variant, the system explodes: 3 effort levels × 2 team modes × 17 extensions = 102 skill variants. Even if only lean4 and general get hard-mode skills initially, the pattern asks for replication every time a new combination is needed.

**The principled solution**: Modes should be _composable overlays_ on base skills, not separate skill files. A skill-orchestrate-hard should be skill-orchestrate + a hard-mode overlay, not a separate 1145-line SKILL.md that duplicates 80% of the original.

**Confidence**: High

### 3. The Single-Task-Origin Problem

Hard mode was derived from observing ONE human orchestrator's interventions on ONE hard task (BimodalLogic task 273, a Lean 4 formalization). The techniques are demonstrably effective for that task class: literature-grounded, formal-verification tasks with deep proof chains. But several techniques are domain-specific in ways the report doesn't flag:

| Technique | Domain Assumption | Generalizes? |
|-----------|-------------------|--------------|
| H2 (anti-analysis) | "The approach is wrong" is a signature of analysis paralysis | Yes — applies to any complex implementation |
| H3 (prior-art grounding) | Assumes literature/papers exist to transcribe | Partially — many tasks have no literature base |
| H4 (adversarial verify) | Research reports drive implementation | Yes — applies broadly |
| H5 (divergence audit) | Formal proofs have checkable semantic divergence | Partially — "divergence" is less defined outside formal methods |
| H8 (hard plan format, lemma-to-source mapping) | Assumes per-lemma deliverables with build checks | Partially — web/nix tasks have different verification |
| H9 (sorry inventory, build-green invariant) | Lean-specific sorry tracking | No — must be generalized per domain |

A general hard mode needs domain-adapted variants of H3, H5, H8, and H9. The lean4 extension could provide lean-specific hard-mode context fragments, while a general hard mode provides the universal subset (H1, H2, H4, H6, H7).

**Confidence**: High

### 4. Adaptive Difficulty Is the Right Long-Term Target, but Premature Now

The dream: the system starts in normal mode and automatically escalates to hard-mode techniques when it detects the failure signatures from Section 2 of report 01 (F1–F6). This would make `--hard` unnecessary — the system would just know.

Why this is premature:
- **Detection requires state tracking that doesn't exist yet**: churn counters, sorry-relocation detection, deflection signatures. These need to be built first as part of hard mode.
- **The escalation policy is a research problem**: when to escalate (after how many failures?), what to escalate to (which of H1–H9?), and when to de-escalate (or not). The report gives heuristics ("three strikes → audit") but these haven't been tested across diverse task types.
- **Hard mode IS the data collection mechanism**: by running tasks with `--hard` and comparing to normal mode, the user builds the empirical basis for adaptive thresholds.

**Recommended trajectory**:
1. **v1**: `--hard` flag with manual activation (this task)
2. **v2**: Churn counters and failure signature detection (built as part of v1, but advisory-only: "this task looks like it needs --hard")
3. **v3**: Auto-escalation with user confirmation ("Detected 3 deflections. Switch to hard mode? [Y/n]")
4. **v4**: Full adaptive mode (auto-escalate without confirmation, configurable thresholds)

**Confidence**: Medium — the trajectory is sound but timelines are speculative

---

## Roadmap Alignment Assessment

### Direct Alignment

The roadmap's current priorities are **documentation infrastructure** and **agent system quality**. Hard mode does not directly advance any current roadmap item. However:

- **Agent frontmatter validation** (roadmap item): Hard-mode agents need frontmatter. This creates pressure to ship the validation check first, which advances the roadmap item.
- **Extension slim standard enforcement** (roadmap item): If hard-mode is implemented as an extension or extension overlay, it would benefit from (and potentially require) the slim standard enforcement.

### New Roadmap Items Created

Hard mode will create several roadmap obligations:

1. **Hard-mode documentation**: Context fragments (H2/H3/H7/H9 prompt contracts) need documentation in the context system
2. **Hard-mode testing strategy**: How to verify that hard-mode skills actually produce better outcomes on hard tasks
3. **Hard-mode extension integration**: If per-domain hard variants are needed (lean4, formal, etc.), the extension system needs a pattern for this
4. **Churn detection infrastructure**: Loop guard extensions (defect_claims, sorry_relocations counters) need schema documentation
5. **Adversarial verification as first-class operation**: Currently no skill for "verify a report" — this needs to be built

### Scoping Opportunity

Hard mode could be scoped to simultaneously advance the "context discovery caching" roadmap item (Phase 2). Hard-mode skills need heavier context loading (prompt contracts, territory specs, foundations lists). If the context loading is done through a cacheable mechanism, it both serves hard mode and advances the caching roadmap item.

**Confidence**: Medium — the alignment is indirect but real

---

## Creative/Unconventional Approaches

### A. Mode-as-Extension Architecture (Recommended for Exploration)

Instead of adding hard-mode skills into the core system or into domain extensions, make "hard mode" itself an extension:

```
.claude/extensions/hard-mode/
├── manifest.json           # Declares routing overrides for --hard
├── EXTENSION.md           # Injected into CLAUDE.md when loaded
├── context/
│   ├── contracts/
│   │   ├── anti-analysis.md        # H2 prompt fragment
│   │   ├── prior-art-grounding.md  # H3 prompt fragment
│   │   ├── territory-contract.md   # H7 prompt fragment
│   │   └── wrap-up-contract.md     # H9 prompt fragment
│   └── patterns/
│       ├── per-phase-dispatch.md   # H1 dispatch pattern
│       ├── adversarial-verify.md   # H4 verification pattern
│       ├── divergence-audit.md     # H5 audit pattern
│       └── churn-detection.md      # H6 detection pattern
├── skills/
│   ├── skill-orchestrate-hard/SKILL.md
│   ├── skill-planner-hard/SKILL.md
│   └── skill-research-hard/SKILL.md
├── agents/
│   └── (thin variant agents if needed)
└── index-entries.json
```

**Pros**:
- Core system stays untouched — no risk of breaking normal mode
- Extension can be loaded/unloaded via the existing extension picker
- Domain extensions (lean, formal) can declare `"dependencies": ["hard-mode"]` and add domain-specific hard-mode overlays
- Testing is contained: test the extension in isolation
- Follows the existing pattern — no new architectural concepts needed

**Cons**:
- The `--hard` flag routing needs to check whether the hard-mode extension is loaded. If not loaded, `--hard` must either auto-load it or warn.
- Routing overrides in manifest.json don't currently support conditional routing (only task-type routing). The manifest format would need a `"hard"` routing key or an overlay mechanism.
- skill-orchestrate-hard at 1145+ lines would be the largest extension skill by far.

**Verdict**: Worth exploring seriously. The main blocker is that the manifest routing format doesn't support effort-flag-based routing — it only supports task-type-based routing. Adding `"routing_hard": {...}` to manifests would be a small schema extension that enables this cleanly.

### B. Contract Composition Pattern (Strongly Recommended)

Instead of duplicating prompt contracts in every hard-mode skill, create a composable contract library:

```
.claude/context/contracts/
├── anti-analysis.md          # H2: read budget, forbidden conclusions, defect bar
├── prior-art-grounding.md    # H3: transcription mandates, PDF-level citation
├── territory.md              # H7: file territory, plan-section territory, commit protocol
├── wrap-up.md                # H9: handoff JSON, continuation markdown, incremental commits
├── convergence-policing.md   # H6: progress criteria, churn signature tracking
└── README.md                 # Index of contracts and when to use each
```

Skills compose contracts by `@-referencing` them in their agent delegation prompts:

```markdown
### Hard-Mode Prompt Assembly

@.claude/context/contracts/anti-analysis.md
@.claude/context/contracts/prior-art-grounding.md
@.claude/context/contracts/territory.md
@.claude/context/contracts/wrap-up.md
```

**This is the CSS-class analogy**: skills "apply" contracts the way HTML elements apply CSS classes. A skill can be `.anti-analysis.territory` without being `.prior-art-grounding` (e.g., a web task with no literature base).

**Key insight**: Most of hard mode is prompt contract, not structural change. Only H1 (per-phase dispatch) and H6 (churn detection) require structural changes to skills. H2, H3, H7, H9 are pure prompt-level changes that existing skills could inject by reading contract files.

This means a v1 implementation could be:
1. Write the contract files (pure context, no skill/agent changes)
2. Modify skill-orchestrate to inject contracts when `--hard` is passed (one code path addition, not a separate skill)
3. Add per-phase dispatch logic to skill-orchestrate behind `--hard` (structural change, but in the existing file)
4. Only create separate hard-mode skills if the structural divergence becomes too large

**Confidence**: High — this approach is clearly lower-risk and lower-maintenance than separate skills

### C. Memory-Augmented Contracts (Future Enhancement)

The memory vault already supports `/learn` for storing knowledge and automatic retrieval during `/research`, `/plan`, and `/implement`. Hard-mode contracts could be:
1. Stored as memories with keywords like `hard-mode`, `anti-analysis`, `territory-contract`
2. Auto-retrieved when `--hard` flag is present (memory retrieval already happens in preflight)
3. Refined over time as the user learns what works for their task types

This would make hard mode _learned_ rather than _prescribed_. The user runs a hard task, discovers what contract worked, runs `/learn "anti-analysis contract: read budget ≤15%, forbidden conclusions: 'approach is wrong'..."`, and future hard-mode runs auto-retrieve it.

**Why defer this**: The current memory system retrieves by keyword matching, which is too coarse for contract composition. Contracts need precise, structured injection — not fuzzy retrieval. But it's a natural v2/v3 enhancement.

### D. Progressive Complexity: Start with H1+H2 Only

Report 01 identifies H1 (per-phase dispatch) as "the single highest-value change." H2 (anti-analysis contract) is the second highest. Together they counter F1 (analysis paralysis), which was the dominant failure mode.

A minimal v1 could implement ONLY H1+H2:
- Per-phase dispatch in skill-orchestrate (structural change)
- Anti-analysis contract as a context fragment (pure content)
- Everything else deferred to v2

This reduces scope by ~70% while capturing ~80% of the measured value (the monolithic→per-phase transition was the inflection point in the task-273 data).

**Risk**: If the user encounters F2/F3 (invented math, citation rot) without H3/H4, they'll need a v2 sooner. But F2/F3 are domain-specific (Lean/formal) and might not apply to the user's next hard tasks.

**Confidence**: Medium — pragmatically sound but depends on what the next hard task is

---

## Long-Term Sustainability Analysis

### Scale Assessment

Current system metrics:
- **1,141 files** in `.claude/` (18MB)
- **12 core agents** (5,432 lines total)
- **23 core skills** (12,142 lines total)
- **17 extensions** providing 66 additional agent files and 73 skill files
- Largest skill: skill-memory (2,482 lines), skill-orchestrate (1,145 lines)

### Worst Case: Separate Hard-Mode Skills Per Extension

If every extension gets hard-mode research + implementation skills:
- +34 new skills (17 extensions × 2 skills)
- +34 new agents (17 extensions × 2 agents)
- Estimated +20,000 lines of SKILL.md content (mostly duplicated from standard versions)
- `.claude/` grows from 18MB to ~25MB

**Verdict**: Unsustainable. Even with the thin-wrapper pattern, 34 new files that are 80% duplicates of existing skills creates a maintenance burden that guarantees drift.

### Best Case: Contract Composition + Minimal Structural Changes

If hard mode uses composable contracts with minimal skill variants:
- +6 contract files (~120 lines each, ~720 lines total)
- +1 skill variant (skill-orchestrate-hard, ~600 lines, the structural parts that can't be shared)
- +0 to +2 agent variants (only if domain-specific agent prompts can't be handled by contract injection)
- `.claude/` grows by ~2,000 lines (0.5MB)

**Verdict**: Highly sustainable. The contract library becomes a shared resource that benefits all modes and extensions.

### Testing Strategy

Hard-mode skills are harder to test than normal skills because their value proposition is _behavioral_ (agents produce code instead of analysis) rather than _structural_ (file exists, status updated). Options:

1. **Regression replay**: Save the delegation context + handoff from hard task 273, replay against hard-mode skills, compare output quality. Expensive but high-fidelity.
2. **Contract lint**: Verify that hard-mode prompts contain required contract sections (anti-analysis block present? territory section present?). Cheap and automatable.
3. **Churn metrics**: After implementing churn detection (H6), track churn rates across tasks. Hard-mode tasks should have lower churn. This is a lagging indicator but the most meaningful.
4. **A/B comparison**: Run the same task with and without `--hard`. Compare token consumption, deflection count, and outcome. The report already provides baseline data from task 273.

**Recommended**: Start with contract lint (automatable, catches regressions) and churn metrics (meaningful outcome measure). Defer regression replay until v2.

### Context Budget Impact

Hard-mode agents receive more context than standard agents (contract fragments, territory specs, foundation lists). Estimated additional context per agent dispatch:
- Anti-analysis contract: ~200 tokens
- Territory contract: ~150 tokens
- Prior-art grounding: ~300 tokens (varies by domain)
- Wrap-up contract: ~200 tokens
- Foundations list: variable, ~100–500 tokens

Total overhead: ~950–1,350 tokens per dispatch. Against the 200k+ token working context of Sonnet/Opus agents, this is <1% overhead. Not a concern.

**However**: If hard-mode uses per-phase dispatch (H1), each task generates MORE dispatches (one per phase vs. one for the whole plan). A 6-phase plan means 6 agent dispatches instead of 1, each with its own context loading. Total token consumption increases ~4–6× per task. This is the main cost driver, not the contract overhead.

---

## Summary Recommendation

**Implement hard mode as a contract-composition system with minimal structural changes, not as a parallel set of hard-mode skill/agent files.**

1. Create a `contracts/` directory in context with composable prompt fragments (H2, H3, H7, H9)
2. Add per-phase dispatch logic to skill-orchestrate behind `--hard` flag (H1, H6, the structural parts)
3. Create skill-orchestrate-hard ONLY if the structural divergence exceeds ~30% of skill-orchestrate
4. Use the extension system for domain-specific hard-mode overlays (lean4 gets H3/H5/H8 specializations)
5. Plan for adaptive difficulty (v2/v3) but don't build it yet — hard mode IS the data collection mechanism

The key insight: **most of hard mode is prompt contract, not code**. The system already has the architecture to inject context into agent prompts. Hard mode should leverage that architecture, not duplicate it.

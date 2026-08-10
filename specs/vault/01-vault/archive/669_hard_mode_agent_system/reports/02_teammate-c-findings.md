# Teammate C (Critic) Findings: Hard-Mode Agent System

- **Task**: 669 - hard_mode_agent_system
- **Date**: 2026-06-12
- **Role**: Critic — gaps, blind spots, and unvalidated assumptions
- **Confidence**: Overall HIGH (grounded in actual file counts, routing tables, and code inspection)

---

## Key Findings

### 1. Single-Task Evidence Base (Confidence: HIGH)

Report 01 derives all 9 hard-mode techniques from a single task: BimodalLogic task 273 (Lean 4 formalization). This is a mathematically rigorous, literature-backed, formally-verified domain — arguably the most demanding task type in the entire system. The evidence is strong *for that type of task*, but the generalization to other hard tasks is assumed, not demonstrated.

**Specific concerns**:
- **H3 (prior-art grounding)** presupposes a literature base with citable propositions. Tasks like "refactor 40 Neovim plugin configs" or "migrate Nix flake to new module system" have no such literature. The technique needs a domain-agnostic reformulation (e.g., "reference grounding" that works with docs, APIs, specs — not just academic papers).
- **H5 (divergence audit)** is framed as "our formalization vs published proof." For non-formal domains, "divergence" must mean something different (our implementation vs reference implementation? Our config vs documented behavior?). The report doesn't propose this generalization.
- **H2 (anti-analysis contracts)** includes "sub-sorry policy" which is pure Lean jargon. The "forbidden conclusions" concept is general but the specific instantiation is narrow.
- **Missing evidence for non-Lean hard tasks**: What does "hard" look like for a complex Nix migration? A 50-file web app refactor? A multi-repository Python deployment? These tasks fail in different ways (dependency hell, environment drift, integration regression) not captured by F1-F6.

**5 of 9 techniques are fully domain-general** (H1, H4, H6, H7, H9). 3 need adaptation (H2, H5, H8). 1 needs fundamental rethinking (H3). The report should acknowledge this gradient rather than presenting all 9 as universal.

### 2. Combinatorial Explosion of Skill Variants (Confidence: HIGH)

The current system has:
- **23 core skills** + **73 extension skills** = **96 total skills**
- **12 core agents** + **65 extension agents** = **77 total agents**
- **17 extensions** with routing
- **59 unique routing entries** across extensions

The `--team` precedent already created 3 new skills (skill-team-research, skill-team-plan, skill-team-implement). Report 01 proposes at minimum:
- skill-orchestrate-hard (1)
- skill-planner-hard (1)
- skill-implementer-hard (1) — or skill-{domain}-implementation-hard per extension
- skill-researcher-hard (1) — or skill-{domain}-research-hard per extension

**Conservative count** (core only): +4 skills, +4 agent variants = 8 new files.
**Full extension coverage**: If lean, nix, neovim, python, web, z3 each get hard variants for research + implement, that's +12 more skills = **20+ new files**.

**The --team × --hard interaction is unaddressed**. Currently:
- `--team` → skill-team-{X}
- `--hard` → skill-{X}-hard (proposed)
- `--team --hard` → ??? (skill-team-{X}-hard? Not mentioned anywhere)

This is a 2×2 matrix per command that will become a 2×2×N matrix across extensions. The `--team` flag already ignores task_type routing (routes to one skill regardless). Will `--hard` do the same, or respect extension routing? The report proposes extension-specific hard skills (skill-lean-implementation-hard) but doesn't address the team interaction.

### 3. effort_flag Is Currently a No-Op (Confidence: HIGH)

The `--hard` flag is already parsed by `parse-command-args.sh` and plumbed through all 4 commands (research, plan, implement, orchestrate) into skills. But in every skill and agent examined, effort_flag is treated identically:

> "If `effort_flag` is set (fast, hard), include it as prompt context for reasoning depth guidance."

**No skill branches on effort_flag**. No agent changes its behavior structurally. It's soft guidance at best. This means:
1. Users who tried `--hard` before got essentially nothing — just a hint in the prompt
2. The infrastructure for passing the flag EXISTS and works; the gap is in skill/agent behavior, not plumbing
3. This is actually good news: the routing infrastructure is ready. The question is whether to use it for routing (switch skill targets, as Report 01 proposes) or for behavioral modulation (enrich the standard skill's behavior when effort_flag=hard)

### 4. The "Separate Skill" vs "Behavioral Injection" Trade-off Is Not Explored (Confidence: HIGH)

Report 01 assumes the answer is separate skill files: skill-orchestrate-hard, skill-planner-hard, etc. The user's own framing supports this ("hard-mode routing to happen early at the command level to divert to a hard-mode skill"). But an alternative was not explored:

**Alternative: Behavioral injection via shared context fragments**

Instead of creating skill-orchestrate-hard (a whole new skill file), skill-orchestrate could check `effort_flag == "hard"` and:
1. Load hard-mode prompt fragments from `.claude/context/hard-mode/` (H2, H3, H7, H9 blocks)
2. Switch its dispatch loop from whole-plan to per-phase (H1)
3. Enable churn detection counters (H6)
4. Require adversarial verification before implementation (H4)

**Advantages**: No new files, no routing changes, no combinatorial explosion, changes are local to the skill that needs them.
**Disadvantages**: Each skill becomes more complex (conditional branches), harder to reason about, harder to test independently.

The user explicitly asked to avoid adding complexity to individual skill files. But the report's alternative (separate files) adds complexity to the system as a whole (more files to maintain, more routing to test). This fundamental tension is not analyzed.

### 5. Missing: When to Use --hard (Confidence: MEDIUM)

There is no proposed heuristic or guidance for the user to know when `--hard` is appropriate. The report identifies "observable signatures" of a hard task (Section 1): multiple plan versions, target moves instead of closing, agents proposing redesigns, inflating estimates. But these are all **retrospective** — you can only see them after several failed attempts.

**Missing**: A prospective indicator or decision framework. For example:
- Use `--hard` when the task has 3+ plan versions
- Use `--hard` when previous implementation attempts produced analysis-only output
- Use `--hard` by default for task types with formal verification (lean4, z3)
- The orchestrate command could auto-escalate to hard mode after detecting churn (no user flag needed)

The lack of guidance means users will either always use `--hard` (wasting tokens on easy tasks) or never use it (not knowing it exists until frustrated).

### 6. Token Cost Impact Not Quantified (Confidence: MEDIUM)

Report 01 provides excellent data for task 273 (Section 6) but doesn't estimate the general cost multiplier. Hard mode adds:
- Adversarial verification = 1 extra dispatch per research report
- Per-phase dispatch = N dispatches instead of 1 (N = number of phases, typically 3-6)
- Churn detection + audit = 1-2 extra dispatches when triggered
- Potential divergence audit = 1-2 research dispatches

**Rough estimate**: A standard research→plan→implement cycle is ~3 dispatches. Hard mode is ~8-15 dispatches. Token multiplier: **3-5x** minimum. For tasks that aren't actually hard, this is pure waste.

Combined with `--team` (5x per report), `--team --hard` would be **15-25x** standard cost. This needs to be communicated upfront.

---

## Assumptions Not Validated

| # | Assumption | Status | Risk |
|---|-----------|--------|------|
| A1 | All hard tasks share the same failure modes (F1-F6) | **Untested** | Different domains fail differently; F2-F3 are formal-verification-specific |
| A2 | Separate skill files are better than behavioral modulation | **Assumed, not compared** | May create unsustainable maintenance burden |
| A3 | --hard is a user-facing choice (opt-in) | **Assumed** | Auto-detection of "hardness" might be more effective |
| A4 | Extension-specific hard variants are needed | **Assumed** | Most of hard mode is domain-agnostic orchestration; domain-specific bits could live in context fragments |
| A5 | The orchestrate skill needs a hard variant | **Reasonable** | This is where most value is (per-phase loop); but it could be a mode within the existing skill |
| A6 | Hard mode for /research means "research + adversarial verify" | **Reasonable** | But this could also be a --verify flag or automatic quality gate |
| A7 | --hard and --team are independent dimensions | **Unaddressed** | Their interaction is undefined |
| A8 | Plan format changes (H8) require a new planner skill | **Questionable** | The planner already adapts to task type; hard-mode format could be injected via context |

---

## Questions That Should Be Asked

### Architecture Questions
1. **Is the routing-first approach (new skill files) better than the injection approach (same skills, conditional behavior)?** Both have trade-offs; the report doesn't compare them.
2. **How does --hard interact with --team?** Are they mutually exclusive? Composable? Independent?
3. **Should hard mode be per-command or per-task?** If a task IS hard, shouldn't ALL commands automatically use hard mode for it? (Store `hard_mode: true` in state.json rather than requiring the flag every time.)
4. **What's the minimum viable hard mode?** The report proposes 9 techniques and 7 implementation steps. What's the single highest-value change? (Almost certainly: per-phase dispatch in skill-orchestrate.)

### Scope Questions
5. **Does /revise need --hard?** The reviser-agent creates new plan versions. In hard mode, revisions should enforce H8 format.
6. **Does /spawn need --hard?** Spawning sub-tasks for a hard task should inherit the hard mode.
7. **How does hard mode persist across sessions?** If the user runs `/orchestrate 273 --hard`, pauses, and resumes tomorrow, does the task remember it's in hard mode? Should `hard_mode` be a state.json field?
8. **What about auto-escalation?** Instead of (or in addition to) --hard, could skill-orchestrate detect churn and automatically escalate to hard-mode behavior?

### Practical Questions
9. **What's the rollout path?** Hard-mode orchestrate alone covers the highest-value change (per-phase dispatch). It could ship independently. Does the plan need to be all-or-nothing?
10. **How do you test hard mode?** There's no test framework for skill behavior. How do you verify that hard-mode orchestrate actually does per-phase dispatch?
11. **What if hard mode makes things worse?** For simple tasks, per-phase dispatch adds overhead (more commits, more handoffs, more context switches). Is there a "this task is too simple for hard mode" escape hatch?

---

## Summary of Gaps

| Gap | Severity | Recommendation |
|-----|----------|----------------|
| Single-task evidence base | Medium | Acknowledge limitation; identify 2-3 additional hard-task archetypes (complex Nix migration, multi-file web refactor, cross-extension meta task) and map which H-techniques apply |
| Combinatorial explosion not addressed | High | Decide: (a) separate files, (b) injection, or (c) hybrid. Count the files each approach creates. Present trade-offs. |
| --team × --hard interaction undefined | High | Define: mutually exclusive, composable, or team-mode-with-hard-contracts |
| No prospective "when to use --hard" guidance | Medium | Propose a decision framework or auto-detection heuristic |
| Domain-specific techniques presented as universal | Medium | Separate core hard-mode contract (H1, H4, H6, H7, H9) from domain-specific extensions (H3, H5 variants) |
| effort_flag is currently a no-op | Low | Good news: infrastructure exists. Decide whether to repurpose it for routing or leave routing to a new mechanism |
| Token cost not quantified | Medium | Estimate per-command multiplier and total lifecycle multiplier; document in /help or command output |

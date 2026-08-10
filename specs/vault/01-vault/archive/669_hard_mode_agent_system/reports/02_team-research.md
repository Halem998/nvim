# Research Report: Task #669

**Task**: Add hard-mode routing (--hard) with hard-mode skills and agents for very complex tasks
**Date**: 2026-06-12
**Mode**: Team Research (4 teammates)
**Session**: sess_1781281284_bda467

---

## Summary

The team converged on a hybrid architecture that satisfies the user's explicit constraint (command-level routing to hard-mode skills) while minimizing file proliferation through contract composition. The core insight — confirmed across all four teammates — is that the nine hard-mode techniques from Report 01 divide cleanly into two buckets: prompt-level changes (H2, H3, H7, H9) that can be delivered as composable context fragments, and structural-loop changes (H1, H5, H6) that require a genuine skill variant for the orchestrator. This division resolves the central tension between the "separate skill files" approach (A's proposal) and the "behavioral injection" approach (B/D's preference): use separate hard-mode skill files as thin routing wrappers that compose shared contract fragments, rather than duplicating the full skill body.

The file inventory is manageable: 5 prompt-contract files, 4 thin hard-mode skill wrappers, 3 hard-mode agent variants (or 1 if agent separation proves unnecessary for workers), and modifications to 5 existing files (command-route-skill.sh + 4 commands). The total is 12–15 new files — above B/D's preferred 6–7 but well below A's worst-case 20+, and the user-facing UX (separate skill files reachable from command-level routing) is exactly what was requested. The skill wrappers are thin precisely because the substantive hard-mode prompt content lives in the shared contract library.

Several sharp concerns from the Critic remain open and must be addressed in the plan. Five of nine H-techniques are domain-general; three (H2, H5, H8) need adaptation for non-Lean domains; one (H3) needs fundamental reformulation as "reference grounding" for domains without academic literature. The --team x --hard interaction is undefined and must receive a policy decision before implementation. Token cost (3–5x per task, 15–25x for --team --hard) must be documented. A prospective "when to use --hard" decision framework is absent from Report 01 and must be written before the feature is considered complete.

The phased rollout recommended by Teammate D captures roughly 80% of the value with 40% of the scope: implement H1 (per-phase dispatch in skill-orchestrate-hard) and H2 (anti-analysis contract fragment) first, ship that as a working --hard flag, then extend to H4/H6/H9 in a second phase and domain-specific overlays (H3, H5, H8 for lean4) in a third phase.

---

## Key Findings

### Primary Approach (from Teammate A)

Teammate A conducted a thorough line-by-line audit of the four target command files and the routing infrastructure. The most important structural finding: all four commands (research.md, plan.md, implement.md, orchestrate.md) share an identical delegation pattern, and the --team flag already demonstrates the exact routing branch to replicate for --hard. The branch point is STAGE 2: DELEGATE in each command, immediately after team-mode is checked and before extension routing. The `--hard` branch slots cleanly between them.

A identified a routing inconsistency in the current codebase: implement.md uses the centralized `command-route-skill.sh` script, but research.md and plan.md inline their extension-manifest routing loops directly (lines 332–366 in research.md, 334–370 in plan.md). The cleanest fix is to extend `command-route-skill.sh` with a fourth argument `$4 = effort_flag` and refactor research.md and plan.md to use it — removing ~35 lines of inline routing each and centralizing all effort-flag handling in one script. This is a clean simplification, not just a feature addition.

The extension manifest schema (routing.{operation}.{task_type}) can be extended with a parallel `routing_hard` sibling key. Because the existing routing script only reads `routing`, the new key is invisible until the script is updated — a backwards-compatible schema extension with graceful degradation (absent `routing_hard` falls back to normal routing).

A's proposed file inventory: 5 contract files + 4 hard skills + 3 hard agents + 7 modified files = 12 new files, 7 modifications. The separate-agent recommendation carries MEDIUM confidence because A acknowledges the ~40% overlap concern but deems it acceptable given the user's explicit preference for clean separation and the ability to reference shared context from the agent files.

### Alternative Approaches (from Teammate B)

Teammate B measured the duplication cost of the full-variant approach by examining the existing --team skills: skill-team-research is 633 lines vs skill-researcher at 465 lines, with ~60% shared boilerplate. If hard-mode follows the same pattern across all extensions, the total grows to 14–20 new files and 7,000–12,000 new lines — a maintenance burden that guarantees drift when base skills change.

B's highest-ranked alternative is a hybrid: prompt contracts for the worker behaviors (H2, H3, H7, H9) and a single new skill file only for the orchestrator (skill-orchestrate-hard), since the per-phase dispatch loop (H1), divergence audit (H5), and churn detection (H6) require genuine structural changes that cannot be expressed as prompt injection. B's file count for this hybrid: ~6–7 new files. This is the minimum viable architecture.

B also identified that the --hard flag is currently a no-op in every skill: `effort_flag` is described in the skill headers as "include it as prompt context for reasoning depth guidance" but no skill branches on it. The plumbing is complete and working; the gap is entirely in skill/agent behavior.

The profile-based approach (storing `hard_mode: true` in state.json so the task remembers it's in hard mode across sessions) is sound as a v2 enhancement. The minimal v1 step is to add `effort_mode` to the task entry in state.json, which is cheap and future-proofs the schema without requiring any behavior change yet.

### Gaps and Shortcomings (from Critic)

The Critic (Teammate C) raised four high-severity issues that the plan must address explicitly.

**The single-task evidence problem.** All nine H-techniques were derived from one task: BimodalLogic task 273, a Lean 4 formalization with academic literature, formal verification, and proof chain constraints. The Critic's domain-generalization gradient is the most actionable finding: H1, H4, H6, H7, H9 are fully domain-general; H2, H5, H8 need adaptation; H3 needs fundamental reformulation. The plan should explicitly scope which techniques are core (universal) and which are lean4-specific overlays, rather than presenting all nine as universal.

**The combinatorial explosion is not addressed.** The current system has 23 core skills + 73 extension skills = 96 total, and 12 core agents + 65 extension agents = 77 total (this is the accurate count inclusive of extensions; core-only is 23 skills / 12 agents). If every extension gets hard-mode research + implementation variants, that is +34 skills. The architecture decision must explicitly answer: core-only hard-mode skills now, extension overlays later via the `routing_hard` manifest key.

**The --team × --hard interaction is completely undefined.** This must receive a policy decision: (a) mutually exclusive — --hard and --team cannot be combined; (b) composable — --team --hard routes to skill-team-{op} with hard-mode contracts injected; (c) independent -- --team takes precedence and --hard is ignored when both are present. Option (a) or (c) is simpler for v1; (b) creates a 2×2×N combinatorial space.

**No prospective "when to use --hard" guidance.** Without a decision framework, users will either always use --hard (wasting tokens) or never use it (not knowing it exists). The plan must include a simple heuristic: e.g., use --hard when the task has 2+ plan versions, when previous implementation attempts produced analysis-only output, or when the task type is lean4/z3 (formal verification domains where F1-F6 are high-probability failure modes).

**Token cost unquantified.** Hard mode adds roughly 3–5x dispatches per task lifecycle. Combined with --team (5x), --team --hard is approximately 15–25x standard cost. This must be documented in the command output or a usage note.

The Critic assessed Teammate A's findings as strong on routing architecture (confirmed by evidence) and weaker on the separate-agent justification (the duplication concern is real and not fully addressed). Teammate B's hybrid approach was assessed as architecturally sounder for long-term maintenance.

### Strategic Horizons (from Horizons)

Teammate D contributed three high-confidence structural insights.

**The three-category model.** The nine H-techniques fall into: dispatch geometry (H1, H7, H8 — change how work is divided), prompt contracts (H2, H3, H9 — change what rules agents follow), and feedback loops (H4, H5, H6 — change how the orchestrator reacts). This categorization matters for implementation: dispatch geometry requires skill structural changes, prompt contracts are context fragments, feedback loops are state-machine additions to the orchestrator. Keeping these categories separate in the implementation allows them to be composed later (e.g., hard plan format H8 applied to normal-mode planning as a standalone improvement).

**The mode-as-extension architecture.** D proposed an unconventional but principled option: make "hard mode" itself a `.claude/extensions/hard-mode/` extension, so it can be loaded/unloaded, domain extensions can declare `"dependencies": ["hard-mode"]`, and the core system stays untouched. The main blocker is that manifest routing currently only keys on task_type, not effort_flag — adding `routing_hard` to the manifest format (as A also proposed) resolves this. This approach is architecturally attractive but adds one layer of indirection that may not be worth the complexity at v1.

**The sustainable scale assessment.** Current system: 1,141 files in .claude/ (18MB), skill-orchestrate at 1,145 lines, skill-memory at 2,482 lines. Worst case (per-extension hard variants for all 17 extensions): +34 skills, +34 agents, ~20,000 new lines, growing .claude/ to ~25MB. Best case (contract composition + minimal structural changes): +6 contract files + 1 skill variant + 0-2 agent variants, ~2,000 new lines. D's recommendation aligns with B's hybrid: minimize separate skill/agent files, maximize composable contracts.

**The adaptive difficulty trajectory.** D sketches the correct v1→v4 progression: v1 (--hard flag, manual), v2 (churn counter detection, advisory warnings), v3 (auto-escalation with user confirmation), v4 (full adaptive mode). Hard mode IS the data collection mechanism for adaptive difficulty — running tasks with --hard vs without builds the empirical basis for adaptive thresholds. Building v2 advisory warnings into v1 (emit a "this task looks hard: consider --hard" message when churn is detected) is a natural addition to the orchestrator that costs almost nothing.

---

## Synthesis

### Conflicts Resolved

**Conflict 1: File count (A's 12 files vs B/D's 6-7 vs Critic's warning against 20+)**

Resolution: **10-12 new files, structured as thin wrappers over shared contracts.**

The apparent disagreement dissolves when the architecture is clarified. B and D's "6-7" assumes no separate agent files and routes prompt changes through existing agents. A's "12" includes 3 hard agent files. The Critic's warning is about extension proliferation, not core file count.

The recommended count: 5 contract files (H2, H3, H6, H7, H9) + 4 thin hard skill wrappers + 3 hard agent files = 12 new files, plus 7 file modifications. The skill wrappers are genuinely thin (120-150 lines each) because the substantive prompt content lives in the contracts library. The 3 agent variants are justified because agents are where the H-technique prompt contracts are permanently baked in (via @-references), which is cheaper per-dispatch than having every skill runtime-load them. If agent separation proves too burdensome, the fallback is contract injection at skill level (B's preference), reducing to 9 new files.

The critical constraint honored from the user: command-level routing to named hard-mode skills. All four hard skill wrappers exist as real files; routing is not conditional behavior inside existing skills.

**Conflict 2: Skill counts (Critic's 96/77 vs A/B's lower numbers)**

Resolution: **Both are correct; they count different scopes.**

- Core system only: 23 skills, 12 agents (confirmed across A, B, D)
- Including all loaded extensions: 96 skills, 77 agents (Critic's count, verified against manifest survey)

The plan targets core hard-mode skills only (4 new). Extension-specific hard variants (lean4, formal, etc.) are explicitly deferred to Phase 3+, enabled by the `routing_hard` manifest key that gracefully falls back to core hard skills when no extension variant exists.

**Conflict 3: Separate agent files vs prompt injection (A leans toward separate; B and D lean toward injection)**

Resolution: **Separate agent files for the 3 worker agents, but using contract @-references to minimize duplication.**

The user's explicit statement ("hard-mode routing to happen early at the command level to divert to a hard-mode skill, which calls hard-mode agents") establishes the intended architecture. Prompt injection (B/D's preference) would require skills to conditionally read and inject files at runtime, adding complexity to each skill file — which directly contradicts the user's "not too much complexity in any one skill or agent file" constraint.

The duplication concern is addressed architecturally: hard agent files reference the contract files via @-syntax rather than duplicating the contract text. The hard agent's system prompt says:
```markdown
## Context References
- `@.claude/context/contracts/anti-analysis.md` — H2 anti-analysis contract
- `@.claude/context/contracts/wrap-up.md` — H9 handoff discipline
```
This means each hard agent carries ~10-20 lines of @-references rather than 200 lines of duplicated prompt contract. The maintenance point for each contract remains a single file.

The one genuine exception: skill-orchestrate-hard (H1, H5, H6) requires a full structural variant because the dispatch loop itself changes. This is approximately 400-600 lines, the majority of which is genuinely new code (per-phase loop, churn detection state machine) rather than duplication.

**Conflict 4: Scope — D's progressive H1+H2 first vs A's full 7-step breakdown**

Resolution: **3-phase rollout with H1+H2+routing infrastructure in Phase 1, H4+H6+H9 in Phase 2, domain-specific overlays in Phase 3.**

D's data point (H1 alone produced the inflection point in task 273 — zero code to 343 lines committed in one dispatch) is strong evidence for prioritizing H1. The plan delivers a working `--hard` flag after Phase 1 with the two highest-value techniques. Phases 2 and 3 add the remaining H-techniques and domain extensions without blocking the initial delivery.

This resolves the tension: A's Phase 5 (extension integration) and Phase 6 (documentation) become Phase 3 in the phased rollout; A's Phases 1-4 (routing + contracts + agents + core skills) map to Phases 1 and 2.

### Coverage Gaps

**Gap 1: Non-Lean domain definitions for H3, H5, H8, H9.**
The current formulation of H3 (prior-art grounding) assumes academic papers. For neovim, nix, web, and general tasks, "prior art" means official documentation, API specifications, reference implementations, and changelog history — not papers. The plan should specify a domain-agnostic "reference grounding" formulation of H3 that the lean4 extension specializes. Similarly, H9 (sorry inventory) is Lean-specific; the general equivalent is "partially-implemented module inventory" or "pending test failures."

**Gap 2: --team × --hard policy.**
This is unresolved. The plan must pick one: (a) mutually exclusive for v1, (b) --team takes precedence and --hard is silently ignored, or (c) --team --hard is an explicit error with a user-facing message. Option (a) with a clear error message is recommended for v1 simplicity.

**Gap 3: "When to use --hard" decision framework.**
No prospective heuristic exists. The plan must produce a 5-bullet decision framework (included in CLAUDE.md and optionally emitted by the command on first --hard use).

**Gap 4: State.json persistence for hard mode.**
If a task is hard, every command run against it should ideally use --hard automatically. The plan should decide whether to add `effort_mode: "hard"` to state.json entries when --hard is first used, so subsequent /implement and /orchestrate calls inherit the mode without re-specifying the flag.

**Gap 5: Testing strategy.**
There is no test framework for skill behavioral correctness. The Critic raised this; D provided three options. The plan should include at least "contract lint" (verify hard-mode agent prompts contain required @-reference sections) as a lightweight automated check, and document the intended A/B comparison methodology for measuring hard-mode effectiveness.

### Recommendations

The following is ordered for direct plan authoring. Each item names the exact files to create or modify.

**Phase 1: Routing Infrastructure + Core Contracts + H1 + H2 (Minimum Viable --hard)**

Deliver a working `--hard` flag with the two highest-value techniques (per-phase dispatch and anti-analysis contract). Covers ~80% of the measured value from Report 01.

1. **Extend `.claude/scripts/command-route-skill.sh`** with a fourth argument `$4 = effort_flag`. When `effort_flag="hard"`: (a) check `routing_hard.{operation}.{task_type}` in each extension manifest before falling back; (b) if no extension hard variant found, append `-hard` to the default skill name; (c) if the `-hard` skill directory does not exist, fall back to the standard skill with a stderr warning. This is a backwards-compatible change — existing callers passing 3 arguments get standard behavior.

2. **Update `.claude/commands/implement.md`** (1 line): pass `"$EFFORT_FLAG"` as 4th argument to `command-route-skill.sh`. Add a policy comment: `--team takes precedence; --hard and --team are mutually exclusive in v1 (emit error if both set)`.

3. **Update `.claude/commands/research.md`**: Replace the inline routing loop (lines 332-366) with a call to `command-route-skill.sh "research" "$task_type" "skill-researcher" "$effort_flag"`. This simplifies the file by ~35 lines.

4. **Update `.claude/commands/plan.md`**: Same refactor as research.md (lines 334-370 → command-route-skill.sh call).

5. **Update `.claude/commands/orchestrate.md`**: Source `parse-command-args.sh` (currently not done), extract `EFFORT_FLAG`, and route to `skill-orchestrate-hard` when `EFFORT_FLAG="hard"`. Add `--team × --hard` mutual-exclusion guard.

6. **Create `.claude/context/contracts/anti-analysis.md`** (~60 lines): The H2 prompt contract verbatim from Report 01 Section 3 — read budget (≤15-20%), forbidden conclusions, defect bar, sub-sorry policy, settled-design preamble. Write in domain-agnostic language with a lean4-specific section at the end that the lean4 extension can override.

7. **Create `.claude/skills/skill-orchestrate-hard/SKILL.md`** (~500 lines): The structural variant for the orchestrator. Core additions over skill-orchestrate: per-phase dispatch loop (H1), churn-detection counters (defect_claims, sorry_relocations), divergence-audit trigger at 3 deflections (H5), mandatory adversarial verify before first implementation dispatch (H4 gate), escalation ladder update (blocker → audit → user-pivot-ask). Inject `@.claude/context/contracts/anti-analysis.md` in the delegation prompt slot.

8. **Update `.claude/context/index.json`**: Add entry for `contracts/anti-analysis.md` with `load_when.agents` pointing to hard-mode agents (to be created in Phase 2).

**Phase 2: Remaining Contracts + Hard Skills + Hard Agents**

Deliver full --hard coverage for /research and /plan commands.

9. **Create `.claude/context/contracts/wrap-up.md`** (~50 lines): H9 handoff contract — orchestrator handoff JSON schema (≤400 tokens, fields: status, phases_completed, sorry_inventory, blockers with verbatim goals, continuation_path), continuation handoff markdown format, incremental commit discipline, build-green invariant. Domain-agnostic formulation with a lean4 `sorry_inventory` section.

10. **Create `.claude/context/contracts/territory.md`** (~40 lines): H7 territory contract — file territory declaration, plan-section territory, commit protocol (rebase on non-fast-forward), handoff merge rule (read-merge-write, never clobber).

11. **Create `.claude/context/contracts/convergence.md`** (~40 lines): H6 convergence policing — progress criterion declaration format, churn-signature definition, three-strikes audit trigger, user-authorization requirement for architectural pivots.

12. **Create `.claude/context/contracts/reference-grounding.md`** (~60 lines): Domain-agnostic reformulation of H3 — "reference grounding" that works for tasks with docs/APIs/specs as well as academic literature. Sections: for literature-backed domains (papers, citations, PDF-level reading), for documentation-backed domains (official docs, changelogs, reference implementations), for implementation-backed domains (reference code, test suites, behavior specs). The lean4 extension will overlay this with the strict transcription-mandate version.

13. **Create `.claude/agents/general-research-hard-agent.md`** (~200 lines): Hard research agent. Same research strategy as `general-research-agent.md`. Additions: mandatory adversarial verification pass after report creation (H4), reference grounding requirement (H3 general form), divergence-audit mode when focus_prompt requests it (H5). Context @-references: `contracts/reference-grounding.md`, `contracts/anti-analysis.md`. Model: sonnet (same as base agent).

14. **Create `.claude/agents/planner-hard-agent.md`** (~250 lines): Hard planning agent. Same plan creation flow as `planner-agent.md`. Additions: phase sizing constraint (each phase completable in one agent run, ~100-500 lines), postmortem-constraints section, preserved-assets accounting, dependency-wave declarations, reference-grounding table when literature exists (H8). Context @-references: `contracts/reference-grounding.md`, `formats/plan-format.md`. Model: opus (plan quality benefits from deeper reasoning).

15. **Create `.claude/agents/general-implementation-hard-agent.md`** (~250 lines): Hard implementation agent. Same execution flow as `general-implementation-agent.md`. Additions: anti-analysis contract baked via @-reference (H2 — the highest single-dispatch value change), wrap-up contract for handoff discipline (H9), territory contract awareness (H7). Context @-references: `contracts/anti-analysis.md`, `contracts/wrap-up.md`, `contracts/territory.md`. Model: sonnet.

16. **Create `.claude/skills/skill-researcher-hard/SKILL.md`** (~150 lines): Thin wrapper delegating to `general-research-hard-agent`. Key additions: after agent returns, if report contains load-bearing claims, emit a note that adversarial verification was triggered (the agent handles it internally, but the skill should log it to the postflight metadata). Standard preflight/postflight lifecycle.

17. **Create `.claude/skills/skill-planner-hard/SKILL.md`** (~120 lines): Thin wrapper delegating to `planner-hard-agent`. Passes H8 plan requirements in delegation context. Standard lifecycle.

18. **Create `.claude/skills/skill-implementer-hard/SKILL.md`** (~150 lines): Thin wrapper delegating to `general-implementation-hard-agent`. Key difference from standard: passes single-phase dispatch context (reads from handoff JSON to identify the next incomplete phase), not whole-plan context. Includes territory contract parameters when parallel dispatch is detected.

19. **Update `.claude/context/index.json`**: Add entries for all 4 contract files + hard agent load conditions.

20. **Update `.claude/CLAUDE.md`**: Add --hard routing to Skill-to-Agent Mapping table, Command Reference table (--hard flag documentation), and add a "When to use --hard" section with decision framework (5 bullets: 2+ plan versions, analysis-only prior outputs, formal verification domain, known literature base, cross-cutting task with multiple implementation agents).

**Phase 3: Extension Integration + Domain Overlays**

Add lean4-specific hard-mode overlays (H3 strict transcription, H5 formal divergence audit, H8 lemma-to-source mapping). Enable the `routing_hard` manifest key for other extensions to declare domain-specific hard variants.

21. **Update extension manifest schema documentation** (`.claude/context/guides/extension-development.md`): Document the optional `routing_hard` key with the same structure as `routing`. Extensions that don't provide `routing_hard` automatically fall back to core hard-mode skills.

22. **Create lean4-specific hard-mode overlays**: `skill-lean-research-hard`, `skill-lean-implementation-hard`, `lean-research-hard-agent.md`, `lean-implementation-hard-agent.md` — with strict H3 transcription mandate, H5 formal divergence audit, H8 lemma-to-source mapping table, H9 sorry inventory tracking.

23. **Update lean4 manifest.json**: Add `routing_hard` entries pointing to the lean4-specific hard skills.

**Cross-cutting: State Persistence + --team × --hard Policy**

24. **Add `effort_mode` field to state.json task entries**: When `--hard` is first passed, set `effort_mode: "hard"` in the task's state.json entry. Subsequent commands check this field; if set to "hard," default behavior is --hard even without the flag. User can override back with `--normal` (or equivalent). This makes hard mode sticky per-task.

25. **Document --team × --hard policy**: In v1, these flags are mutually exclusive. If both are passed, emit an error: `"--team and --hard cannot be combined in v1. Use one or the other. --team --hard will be supported in a future release."` Document in CLAUDE.md.

---

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary implementation approach and routing architecture | completed | High (routing) / Medium (agent separation) |
| B | Alternative patterns, prior art, and hybrid architecture | completed | High (duplication analysis) / Medium (web patterns) |
| C | Critic: gaps, blind spots, unvalidated assumptions | completed | High (file counts, domain-generalization) / Medium (token cost, when-to-use) |
| D | Strategic horizons: long-term sustainability and trajectory | completed | High (three-category model, scale analysis) / Medium (adaptive trajectory) |

---

## References

### Files Examined in This Codebase

- `/home/benjamin/.config/nvim/.claude/commands/implement.md` (lines 125-128: routing call)
- `/home/benjamin/.config/nvim/.claude/commands/research.md` (lines 323-366: inline routing loop)
- `/home/benjamin/.config/nvim/.claude/commands/plan.md` (lines 334-370: inline routing loop)
- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` (stage 1b case statement)
- `/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh` (current 3-argument signature)
- `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh` (EFFORT_FLAG export confirmed)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (465 lines — base size)
- `/home/benjamin/.config/nvim/.claude/skills/skill-team-research/SKILL.md` (633 lines — team variant size)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (506 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-team-plan/SKILL.md` (616 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (638 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-team-implement/SKILL.md` (695 lines)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (1,145 lines — largest skill)
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md` (base research agent)
- `/home/benjamin/.config/nvim/.claude/agents/planner-agent.md` (base planner agent)
- `/home/benjamin/.config/nvim/.claude/agents/general-implementation-agent.md` (base implementation agent)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json` (routing schema example)
- `/home/benjamin/.config/nvim/specs/669_hard_mode_agent_system/reports/01_hard-mode-orchestration-approach.md` (prior report, evidence base)

### Web Sources (from Teammate B)

- [Progressive Complexity Escalation pattern](https://agentic-patterns.com/patterns/progressive-complexity-escalation/) — validates tiered effort routing; warns about tier management overhead
- [Code Agent Orchestra](https://addyosmani.com/blog/code-agent-orchestra/) — quality gates as escalation triggers
- [Claude Code Skills Best Practices](https://www.firecrawl.dev/blog/best-claude-code-skills) — cost-routing layer pattern
- [CLAUDE.md Architecture 2026](https://www.obviousworks.ch/en/designing-claude-md-right-the-2026-architecture-that-finally-makes-claude-code-work/) — control stack pattern
- [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents) — SkillTool (inject) vs AgentTool (spawn) cost distinction
- [Multi-Agent Orchestration Guide](https://www.codebridge.tech/articles/mastering-multi-agent-orchestration-coordination-is-the-new-scale-frontier) — supervisor model with tiered effort

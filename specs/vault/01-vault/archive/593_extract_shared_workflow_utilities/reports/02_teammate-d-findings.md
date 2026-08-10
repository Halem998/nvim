# Research Report: Task 593 — Teammate D (Horizons) Strategic Findings

**Task**: 593 — Extract shared workflow utilities
**Role**: Teammate D (Horizons) — long-term strategic alignment
**Started**: 2026-05-22
**Focus**: Roadmap alignment, downstream implications, architecture resilience

---

## Key Findings (Strategic Alignment)

### 1. Roadmap Alignment: Moderate but Indirect

The ROADMAP.md contains no direct mention of the workflow refactor suite (tasks 593-599). Its Phase 1 priorities focus on documentation infrastructure (manifest-driven README generation, CI doc-lint enforcement, extension-slim linting) and agent system quality (subagent-return reference cleanup, frontmatter validation). These are maintenance and documentation concerns.

The success metrics listed include "Time from /task creation to first artifact < 60 seconds on average" — which is directly served by the token savings and complexity reduction from this refactor. However, this is a proxy metric, not a stated goal.

**Assessment**: Task 593 is not on the roadmap but serves it obliquely. The refactor is a systemic improvement that makes every other roadmap item faster to implement and maintain. If the ROADMAP.md were updated to reflect the actual trajectory of development, the workflow refactor would appear as Phase 0 infrastructure.

### 2. Task 593 Sets the Right Foundation — With One Scope Gap

Task 593 extracts the right targets in the right order. The design guidance (03_design-guidance.md) is concrete and implementation-ready. The scope is well-bounded: 4 scripts, ~525 lines eliminated, no changes to skill logic or extension routing.

**The scope gap**: Task 593's description includes `postflight-workflow.sh` as one of its 4 deliverables, but the existing `postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh` are bash scripts that run outside the LLM context. Their extraction produces zero token savings (confirmed by seed research). Their value is maintenance reduction only. This is correct and worth doing, but it should be stated clearly in the implementation to set accurate expectations. The real token-impact deliverables are `parse-command-args.sh`, `command-gate-in.sh`, and `command-gate-out.sh`.

**The missing deliverable**: The baseline token measurement methodology (documented in seed research as prerequisite #0) is not tracked as a discrete artifact in task 593's state.json entry. The design guidance mentions it but doesn't assign it an artifact slot. A research-oriented baseline report before extraction would let the team validate actual savings after tasks 594-595 complete.

### 3. Task 593 Correctly Serves 594-596

The dependency chain is well-designed:
- Task 593 provides the GATE IN/GATE OUT scripts that task 597 uses for `/task`, `/revise`, `/todo`, `/review`
- Task 593 provides `parse-command-args.sh` that task 595 uses when slimming `/research`, `/plan`, `/implement`
- Task 594 builds `skill-base.sh` on top of task 593's established patterns
- Tasks 595 and 596 both depend on tasks 593 and 594 completing first

The only dependency concern is task 598 (progressive disclosure context budgets) being elevated to Wave 2 while task 593 is Wave 1. This means task 593 is implementing shared utilities before the context budget constraints are finalized. The risk is low because the 4 scripts in task 593 are execution utilities (shell scripts), not context-bearing files. They are not subject to the token budget constraints that task 598 will establish.

---

## Long-Term Considerations

### A. Shared Scripts vs. the /orchestrate Architecture

This is the central strategic tension. The shared scripts (`parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh`) are designed for the current prompt-markdown-command model where a human types `/research 593` and the orchestrator runs a command file that sources these scripts.

The `/orchestrate` state machine (task 596) operates differently:
- It dispatches skills via `dispatch_agent()` inside a loop
- It never runs the command files directly
- It reads `.orchestrator-handoff.json` (400 tokens) instead of full agent output
- The `orchestrator_mode=true` flag flows through delegation context to skills

**Key insight**: The shared scripts (`parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh`) are consumed by the **command layer** (research.md, plan.md, implement.md). The `/orchestrate` state machine bypasses the command layer entirely — it invokes skills directly. Therefore, the shared scripts are not called by `/orchestrate` at all.

This is architecturally consistent and correct. The scripts serve the human-facing command path. The `/orchestrate` path is a parallel track that calls skills directly. Both paths are valid; they serve different use cases.

**Implication**: Task 593 is not at risk of becoming obsolete when task 596 ships. The human-typed commands remain the primary interaction mode for most users. The shared scripts reduce maintenance burden for that mode regardless of whether `/orchestrate` exists.

### B. `postflight-workflow.sh` — Serving the Right Master

The existing three postflight scripts (`postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh`) are called by **skills**, not by commands. They run after the LLM agent returns. This means they are part of the skill execution path, which is also the path that `/orchestrate` uses.

**Strategic implication**: Unifying these three scripts into `postflight-workflow.sh` serves both the human-command path AND the `/orchestrate` path. When `/orchestrate` dispatches a skill that calls `postflight-workflow.sh research`, the consolidated script fires correctly regardless of which path invoked the skill.

This is a rare case where task 593's work benefits both current and future architecture equally. It should be noted as a durable investment.

### C. Platform Evolution Risk

The shared scripts assume the current Claude Code prompt-markdown execution model where:
1. Command files (`.claude/commands/*.md`) are executed as prompts
2. Skills (`.claude/skills/*/SKILL.md`) are invoked via the Skill tool
3. Shell code in prompts is executed by the LLM reading and interpreting it

If Anthropic changes how commands work — for example, moving to native YAML command definitions, a declarative routing DSL, or native orchestration primitives — the prompt-markdown shell code blocks would need to be rewritten. The shared scripts themselves (pure bash) would survive such changes, but the `source` directives embedding them in commands would not.

**Resilience assessment**: The extraction approach is *more* resilient than the copy-paste status quo. If the command format changes, there are 3 places to update (3 command files) instead of 3*N places (3 commands * N duplicated blocks). The scripts themselves are pure bash and will survive any prompt-format change.

**Low risk**: Anthropic has not announced changes to the command model. The experimental fork/team APIs are additive, not replacing the existing model.

### D. The `command-gate-in.sh` and Session ID Generation

The `command-gate-in.sh` script generates `SESSION_ID` using `sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')`. This is currently done in each command file individually. Centralizing it in a shared script means all commands produce session IDs with the same format, which is good for consistency.

However, there is a subtle issue: if `/orchestrate` bypasses command files and invokes skills directly, it must generate its own session ID. The design guidance for task 596 already accounts for this — `skill-orchestrate` generates a session ID in its own initialization. This means session ID generation will exist in two places after the refactor:
1. `command-gate-in.sh` (for human-typed commands)
2. `skill-orchestrate/SKILL.md` (for the autonomous orchestrator)

This is not a bug — it is correct separation of concerns. The orchestrator is a different actor than the commands. But it should be noted so task 596 implementers know they do not source `command-gate-in.sh`.

---

## Opportunities and Risks

### Opportunities

**O1: Add a `--dry-run` flag to `parse-command-args.sh`**
A `--dry-run` flag that prints what would happen without executing could be added at low cost during this extraction. It would help users preview multi-task operations before committing. This is a small scope addition that does not affect downstream tasks.

**O2: Establish baseline measurements as a first-class artifact**
The seed research identifies baseline measurements as prerequisite #0 but does not give it an artifact slot. Create `specs/593_.../reports/02_baseline-measurements.md` explicitly before extraction begins. After tasks 594-595 complete, compare. This creates a permanent record of the refactor's actual impact.

**O3: Version the script API in a comment header**
Each script should include a `# API version: 1.0` comment and a `# Changed in: task 593` annotation. When task 595 or 596 modifies a script's interface, the version bump is visible in git blame. Low-cost, high-value for debugging.

**O4: `postflight-workflow.sh` as the `/orchestrate` postflight path**
Since the postflight scripts are called by skills (not commands), and `/orchestrate` calls skills, task 593's `postflight-workflow.sh` will be on the critical path for the autonomous orchestrator. This means task 593 delivers a component that task 596 depends on functionally, not just architecturally. The task 596 implementers should note this dependency.

### Risks

**R1: Scope creep into skill-base.sh territory**
The design guidance correctly says "Do NOT tackle skill-base.sh in task 593." However, as implementers work through the command files, they may be tempted to also factor out skill-level logic. This risks blurring the boundary between task 593 (command utilities) and task 594 (skill base). Strict adherence to scope is needed.

**R2: Incomplete GATE IN/GATE OUT extraction leaving hybrid state**
If the extraction leaves some GATE IN logic in command files and some in `command-gate-in.sh`, the system will have a hybrid state that is harder to reason about than either the original or the target. The implementation must be atomic: fully extract or leave in place. Partial extraction would make task 595 harder.

**R3: Extension command files not updated**
The extension skills (nix, neovim) have their own command-like patterns. If `parse-command-args.sh` is updated but extension entry points are not, users routing through extension skills will get inconsistent arg parsing. However, the task description correctly scopes to `/research`, `/plan`, `/implement` (core commands). Extension routing is task 599's concern. Low risk if scope is maintained.

**R4: `specs/tmp/` dependency in postflight scripts**
The existing postflight scripts use `specs/tmp/state.json` as a temp file destination. The unified `postflight-workflow.sh` must ensure `specs/tmp/` exists before writing to it, or use a more robust temp file pattern (`mktemp`). This is a minor implementation detail but easy to overlook during consolidation.

---

## Recommendations

**R1 (Primary): Proceed with task 593 as designed.** The scope is correct. The design guidance is implementation-ready. The extraction serves both current (human command) and future (/orchestrate) architecture.

**R2: Create the baseline measurement artifact before any extraction.** Run `wc -l` on all three command files, record the output as `02_baseline-measurements.md`, then begin extraction. This creates before/after proof.

**R3: Explicitly document that `postflight-workflow.sh` is on the `/orchestrate` critical path.** Add a comment in the script: `# Used by: skills (postflight stage); also on /orchestrate critical path via skill dispatch`. This prevents task 596 implementers from accidentally bypassing it.

**R4: Add `specs/tmp/` creation guard to `postflight-workflow.sh`.** Include `mkdir -p specs/tmp` at the top of the unified script to eliminate the silent failure mode.

**R5: Do NOT add `--dry-run` or version comments now.** These are nice-to-haves that should not delay the extraction. Flag them as follow-up items in the task summary. The scope is tight and the downstream tasks are waiting.

**R6: Keep the three old postflight scripts as thin wrappers for backward compatibility.** Rather than deleting `postflight-research.sh`, etc., make them thin wrappers that call `postflight-workflow.sh` with the appropriate operation type. This prevents breakage if any undocumented call sites exist in extensions or hooks. Delete the old scripts in task 599 after extension compatibility is confirmed.

---

## Confidence Level

**High** — The strategic alignment is clear. The architecture design from task 592 is thorough and the implementation guidance from task 593's design guidance doc is concrete. The main strategic risks are scope-related (don't do too much) rather than architectural (the approach is sound). The `/orchestrate` compatibility question is resolved: shared command scripts serve the command layer; skills serve the orchestrator layer; `postflight-workflow.sh` serves both.

The one genuine uncertainty is platform evolution risk — if Anthropic substantially changes the command execution model, this extraction work may need to be redone. But this risk applies to all of tasks 593-599 equally, and the extraction makes the system *more* resilient to changes by eliminating copy-paste multiplication.

---

## Appendix: Files Examined

- `specs/ROADMAP.md` — Roadmap priorities (Phase 1 and Phase 2)
- `specs/state.json` — Full task suite 593-599 descriptions and dependencies
- `.claude/docs/architecture/architecture-spec.md` — 7-component unified architecture
- `.claude/docs/architecture/orchestrate-state-machine.md` — /orchestrate state machine design
- `.claude/docs/architecture/dispatch-agent-spec.md` — dispatch_agent() function specification
- `specs/593_extract_shared_workflow_utilities/reports/01_seed-research.md` — Distilled research
- `specs/593_extract_shared_workflow_utilities/reports/03_design-guidance.md` — Implementation spec
- `.claude/commands/research.md` (500L) — Current command structure (lines 1-300 examined)
- `.claude/scripts/postflight-research.sh` (70L) — Existing postflight script
- `.claude/scripts/postflight-implement.sh` (70L) — Existing postflight script

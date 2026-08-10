# Research Report: Implementation Approaches for Claude Code Skills (Teammate A)

- **Task**: 250 - Embed vault detection as inline check within skill-todo archive stage
- **Angle**: Implementation approaches and patterns for Claude Code skills
- **Started**: 2026-03-19
- **Completed**: 2026-03-19
- **Effort**: ~1 hour
- **Sources/Inputs**:
  - Web research: Anthropic official guides, DEV Community articles, Towards Data Science
  - `.claude/skills/skill-todo/SKILL.md` - Current skill being improved
  - `.claude/skills/skill-refresh/SKILL.md` - Reference for step-based skills
  - `.claude/skills/skill-status-sync/SKILL.md` - Reference for direct execution skills
  - `specs/250_embed_vault_detection_in_archive_stage/reports/01_vault-embedding-strategy.md` - Prior research

---

## Key Findings

### Finding 1: Prompt-Level Instructions Are Suggestions, Not Laws

The most significant finding from 2026 community research is a clear articulation of why the current SKILL.md structure fails:

> "Prompt-level instructions are suggestions. No matter how you phrase them, there is always a probability that Claude will skip a rule. Rules in prompts are requests; hooks in code are laws."
> — DEV Community, "5 Patterns That Make Claude Code Actually Follow Your Rules"

The current skill-todo has five separate vault stages (11-15), each beginning with "skip if vault_needed = false". This structure invites the LLM to make a skip decision at the stage level before evaluating the condition. The stage boundary itself is a skip opportunity.

### Finding 2: Anthropic's Official Guide Confirms Stage-Skipping Is a Known Problem

Anthropic's 33-page official guide ("The Complete Guide to Building Skills for Claude", February 2026) explicitly addresses the stage-skipping problem:

> "Skills sometimes skip steps even though they were clearly written. The goal is preventing step-skipping and ensuring repeatability. Natural language alone is not enough for strict workflows; deterministic scripting increases reliability."

This validates the root cause diagnosis in report 01: the current vault stages are skipped because they use natural language conditions at stage boundaries, not deterministic code.

### Finding 3: Per-Step Constraint Design Reduces Drift

A February 2026 DEV Community article ("How to Stop Claude Code Skills from Drifting with Per-Step Constraint Design") introduces a practical framework:

Rather than applying one freedom level across an entire skill, assign constraint levels per step. Steps that are mandatory should have strict output requirements. Steps that are optional can be flexible.

The anti-pattern identified: specifying what to do without defining acceptance criteria. The fix: quantify what "done" looks like at each step.

**Application to skill-todo**: The vault threshold check step needs explicit acceptance criteria:
- Accept: "Vault check ran; next_project_number=N; threshold status confirmed"
- Reject: Stage completed without running the threshold check bash block

### Finding 4: Bash Output Creates Mandatory Context

Multiple sources confirm that bash script output is incorporated into the model's immediate reasoning context with higher weight than static SKILL.md instructions. This is because bash output appears in the tool result at execution time rather than as pre-execution instructions.

The effective pattern (from report 01 and confirmed by community research):

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  echo "===== VAULT THRESHOLD EXCEEDED ($next_num > 1000) ====="
  echo "MANDATORY ACTION: Execute vault sub-steps below"
  echo "====="
fi
```

When this appears in a tool result, the model treats "MANDATORY ACTION" as an imperative instruction derived from the actual system state, not a static prompt instruction that may have been written "just in case."

### Finding 5: Sub-Steps Within a Stage Are More Reliable Than Separate Stages

From Anthropic's guide and community patterns, complex operations should use sub-steps within a single stage rather than separate sequential stages. The reasoning: a stage boundary is a decision point for the LLM. Sub-steps within a process block are executed together as part of the same atomic operation.

This confirms the consolidation strategy: moving vault operations from separate stages (11-15) into sub-steps within the archive stage eliminates four stage boundaries.

### Finding 6: Checkpoints/Gates in Critical Skills Should Be Imperative

The "issue-prerequisite" skill pattern (2026 community reference) demonstrates the gate design principle:

> "This is a hard gate. Once the gate passes, proceed to the next step. This is a hard requirement - no work starts without it."

The current skill-todo Stage 11 is soft: it begins "Detect if vault operation is needed" and then describes how to skip. A gate pattern would be: "Check vault threshold (MANDATORY). If threshold exceeded, user confirmation required before proceeding to commit."

### Finding 7: Production-Ready Skills Use Code Enforcement as Defense-in-Depth

For skills that perform critical or irreversible operations, the community consensus for 2026 is defense-in-depth:

1. **Inline check**: Bash block within the critical stage outputs a directive
2. **Pre-commit validation**: The git commit stage verifies preconditions were met
3. **Exit code enforcement**: If preconditions unmet, bash exits non-zero, preventing progression

The pre-commit safety net pattern from report 01 aligns precisely with this third-layer enforcement.

### Finding 8: XML Stage Tags Don't Prevent LLM Skipping

Anthropic's documentation recommends XML tags for prompt structure and unambiguous parsing. However, the research confirms that XML tags do not prevent skip behavior — they improve parsing clarity but don't enforce execution order. The `<stage id="11">` tags in skill-todo make the structure legible but don't compel execution.

The solution is not better XML structure but inline bash that outputs directives based on real state.

---

## Recommended Approach

Based on the research, the recommended approach has three components, applied in priority order:

### Component 1: Embed Vault Check as Mandatory Sub-Step in Archive Stage (Primary Fix)

Move the vault threshold detection from Stage 11 into Stage 10 as an inline bash block, executed immediately after task archiving. The key design requirement: the bash block must run unconditionally and produce visible output regardless of whether vault is needed.

Structure:

```
Stage 10 (ArchiveAndVault):
  Steps 1-8: Archive operations (existing content)
  Step 9: Vault Threshold Check (MANDATORY SUB-STEP)
    - Execute bash: read next_project_number
    - Output status regardless of condition
    - If threshold exceeded: output "VAULT REQUIRED" directive
    - If threshold not exceeded: output "vault check passed"
    Sub-step 9.1: VaultConfirmation (only if threshold exceeded)
    Sub-step 9.2: CreateVault (only if confirmed)
    Sub-step 9.3: RenumberTasks (only if vault created)
    Sub-step 9.4: ResetState (only if renumbered)
```

The unconditional output for both cases is critical: if the bash block only produces output when threshold is exceeded, the model may rationalize that "since nothing was output, the check ran and passed" — which may not be true if the step was skipped.

### Component 2: Remove Stages 11-15 After Consolidation

After embedding vault logic in Stage 10, the five standalone vault stages become dead code that creates confusion. Remove them entirely to reduce the total stage count from 21 to ~16, eliminating four additional skip opportunities.

This is a clean-break change (no deprecation period needed for internal tooling).

### Component 3: Pre-Commit Safety Net in Git Stage

In the GitCommit stage, add a validation check before `git add -A`:

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
if [ "$next_num" -gt 1000 ]; then
  echo "ERROR: COMMIT BLOCKED - vault threshold exceeded"
  echo "next_project_number: $next_num (must be <= 1000 before commit)"
  echo "ACTION: Return to archive stage and execute vault operations"
  exit 1
fi
```

This acts as a second enforcement layer. If Stage 10's inline check was somehow bypassed, the commit will fail with an explicit error message that forces the model back to the vault operation.

---

## Evidence and Examples

### Evidence 1: skill-status-sync as Reference Implementation

The existing `skill-status-sync/SKILL.md` demonstrates the correct pattern for mandatory operations:
- Single stage execution
- All sub-operations within one `<process>` block
- No "skip if" conditionals at stage level
- Operations described as numbered steps in sequence

The vault embedding should adopt the same structure: numbered sub-steps within Stage 10 rather than a separate conditional stage chain.

### Evidence 2: Observed LLM Execution from Report 01

The failed test execution data from Task 249 is direct evidence:
- Executed stages: 2, 3, 5, 10, 18, 20, 21
- Skipped stages: 4, 6, 7, 8, 9, **11-17**, 19

Stages 11-17 were all skipped. These are exactly the stages with "skip if" at stage level. This is a clean natural experiment: stages without skip conditions execute; stages with skip conditions are themselves skipped.

### Evidence 3: Anthropic's Official Guidance

From "The Complete Guide to Building Skills for Claude" (February 2026):
- Natural language alone is not sufficient for strict workflows
- Deterministic scripting increases reliability
- Stage-skipping is a known LLM behavior pattern, not a bug specific to this skill

### Evidence 4: Community Pattern Convergence

Multiple independent sources in 2026 (DEV Community articles, Towards Data Science, community GitHub repositories) have converged on the same diagnosis and solution:
- Prompt instructions can be ignored
- Bash output is treated as imperative context
- Sub-steps within a stage are more reliable than separate stages
- Code-level enforcement (hooks, exit codes) is required for mandatory operations

---

## Confidence Level

**High** for the primary recommendation (embed vault check as mandatory sub-step with bash output).

**High** for the pre-commit safety net pattern.

**Medium** for the exact output text needed to reliably trigger model action — the unconditional output pattern (both success and failure messages) is a reasonable inference from the research, but has not been A/B tested in this specific codebase.

The confidence is high because:
1. The diagnosis from report 01 is confirmed by external sources
2. The proposed pattern follows Anthropic's own guidance
3. Multiple independent community sources have validated the approach
4. The existing skill-status-sync in this project demonstrates the correct structure

---

## Sources

- [Best Practices for Claude Code - Claude Code Docs](https://code.claude.com/docs/en/best-practices)
- [Skill authoring best practices - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [How to Build a Production-Ready Claude Code Skill - Towards Data Science](https://towardsdatascience.com/how-to-build-a-production-ready-claude-code-skill/)
- [How to Stop Claude Code Skills from Drifting with Per-Step Constraint Design - DEV Community](https://dev.to/akari_iku/how-to-stop-claude-code-skills-from-drifting-with-per-step-constraint-design-2ogd)
- [5 Patterns That Make Claude Code Actually Follow Your Rules - DEV Community](https://dev.to/docat0209/5-patterns-that-make-claude-code-actually-follow-your-rules-44dh)
- [Anthropic's 33-Page Official Guide Distilled - SmartScope](https://smartscope.blog/en/generative-ai/claude/claude-skills-design-patterns-official-guide/)
- [The Complete Guide to Building Skills for Claude - Anthropic PDF](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)
- [I Wrote 200 Lines of Rules for Claude Code. It Ignored Them All. - DEV Community](https://dev.to/minatoplanb/i-wrote-200-lines-of-rules-for-claude-code-it-ignored-them-all-4639)
- [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Inside Claude Code Skills: Structure, prompts, invocation - Mikhail Shilkov](https://mikhail.io/2025/10/claude-code-skills/)

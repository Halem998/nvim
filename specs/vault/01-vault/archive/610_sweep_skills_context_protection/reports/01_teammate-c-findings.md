# Teammate C Findings: Critic Analysis

- **Task**: 610 - Apply context-protective pattern to remaining skills
- **Teammate**: C (Critic, Wave 2)
- **Focus**: Quality assessment and gap analysis of Wave 1 findings
- **Confidence Level**: High

---

## Key Findings

### 1. Missed Target: skill-reviser (489 lines)

Neither teammate identified **skill-reviser** as a target. It has the same format-injection violation as the Group A skills:

```bash
# Line 185 of skill-reviser/SKILL.md
format_content=$(cat .claude/context/formats/plan-format.md)
```

This is identical to the violations found in skill-researcher (report-format.md), skill-planner (plan-format.md), and skill-implementer (summary-format.md). At 489 lines, skill-reviser is the **third-largest skill** after the two team skills and should be included in the target list.

**Severity**: Medium. The violation is mechanical to fix (same @-reference substitution as Group A), but omitting it would leave an inconsistency in the codebase.

### 2. Teammate A's Token Bloat Estimates: Partially Overstated

**Spot-check: skill-team-plan (~13,000 tokens claimed)**

Teammate A claimed ~13,000 tokens bloat for skill-team-plan. Verified against the actual file:

- **Violation 1 (research content injection, Stage 5b, line 183-184)**: Teammate A says 2,000-5,000 tokens. This is **accurate** — research reports are typically 150-400 lines. However, the `research_content` is injected into *each teammate prompt*, effectively multiplying it by `team_size` (2-3x). Teammate A didn't account for this multiplication — the actual bloat from this violation in lead context is the single `cat` call (~2-5k), but the *agent-spawning overhead* is larger because the content is duplicated per teammate. The lead context impact is correctly estimated, though the total token cost is higher.

- **Violation 2 (inline synthesis, Stages 7-9)**: Teammate A claims 4,000-8,000 tokens. This is **overstated**. The Stage 7 code (lines 309-331) uses `teammate_results+=("...")` — the ellipsis is pseudocode, not a literal read. The actual skill text at Stage 8 (lines 335-349) contains only a 5-bullet task list and a 4-item comparison checklist. The lead's synthesis work is described in ~15 lines of instruction, not thousands of tokens. The *intent* is clear (the lead will read candidate plans during execution), but the file itself doesn't have literal `cat` or `Read` calls for candidate plans — it's implicit ("Lead synthesizes plan candidates"). The actual context cost depends on how the executor interprets these instructions.

**Verdict**: Teammate A correctly identifies the violations but the upper bound of ~13,000 tokens is realistic only if the executor reads full candidate plans during Stage 8. The skill text is ambiguous — it says "Read each teammate's output file" (Stage 7, line 311) without explicit `cat` or `Read` calls.

**Spot-check: skill-orchestrator (~1,600 tokens claimed)**

Teammate A says two violations: full state.json Read and full TODO.md Read. Verified against actual file:

- Line 32: `1. Read specs/state.json` — this is within a numbered instruction list, not a bash block. The skill text says "Find task by project_number" on the next line, implying a targeted lookup.
- Line 34: `4. Read TODO.md for additional context if needed` — this says "if needed", making it conditional.

The violations are **real but minor**. The skill is only 128 lines and is routing-only. The instructions could be clarified to use jq extraction, but the actual context impact depends on executor behavior. Teammate A's ~1,600 token estimate is a reasonable upper bound, not a measured value.

### 3. Teammate B's "Skip skill-orchestrator" — Partially Correct

Teammate B recommends skipping skill-orchestrator entirely, calling it "already compliant." This is **mostly correct** but imprecise:

- The skill has no `cat` calls, no `memory-retrieve.sh`, no format injection
- The "Read specs/state.json" instruction (line 32) is informal (not a bash block), but could lead an executor to use the Read tool on the full file
- The "Read TODO.md" instruction (line 34) is conditional ("if needed")

**Verdict**: skill-orchestrator is low-priority, not zero-priority. A one-line fix (replacing "Read specs/state.json" with a jq extraction example) would remove ambiguity. This is a 5-minute change, not worth a separate phase.

### 4. Teammate B's Phasing Strategy: Sound with One Gap

The two-phase strategy (Group A thin wrappers first, Group B team skills second) is **sound** because:
- Group A changes are mechanical and independently testable
- Group B changes require the synthesis-agent pattern, which is more complex
- Isolation reduces blast radius

**Gap**: Teammate B doesn't specify where skill-reviser fits. It's a thin wrapper (Group A pattern) but wasn't identified. It should be included in Phase 1.

### 5. Both Teammates Agree: skill-team-plan is Highest Priority

Teammate A ranks it #1 by token bloat. Teammate B identifies it as the skill with the most complex violations (inline synthesis + research content injection). This agreement is well-founded:

- It's one of only two skills that performs inline synthesis (the other was skill-team-research, already fixed in task 609)
- The research content injection (`cat "$research_path"`) at Stage 5b is the most wasteful single violation — the research is read into the lead, then injected verbatim into 2-3 teammate prompts
- The synthesis at Stages 7-9 is clearly described as lead-performed work

### 6. Missing Consideration: skill-team-implement's Summary Creation

Teammate B correctly notes that skill-team-implement writes the implementation summary (Stage 11) as a violation requiring synthesis-agent delegation. Teammate A mentions this skill's plan content embedding (Stage 7, lines 268-299) but **does not flag Stage 11** as a violation. 

Checking the actual file: skill-team-implement does have a summary creation stage. The lead would need to read phase results to write a meaningful summary. This is an inline synthesis violation.

However, the skill text at Stage 7 line 268 has an explicit CRITICAL note: "All template variables... MUST be populated by extracting text from the plan file." This means the lead is *expected* to read the plan. Teammate A's "borderline" assessment is accurate — the plan reading is a legitimate lead responsibility for wave calculation, but the phase details embedding is not.

### 7. Unasked Questions

1. **Testing strategy**: Neither teammate addresses how to verify the refactored skills work correctly. Task 609 presumably had verification — what was it? Running `/research --team` on a test task? The plan should specify verification commands for each phase.

2. **skill-orchestrate vs skill-orchestrator**: The task description mentions "skill-orchestrator" but `.claude/context/patterns/context-protective-lead.md` cites `skill-orchestrate` as the reference implementation. These are different skills (skill-orchestrate = autonomous lifecycle state machine, skill-orchestrator = routing skill). Neither teammate checked skill-orchestrate for violations.

3. **Extension skills**: skill-neovim-research, skill-nix-research, skill-neovim-implementation, skill-nix-implementation were not checked. My spot-check found them clean (no `cat` content injection, no memory retrieval in lead), but this should be noted as verified rather than assumed.

---

## Recommended Approach

1. **Add skill-reviser to the target list** — Group A (Phase 1), mechanical @-reference fix
2. **Keep the two-phase strategy** — it's sound
3. **Clarify skill-orchestrator scope** — one-line jq fix, include in Phase 1 as a quick addendum (not a separate phase)
4. **Include verification commands** in the plan — `/research N`, `/plan N`, `/plan N --team`, `/implement N --team` on a test task
5. **Note extension skills as verified clean** — don't include but document the check
6. **Flag skill-team-implement Stage 11** as a synthesis violation (Teammate A missed this)

---

## Evidence/Examples

### skill-reviser format injection (missed by both teammates)

```bash
# Line 185 of skill-reviser/SKILL.md — same pattern as Group A violations
format_content=$(cat .claude/context/formats/plan-format.md)
# Later injected into Agent prompt as format specification block
```

### skill-team-plan Stage 8 is ambiguous, not explicit

Stage 8 (lines 335-349) says:
```
Lead synthesizes plan candidates:
1. Compare phase structures from candidates A and B
2. Evaluate trade-offs between approaches
3. Incorporate risk analysis (if available)
4. Select best elements from each candidate
5. Identify parallelization opportunities
```

This is a prose instruction, not executable code with explicit `Read`/`cat` calls. The *intent* is clear (lead performs synthesis inline), but Teammate A's token estimate assumes the executor will Read full candidate files, which is likely but not guaranteed by the skill text.

### Extension skills verified clean

```bash
# skill-neovim-research: only heredoc cat
grep -n "cat " skill-neovim-research/SKILL.md → line 74 (postflight marker heredoc only)

# skill-nix-research: only heredoc cat
grep -n "cat " skill-nix-research/SKILL.md → line 73 (postflight marker heredoc only)

# skill-spawn: only heredoc cat
grep -n "cat " skill-spawn/SKILL.md → lines 109, 436 (marker + git commit heredoc only)
```

---

## Confidence Level: High

- Spot-checks against actual skill files confirm Teammate A's violation identifications are substantively correct, with some estimate inflation
- Teammate B's strategic analysis is sound, with the skill-reviser gap being the main omission
- The missed skill-reviser target is a concrete finding backed by file evidence
- Extension skill verification provides confidence that the target list (with skill-reviser added) is complete

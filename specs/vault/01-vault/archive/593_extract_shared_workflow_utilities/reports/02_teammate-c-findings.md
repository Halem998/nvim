# Critic Findings: Task 593 — Extract Shared Workflow Utilities

**Role**: Teammate C (Critic)
**Date**: 2026-05-22
**Focus**: Validate assumptions, surface gaps, identify failure modes

---

## Key Findings

### Finding 1: The "~500 Line" Claim Is Correct for the Active Files, but Wrong Files Were Initially Cited

The task description and architecture spec claim "~500 lines per command." After measuring:

| File | Actual Lines |
|------|-------------|
| `.claude/commands/research.md` | 122 (DEPRECATED mirror) |
| `.claude/commands/plan.md` | 119 (DEPRECATED mirror) |
| `.claude/commands/implement.md` | 197 (DEPRECATED mirror) |
| **`.opencode/commands/research.md`** | **500 (ACTIVE)** |
| **`.opencode/commands/plan.md`** | **531 (ACTIVE)** |
| **`.opencode/commands/implement.md`** | **612 (ACTIVE)** |

The `.claude/commands/` files are **explicitly marked DEPRECATED** in `.claude/commands/README.md`. The README states: "These command files are legacy copies from an earlier version of the system. The active command definitions are in `.opencode/commands/`."

**The design guidance and architecture spec reference `.claude/commands/` for modification, not `.opencode/commands/`.** If implemented as written, Task 593 would modify deprecated legacy mirrors, not the actively-used files. The scripts would also need to live in `.opencode/scripts/` (where the active skills and scripts already reside) rather than `.claude/scripts/`.

The 525-line duplication claim in `architecture-spec.md` Appendix C is validated against the active `.opencode/commands/` files, which do match these sizes. The claim is accurate — for the right files.

---

### Finding 2: Commands Are Markdown Prompt Files, Not Bash Scripts — "Source" Semantics Are Undefined

This is the deepest architectural concern.

Commands like `research.md`, `plan.md`, and `implement.md` are **markdown prompt files read by the LLM as cognitive instructions**, not shell scripts executed as programs. When the architecture spec proposes:

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS, TEAM_MODE, ...
```

...it implies shell variable export semantics. But Claude Code does not maintain shell state between Bash tool invocations. Each `Bash` tool call is an independent subprocess.

The current system handles this correctly: `parse_task_args()` appears in command files as **pseudocode that Claude reads and follows cognitively**. The LLM parses the argument string by following the algorithm's logic, not by executing bash. There is no real `parse_ranges()` function — it exists nowhere in the scripts directories. The algorithm is entirely LLM-interpreted.

**Proposed "source" approach has two possible interpretations, both problematic:**

1. **Claude executes `bash -c "source parse-command-args.sh && env"` and parses the output**: This would work mechanically but means every command invocation adds an extra Bash tool call. The variables would need to be extracted from stdout and mentally stored by Claude for use in subsequent Bash calls. This is an entirely new interaction pattern not demonstrated anywhere in the current codebase.

2. **Commands become real bash scripts executed by a shell**: There is no infrastructure for this. Claude Code processes command files by reading them into the LLM context, not by executing them as bash programs. The experimental `execute-command.sh` script references non-existent paths and is not integrated into any command processing pipeline.

**The existing evidence in `skill-implementer/SKILL.md`** shows that skills DO use real bash execution via the Bash tool. Line 420 shows:
```bash
if source "$PROJECT_ROOT/.opencode/scripts/update-recommended-order.sh" 2>/dev/null; then
    remove_from_recommended_order "$task_number" || ...
fi
```

This works in a skill because the `source` happens inside a single Bash tool call that also calls the sourced function in the same subprocess. Skills are also read as markdown by Claude, but the bash blocks within them are executed as real bash. The key difference: skills source scripts to get function definitions, then call those functions within the same Bash invocation. Commands cannot do this because the routing decision (which skill to invoke) must happen *after* the parsed values are known, and that routing is expressed in Claude's cognitive processing, not in a continuous bash subprocess.

**In summary**: The `source` paradigm works for utility functions (like `remove_from_recommended_order`) that are called within a single Bash tool execution. It does NOT work as a mechanism for exporting variables that Claude subsequently uses to make routing decisions. The current pseudocode algorithm pattern — where Claude reads and follows the algorithm cognitively — has no equivalent shell-sourcing replacement.

---

### Finding 3: Implement's GATE OUT Differs Materially from Research's

The task assumes GATE OUT is "near-identical" and extractable. Measuring the actual differences:

**research.md GATE OUT** (lines 411-460, ~50 lines):
- Validates: `status`, `summary`, `artifacts`
- Defensive check: state.json shows "researched"
- Defensive check: TODO.md shows `[RESEARCHED]`

**plan.md GATE OUT** (~74 lines):
- Validates: `status`, `summary`, `artifacts`, `metadata (phase_count, estimated_hours)`
- Defensive check: state.json shows "planned"
- Defensive check: TODO.md shows `[PLANNED]`
- Additional check: Plan file status marker shows `[NOT STARTED]` (unique to plan)

**implement.md GATE OUT** (~92 lines):
- Validates: `status`, `summary`, `artifacts`, `metadata (phases_completed, phases_total)`
- Branch logic: `result.status == "implemented"` vs `"partial"` (two distinct code paths)
- **Unique**: Populates `completion_summary` in state.json (jq update)
- **Unique**: Updates TODO.md with `- **Summary**: {completion_summary}` line
- **Unique**: Verifies plan file was updated to `[COMPLETED]` status
- Defensive check: TODO.md shows `[COMPLETED]`
- Note: "Post-Delegation Takeover Detection (Future Work)" comment

Implement's GATE OUT has roughly **twice the lines** of research's and includes four structural differences that cannot be parameterized away with a single string variable. The `completion_summary` population step involves a jq mutation unique to implement, and the plan-file status verification only applies to implement.

A `command-gate-out.sh` that covers all three cases would need to be parameterized across 5-7 dimensions (operation, expected_status, required_metadata_fields, do_completion_summary, do_plan_file_check). At that point, the shared script would be nearly as long as the command-specific blocks it replaces, and significantly harder to follow.

---

### Finding 4: Flag Parsing Has Meaningful Divergences Between Commands

The architecture spec claims flag parsing is "confirmed identical." Comparing actual STAGE 1.5 blocks:

| Flag | research.md | plan.md | implement.md |
|------|------------|---------|-------------|
| `--team-size` clamp | max 4 | **max 3** | max 4 |
| `--roadmap` | absent | **present** | absent |
| `--force` | absent | absent | **present** |
| `--focus` extraction | present | absent | absent |
| Step ordering | flags 1-6 | flags 1-6 | flags 1-2 then 3-6 (reordered) |

The `--team-size` maximum differs between plan (max 3) and research/implement (max 4). The design comment in plan.md explains this: "2-3 for planning" (planning needs fewer teammates than research/implement). A single `parse-command-args.sh` would need to make `TEAM_SIZE_MAX` configurable, or the clamp would be wrong for one command.

The `--roadmap` flag exists only in plan.md and exports `roadmap_flag`. Implementing this in a shared parser requires either: (a) always parsing and exporting `ROADMAP_FLAG` (leaking plan-specific semantics into shared code), or (b) accepting extension points where commands add post-parse processing (negating the simplification goal).

The `--focus` stripping exists in research.md (to produce `focus_prompt` for the skill) but not in plan.md or implement.md (which have no free-text focus argument). The shared parser would need conditional behavior for this.

---

### Finding 5: The 150-200 Line Target Omits the Multi-Task Dispatch Block

The architecture spec Appendix C says the command will retain:
- Multi-task batch loop (~40 lines)

Measuring the actual MULTI-TASK DISPATCH sections:

| Command | STAGE 0 (parse) | MULTI-TASK DISPATCH |
|---------|-----------------|---------------------|
| research.md | ~60 lines | ~115 lines |
| plan.md | ~61 lines | ~120 lines |
| implement.md | ~64 lines | ~147 lines |

The multi-task dispatch is command-specific (research has its own batch logic, plan has different invalid task handling, implement has `--force` propagation). None of this is extractable into shared scripts without becoming a large parameterized framework.

After removing only the three extractable blocks (parse_task_args, STAGE 1.5, GATE IN/OUT), the remaining unique content is approximately:

| Section | Lines (research) |
|---------|-----------------|
| Frontmatter | 6 |
| Anti-bypass constraint | 10 |
| Multi-task dispatch | 115 |
| Extension routing table | 55 |
| Skill delegation (STAGE 2) | 50 |
| COMMIT block | 16 |
| Output/Error sections | 18 |
| **Total** | **~270** |

The 150-200 line target appears to assume the multi-task dispatch is also extractable or dramatically shorter than it actually is. Even after full extraction of the three shared blocks (~185 lines), the residual content is ~270 lines — above the target.

---

### Finding 6: Token Savings Are Zero for Bash Scripts, Unclear for Command Files

The architecture spec conflates two types of savings:

**Postflight scripts** (`postflight-workflow.sh`): These scripts run in bash (via the Bash tool). They do NOT consume LLM context tokens. The seed research report correctly notes: "Token savings from this extraction are zero (scripts run in bash, not LLM context). The value is maintenance burden reduction." This is valid but should not be framed as token cost reduction.

**Command files** (`research.md`, `plan.md`, `implement.md`): These ARE loaded into the LLM context. If they shrink from 500 to 200 lines, that's ~300 lines (~3,000 tokens) saved per invocation. However:

1. The scripts being "sourced" would need to be read/loaded somehow for Claude to understand what they do. If Claude needs to read `parse-command-args.sh` to understand what `TASK_NUMBERS` means, the token savings evaporate.
2. If Claude does NOT read the scripts (treats them as opaque tools), it loses the ability to reason about their behavior, debug failures, or handle edge cases.
3. The architecture spec promises commands become "routing-only controllers" but the multi-task dispatch (which is 115-147 lines of unique logic) cannot be moved to scripts without changing the interpretation model.

The ~525-line saving is plausible only if:
- The parse_task_args pseudocode disappears from the command file and Claude is somehow given the parsed values without reading the algorithm
- The flag-parsing block disappears similarly
- Claude can call bash scripts and trust their output without needing to understand them

This is a fundamentally different agent behavior model than what currently exists.

---

## Unvalidated Assumptions

1. **"Commands source these scripts"** — Unvalidated. Commands are markdown prompt files; they do not execute bash. The mechanism by which Claude would "source" a shell script and receive exported variables is not defined.

2. **"Identical across all three commands"** — Partially false. The parse_task_args() function body is verbatim-identical, but STAGE 1.5 has flag-specific divergences (--roadmap in plan, --force in implement, team-size max differs).

3. **"Each command shrinks to ~150-200 lines"** — Unvalidated. The multi-task dispatch alone is 115-147 lines of unique, non-extractable logic per command. Even perfect extraction leaves ~270 lines per command.

4. **"~165 lines of identical copy-paste eliminated by parse-command-args.sh"** — The parse_task_args function body is ~30 lines verbatim × 3 commands = 90 lines. STAGE 1.5 is ~50 lines × 3 = 150 lines but with meaningful divergences. Total is nearer ~130 lines of near-identical content, not 165 lines of identical content.

5. **"Token budget concerns addressed by script extraction"** — Unvalidated. Scripts called via bash cost zero tokens. But if commands reference script signatures (to explain what they export), the reference prose must also live somewhere in the LLM context. Savings may shift rather than disappear.

6. **"Task 593 modifies .claude/commands/"** — Incorrect target. The active system uses `.opencode/commands/`. The `.claude/commands/` directory is deprecated.

---

## Potential Failure Modes

### FM-1: Scripts Created in Wrong Directory
If the implementer follows the spec and creates scripts in `.claude/scripts/` instead of `.opencode/scripts/`, the active skills (which reference `.opencode/scripts/`) will not find them. The active postflight scripts are in `.opencode/scripts/postflight-research.sh`, not `.claude/scripts/`.

### FM-2: Source Semantics Break Command Interpretation
If the command files are modified to say `source parse-command-args.sh` instead of the inline `parse_task_args()` algorithm, Claude loses the algorithm context. Claude cannot follow instructions it hasn't read. The commands would need to either (a) still contain the algorithm inline (no savings) or (b) Claude must infer behavior from the script's exported variable names (fragile, error-prone).

### FM-3: Implement GATE OUT Resists Extraction
If `command-gate-out.sh` is written to cover the research/plan case but not implement's `completion_summary` population and plan-file status check, the implement command must keep those blocks inline. This creates a partial extraction where implement.md still has 300+ lines and is inconsistent with the shared pattern.

### FM-4: Team-Size Clamp Error
If a shared `parse-command-args.sh` uses a single `TEAM_SIZE_MAX` of 4 (matching research and implement), the plan command's correct max of 3 is violated. With `--team-size 4`, planning would spawn 4 teammates instead of the designed maximum of 3. If it uses max 3, research and implement are unnecessarily restricted.

### FM-5: Roadmap Flag Missing from Shared Parser
If `--roadmap` is not in the shared parser, plan.md must still parse it locally (partial extraction, inconsistency). If it IS in the shared parser, research.md and implement.md start exporting `ROADMAP_FLAG=false` (unnecessary, leaks plan-specific semantics).

### FM-6: Concurrent State Writes Unchecked
The gate-out defensive correction calls `update-task-status.sh` which uses a tmp-file-swap pattern. In parallel multi-task mode, two concurrent invocations could both read state.json, both modify it, and race on the tmp file. The current three separate postflight scripts have this same risk, but consolidating into one shared script without adding locking does not improve safety. This is pre-existing, but the extraction is not eliminating the risk either.

---

## Questions That Should Be Asked

**Q1**: Are the target files `.claude/commands/` or `.opencode/commands/`? The task description, design guidance, and architecture spec all reference `.claude/commands/`, but the README in that directory says these are deprecated mirrors of `.opencode/commands/`.

**Q2**: What is the actual mechanism by which a command file "sources" a shell script and receives the exported variables for use in subsequent routing decisions? The design says "source" but this word means something entirely different in a bash context (persistent within one subprocess) versus a markdown prompt context (Claude reads the file for reference).

**Q3**: If `parse_task_args()` becomes a real bash script, does Claude still need to understand the algorithm, or does it blindly trust the script's output? If the latter, how does Claude handle errors or edge cases in the script?

**Q4**: Can `postflight-workflow.sh` actually replace the three separate postflight scripts without losing the type-specific filtering logic? The current scripts filter artifacts by type ("research", "plan", "summary") using the `select(.type != "...")` pattern. A shared script parameterized on type must handle this correctly.

**Q5**: Has the architecture for Task 595 (refactor commands) been designed yet? Task 593 is listed as a foundation for Task 595, but if the "commands source scripts" mechanism is not yet defined, Task 593 may be building foundations for an uncertain target.

**Q6**: Are there any other commands beyond research/plan/implement that would benefit from or need to be updated to use these shared scripts? The `revise.md`, `errors.md`, and other commands also have GATE IN/OUT patterns. If the shared scripts define the canonical pattern, all commands should use them — but the task only mentions three.

**Q7**: What does "postflight-workflow.sh" add beyond the existing three separate postflight scripts? The current three scripts are 69 lines each, clearly separated by operation type. Merging them into one with an `OPERATION_TYPE` parameter reduces file count but not complexity. The maintenance benefit may be less than claimed.

---

## Confidence Level: High

All findings are based on direct measurement of the actual files at known paths. Line counts are exact; the flag divergences are visible in the literal diff between command files; the deprecated/active directory distinction is documented in the README. The fundamental concern about "source" semantics (Finding 2) is grounded in how Claude Code's Bash tool operates — each invocation is an independent subprocess, and shell state does not persist between Bash tool calls.

The only area of uncertainty is whether the architecture design (Task 592) has resolved the "source" mechanism question in documentation not yet read. The `architecture-spec.md` references `command-gate-in.sh` with "Usage: source ..." syntax but does not explain how command prompt files consume that source — it appears to assume the reader will understand the mechanism, but the mechanism is not demonstrated anywhere in the existing codebase for prompt-file-to-bash-variable-passing.

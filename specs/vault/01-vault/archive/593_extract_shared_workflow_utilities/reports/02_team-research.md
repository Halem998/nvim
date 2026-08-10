# Research Report: Task #593 — Team Research Synthesis

- **Task**: 593 - Extract shared workflow utilities
- **Status**: [RESEARCHED]
- **Date**: 2026-05-22
- **Mode**: Team Research (4 teammates)
- **Session**: sess_1779471688_f47481

## Summary

Team research confirms the 4-script extraction is well-designed and the correct scope. Three scripts (`parse-command-args.sh`, `command-gate-in.sh`, `command-gate-out.sh`) reduce command file token cost; the fourth (`postflight-workflow.sh`) unifies dead-code postflight scripts and becomes a dependency for task 594's skill-base.sh. The Critic raised a fundamental concern about "source" semantics in markdown prompt files that requires architectural clarity: shared scripts work as real bash executed via the Bash tool, but the command files remain LLM-interpreted markdown. The 150-200 line target is aspirational and likely lands at ~250-280 lines after task 593 alone (multi-task dispatch blocks are non-extractable). Full target is achievable only after task 595.

## Key Findings

### 1. Duplication is confirmed and well-quantified (Teammate A)

- `parse_task_args()` is **byte-identical** across all 3 commands (27 lines each, diff-verified)
- STAGE 1.5 flag parsing is functionally identical with 3 shallow divergences: `--team-size` max (3 in plan, 4 in research/implement), `--roadmap` (plan only), `--force` (implement only)
- GATE IN shared core: 29 lines (session ID, jq lookup, terminal guard) — command-specific extensions stay inline
- GATE OUT: only the defensive correction pattern (~25 lines) is extractable; implement adds 3 unique steps (completion_summary, plan file verify, TODO summary line)
- Extension routing algorithm: identical across all 3 commands except for 3 string constants (routing key, default skill name)
- Total extractable: ~390 lines across 3 commands (~130 lines per command)

### 2. Three existing postflight scripts are dead code but architecturally important (Teammates A, B)

- `postflight-research.sh`, `postflight-plan.sh`, `postflight-implement.sh` (70 lines each) are structurally identical, differing in only 7 string constants
- **Not called by any skill file** (grep-confirmed: zero references)
- Skills inline equivalent jq directly in their postflight stages
- Creating `postflight-workflow.sh` serves as task 594's dependency: `skill-base.sh` will call it as part of the unified skill lifecycle
- Also on the `/orchestrate` critical path (task 596) since orchestrator dispatches skills, which call postflight

### 3. The 4-script decomposition is optimal (Teammate B)

- Alternative A (3 scripts, merged gates): rejected — GATE IN and GATE OUT are called at different lifecycle points
- Alternative B (5 scripts, split parse): rejected — no benefit since skills don't parse `$ARGUMENTS`
- Alternative C (single monolith): rejected — god-module problem
- The `source` idiom (for `parse-command-args.sh` and `command-gate-in.sh`) departs from the codebase convention of subprocess-call. This is justified because subprocesses cannot export variables to the caller, but should be explicitly documented

### 4. Command-layer scripts are independent from /orchestrate (Teammate D)

- Shared scripts serve the **command layer** (human-typed `/research`, `/plan`, `/implement`)
- `/orchestrate` bypasses commands entirely — it invokes skills directly via `dispatch_agent()`
- `postflight-workflow.sh` is the exception: it serves both paths (called by skills, which are called by both commands and orchestrator)
- Session ID generation will correctly exist in two places: `command-gate-in.sh` (human commands) and `skill-orchestrate/SKILL.md` (autonomous orchestrator)

### 5. Incremental migration is safe (Teammates A, B)

- Command files are independent — each can adopt shared scripts one at a time
- Recommended order: `research.md` first (simplest, 500L), `plan.md` second (531L), `implement.md` last (612L, has continuation loop and --force)
- Old postflight scripts should become thin wrappers calling `postflight-workflow.sh` for backward compatibility until task 599 confirms no external callers

## Conflicts Resolved

### Conflict 1: Command file location (.claude/ vs .opencode/)

Teammate C identified `.claude/commands/README.md` as marking that directory deprecated, pointing to `.opencode/commands/` as the active files. Teammates A and B read and analyzed files from `.claude/commands/` finding 500/531/612 line counts.

**Resolution**: Claude Code reads commands from `.claude/commands/`. The `.opencode/` directory serves OpenCode (a separate system). The loader copies full files to `.claude/commands/`. Both directories contain the full-length files. Task 593 targets `.claude/commands/` (Claude Code's command path) and `.claude/scripts/` (where shared scripts live). The README teammate C found describes the legacy mirror relationship from OpenCode's perspective, not Claude Code's. **Target: `.claude/commands/` and `.claude/scripts/`.**

### Conflict 2: "Source" semantics in markdown prompt files (critical)

Teammate C raised the deepest architectural concern: commands are markdown prompt files interpreted cognitively by the LLM, not bash scripts. The `source` keyword in a command file means "Claude, execute this bash command via the Bash tool" — not shell-level sourcing across tool calls.

**Resolution**: The "source" pattern works because:
1. Claude runs `source parse-command-args.sh "$ARGS" && echo "TASK_NUMBERS=$TASK_NUMBERS" ...` in a **single Bash tool call**
2. The exported variables are captured in the tool output
3. Claude stores these values cognitively and uses them in subsequent Bash tool calls and routing decisions

This is NOT a new pattern — teammate B found a precedent in `skill-implementer/SKILL.md` Stage 7 where `source update-recommended-order.sh` is used to call a function within the same Bash invocation. The key constraint: **all sourcing and variable usage must happen within a single Bash tool call**. Cross-tool-call state does not persist.

The token savings are real: removing the pseudocode algorithm from the command file (~130 lines per command) reduces LLM context load. The shared scripts themselves run as bash and cost zero LLM tokens.

### Conflict 3: 150-200 line target vs ~270 line reality

Teammate C measured ~270 lines remaining after extraction. Teammate A's line counts confirm the multi-task dispatch block (115-147 lines) is the largest non-extractable section.

**Resolution**: The 150-200 line target is for the **end state after tasks 593 AND 595 together**. Task 593 alone reduces commands to ~250-280 lines. Task 595 further slims by extracting extension routing and refactoring multi-task dispatch. The architecture spec's target is correct but refers to the combined outcome of two tasks. Task 593's realistic per-command target is ~250-280 lines (a ~45-50% reduction from 500-612).

### Conflict 4: Flag parsing divergences — shallow vs meaningful

Teammate A calls them "shallow and easily handled." Teammate C calls them "meaningful divergences."

**Resolution**: Both are right at different levels. The divergences ARE real (--team-size max differs, --roadmap is plan-only, --force is implement-only). But the superset approach handles them cleanly: parse ALL flags unconditionally, export all. Each command uses only what it needs. The team-size clamp can be passed as a parameter (`TEAM_SIZE_MAX`), or each command can re-clamp after sourcing. This is a 2-line addition per command, not a structural problem. **Adopt the superset approach with per-command post-clamp.**

## Gaps Identified

1. **Baseline measurement artifact**: Seed research identifies this as prerequisite #0 but no artifact slot exists. Create before extraction begins to enable before/after validation (Teammate D).

2. **`specs/tmp/` guard**: The unified `postflight-workflow.sh` must include `mkdir -p specs/tmp` at the top since the temp directory may not exist in fresh checkouts (Teammate D).

3. **Batch validation `--force` divergence**: The multi-task batch loop has an implement-specific `--force` override for completed tasks. This stays in each command — the shared scripts don't cover batch validation (Teammate A, confirmed by Teammates B, C).

4. **jq `!=` escaping**: Gate-out defensive correction must use the `select(.status == "X" | not)` pattern, never `!=` (Teammate B, Claude Code Issue #1132).

5. **Backward compatibility for old postflight scripts**: Keep as thin wrappers until task 599. Don't delete yet — undocumented call sites may exist in extensions or hooks (Teammates B, D).

## Recommendations

1. **Proceed with the 4-script extraction as designed** — all 4 teammates confirm the approach is sound
2. **Create baseline measurements first** (prerequisite #0) — `wc -l` on all command files before any changes
3. **Document the "source" convention explicitly** — it departs from the subprocess-call convention; add a comment header in scripts that require sourcing
4. **Set realistic line target for task 593**: ~250-280 lines per command (~45-50% reduction), not 150-200 (that's the task 595 target)
5. **Migrate incrementally**: research.md first, implement.md last
6. **Superset flag parser** with per-command post-clamp for team-size max
7. **Thin wrappers for old postflight scripts** — backward compatibility until task 599

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary | completed | high | Exact line counts, diff-verified duplication, GATE OUT divergence analysis |
| B | Alternatives | completed | high | 3 existing dead postflight scripts, source vs subprocess convention, 4-script optimality |
| C | Critic | completed | high | "Source" semantics challenge, 150-200 line target debunking, flag divergence analysis |
| D | Horizons | completed | high | /orchestrate compatibility, postflight dual-path value, baseline measurement gap |

## References

- `specs/593_extract_shared_workflow_utilities/reports/02_teammate-a-findings.md`
- `specs/593_extract_shared_workflow_utilities/reports/02_teammate-b-findings.md`
- `specs/593_extract_shared_workflow_utilities/reports/02_teammate-c-findings.md`
- `specs/593_extract_shared_workflow_utilities/reports/02_teammate-d-findings.md`
- `specs/593_extract_shared_workflow_utilities/reports/01_seed-research.md`
- `specs/593_extract_shared_workflow_utilities/reports/03_design-guidance.md`
- `.claude/docs/architecture/architecture-spec.md` (Component 1)
- `.claude/docs/architecture/orchestrate-state-machine.md`

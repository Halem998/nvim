# Research Report: Task #145 - Slim commands/orchestrate.md to the flag table and the dispatch

- **Task**: 145 - Slim commands/orchestrate.md to the flag table and the dispatch, deleting the multi-task block its own text labels illustrative
- **Started**: 2026-09-02T00:00:00Z
- **Completed**: 2026-09-02T00:00:00Z
- **Effort**: ~1 hour (codebase inventory only, no web research needed)
- **Dependencies**: None (research-only; findings below identify a probable dependency on a future "feature-port" task)
- **Sources/Inputs**:
  - `agent-system/extensions/core/commands/orchestrate.md` (edit target)
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  - `agent-system/extensions/core/scripts/parse-command-args.sh`
  - `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  - `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
  - `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
  - `agent-system/extensions/core/context/patterns/multi-task-operations.md`
  - `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
  - `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
  - `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
  - `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`, `test-session-runtime-files.sh`
  - `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh`
  - `agent-system/extensions/core/docs/examples/research-flow-example.md`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The file is currently **44,953 B / 790 lines** (re-measured after the predecessor task's team-mode deletion, which removed 1,921 B) — `### MULTI-TASK DISPATCH` (Steps 1-5) is **28,059 B (62%)**, `### STAGE 0` is **4,348 B**.
- **Byte-budget contradiction**: the sections instruction (4) marks "keep unchanged" already sum to **12,546 B**, which alone exceeds the ≤8,000 B target before any STAGE 0 content is restored. This is arithmetically impossible to satisfy under a literal reading of "unchanged" and must be resolved explicitly by the plan phase (relax the target, or get sign-off that "unchanged" tolerates prose-tightening with no semantic change).
- **Live-multi-task-dispatch regression risk**: only one paragraph of Steps 1-5 (the "Runtime wave-split check" subsection) is genuinely self-labeled illustrative. The rest — Batch Validation, Pre-Dispatch Review invocation, Dependency Graph Construction, Kahn's-Algorithm Wave Assignment, the MAX_TASKS guard, and Step 4's JSON construction plus the actual `Skill` tool invocation — is the **only** place in the tree that builds `dependency_graph`/`waves` and the **only** invocation site for multi-task-mode `Skill` dispatch. Deleting Steps 1-5 in full will break live (non-`--dry-run`) `/orchestrate N,M` runs. The stated ACCEPTANCE criteria test only `--dry-run`, and `orchestrate-dry-run-report.sh` is a fully independent reimplementation of this logic, so the given acceptance test will pass regardless — this is a real, undisclosed-by-default behavior change that must be called out.
- Of the three items flagged as "contract text not stated elsewhere," only two genuinely need relocation: the `MAX_TASKS=8` BATCHING RULE, and two specific pieces of the commit-reconciliation prose (the Exit-Path Coverage table and the residue-check bash block). The wave-split defense-in-depth narrative is already fully documented in `context/patterns/multi-task-operations.md` and can simply be dropped.
- The Options table has exactly one genuine documentation gap for this command: `--hard`. Other undocumented parser flags (`--force`, `--local`, `--exploit`, `--explore`) belong to other commands or are now fully orphaned (team mode, already deleted) and are correctly excluded from this table.
- Deleting Steps 1-5 has a wide blast radius: 25+ cross-reference sites across `skill-orchestrate/SKILL.md` (14+ sites) and 7 other docs/scripts name specific Step numbers or "MT-3 step 4.5" mirror relationships that will need repointing or deletion.

## Context & Scope

Task 145 asks for `commands/orchestrate.md` (source store: `agent-system/extensions/core/commands/orchestrate.md`) to be reduced to the flag table and the single-task dispatch, deleting the `### MULTI-TASK DISPATCH` section in full and shrinking `### STAGE 0`'s narrative prose (already duplicated by the Options table). This research verifies the premise that the deleted section is "illustrative," measures exact section sizes, determines what deleted contract text must be relocated to `docs/architecture/orchestrate-state-machine.md`, audits `Options` table coverage against `parse-command-args.sh`'s exported flags, and enumerates every cross-reference elsewhere in the tree that names the section's internal step numbers.

Constraints from the task: no change to flag semantics, delegation-context keys, checkpoint order, or the dry-run prohibition block. Pre-existing `verify-deploy.sh` gate failures (gate3/gate8/gate10/gate12) are out of scope and were not re-verified.

## Findings

### Codebase Patterns

#### 1. Exact byte/line ranges (measured after predecessor's team-mode deletion)

Full file: 44,953 B / 790 lines (was 46,874 B before the predecessor ran; matches the claimed 1,910-1,921 B removed for team mode).

| Section | Lines | Bytes |
|---|---|---|
| frontmatter + title | 1-12 | 546 |
| `## Arguments` | 13-21 | 318 |
| `## Constraints` | 22-31 | 694 |
| `## Options` | 32-50 | 3,063 |
| `## Anti-Bypass Constraint` | 51-56 | 230 |
| `## Execution` heading | 57-58 | 14 |
| **`### STAGE 0: PARSE AND DISPATCH`** | **59-130** | **4,348** |
| **`### MULTI-TASK DISPATCH`** (Steps 1-5) | **131-634** | **28,059 (62% of file)** |
| `### CHECKPOINT 1: GATE IN` | 635-653 | 934 |
| `### STAGE 2: DELEGATE` | 654-689 | 1,152 |
| `### CHECKPOINT 2: GATE OUT` | 690-698 | 262 |
| `### CHECKPOINT 3: COMMIT` | 699-759 | 3,153 |
| `## Output` | 760-783 | 1,607 |
| `## Error Handling` | 784-790 | 573 |

`MULTI-TASK DISPATCH` internal structure: Step 1 Batch Validation (133-156), Step 1.5 Pre-Dispatch Review (157-178), Step 2 Dependency Graph Construction (179-207), Step 3 Topological Wave Assignment / Kahn's Algorithm, including the self-labeled-illustrative "Runtime wave-split check" subsection (208-408), Step 4 Wave Execution (409-493), Step 5 Commit Reconciliation and Consolidated Output (494-634).

#### 2. Byte-budget contradiction (decision required from the plan phase)

Summing every section instruction (4) marks "keep unchanged" — frontmatter/title (546) + Arguments (318) + Constraints (694) + Options (3,063, before adding the new `--hard` row) + Anti-Bypass (230) + `## Execution` heading (14) + CHECKPOINT 1 (934) + STAGE 2 (1,152) + CHECKPOINT 2 (262) + CHECKPOINT 3 (3,153) + Output (1,607) + Error Handling (573) = **12,546 B**.

This already exceeds the ≤8,000 B acceptance target by roughly 4,500 B, **before** restoring any STAGE 0 content (the reduced source-parse/dry-run/branch content) or the new `--hard` Options row. Reaching ≤8,000 B is not achievable while treating Arguments/Constraints/Options/Anti-Bypass/CHECKPOINT 1-3/Output/Error Handling as byte-identical. **This is a decision the plan phase must resolve explicitly**: either the ≤8,000 B target is relaxed (e.g., to a value nearer 13,000 B, which would still be a ~71% reduction from the original 46,874 B baseline), or "keep unchanged" is understood to permit prose-tightening (no semantic/flag/checkpoint-order changes) within those sections — most plausibly the dense `--research`/`--plan`/`--implement` Options rows (~450 B each) and/or CHECKPOINT 3's 3,153 B of inline commentary.

#### 3. Live-multi-task-dispatch regression risk (major structural finding)

The task's framing — "deleting the multi-task block its own text labels illustrative" — is accurate for only one paragraph out of ~500 lines: the **"Runtime wave-split check (cross-batch defense-in-depth)"** subsection (inside Step 3, lines ~304-317 of the section, immediately before Step 4), which explicitly states: *"this subsection is illustrative of the CONTRACT `skill-orchestrate` fulfills, not code this file itself runs."* `docs/architecture/batch-admit-schema.md` independently confirms this scope at lines 12, 297, 497, and 537 — each names "commands/orchestrate.md Step 3 (pre-computed wave schedule, illustrative only)" for specifically the `orchestrate-batch-admit.sh` invocation shown in that one paragraph.

Everything else in Steps 1-5 is treated elsewhere in the tree as real, agent-executed logic with no other implementation:

- `skills/skill-orchestrate/SKILL.md` Stage MT-1 (~lines 2471-2517) states explicitly: *"this stage receives an already-built `dependency_graph` from the command's Step 2/3 output rather than rebuilding any part of it itself."* Stage MT-1 requires `dependency_graph` and `waves` as delegation-context inputs that are computed nowhere else in the codebase.
- `context/patterns/batch-orchestration-guardrails.md` (line 168, and the "Rejected Approaches" section ~lines 717-724) confirms the Kahn's-algorithm wave assignment is "agent-executed pseudocode," deliberately never converted into a real script (a rejected proposal, on the grounds that `commands/orchestrate.md` sits on the orchestrator-critical inclusion list and converting it would itself trip the self-modification hazard gate for zero behavioral gain) — but it remains the sole place this computation happens, and the guardrails doc's own table row calls Step 3 "the command entry point that builds the wave schedule."
- Step 4's construction of `dep_graph_json`/`waves_json`/`task_numbers_json` and the literal `Skill` tool invocation is the **only** place multi-task mode's `Skill` call (`multi_task_mode=true`) is ever made anywhere in the tree.

**Consequence**: deleting Steps 1-5 in full, as literally instructed, removes the only mechanism that builds the dependency graph/wave schedule and the only invocation site for multi-task `Skill` dispatch. This will break **live** (non-`--dry-run`) `/orchestrate N,M` runs until a future "feature-port" task (referenced by the task's own addendum text — "per-task in the batch engine once the feature-port task lands") moves this computation into `skill-orchestrate` itself.

This appears to be *known and accepted* by whoever authored task 145: the stated ACCEPTANCE criteria test only `--dry-run` for one- and two-number invocations, never live multi-task dispatch. Crucially, `scripts/orchestrate-dry-run-report.sh` is already a **fully independent reimplementation** of Steps 1-4's logic — confirmed by its own comments ("mirrors commands/orchestrate.md MULTI-TASK DISPATCH Step 1: not-found...", "MAX_TASKS=8 guard (verbatim from orchestrate.md Step 4)", lines 36-38, 71, 112, 175, 212, 518) — so the given `--dry-run` acceptance test will pass regardless of what happens to the markdown in `commands/orchestrate.md`. The plan/summary must call out this live-dispatch regression explicitly rather than let it pass silently as a side effect of "removing illustrative text."

#### 4. Three-way relocation verdict for contract text (instruction 1)

- **BATCHING RULE** (`MAX_TASKS=8` guard: "Batching is not yet supported. Running with first 8 tasks only.") — confirmed **absent** from `orchestrate-state-machine.md` and `batch-orchestration-guardrails.md`. The latter's "Batch-Size Scaling: Scope of Deferral, Not Existence of the Check" section and Non-Negotiable 5 discuss the *policy* around a size cap but never state the number 8 or the trim-to-first-8 behavior. **Verdict: must relocate** to `docs/architecture/orchestrate-state-machine.md`.
- **Wave-split defense-in-depth note** ("File-safety is a property of `dependencies[]` accuracy" plus the same-batch/cross-batch coverage explanation) — this is **already fully documented**, near-verbatim, in `context/patterns/multi-task-operations.md`'s "File Footprint Overlap as a Serialization Edge" section (lines ~612-624), including the identical same-batch-vs-cross-batch distinction. **Verdict: safe to drop outright**, no relocation needed — only the one cross-reference at `multi-task-operations.md:629` (which currently points at "`.claude/commands/orchestrate.md` Step 3") needs repointing.
- **Commit-reconciliation rule** — the bulk of Step 5's "MT mode no longer produces one combined end-of-batch commit..." narrative is **already covered**, nearly identically worded, by `orchestrate-state-machine.md`'s existing "Commit Granularity" section (lines 420-431). However, two specific pieces are genuinely absent elsewhere: (a) the **Exit-Path Coverage table** (mapping each MT terminal outcome — `completed`/`failed`/`blocked`/partial/deferred-self-modifying/deferred-by-redeploy-checkpoint — to where its commit is issued), and (b) the **residue-check bash block** (`git status --porcelain -- specs/`, warn-only, never commits). **Verdict: only these two pieces need relocating**; the rest of the commit-reconciliation prose can be dropped as redundant.

#### 5. Flag-gap analysis (instruction 3)

`parse-command-args.sh` exports (line 184, a shared "superset" parser used by every command): `TASK_NUMBERS, REMAINING_ARGS, EFFORT_FLAG, MODEL_FLAG, CLEAN_FLAG, FORCE_FLAG, DRY_RUN_FLAG, LOCAL_FLAG, EXPLOIT_FLAG, EXPLORE_FLAG, LIT_FLAG, ALLOW_SELF_MODIFYING_FLAG, ALLOW_SCOPE_COLLISION_FLAG, CONTINUE_BUDGET_FLAG, FORCE_PHASES_FLAG, FOCUS_PROMPT`.

The Options table currently documents 14 flags: `--lit, --dry-run, --allow-self-modifying, --allow-scope-collision, --continue-budget, --clean, --fast, --haiku, --sonnet, --opus, --fable, --research, --plan, --implement`.

Gap analysis:
- **`--hard`** (`EFFORT_FLAG="hard"`) — confirmed genuine gap. Threaded as `effort_flag` into the delegation context; `skill-orchestrate/SKILL.md` (lines 57-58) derives `hard_mode` from it and gates roughly 10 stages on that boolean. **Must be added** to the Options table with cost/composability documented in one row, per instruction (3).
- `--force` (`FORCE_FLAG`) and `--local` (`LOCAL_FLAG`) — used exclusively by `/tag`, `/refresh`, `/implement`, and `/meta` respectively; zero references anywhere in `orchestrate.md` or `skill-orchestrate/SKILL.md`. Correctly excluded from this command's table — not a gap.
- **`--exploit`/`--explore` (`EXPLOIT_FLAG`/`EXPLORE_FLAG`) — orphaned-flag follow-up observation**: the parser's own header comment still describes these as "mode hint for team research," but team mode was fully deleted from both `orchestrate.md` and `skill-orchestrate/SKILL.md` by the predecessor task in this batch (`grep -n "team_mode\|--team\b" skills/skill-orchestrate/SKILL.md` returns nothing). A repo-wide `grep -rl "EXPLOIT_FLAG\|EXPLORE_FLAG"` finds these flags referenced **only inside `parse-command-args.sh` itself** — they are now completely dead code with zero consumers. Not a documentation gap for this task's Options table (never was consumed by orchestrate), but worth flagging as an incidental follow-up cleanup opportunity in the shared parser script (out of scope here since `parse-command-args.sh` is not this task's edit target).

### Cross-References to the Deleted Section's Step Numbers (instruction 5)

Deleting Steps 1-5 has a wide blast radius. Every site below names `commands/orchestrate.md` by a specific "Step N" / "MT-3 step 4.5" mirror relationship and will need repointing to `docs/architecture/orchestrate-state-machine.md` or deletion:

**`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`** (14+ sites):
- Line 578: "8 threading sites" count for `force_phases` end-to-end chain documentation — this count includes Step 4's threading site and will shrink once it is removed.
- Lines 2507, 2516: Stage MT-1's dependency on "the command's Step 1.5 (Pre-Dispatch Review)" and "Step 2/3 output."
- Lines 2600, 2613, 2651, 2670: "Step 5" cited as a reader of MT state fields (`forward_progress_violated`, etc.).
- Line 2683: Step 5's three-branch invariant resolution, described as mirrored logic.
- Line 3072: "orchestrate.md Step 3" cited as the origin of the mirrored wave-split check.
- Lines 3675, 3778, 3865: Step 5's commit/rendering references ("so `commands/orchestrate.md` Step 5 can read it").
- Lines 3850, 3858, 3872: Step 5's output-section pointers (Pre-Existing Deploy-Verify Failures, System Defects Detected, consolidated-output template).

**`agent-system/extensions/core/docs/architecture/batch-admit-schema.md`** (6 sites): lines 12, 297, 342, 474, 497, 538 — all naming "Step 3" as a reader/consumer of the admission-verdict schema, several explicitly noting "illustrative only."

**`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`** (8 sites): lines 168 (table row: "the command entry point that builds the wave schedule... (Step 3)"), 255, 410, 469, 717-721 ("Converting `commands/orchestrate.md`'s Kahn's-algorithm pseudocode into an executable script" rejected-approach entry), 831, 838, 902.

**`agent-system/extensions/core/context/patterns/multi-task-operations.md`**: line 629 (Step 3 mirror pointer — safe to drop per the relocation verdict above) and line 667 (`## See Also`: "`.claude/commands/orchestrate.md` -- Full orchestrate command implementation with MULTI-TASK DISPATCH section").

**`agent-system/extensions/core/context/patterns/file-footprint-overlap.md`**: lines 108-109 (Step 3 listed as a consumer of the shared overlap predicate).

**`agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`**: line 4 ("`/orchestrate`'s (`commands/orchestrate.md`) MULTI-TASK DISPATCH path emits at Step 5").

**`agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`**: line 424 (Step 5 self-reference inside the very doc that will host the relocated content — needs rewording to describe itself as the source of truth rather than pointing at orchestrate.md's Step 5).

**`agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`**: line 43 references "The batch commit step in `commands/orchestrate.md`" — this is **already stale independent of task 145** (that batch commit was retired per Step 5's own text and the state-machine doc's "Commit Granularity" section, which both state MT mode "no longer produces one combined end-of-batch commit"). Worth fixing opportunistically but is a pre-existing defect, not caused by this task.

**Scripts** (comments only, non-blocking but should stay accurate): `scripts/orchestrate-dry-run-report.sh` (7 sites: lines 36, 38, 71, 112, 175, 212, 518), `scripts/orchestrate-predispatch-review.sh` (line 6), `scripts/test-session-runtime-files.sh` (line 132).

**No change needed**: `scripts/lint/lint-task-lookup-adoption.sh:284` and `docs/examples/research-flow-example.md` reference `commands/orchestrate.md` generically (not step-numbered, and concern the single-task path, which is unaffected).

### Recommendations

- Resolve the byte-budget contradiction explicitly before implementation begins (see Finding 2) — do not silently miss the ≤8,000 B target or silently violate the "keep unchanged" instruction; pick one and state it in the plan.
- Explicitly disclose the live-multi-task-dispatch regression in the plan and the eventual commit message / summary, rather than treating it as an implied consequence of "removing illustrative text" (see Finding 3).
- Relocate only the two genuinely-orphaned pieces of contract text identified in Finding 4 (BATCHING RULE in full; Exit-Path Coverage table + residue-check bash block from commit-reconciliation) — do not relocate the wave-split note, it is redundant with `multi-task-operations.md`.
- Add a single `--hard` row to the Options table (Finding 5); do not add rows for `--force`/`--local`/`--exploit`/`--explore` — they do not belong to this command.
- Budget real implementation effort for the cross-reference repoint inventory (25+ sites across 9 files) — this is likely larger than the edit to `orchestrate.md` itself.
- File the orphaned `EXPLOIT_FLAG`/`EXPLORE_FLAG` cleanup as a separate, out-of-scope follow-up rather than folding it into this task (parser script is not this task's edit target).

## Decisions

- Confirmed via direct codebase measurement (not assumption) that the file is 44,953 B post-predecessor, matching the task's own math (46,874 - ~1,921 team-mode bytes).
- Treated the "illustrative" self-label as scoped strictly to the "Runtime wave-split check" subsection based on explicit textual evidence in three independent files (`orchestrate.md` itself, `batch-admit-schema.md`, `batch-orchestration-guardrails.md`), not the whole `MULTI-TASK DISPATCH` section.
- Did not attempt to resolve the byte-budget contradiction or the live-dispatch regression myself — both are flagged as decisions for the plan phase, per this agent's research-only scope.

## Risks & Mitigations

- **Risk**: implementer deletes Steps 1-5 wholesale without preserving any equivalent dependency-graph/wave-computation and Skill-invocation logic, silently breaking live multi-task `/orchestrate N,M` with no disclosure. **Mitigation**: plan must explicitly decide and document the fate of live multi-task dispatch (accept regression pending feature-port task vs. retain a minimal executable core).
- **Risk**: the ≤8,000 B target is treated as a hard gate and implementer over-trims sections marked "keep unchanged" (e.g., collapsing Options-table prose) beyond what was authorized, silently changing flag semantics. **Mitigation**: plan must state explicitly which sections, if any, get prose-tightened to hit the target, and confirm no semantic change results.
- **Risk**: a cross-reference repoint is missed, leaving a dangling pointer to a deleted Step number. **Mitigation**: use the enumerated site list above as a implementation checklist; re-grep after edits for `"Step [0-9]"` and `"MULTI-TASK DISPATCH"` scoped to `commands/orchestrate.md` references.

## Context Extension Recommendations

None — this is a meta task; the relevant context files (`orchestrate-state-machine.md`, `batch-admit-schema.md`, `batch-orchestration-guardrails.md`) already exist and are the correct homes for relocated content, not new documentation gaps.

## Appendix

- Search commands used: `wc -c`/`wc -l`, `grep -n "^#"`, `sed -n` range reads, a small Python byte-offset script for precise section boundaries, and targeted `grep -rn` sweeps across `agent-system/extensions/core/{commands,skills,docs,context,scripts}` for step-number and flag cross-references.
- Pre-existing gate failures (verify-deploy.sh gate3/gate8/gate10/gate12) were noted per the task's own disclosure and not independently re-verified, per explicit out-of-scope instruction.

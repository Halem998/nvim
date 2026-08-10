# Research Report: Task #593 — Teammate A Findings

**Task**: 593 — Extract shared workflow utilities
**Focus**: Implementation approaches and patterns
**Teammate**: A (Primary Angle)
**Started**: 2026-05-22
**Completed**: 2026-05-22

---

## Key Findings

### 1. Exact Duplication Confirmed — 81 Lines Verbatim Across Three Commands

The `parse_task_args()` function (27 lines each, lines 64-90 in research.md, 56-82 in plan.md,
58-84 in implement.md) is byte-identical across all three command files. `diff` returns no output
when comparing these blocks. This is the safest extraction target: zero behavioral divergence,
zero risk.

**Companion duplication**: STAGE 1.5 flag parsing (46-53 lines each) is functionally identical
across all three commands. The only meaningful differences:
- `plan.md` adds step 6 "Extract Roadmap Flag" (`--roadmap` → `roadmap_flag = true`) — 6 extra lines
- `implement.md` adds step 2 "Extract Other Flags" (`--force` → `force_mode = true`) — 3 extra lines
- `research.md` uses `team_size` clamp 2-4; `plan.md` clamps 2-3; `implement.md` clamps 2-4

These three divergences are shallow and easily handled by including all flags in
`parse-command-args.sh` with no-op behavior when a flag is irrelevant to a given command.
Specifically: `FORCE_FLAG` and `ROADMAP_FLAG` exported unconditionally; each command uses only
what it needs.

### 2. GATE IN Has a Shared Core (Sessions + Validation) and Command-Specific Extensions

The shared GATE IN core across all three commands (29 lines in research.md, extending to 36 in
plan.md and 41 in implement.md):

**Shared (identical) steps**:
1. Generate SESSION_ID (`sess_{timestamp}_{random}`)
2. Look up task from state.json via jq
3. Validate: task exists + status is not terminal (completed, abandoned, expanded)

**Command-specific extensions that remain in each command file**:
- `research.md`: no unique step (extract `task_type` inline — already in shared lookup)
- `plan.md`: Step 4 — Load Context (discover prior plan path, read research reports)
- `implement.md`: Steps 4-5 — Load Implementation Plan + Detect Resume Point (scan phase markers)

**Implication for `command-gate-in.sh`**: The script handles only the shared 3 steps (session ID,
lookup, terminal guard). The command-specific context loading stays inline after `source
command-gate-in.sh` is called. This is the correct decomposition per the architecture spec.

The implement.md GATE IN has an additional behavioral divergence: `completed` status is blocked
UNLESS `--force` is present. This exception is implement-specific and stays in the command.

### 3. GATE OUT Divergence Is Larger Than Estimated — Implement Has Three Extra Steps

The shared GATE OUT core across research.md and plan.md (steps 1-3: validate return, verify
artifacts, verify status updated) runs to ~25 lines. The defensive status correction pattern
(steps 4-5) is nearly identical but parameterized by expected status string.

**Implement.md GATE OUT has 3 additional steps not present in research/plan**:
- Step 4: Populate Completion Summary (update state.json + TODO.md with `completion_summary`)
- Step 5: Verify Plan File Status Updated (check/fix plan file `[COMPLETED]` marker)
- Step 7: Post-Delegation Takeover Detection (future work, documented note)

Line counts: research.md GATE OUT = 50 lines; plan.md = 72 lines; implement.md = 90 lines.

**Implication for `command-gate-out.sh`**: Extract only the common defensive status correction
pattern (steps 4-5 as specified in the architecture spec). The implement-specific steps (completion
summary, plan file verification) stay inline in implement.md after calling `source
command-gate-out.sh`. This is correctly handled by the architecture spec — the spec's GATE OUT
signature is narrow (just reads `.return-meta.json` and applies defensive correction).

### 4. Extension Routing Algorithm Is Identical — Only 3 Values Differ

The extension routing block in all three commands uses the exact same algorithm (32-35 lines):
```
skill_name = ""
for manifest in extensions/*/manifest.json:
  ext_skill = manifest.routing.{operation}[$task_type]  # "research", "plan", or "implement"
  if ext_skill: skill_name = ext_skill; break
# compound key fallback (same logic)
skill_name = skill_name OR "skill-{default}"  # "skill-researcher", "skill-planner", "skill-implementer"
```

The three values that differ: `routing.{operation}` key and the default skill name. This routing
block is NOT extracted into `parse-command-args.sh` or `command-gate-in.sh` — it belongs in each
command's STAGE 2: DELEGATE section. It stays in the command file because the routing key
(`research` vs `plan` vs `implement`) is semantically meaningful per command.

However, noting this duplication is valuable: when task 595 further slims the commands, the
routing algorithm itself could be factored into a `resolve-skill.sh` helper. This is out of
scope for task 593 but a clean follow-on.

### 5. Three Existing Postflight Scripts Are Dead Code — But Correctly Targeted for Unification

`postflight-research.sh` (70L), `postflight-plan.sh` (70L), `postflight-implement.sh` (70L)
are structurally byte-identical. The only differences are 7 string constants (see teammate B
findings for table). These scripts are NOT called by the skills (`skill-researcher/SKILL.md`,
`skill-planner/SKILL.md`, `skill-implementer/SKILL.md`). Skills call `update-task-status.sh`
and `link-artifact-todo.sh` directly.

The scripts are documented in `jq-escaping-workarounds.md` as utility references and exist in
`extensions/core/scripts/` as well. They represent a prior extraction attempt that the skills
evolved past.

**Critical insight from architecture spec (Component 2, task 594)**: `skill-base.sh` will call
`postflight-workflow.sh` as part of the unified skill lifecycle. Creating `postflight-workflow.sh`
now (task 593) enables `skill-base.sh` to consume it in task 594. It is a forward-compatibility
dependency, not just dead-code cleanup.

**Implication for `postflight-workflow.sh`**: Unify the three 70-line scripts into one 80-90 line
parameterized script (`OPERATION_TYPE` = "research" | "plan" | "implement"). Keep the three old
scripts as thin wrappers calling the new script for backward compatibility until task 599
confirms no external callers remain. The token savings are zero (bash subprocess, not LLM context)
but the maintenance reduction is real and the script becomes task 594's dependency.

### 6. Batch Validation Has Minor Divergence — Implement Adds `--force` Override

The multi-task batch validation loop is near-identical across all three commands (~27-38 lines
each). The key divergence: `implement.md` adds a `--force` override that allows re-implementing
already-completed tasks:
```bash
completed)
  if [ "$force_mode" = "true" ]; then : # Allow
  else skipped_tasks+=("$task_num: already completed (use --force)"); continue; fi
  ;;
```

This divergence means the batch validation loop cannot be fully extracted into a single shared
block — the `implement.md` version has semantically different behavior for `completed` status.
However, the base structure (jq lookup, not-found check, terminal status guard) is extractable.
Since `command-gate-in.sh` handles single-task validation, the batch validation loop remains in
each command (the architecture spec already accounts for this as part of the ~40-line "multi-task
batch loop" that stays in each command).

---

## Recommended Approach

### Extraction Strategy (Implementation Order)

**Step 1: Write `parse-command-args.sh` first**

Include ALL flags unconditionally (FORCE_FLAG, ROADMAP_FLAG, TEAM_SIZE with 2-4 range). Each
command uses only what it needs. This eliminates the ~165 lines of STAGE 0 + STAGE 1.5
duplication:
- STAGE 0 `parse_task_args()` function: 27 × 3 = 81 lines eliminated
- STAGE 1.5 flag parsing block: ~49 × 3 = 147 lines eliminated (including flag-specific text)
- Total: ~228 lines → 3 `source` calls + 3 command-specific dispatch decisions

Use `source` (not subprocess) because variable export is required. Use absolute paths for
`BASH_SOURCE[0]` to handle cwd reset between Bash tool calls.

**Step 2: Write `command-gate-in.sh` second**

Extract only: session ID generation, task lookup, terminal status guard. Export: SESSION_ID,
TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM.

Eliminates: ~29 lines × 3 = 87 lines. Each command then sources this and adds its own context
loading inline (~7-18 lines of command-specific steps).

**Step 3: Write `command-gate-out.sh` third**

Extract only: read `.return-meta.json`, apply defensive status correction. Use subprocess pattern
(no variable export needed — side effects only). The implement-specific completion summary and
plan file verification steps remain inline.

Eliminates: ~25 lines × 3 = 75 lines. (The full GATE OUT sections are 50, 72, 90 lines; the
shared defensive correction is a subset.)

**Step 4: Update research.md, plan.md, implement.md** (in that order)

Research first (least complex, 500L → ~150L target), then plan (531L), then implement (612L).
Test each independently before migrating the next.

**Step 5: Write `postflight-workflow.sh` last**

Parameterized by OPERATION_TYPE. Used as: `bash postflight-workflow.sh $task_number
$artifact_path [$summary] research`. Keep old scripts as thin wrappers temporarily.

Eliminates: ~65 lines of duplication across 3 × 70-line scripts.

### What Stays in Each Command File After Extraction

| Section | Stays in Command | Moves to Script |
|---------|-----------------|----------------|
| YAML frontmatter | research/plan/implement | — |
| Anti-bypass PROHIBITION | research/plan/implement | — |
| STAGE 0 `parse_task_args()` | replaced by source | parse-command-args.sh |
| STAGE 0 dispatch decision | research/plan/implement | — |
| Multi-task batch loop | research/plan/implement (with force divergence) | — |
| CHECKPOINT 1 shared core | replaced by source | command-gate-in.sh |
| plan.md Load Context step | plan.md only | — |
| implement.md Load Plan + Resume | implement.md only | — |
| STAGE 1.5 flag parsing | replaced by source | parse-command-args.sh |
| Extension routing algorithm | research/plan/implement | — |
| Team/non-team skill selection | research/plan/implement | — |
| CHECKPOINT 2 defensive correction | replaced by source | command-gate-out.sh |
| implement.md completion summary | implement.md only | — |
| implement.md plan file verify | implement.md only | — |
| CHECKPOINT 3 COMMIT | research/plan/implement | — |

---

## Evidence and Examples

### Evidence 1: parse_task_args Byte-Identical

Confirmed via `diff` — zero output when comparing the 27-line function across all three commands.
Lines: research.md:64-90, plan.md:56-82, implement.md:58-84.

### Evidence 2: Line Counts (Actual, Not Estimated)

From `wc -l`:
- `research.md`: 500 lines total
- `plan.md`: 531 lines total
- `implement.md`: 612 lines total

Section line counts (measured, not estimated):

| Section | research.md | plan.md | implement.md |
|---------|-------------|---------|--------------|
| `parse_task_args()` fn | 27 | 27 | 27 |
| STAGE 1.5 flag parsing | 53 | 49 | 46 |
| Batch validation loop | 27 | 38 | 38 |
| CHECKPOINT 1 GATE IN | 29 | 36 | 41 |
| Extension routing | 34 | 37 | 36 |
| CHECKPOINT 2 GATE OUT | 50 | 72 | 90 |

### Evidence 3: GATE OUT Divergence in implement.md

Three additional steps in implement.md GATE OUT (steps 4, 5, 7) total ~47 lines. These cannot be
extracted into `command-gate-out.sh` without making the script implement-specific. The architecture
spec correctly scopes `command-gate-out.sh` to the narrow defensive correction pattern only.

### Evidence 4: Postflight Scripts Are Unused by Skills

Verified: zero references to `postflight-research.sh`, `postflight-plan.sh`, or
`postflight-implement.sh` in:
- `skills/skill-researcher/SKILL.md`
- `skills/skill-planner/SKILL.md`
- `skills/skill-implementer/SKILL.md`

Skills call `update-task-status.sh` and `link-artifact-todo.sh` directly (Stage 7 and Stage 8
respectively). The legacy postflight scripts predate this architecture and are now orphaned.

### Evidence 5: Extension Routing — Exact Diffs

`diff research.md(333-370) plan.md(335-371)` produces only 5 lines of diff, all cosmetic:
- Comment text ("for research" vs "for plan")
- Routing key string `'.routing.research[$tt]'` vs `'.routing.plan[$tt]'`
- Fallback skill name `skill-researcher` vs `skill-planner`

The algorithm structure — dual loops with compound-key fallback — is byte-identical.

### Evidence 6: STAGE 1.5 Flag Parsing Divergences (Shallow)

| Divergence | research.md | plan.md | implement.md |
|------------|-------------|---------|--------------|
| `--force` flag | absent | absent | step 2 (3 lines) |
| `--roadmap` flag | absent | step 6 (6 lines) | absent |
| Team size clamp upper bound | 4 | 3 | 4 |

All three divergences can be handled by including all flags in the shared script with unconditional
export. Each command ignores flags it doesn't use.

---

## Confidence Level

**High** — All findings are directly confirmed by reading the command files, running diffs, and
counting lines. No external sources consulted; all evidence is from the actual codebase.

**High confidence findings**:
- `parse_task_args()` is byte-identical across all three commands (diff-confirmed)
- STAGE 1.5 flag parsing is functionally identical with 3 shallow divergences (directly verified)
- GATE IN has a shared core (3 identical steps) with command-specific extensions (reading files)
- GATE OUT has a shared defensive correction pattern but implement.md adds 3 unique steps
- The three postflight scripts are structurally identical (diff produces only string constants)
- Postflight scripts are unused by the current skill files (grep-confirmed: zero references)

**Medium confidence findings**:
- Exact line savings after extraction (~228 lines from parse+flags, ~87 from gate-in, ~75 from
  gate-out) — approximate because command-specific sections stay inline after each source call
- `postflight-workflow.sh` will be consumed by task 594 (per architecture spec design intent;
  not yet confirmed by task 594 implementation)

**Low confidence findings**:
- cwd reset between Bash tool calls with sourced scripts (theoretical risk; may require
  absolute path handling — needs testing during implementation)

---

## Appendix: Files Examined

- `/home/benjamin/.config/nvim/.claude/commands/research.md` (500 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/commands/plan.md` (531 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/commands/implement.md` (612 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-research.sh` (69 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-plan.sh` (69 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-implement.sh` (69 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` (418 lines) — Full read
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (558 lines) — Grep only
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (490 lines) — Grep only
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (629 lines) — Grep only
- `/home/benjamin/.config/nvim/.claude/docs/architecture/architecture-spec.md` — Sections 1-2
- `specs/593_.../reports/01_seed-research.md` — Full read
- `specs/593_.../reports/03_design-guidance.md` — Full read
- `specs/593_.../reports/02_teammate-b-findings.md` — Full read (prior to writing this report)
- `specs/593_.../reports/02_teammate-d-findings.md` — Full read (prior to writing this report)

### Baseline Measurements (Prerequisite for Validation)

```bash
# Before extraction — confirmed measurements:
wc -l .claude/commands/research.md .claude/commands/plan.md .claude/commands/implement.md
# Output: 500  531  612  1643 total

# After extraction — target:
# Each command: 150-200 lines (70% reduction)
# 3 command files total: ~450-600 lines (vs 1643 today)
# Savings: ~1043-1193 lines across command files
```

Token impact: Command files are read into orchestrator context at invocation. At ~250 tokens per
page (~50 lines), 1643 lines ≈ 8200 tokens. Target ~2250-3000 tokens. Savings: ~5200-5950 tokens
per multi-task orchestrator session that loads all three commands. Per single-command invocation,
savings ≈ 1700 tokens (one command file: 500L → 150L).

These are context-load savings at the orchestrator level. The shared scripts themselves run in
bash subprocess (or sourced in a single Bash tool call) and do not add to LLM context.

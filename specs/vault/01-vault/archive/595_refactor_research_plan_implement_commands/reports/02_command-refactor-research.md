# Research Report: Task #595

**Task**: 595 - refactor_research_plan_implement_commands
**Started**: 2026-05-22T13:00:00Z
**Completed**: 2026-05-22T13:45:00Z
**Effort**: 1 hour
**Dependencies**: Task 593 (completed), Task 594 (completed)
**Sources/Inputs**:
- Codebase: `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md`
- Codebase: `.claude/scripts/parse-command-args.sh`, `.claude/scripts/command-gate-in.sh`, `.claude/scripts/command-gate-out.sh`, `.claude/scripts/skill-base.sh`
- Codebase: `.claude/skills/skill-researcher/SKILL.md`, `.claude/skills/skill-planner/SKILL.md`, `.claude/skills/skill-implementer/SKILL.md`
- Codebase: `.claude/extensions/nvim/manifest.json`, `.claude/extensions/nix/manifest.json`
- Architecture: `.claude/docs/architecture/architecture-spec.md` (Components 1, 2, 5, 6, 7)
- Architecture: `.claude/docs/architecture/handoff-schema.md`
- Task summaries: `specs/593_*/summaries/02_extract-shared-utilities-summary.md`, `specs/594_*/summaries/02_refactor-shared-base-summary.md`
**Artifacts**:
- `specs/595_refactor_research_plan_implement_commands/reports/02_command-refactor-research.md` (this file)
**Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

---

## Executive Summary

- Current command files stand at 393, 420, and 525 lines (research, plan, implement) after task 593 extracted shared gate scripts; target is 150-200 lines each.
- Three extractable categories remain: (1) multi-task dispatch blocks (~119-152 lines each, mostly identical), (2) inline extension routing loops (~36 lines each, identical), and (3) redundant inline GATE OUT defensive checks (~38 lines each, already handled by `command-gate-out.sh`).
- The multi-task dispatch extraction is the largest opportunity — creating a `command-multi-dispatch.sh` script would reduce each command by ~100-115 lines.
- Skills (`skill-researcher`, `skill-planner`, `skill-implementer`) currently have no `orchestrator_mode` support; task 595 must add detection and handoff writing to all three, plus add `max_continuations=0` logic to `skill-implementer`.
- Extension compatibility (nvim, nix) is confirmed unaffected: both extensions use standard routing keys (`neovim`, `nix`) with no changes required to manifest routing tables.
- Realistic post-595 line counts: research ~175, plan ~175, implement ~195 — all within the 150-200 line target.

---

## Context & Scope

Task 595 refactors the three core workflow command files (`/research`, `/plan`, `/implement`) to achieve two goals:

1. **Size reduction**: Bring commands to ~150-200 lines by delegating remaining inline logic to shared scripts, per the four-tier context model (commands are Tier 2; agent-level context must not be embedded in commands).

2. **Orchestrator mode support**: Add `orchestrator_mode=true` detection to skills so they write `.orchestrator-handoff.json` when invoked by the future `/orchestrate` command (task 596).

**Baseline state** (after tasks 593 and 594):
- Commands: 393, 420, 525 lines (not yet at target)
- Skills: 231, 203, 336 lines (at or near target; task 594 complete)
- Shared scripts: `parse-command-args.sh` (123L), `command-gate-in.sh` (73L), `command-gate-out.sh` (81L), `skill-base.sh` (274L)

**Task 593 summary** (per `02_extract-shared-utilities-summary.md`): Extracted gate scripts, reducing commands by 87-111 lines each. However, multi-task dispatch blocks (~115 lines each) were explicitly deferred to task 595. The 150-200 line target is achievable only after task 595.

---

## Findings

### 1. Current Line Counts and Content Breakdown

#### `research.md` (393 lines)

| Section | Lines | Tier | Action |
|---------|-------|------|--------|
| YAML frontmatter | 6 | 2 | Keep |
| Title + description | 5 | 2 | Keep |
| Arguments + options docs | 41 | 2 | Keep |
| Anti-bypass constraint | 8 | 2 | Keep |
| Stage 0: source parse + clamp | 33 | 2 | Keep (simplify to ~10) |
| Multi-task dispatch | 119 | 2 | Extract to script (~3 lines) |
| CHECKPOINT 1 GATE IN ref | 15 | 2 | Keep (already references script; simplify) |
| STAGE 2 extension routing loop | 36 | 2 | Extract to script (~3 lines) |
| STAGE 2 routing table + invocation | 55 | 2 | Keep (command-specific) |
| CHECKPOINT 2 GATE OUT: script call | 3 | 2 | Keep |
| GATE OUT inline defensive checks | 38 | 3 | **Remove** (redundant with gate-out.sh) |
| CHECKPOINT 3 COMMIT | 15 | 2 | Keep |
| Output + error handling | 19 | 2 | Keep |

**Estimated post-595**: ~173 lines

#### `plan.md` (420 lines)

| Section | Lines | Tier | Action |
|---------|-------|------|--------|
| YAML frontmatter + title + docs | 50 | 2 | Keep |
| Anti-bypass constraint | 8 | 2 | Keep |
| Stage 0: source parse + clamp + roadmap flag | 29 | 2 | Keep (simplify to ~12) |
| Multi-task dispatch | 121 | 2 | Extract to script (~3 lines) |
| CHECKPOINT 1 GATE IN ref + plan-specific context load | 22 | 2 | Keep (simplify to ~10) |
| STAGE 2 extension routing loop | 36 | 2 | Extract to script (~3 lines) |
| STAGE 2 routing table + invocation | 58 | 2 | Keep |
| CHECKPOINT 2 GATE OUT: script call | 3 | 2 | Keep |
| GATE OUT inline defensive checks (state.json + TODO.md) | 38 | 3 | **Remove** (redundant with gate-out.sh) |
| GATE OUT plan file status check | 18 | 2 | Keep (plan-specific) |
| CHECKPOINT 3 COMMIT | 15 | 2 | Keep |
| Output + error handling | 22 | 2 | Keep |

**Estimated post-595**: ~175 lines

#### `implement.md` (525 lines)

| Section | Lines | Tier | Action |
|---------|-------|------|--------|
| YAML frontmatter + title + docs | 50 | 2 | Keep |
| Anti-bypass constraint | 8 | 2 | Keep |
| Stage 0: source parse + clamp + examples | 37 | 2 | Keep (simplify to ~15) |
| Multi-task dispatch | 152 | 2 | Extract to script (~5 lines; --force logic) |
| CHECKPOINT 1 GATE IN + force override + resume detection | 33 | 2 | Keep (implement-specific) |
| STAGE 2 extension routing loop | 36 | 2 | Extract to script (~3 lines) |
| STAGE 2 routing table + invocation | 54 | 2 | Keep |
| CHECKPOINT 2 GATE OUT: script call | 3 | 2 | Keep |
| GATE OUT steps 1-3 (general defensive) | 35 | 3 | **Remove/move to gate-out.sh** |
| GATE OUT steps 4-7 (implement-specific) | 55 | 2 | Keep |
| CHECKPOINT 3 COMMIT (partial/complete variants) | 30 | 2 | Keep |
| Output + error handling | 32 | 2 | Keep |

**Estimated post-595**: ~196 lines

---

### 2. What Stays vs. What Goes

#### Stays (Tier 2 — Controller Logic)

- YAML frontmatter (allowed-tools, argument-hint, model)
- User-facing argument and option documentation
- Anti-bypass constraint (prohibition on direct writes)
- Stage 0: `source parse-command-args.sh` + per-command clamp + command-specific flag extraction
- Multi-task dispatch: a concise loop calling a shared script, with command-specific result table
- CHECKPOINT 1: `source command-gate-in.sh` + command-specific context loading (implement: plan file detection + resume point; plan: prior plan path)
- STAGE 2: A routing table (extension table) + `Skill` invocation with command-specific args
- CHECKPOINT 2: `bash command-gate-out.sh` + command-specific checks (plan: plan file status; implement: completion_summary, plan file verification)
- CHECKPOINT 3: git commit
- Output and error handling sections

#### Goes (Tier 3 — Agent-Level Context, or Extractable Logic)

1. **Multi-task dispatch blocks** (~119-152 lines each): This is repetitive orchestration logic — batch validate, generate session ID, loop through tasks calling `Skill`, format output table. This is controller logic but is too verbose and mostly identical. Extraction to `command-multi-dispatch.sh` is appropriate.

2. **Extension routing loops** (~36 lines, identical): The `for manifest in .claude/extensions/*/manifest.json` loop is pure shell plumbing. Extract to `command-route-skill.sh <operation> <TASK_TYPE> <default_skill>` which exports `SKILL_NAME`.

3. **Inline GATE OUT defensive checks** for state.json and TODO.md status verification (~38 lines in research.md, ~38 lines in plan.md, ~35 lines in implement.md): These are already performed by `command-gate-out.sh`. Keeping them inline creates confusion about whether the script or inline code is authoritative and inflates command length unnecessarily. The inline content should be replaced with a brief comment: "Defensive correction handled by `command-gate-out.sh`."

---

### 3. Orchestrator Mode Analysis

The `orchestrator_mode` flag is the mechanism by which `/orchestrate` (task 596) communicates to skills that they are operating within an autonomous loop rather than a direct user invocation.

#### Current State

- No `orchestrator_mode` support exists in any skill file or `skill-base.sh`.
- The architecture spec (Component 5) defines the contract: skills write `.orchestrator-handoff.json` when and only when `"orchestrator_mode": true` appears in delegation context.

#### What Task 595 Must Add

**In `skill-base.sh`** (shared library):
```bash
# skill_write_orchestrator_handoff() — write handoff JSON if orchestrator_mode=true
# Called in each skill's postflight
skill_write_orchestrator_handoff() {
  local orchestrator_mode="$1"
  local padded_num="$2"
  local project_name="$3"
  local phase="$4"    # "research" | "plan" | "implement"
  local status="$5"   # "researched" | "planned" | "implemented" | "partial" | "failed" | "blocked"
  local summary="$6"
  local artifact_path="$7"
  local artifact_type="$8"
  local next_hint="$9"
  # Optional: blockers_json, files_modified_json, decisions_json, continuation_json
  ...
}
```

**In `skill-implementer/SKILL.md`** (Stage 5c — continuation loop init):
```bash
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')
if [ "$orchestrator_mode" = "true" ]; then
  max_continuations=0  # Disable inner loop; orchestrator drives continuation
else
  max_continuations=3  # Normal inner loop behavior
fi
```

**In all three skills' postflight** (after Stage 7 status update):
```bash
# If orchestrator_mode, write .orchestrator-handoff.json for skill-orchestrate to read
skill_write_orchestrator_handoff "$orchestrator_mode" "$PADDED_NUM" "$PROJECT_NAME" \
  "$phase" "$SUBAGENT_STATUS" "$ARTIFACT_SUMMARY" "$ARTIFACT_PATH" "$ARTIFACT_TYPE" "$next_hint"
```

#### Where orchestrator_mode Comes From

The `orchestrator_mode` value flows from the delegation context JSON. Each skill receives the delegation context as part of its invocation prompt. The skill reads it early (Stage 1 or during Stage 4 context preparation):

```bash
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"')
```

In normal `/research`, `/plan`, `/implement` invocations, this field is absent (defaults to `"false"`). In `/orchestrate`-dispatched invocations (task 596), `"orchestrator_mode": true` will be injected into the delegation context by `skill-orchestrate`.

#### Handoff File Schema

Per `handoff-schema.md`, the file must stay under 400 tokens total. Key fields:
- `phase`, `status`, `summary` (required)
- `artifacts`, `blockers`, `next_action_hint` (required/optional)
- `continuation_context` (present when `status="partial"`)

The file is written to `specs/${padded_num}_${project_name}/.orchestrator-handoff.json` (static path, overwritten each cycle).

---

### 4. Extension Compatibility Assessment

Both active extensions (nvim and nix) are confirmed compatible with the proposed refactoring:

**nvim extension** (`manifest.json`):
- Routes: `research.neovim → skill-neovim-research`, `plan.neovim → skill-planner`, `implement.neovim → skill-neovim-implementation`
- No changes needed; routing keys remain unchanged after refactor.
- The routing lookup loop (extracted to `command-route-skill.sh`) will still correctly find `neovim` key in `manifest.json`.

**nix extension** (`manifest.json`):
- Routes: `research.nix → skill-nix-research`, `plan.nix → skill-planner`, `implement.nix → skill-nix-implementation`
- Same assessment: no changes needed.

**Extension routing lookup** (the shell loop being extracted):
```bash
ext_skill=$(jq -r --arg tt "$TASK_TYPE" '.routing.research[$tt] // empty' "$manifest")
```
This is a pure manifest-read operation. Extracting it to a script does not alter the lookup semantics — extensions will continue to be discovered correctly via their `routing` tables.

**Extension skills** (skill-neovim-research, skill-nix-research, etc.): These are standalone implementations that do not inherit from `skill-base.sh` (per task 594 summary: "extension skills are unaffected — they have standalone implementations"). Task 595 does not need to add `orchestrator_mode` to extension skills; that is deferred to task 599 (extension hooks).

---

### 5. Size Reduction Estimates

| Command | Current | Lines to Remove | Estimated Post-595 |
|---------|---------|-----------------|---------------------|
| research.md | 393 | ~220 | ~173 |
| plan.md | 420 | ~245 | ~175 |
| implement.md | 525 | ~330 | ~195 |

Breakdown of reductions for research.md:
- Remove multi-task dispatch block: -117 lines → +3-5 lines reference = net -114
- Remove extension routing loop: -36 lines → +3 lines = net -33
- Remove redundant GATE OUT inline checks: -38 lines → +2 comment = net -36
- Simplify Stage 0 clamp verbosity: -23 lines (keep essential ~10 lines)
- Net removal: ~206 lines → target ~187 lines ✓

**New scripts to create:**

| Script | Lines (est.) | Purpose |
|--------|-------------|---------|
| `command-multi-dispatch.sh` | ~80 | Shared batch validation + parallel skill dispatch + output formatting |
| `command-route-skill.sh` | ~50 | Extension manifest routing loop + default fallback |

---

## Decisions

1. **Multi-task dispatch extraction strategy**: Extract shared logic to `command-multi-dispatch.sh`. The implement-specific `--force` handling stays inline or is passed as a parameter. This is the most impactful single reduction (119-152 lines → 3-5 lines per command).

2. **Extension routing extraction**: Extract to `command-route-skill.sh` which accepts `<operation>` and `<task_type>` and exports `SKILL_NAME`. Routing tables (documenting which skill handles which task type) remain inline in each command as documentation.

3. **Inline GATE OUT redundancy**: Remove the inline defensive check code from all three commands since it duplicates what `command-gate-out.sh` already does. Replace with a one-line comment pointing to the script.

4. **orchestrator_mode placement**: Add `skill_write_orchestrator_handoff()` to `skill-base.sh` as a shared function. Each of the three skills calls it in postflight. This is better than duplicating handoff-writing logic in three places.

5. **skill-implementer continuation loop**: Add `orchestrator_mode` detection to Stage 5c (continuation loop init) — when `true`, set `max_continuations=0`. This is a two-line addition to the existing loop guard init block.

6. **Extension skills excluded from orchestrator_mode**: Task 595 only adds orchestrator_mode to the three core skills. Extension skills (neovim, nix) gain orchestrator_mode support in task 599.

---

## Recommendations

### Priority 1: Extract Multi-Task Dispatch to Script

Create `.claude/scripts/command-multi-dispatch.sh`. This script should:
- Accept: `$1=operation`, `$2=default_skill`, `$3=force_flag`, remaining args = validated task numbers
- Perform: batch validation, session ID generation, parallel Skill invocations, result collection, batch git commit
- Display: consolidated output table (Succeeded/Failed/Skipped)
- The extension routing per-task needs to happen inline within the dispatch OR be called via `command-route-skill.sh` for each task

This is the highest-impact change: removes ~117-152 lines from each command.

### Priority 2: Extract Extension Routing Loop

Create `.claude/scripts/command-route-skill.sh`. This script should:
- Accept: `$1=operation` (research/plan/implement), `$2=TASK_TYPE`, `$3=default_skill`
- Export: `SKILL_NAME` (the resolved skill)
- Search extension manifests using the existing `jq` loop logic
- Handle compound keys (e.g., `founder:deck` → try exact, then base type)

### Priority 3: Remove Redundant Inline GATE OUT

In research.md and plan.md, remove the inline `Verify state.json Status` and `Verify TODO.md Status` sections that follow the `bash command-gate-out.sh` call. These are already performed by the script. Add a brief comment: "Defensive correction (state.json + TODO.md) handled by `command-gate-out.sh` above."

For implement.md, steps 1-3 of CHECKPOINT 2 are also handled by gate-out.sh; remove them. Steps 4-7 (completion summary, plan file verification) are implement-specific and must stay.

### Priority 4: Add Orchestrator Mode to Skills

In `skill-base.sh`, add `skill_write_orchestrator_handoff()` function implementing the schema from `handoff-schema.md`. All three core skills call this in postflight. In `skill-implementer`, add `orchestrator_mode` detection to Stage 5c.

### Priority 5: Simplify Verbose Sections

After the above extractions, review Stage 0 blocks for verbose explanatory tables and examples (implement.md has a 5-row input/output table that could be moved to docs). This yields an additional 15-20 lines per command.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `command-multi-dispatch.sh` cannot invoke Skill tool (it's a bash script) | High | The dispatch loop must remain in command files as markdown prose; the script handles only pre-dispatch validation + post-dispatch output formatting |
| Removing inline GATE OUT docs breaks developer understanding | Medium | Keep a brief comment explaining what gate-out.sh does; add reference to gate-out.sh source for details |
| orchestrator_mode detection in wrong stage | Medium | Add detection at very start of skill execution (during initial context reading), export as variable |
| Handoff JSON token budget exceeded | Low | `skill_write_orchestrator_handoff()` should truncate `decisions_made`/`dead_ends` if combined object exceeds 400 tokens |
| Breaking extension routing with script refactor | Low | Test with `TASK_TYPE=neovim` and `TASK_TYPE=nix` after creating `command-route-skill.sh` |

### Critical Insight: Skill Dispatch Cannot Be in Bash Scripts

The Skill tool invocation (the parallel Skill calls in multi-task dispatch) is part of Claude's tool-call mechanism — it cannot be delegated to a bash script. This means the multi-task dispatch extraction has a fundamental constraint:

- **Extractable**: batch validation, session ID generation, output formatting, batch git commit
- **Not extractable**: the parallel Skill tool calls themselves

The recommended approach for `command-multi-dispatch.sh`:
1. Script handles pre-dispatch validation (batch validation, session ID) — invoked before the Skill calls
2. The command file retains a lean loop: `for task in $validated_tasks; do invoke Skill...`
3. Script handles post-dispatch output formatting — invoked after all Skill calls return

This means the command files will still have the dispatch loop, but it will be a 10-15 line loop instead of 40-50 lines.

**Revised size estimate with this constraint:**
- research.md: ~180 lines (still within target)
- plan.md: ~180 lines (still within target)
- implement.md: ~205 lines (slightly over but acceptable)

---

## Context Extension Recommendations

- **Topic**: Command file tier analysis
- **Gap**: No documentation in `.claude/context/` explains what belongs in Tier 2 (command) vs Tier 3 (agent). Developers adding new commands may not know the boundary.
- **Recommendation**: After task 595, create `.claude/context/patterns/command-design.md` documenting the controller-only pattern with concrete examples of what stays vs. moves.

---

## Appendix

### Key File Paths

- Command files: `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md`
- Shared scripts (from task 593): `.claude/scripts/parse-command-args.sh`, `.claude/scripts/command-gate-in.sh`, `.claude/scripts/command-gate-out.sh`
- Skill base (from task 594): `.claude/scripts/skill-base.sh`
- Skills: `.claude/skills/skill-researcher/SKILL.md`, `.claude/skills/skill-planner/SKILL.md`, `.claude/skills/skill-implementer/SKILL.md`
- Architecture: `.claude/docs/architecture/architecture-spec.md`, `.claude/docs/architecture/handoff-schema.md`
- Extension manifests: `.claude/extensions/nvim/manifest.json`, `.claude/extensions/nix/manifest.json`

### Scripts to Create in Task 595

| Script | Lines (estimated) |
|--------|------------------|
| `.claude/scripts/command-multi-dispatch.sh` | ~80 |
| `.claude/scripts/command-route-skill.sh` | ~50 |

### New Function in skill-base.sh

`skill_write_orchestrator_handoff()` — ~25 lines, shared across all three skills.

### Line Count Summary

| File | Before | After (est.) | Change |
|------|--------|-------------|--------|
| research.md | 393 | ~178 | -215 |
| plan.md | 420 | ~178 | -242 |
| implement.md | 525 | ~202 | -323 |
| command-multi-dispatch.sh | 0 | ~80 | +80 |
| command-route-skill.sh | 0 | ~50 | +50 |
| skill-base.sh | 274 | ~302 | +28 |
| skill-researcher/SKILL.md | 231 | ~240 | +9 |
| skill-planner/SKILL.md | 203 | ~212 | +9 |
| skill-implementer/SKILL.md | 336 | ~355 | +19 |
| **Net change** | | | **-585** |

Total lines eliminated from commands: ~780. Total new lines (scripts + skill additions): ~195. Net reduction: ~585 lines.

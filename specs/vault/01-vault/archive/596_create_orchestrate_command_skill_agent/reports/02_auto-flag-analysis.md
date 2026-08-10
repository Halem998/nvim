# Research Report: Task #596 — --auto Flag vs. Standalone /orchestrate

**Task**: 596 - Create /orchestrate command, skill-orchestrate, and dispatch-agent.sh
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T00:45:00Z
**Effort**: ~45 min (architecture analysis, no web search needed)
**Dependencies**: Reports 01 (seed research) and 03 (design guidance)
**Sources/Inputs**:
- `.claude/commands/implement.md` — full implement command flow
- `.claude/skills/skill-implementer/SKILL.md` — continuation loop, orchestrator_mode handling
- `.claude/skills/skill-orchestrator/SKILL.md` — current routing-only skill
- `.claude/scripts/skill-base.sh` — shared lifecycle functions (skill_write_orchestrator_handoff)
- `.claude/scripts/command-gate-in.sh` — session generation, terminal guard
- `.claude/scripts/command-gate-out.sh` — defensive status correction
- `specs/596_.../reports/01_seed-research.md` — fire-and-forget directive, blocker escalation design
- `specs/596_.../reports/03_design-guidance.md` — state machine, dispatch_agent(), handoff schema
**Artifacts**:
- `specs/596_create_orchestrate_command_skill_agent/reports/02_auto-flag-analysis.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- Option A (`--auto` flag on `/implement`) would require `/implement` to handle multi-phase state management, blocker escalation research, and plan revision — a severe violation of single-responsibility that collapses two architecturally distinct workflows into one command.
- Option B (standalone `/orchestrate`) maps cleanly to the existing command taxonomy: each command owns a distinct lifecycle phase, and `/orchestrate` owns the cross-phase lifecycle.
- The continuation loop in `skill-implementer` already detects `orchestrator_mode` from the delegation context and disables its inner loop — the infrastructure for a separate orchestrator was built into the implement skill from the start.
- Blocker escalation (detect → fork-research → revise → re-implement) is a multi-command workflow that fundamentally cannot live inside a single-phase command.
- Context management requirements diverge completely: `/implement` is single-phase with flat context; `/orchestrate` is multi-cycle with a strict 400-token handoff protocol to prevent context accumulation.
- **Recommendation**: Standalone `/orchestrate` is the correct architecture. Adding `--auto` to `/implement` would produce a command that is neither a reliable single-phase implementer nor a reliable autonomous loop.

---

## Context & Scope

The question is whether to add a `--auto` flag to `/implement` that causes it to run the full research → plan → implement pipeline when the task has not yet been researched/planned, or to keep this as a separate `/orchestrate` command.

This analysis examines five dimensions:
1. What `/implement` currently does and what its architectural constraints are
2. Where `orchestrator_mode` is already plumbed in `skill-implementer`
3. How blocker escalation interacts with the implement command boundary
4. Context management requirements for a multi-cycle loop vs. single-phase execution
5. The fork-vs-fresh-agent decision matrix and where it belongs

---

## Findings

### 1. Current /implement Architecture

`/implement` follows the three-checkpoint pattern: GATE IN → DELEGATE → GATE OUT → COMMIT.

**GATE IN responsibilities**:
- Generate `SESSION_ID`
- Validate task exists and is not terminal
- Locate the latest plan file (`specs/${PADDED_NUM}_${PROJECT_NAME}/plans/*.md`)
- **Hard abort if no plan is found**: "No implementation plan found. Run /plan {N} first."
- Detect resume point from phase markers

The hard abort on missing plan is load-bearing. It enforces the invariant that `/implement` always executes against an existing plan. This boundary is what makes the implement skill safe to invoke as a named subagent — it cannot accidentally start work without a plan.

**DELEGATE responsibilities**:
- Route to `skill-implementer`, `skill-neovim-implementation`, `skill-nix-implementation`, or `skill-team-implement` by task type
- Pass `orchestrator_mode=false` explicitly (hardcoded in the current command)
- Pass `session_id`, `plan_path`, `resume_phase`, `effort_flag`, `model_flag`

The `orchestrator_mode=false` is hardcoded in the current `/implement` command's skill invocation. This is intentional — it prevents the inner continuation loop from being disabled unless an actual orchestrator is driving.

**GATE OUT responsibilities**:
- Read `.return-meta.json` for status
- Apply defensive status correction (planned → completed, etc.)
- Populate `completion_summary` in state.json when `status == "implemented"`
- Verify plan file shows `[COMPLETED]`

**Structural constraint**: The gate-in, gate-out, and commit logic treat each `/implement` invocation as an atomic unit. The session ID is generated once at gate-in and committed once at gate-out. A multi-cycle loop (research → plan → implement → implement on blocker) would require multiple session IDs, multiple gate-in/gate-out cycles, and multiple commits — none of which fit the current single-invocation model.

---

### 2. orchestrator_mode Is Already Plumbed for a Separate Orchestrator

`skill-implementer/SKILL.md` Stage 4 reads `orchestrator_mode` from the delegation context:

```bash
orchestrator_mode=$(echo "$delegation_context" | jq -r '.orchestrator_mode // "false"' 2>/dev/null || echo "false")
```

Stage 5c (continuation loop init) sets `max_continuations` based on this flag:

```bash
if [ "$orchestrator_mode" = "true" ]; then
  max_continuations=0  # Outer orchestrator loop handles continuation
else
  max_continuations=3  # Normal inner loop
fi
```

Stage 7 (postflight) calls `skill_write_orchestrator_handoff()` — a function in `skill-base.sh` specifically designed to write `.orchestrator-handoff.json` for an external orchestrator to read.

This is not accidental. The implementer was designed from the start to behave differently when called by an external orchestrator vs. called directly by the user. The flag separation creates a clean interface boundary: the implementer does not need to know whether it is being driven by `/orchestrate` or by the user — it only checks the flag passed in the delegation context.

If `--auto` were added to `/implement`, this flag would need to flip mid-execution (from `false` to `true` partway through), or the command would need to re-dispatch itself as an inner agent with the flag set. Both approaches would break the clean interface.

---

### 3. Blocker Escalation Cannot Live Inside /implement

The blocker escalation pattern from report 03 is:

```
implement phase N → blocked
  → orchestrator reads blocker from handoff
  → FORK: blocker research (inherits orchestrator's warm context)
  → fresh named subagent: reviser-agent (plan revision)
  → fresh named subagent: general-implementation-agent (re-implement)
```

This requires three additional agent dispatches after the implement agent returns a `blocked` status. `/implement`'s current postflight loop in `skill-implementer` handles `partial` status via the continuation loop (max 3 continuations), but it explicitly does **not** handle `blocked` — it sets `max_continuations=0` for `orchestrator_mode=true` and lets the outer orchestrator drive.

If `--auto` were added to `/implement`, the command would need to:
1. Detect `blocked` status from the skill's return metadata
2. Dispatch a research fork to investigate the blocker
3. Dispatch a reviser agent to revise the plan
4. Re-invoke `/implement` (or the implementation skill) against the revised plan
5. Track the total cycle count across all of this

This is exactly the state machine that `/orchestrate` is designed to implement. Putting it inside `/implement` would mean `/implement` is no longer "execute a plan" — it is "manage the full autonomous loop from plan execution through blocker resolution." That is a different command.

---

### 4. Context Management Requirements Diverge Completely

**`/implement` context model**:
- Single session ID from gate-in to commit
- Plan content read once at gate-in
- Skill returns a single metadata file
- Gate-out reads that file, updates state, commits

**`/orchestrate` context model** (from reports 01 and 03):
- Multi-cycle loop with MAX_CYCLES = 5
- Each cycle dispatches an agent and reads a ≤400-token handoff file
- Orchestrator context growth: ~450 tokens/cycle, ~2250 tokens after 5 cycles
- The 400-token handoff budget is the mechanism that keeps context flat
- The loop guard file (`.orchestrator-loop-guard`) persists cycle count across interruptions

The `/implement` command's single-session model is what makes its context safe. Adding a multi-cycle loop to it would require the command to maintain a loop guard, read handoff files, track cycle counts — none of which are compatible with the GATE IN → DELEGATE → GATE OUT → COMMIT lifecycle.

There is also a model consideration: `/implement` currently runs at `model: opus` to handle large context accumulation. `/orchestrate` needs its own model declaration to handle multi-cycle context. These are separate context profiles.

---

### 5. Fork-vs-Fresh-Agent Matrix Belongs in /orchestrate

From report 03, the dispatch decision matrix:

| State | Path | Reason |
|-------|------|--------|
| not_started → research | Fresh named | Needs specialized research agent context |
| researched → plan | Fresh named | Needs planner agent prompt |
| planned → implement | Fresh named | Needs implementation agent context |
| Blocker research | Fork | Inherits orchestrator's warm context (~90% token savings) |
| Blocker revise | Fresh named | Needs reviser agent prompt |

This matrix is orchestration logic — it determines which agent to dispatch and how, based on what just happened in the previous cycle. It has no natural home inside `/implement`, which dispatches exactly one agent (the implementer).

If `--auto` added this matrix to `/implement`, the command would need to know about `general-research-agent`, `planner-agent`, and `reviser-agent` — agents that have nothing to do with implementation. This violates the principle that each command routes only to skills in its own domain.

---

## Decisions

1. **Option B (standalone /orchestrate) is the correct architecture.** The existing codebase already treats `/implement` as a single-phase executor and has built explicit `orchestrator_mode` plumbing for an external orchestrator to drive it.

2. **The `--auto` flag on `/implement` would create a hybrid command** that partially overlaps with the existing single-phase model and partially implements a new multi-phase model. The resulting command would be harder to reason about and harder to test.

3. **`orchestrator_mode=false` should remain hardcoded in `/implement`.** The flag should only be set to `true` by `/orchestrate` (or `skill-orchestrate`) in the delegation context it passes to `skill-implementer`. This preserves the clean interface boundary.

4. **The current `skill-orchestrator/SKILL.md` (128 lines, routing-only) is vestigial** and should be replaced by the new `skill-orchestrate/SKILL.md` state machine per report 03. The routing function it currently performs is already handled by `command-route-skill.sh`.

---

## Recommendations

1. **Proceed with standalone `/orchestrate` command** as specified in reports 01 and 03. The implementation scope is:
   - `.claude/commands/orchestrate.md` — entry point, arg parsing, GATE IN, DELEGATE to skill-orchestrate, GATE OUT, COMMIT
   - `.claude/skills/skill-orchestrate/SKILL.md` — state machine (~200 lines)
   - `.claude/scripts/dispatch-agent.sh` — fork-vs-fresh-agent function

2. **Do not add `--auto` to `/implement`.** The implement command's GATE IN already has the correct hard abort on missing plan. This boundary should not be softened.

3. **Preserve `orchestrator_mode=false` as the hardcoded default** in `implement.md`'s skill invocation. Only `/orchestrate` should set this to `true`.

4. **The `/orchestrate` command gate-in differs from `/implement`**: it should NOT require a plan. Instead, it reads `state.json` to determine the current task state and decides which phase to dispatch first. The state machine loop drives forward from whatever state the task is in.

5. **`skill-orchestrator/SKILL.md` (the vestigial routing-only skill)** should be retired or substantially replaced during task 596 implementation. The new `skill-orchestrate/SKILL.md` is not the same skill — it contains the state machine, dispatch logic, and blocker escalation. The old routing skill can be archived or left as a stub.

---

## Risks & Mitigations

| Risk | Description | Mitigation |
|------|-------------|------------|
| Naming confusion | `skill-orchestrator` (vestigial) vs. `skill-orchestrate` (new) | Rename old to `skill-orchestrate-router` or retire it; document clearly in CLAUDE.md |
| orchestrator_mode flag contract | If `skill-implementer` changes how it reads the flag, `/orchestrate` breaks silently | Add a comment in `skill-implementer` Stage 4 cross-referencing `/orchestrate`'s dependency |
| Double-loop on resume | User runs `/orchestrate` on a task mid-implementation; the loop guard must correctly count cycles across invocations | `.orchestrator-loop-guard` persists cycle count per report 03 — design is correct |
| Blocker escalation infinite loop | A consistently bad task could cause research → revise → implement → block → research → revise → implement → block | Cap blocker escalation at 2 attempts; on 3rd block, exit with human escalation message |
| GATE IN for /orchestrate | `/orchestrate` gate-in must allow non-planned tasks (unlike `/implement` which requires a plan) | Gate-in for `/orchestrate` should only check terminal states, not require a specific pre-existing status |

---

## Appendix

### Key File Paths Examined

- `/home/benjamin/.config/nvim/.claude/commands/implement.md` — lines 1-208
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` — lines 1-364
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrator/SKILL.md` — lines 1-129
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — lines 1-230 (skill_write_orchestrator_handoff stub referenced)
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-in.sh` — full
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-out.sh` — full
- `specs/596_.../reports/01_seed-research.md` — fire-and-forget directive, blocker escalation, nested loop resolution
- `specs/596_.../reports/03_design-guidance.md` — state table, dispatch_agent() spec, handoff schema, blocker escalation 5-step, context flatness guarantee

### Architecture Evidence for Option B

The clearest evidence that `/orchestrate` belongs as a separate command is already in the codebase:

1. `skill-implementer` Stage 5c sets `max_continuations=0` when `orchestrator_mode=true`, explicitly delegating continuation control to an external orchestrator.
2. `skill-implementer` Stage 7 calls `skill_write_orchestrator_handoff()` — a postflight function whose entire purpose is to communicate back to an external orchestrator. This function would have no caller if `/orchestrate` did not exist as a separate command.
3. `implement.md` hardcodes `orchestrator_mode=false` in the skill invocation, explicitly stating that user-invoked `/implement` is not orchestrator-driven.
4. The `skill-base.sh` comment at line 27: "ORCHESTRATOR MODE: Support for skill-orchestrate dispatch (task 596). When orchestrator_mode=true in delegation context, skills call skill_write_orchestrator_handoff() in their postflight..."

The infrastructure was built in anticipation of a separate `/orchestrate` command. The `--auto` flag question is therefore already answered by the codebase: the two command modes are architecturally separated, and the interface between them (the `orchestrator_mode` flag and the `.orchestrator-handoff.json` handoff file) is already defined.

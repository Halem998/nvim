# Teammate A Findings: Primary Implementation Approach

**Task**: 669 — hard_mode_agent_system
**Angle**: Primary implementation approach and routing architecture
**Date**: 2026-06-12

## Key Findings

### Finding 1: The routing branch point is consistent across all four commands (HIGH confidence)

All four target commands (implement.md, research.md, plan.md, orchestrate.md) share an identical three-step delegation pattern:

1. Parse flags via `parse-command-args.sh` → `EFFORT_FLAG="hard"` already works
2. Resolve skill target at STAGE 2: DELEGATE → **this is the branch point**
3. Invoke the Skill tool with the resolved skill name

The `--team` flag already demonstrates the exact pattern needed. In every command's STAGE 2, the routing logic is:

```
if team_mode:
  skill_name = "skill-team-{operation}"
else:
  skill_name = {extension routing} OR "skill-{operation}"
```

The --hard flag should slot in between team mode and extension routing:

```
if team_mode:
  skill_name = "skill-team-{operation}"
elif hard_mode:
  skill_name = {extension hard routing} OR "skill-{operation}-hard"
else:
  skill_name = {extension routing} OR "skill-{operation}"
```

### Finding 2: implement.md uses command-route-skill.sh; research.md and plan.md inline the routing logic (HIGH confidence)

- **implement.md** (line 125-128): Uses `source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"` — a centralized routing script.
- **research.md** (lines 332-366): Inlines the extension manifest lookup loop directly in the command file.
- **plan.md** (lines 334-370): Also inlines the extension manifest lookup.
- **orchestrate.md**: Uses a `case` statement in Stage 1b (lines 80-98) to resolve agents directly, with a separate extension fallback.

**Implication**: The cleanest approach is to extend `command-route-skill.sh` with an optional `$4 = effort_flag` parameter. When `effort_flag="hard"`, it checks `routing_hard` in extension manifests first, then falls back to appending `-hard` to the default skill name. The inline routing in research.md and plan.md should also be updated to honor the effort flag (or ideally refactored to use command-route-skill.sh).

### Finding 3: Extension manifest.json already has a clean routing schema that can be extended (HIGH confidence)

The lean extension's manifest.json shows the routing structure:

```json
{
  "routing": {
    "research": { "lean4": "skill-lean-research" },
    "plan":     { "lean4": "skill-planner" },
    "implement": { "lean4": "skill-lean-implementation" }
  }
}
```

Adding hard-mode routing should add a parallel section:

```json
{
  "routing": {
    "research": { "lean4": "skill-lean-research" },
    "plan":     { "lean4": "skill-planner" },
    "implement": { "lean4": "skill-lean-implementation" }
  },
  "routing_hard": {
    "research":  { "lean4": "skill-lean-research-hard" },
    "plan":      { "lean4": "skill-planner-hard" },
    "implement": { "lean4": "skill-lean-implementation-hard" }
  }
}
```

If `routing_hard` is absent or the key isn't found, the system falls back to the normal `routing` section — graceful degradation built in.

### Finding 4: Separate skill files are better than branching within existing skills (HIGH confidence)

The user explicitly said: "I want the hard-mode routing to happen early at the command level in order to divert to a hard-mode skill, which calls hard-mode agents, etc., as appropriate."

Examining the thin-wrapper skill pattern (skill-researcher, skill-planner, skill-implementer), each is ~100-200 lines with minimal logic:
1. Input validation
2. Preflight status update
3. Create postflight marker
4. Spawn agent
5. Parse return
6. Postflight (status, artifacts, git)

The hard-mode skills should follow this same thin-wrapper pattern but with different:
- **Agent selection**: e.g., `planner-hard-agent` instead of `planner-agent`
- **Delegation context**: Include hard-mode prompt contract references
- **Model defaults**: Opus for audit/plan dispatches; sonnet for worker agents

This means 4 new skill directories:
- `.claude/skills/skill-researcher-hard/SKILL.md`
- `.claude/skills/skill-planner-hard/SKILL.md`
- `.claude/skills/skill-implementer-hard/SKILL.md`
- `.claude/skills/skill-orchestrate-hard/SKILL.md`

### Finding 5: Agent variants should be separate files, not prompt injection (MEDIUM confidence)

Trade-off analysis:

| Approach | Pros | Cons |
|----------|------|------|
| Separate agent files | Clean separation; skill stays thin; agent system prompt bakes in H2/H3/H9; no runtime Read calls | Duplication of common sections (~40% overlap) |
| Prompt injection from skill | No duplication; one agent file | Skill gets complex; @-reference loading at runtime; harder to test; contradicts user's "not too much complexity in any one file" |
| Agent base + hard overlay | Minimal duplication; agent reads context at runtime | Still adds runtime Read; agent must self-modify behavior based on context |

**Recommendation**: Separate agent files. The overlap can be minimized by having hard agents reference shared context files for their non-hard-specific behaviors (research strategy tree, execution flow, etc.) while baking in the hard-mode contract sections.

New agent files:
- `.claude/agents/general-research-hard-agent.md`
- `.claude/agents/planner-hard-agent.md`
- `.claude/agents/general-implementation-hard-agent.md`

The orchestrate-hard skill doesn't need its own agent because it dispatches to the above three agents — it IS the orchestrator.

### Finding 6: Shared prompt-contract fragments belong in .claude/context/contracts/ (HIGH confidence)

The existing context directory already has well-organized subdirectories: `patterns/`, `formats/`, `standards/`, `orchestration/`. Hard-mode contracts are a new category. Proposed structure:

```
.claude/context/contracts/
├── anti-analysis.md         (H2: read budget, forbidden conclusions, defect bar)
├── prior-art-grounding.md   (H3: transcription mandate, PDF citation requirements)
├── territory.md             (H7: file territory, plan territory, commit protocol)
├── wrap-up.md               (H9: handoff JSON, continuation markdown, incremental commits)
├── convergence.md           (H6: progress criteria, churn signature tracking)
└── README.md                (index and usage guide)
```

Hard-mode agents include these as @-references in their Context References section:
```markdown
## Context References
- `@.claude/context/contracts/anti-analysis.md` - Anti-analysis contract (H2)
- `@.claude/context/contracts/prior-art-grounding.md` - Prior-art grounding (H3)
- `@.claude/context/contracts/wrap-up.md` - Wrap-up contract (H9)
```

These fragments are also added to `index.json` with `load_when.agents` pointing to the hard-mode agents.

### Finding 7: skill-orchestrate-hard is the most architecturally different (HIGH confidence)

While the other hard skills are thin wrappers with different agent targets and delegation context, skill-orchestrate-hard fundamentally changes the dispatch loop:

| Aspect | Standard orchestrate | Hard orchestrate |
|--------|---------------------|------------------|
| Dispatch unit | Whole plan | Single phase |
| Loop guard | cycle_count, MAX_CYCLES=5 | cycle_count + defect_claims + sorry_relocations |
| Escalation | blocker research → plan revision → re-dispatch | blocker → divergence audit (H5) → user pivot decision |
| Verification | None before implementation | Mandatory adversarial verify of research (H4) |
| Agent selection | task-type-based | task-type-based + hard variants |
| Handoff schema | status, phases_completed, blockers | + sorry_inventory, churn_counters |

This is NOT a thin wrapper — it's a full state machine variant. Expected size: ~400-600 lines (vs ~350 for standard skill-orchestrate).

## Recommended Approach

### Phase 1: Routing Infrastructure (touches 5 files)

**1a. Extend `command-route-skill.sh`** — Add `$4 = effort_flag` parameter:

```bash
# After Step 1 (extension routing), before Step 3 (fallback):
# Step 1.5: If hard mode, check routing_hard section
if [ "$_route_effort" = "hard" ] && [ -z "$SKILL_NAME" ]; then
  for _manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$_manifest" ]; then
      _ext_skill=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
        '.routing_hard[$op][$tt] // empty' "$_manifest" 2>/dev/null)
      if [ -n "$_ext_skill" ]; then
        SKILL_NAME="$_ext_skill"
        break
      fi
    fi
  done
fi

# Step 3: Fallback — append -hard to default if effort_flag=hard
if [ -z "$SKILL_NAME" ]; then
  if [ "$_route_effort" = "hard" ]; then
    _hard_skill="${_route_default_skill}-hard"
    # Only use hard variant if the skill directory exists
    if [ -d ".claude/skills/${_hard_skill}" ]; then
      SKILL_NAME="$_hard_skill"
    else
      SKILL_NAME="$_route_default_skill"
      echo "[route] WARNING: No hard variant found for ${_route_default_skill}, using standard" >&2
    fi
  else
    SKILL_NAME="$_route_default_skill"
  fi
fi
```

**1b. Update implement.md** (1 line change, line ~125):

```bash
# FROM:
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"

# TO:
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer" "$EFFORT_FLAG"
```

The team_mode check happens earlier and takes precedence (unchanged). Add a note that `--hard --team` is not supported (or define behavior: team-hard routes to `skill-team-implement-hard` — future work).

**1c. Update research.md** — Replace inline routing with:

```bash
source .claude/scripts/command-route-skill.sh "research" "$task_type" "skill-researcher" "$effort_flag"
skill_name="$SKILL_NAME"
```

(The inline routing loop at lines 332-366 becomes dead code — remove it.)

**1d. Update plan.md** — Same refactor as research.md:

```bash
source .claude/scripts/command-route-skill.sh "plan" "$task_type" "skill-planner" "$effort_flag"
skill_name="$SKILL_NAME"
```

**1e. Update orchestrate.md** — Route to skill-orchestrate-hard when `EFFORT_FLAG="hard"`:

The orchestrate command doesn't currently parse effort flags (it only parses task numbers and focus prompt). It needs:
1. Add `--hard` to its argument parsing (source parse-command-args.sh)
2. In its CHECKPOINT 1: GATE IN, route to skill-orchestrate-hard if `EFFORT_FLAG="hard"`

### Phase 2: Shared Prompt Contracts (5 new files)

Create `.claude/context/contracts/` with the H2, H3, H6, H7, H9 fragments extracted from Report 01 Section 3. Each fragment is 30-60 lines of specific, copy-pasteable prompt contract text.

Add entries to `index.json` with:
```json
{
  "path": "contracts/anti-analysis.md",
  "load_when": {
    "agents": ["general-implementation-hard-agent", "planner-hard-agent", "general-research-hard-agent"]
  }
}
```

### Phase 3: Hard-Mode Agents (3 new files)

**3a. `general-research-hard-agent.md`**:
- Same research strategy tree as `general-research-agent.md`
- Added: mandatory adversarial verification pass (H4) — after creating report, spawn a verification sub-section
- Added: divergence audit mode when focus_prompt requests it (H5)
- Added: PDF-level citation requirement (H3)
- Context references: `@contracts/prior-art-grounding.md`, `@contracts/anti-analysis.md`

**3b. `planner-hard-agent.md`**:
- Same plan creation flow as `planner-agent.md`
- Added: phase sizing constraint — each phase MUST be completable in one agent run (~100-500 lines)
- Added: postmortem-constraints section in plan (H8)
- Added: preserved-assets accounting (H8)
- Added: lemma-to-source mapping table when literature exists (H3)
- Added: dependency waves for parallel dispatch (H7)
- Context references: `@contracts/prior-art-grounding.md`, `@formats/plan-format.md`

**3c. `general-implementation-hard-agent.md`**:
- Same execution flow as `general-implementation-agent.md`
- Added: Anti-analysis contract baked into system prompt (H2 — the single most valuable change)
- Added: Wrap-up contract requiring handoff JSON and incremental commits (H9)
- Added: Territory contract awareness (H7) — reads territory from delegation context
- Context references: `@contracts/anti-analysis.md`, `@contracts/wrap-up.md`, `@contracts/territory.md`

### Phase 4: Hard-Mode Skills (4 new directories)

**4a. `skill-researcher-hard/SKILL.md`**:
- Thin wrapper delegating to `general-research-hard-agent`
- After agent returns: if report contains load-bearing claims, spawn second adversarial-verify dispatch (H4)
- Postflight: standard (status update, artifact linking, git commit)
- ~150 lines

**4b. `skill-planner-hard/SKILL.md`**:
- Thin wrapper delegating to `planner-hard-agent`
- Passes H8 plan requirements in delegation context
- Postflight: standard
- ~120 lines

**4c. `skill-implementer-hard/SKILL.md`**:
- Thin wrapper delegating to `general-implementation-hard-agent`
- Key difference: passes **single phase** dispatch context, not whole plan
- Includes territory contract in delegation context (H7)
- ~150 lines

**4d. `skill-orchestrate-hard/SKILL.md`**:
- Full state machine variant (~400-600 lines)
- Per-phase dispatch loop (H1) instead of whole-plan dispatch
- Churn detection counters (defect_claims, sorry_relocations) (H6)
- Divergence audit trigger after 3 deflections (H5)
- Mandatory adversarial verify before first implementation dispatch (H4)
- Escalation: continuation → blocker research → plan revision → divergence audit → user pivot
- Loop guard schema extensions: sorry_inventory, churn_counters
- Prompt assembly from template with slots (Mission, Settled Design, Foundations, Literature Anchors, Hard Rules, Territory, Wrap-up)

### Phase 5: Extension Integration

**5a. Update manifest.json schema** — Add optional `routing_hard` section (same structure as `routing`):

```json
{
  "routing_hard": {
    "research":  { "lean4": "skill-lean-research-hard" },
    "implement": { "lean4": "skill-lean-implementation-hard" }
  }
}
```

Extensions don't need to provide hard variants immediately. The routing script falls back to normal routing when `routing_hard` is absent.

**5b. Lean extension (first domain)** — Create:
- `skill-lean-research-hard/` — with PDF grounding mandate, adversarial verify
- `skill-lean-implementation-hard/` — with anti-analysis contract, per-phase dispatch
- `lean-research-hard-agent.md` — with lean-specific divergence audit
- `lean-implementation-hard-agent.md` — with sorry-aware anti-analysis contract

### Phase 6: Documentation and Index Updates

- Update CLAUDE.md routing tables to document --hard routing
- Add `contracts/` entries to `index.json`
- Update `command-structure.md` to document the effort_flag routing convention
- Update `skill-agent-mapping` reference

## Evidence/Examples

### Evidence 1: --team pattern in research.md (lines 323-328)

```python
# research.md STAGE 2:
if team_mode == true:
  skill_name = "skill-team-research"   # override regardless of task_type
else:
  skill_name = {extension routing} OR "skill-researcher"
```

This is the exact pattern --hard should follow:

```python
if team_mode:
  skill_name = "skill-team-{op}"
elif hard_mode:
  skill_name = {extension hard routing} OR "skill-{op}-hard"
else:
  skill_name = {extension routing} OR "skill-{op}"
```

### Evidence 2: command-route-skill.sh architecture (full file)

The script accepts `(operation, task_type, default_skill)` and returns `SKILL_NAME`. Adding `effort_flag` as $4 is a backwards-compatible extension — existing callers that don't pass it get standard routing (empty string = no hard mode).

### Evidence 3: Extension manifest routing isolation

The lean manifest shows routing is ONLY in `routing.{operation}.{task_type}`. Adding `routing_hard` as a sibling key doesn't break any existing manifest parsing — `command-route-skill.sh` only reads `routing`, so `routing_hard` is invisible until the script is updated.

### Evidence 4: Effort flag already fully parsed

`parse-command-args.sh` already exports `EFFORT_FLAG="hard"` when `--hard` is present. The orchestrate command just needs to source it (currently it doesn't use the shared parser for this).

## Confidence Levels

| Finding | Confidence | Reasoning |
|---------|------------|-----------|
| Routing branch point location | HIGH | Verified in all 4 command files — identical pattern |
| command-route-skill.sh extension | HIGH | Backwards-compatible; proven pattern |
| Extension manifest schema | HIGH | routing_hard is additive, no breaking changes |
| Separate skill files | HIGH | User explicitly requested this architecture |
| Separate agent files | MEDIUM | Duplication concern is real; prompt injection is simpler but contradicts user preference |
| skill-orchestrate-hard scope | HIGH | Report 01 Section 4 provides detailed spec |
| contracts/ directory location | HIGH | Follows existing context/ organization pattern |

## Files to Create

| File | Type | ~Lines | Purpose |
|------|------|--------|---------|
| `.claude/context/contracts/anti-analysis.md` | Context | 60 | H2 prompt contract |
| `.claude/context/contracts/prior-art-grounding.md` | Context | 50 | H3 prompt contract |
| `.claude/context/contracts/territory.md` | Context | 40 | H7 prompt contract |
| `.claude/context/contracts/wrap-up.md` | Context | 50 | H9 prompt contract |
| `.claude/context/contracts/convergence.md` | Context | 40 | H6 prompt contract |
| `.claude/skills/skill-researcher-hard/SKILL.md` | Skill | 150 | Hard research wrapper |
| `.claude/skills/skill-planner-hard/SKILL.md` | Skill | 120 | Hard planning wrapper |
| `.claude/skills/skill-implementer-hard/SKILL.md` | Skill | 150 | Hard implementation wrapper |
| `.claude/skills/skill-orchestrate-hard/SKILL.md` | Skill | 500 | Hard orchestration state machine |
| `.claude/agents/general-research-hard-agent.md` | Agent | 200 | Hard research agent |
| `.claude/agents/planner-hard-agent.md` | Agent | 250 | Hard planning agent |
| `.claude/agents/general-implementation-hard-agent.md` | Agent | 250 | Hard implementation agent |

## Files to Modify

| File | Change | ~Lines Changed |
|------|--------|----------------|
| `.claude/scripts/command-route-skill.sh` | Add $4 effort_flag + routing_hard lookup | +25 |
| `.claude/commands/implement.md` | Pass EFFORT_FLAG to route script | +2 |
| `.claude/commands/research.md` | Replace inline routing with route script; add hard branch | +5, -35 |
| `.claude/commands/plan.md` | Replace inline routing with route script; add hard branch | +5, -35 |
| `.claude/commands/orchestrate.md` | Source parse-command-args.sh; route to hard skill | +15 |
| `.claude/context/index.json` | Add contracts/ entries + hard agent entries | +60 |
| `.claude/CLAUDE.md` | Document --hard routing in Skill-to-Agent and Command tables | +20 |

# Research Report: Establish Plan File Markers as Primary Source of Truth for Resume Points

**Task**: 535 - establish_resume_point_truth  
**Report Date**: 2026-05-07  
**Researcher**: general-research-agent  
**Status**: researched

---

## 1. Executive Summary

The current implementation resume mechanism has **two competing sources of truth** for where to resume a task:
1. **Plan file phase markers** (`[NOT STARTED]`, `[IN PROGRESS]`, `[PARTIAL]`, `[COMPLETED]`) embedded in the plan markdown.
2. **`state.json` `resume_phase` field**, an ad-hoc numeric field written by skills during postflight.

The `/implement` command currently scans plan markers to compute a `resume_phase`, passes it to the skill, but the skill may not use it. Meanwhile, skills also write `resume_phase` back to `state.json` on partial completion. When these sources diverge (e.g., Task 107: `state.json` said `resume_phase: 2` while plan showed Phase 4 `[PARTIAL]` and Phase 5 `[COMPLETED]`), agents waste tokens reconciling them and may resume from the wrong phase.

**Recommendation**: Make plan file markers the **primary** source of truth. Remove or demote `state.json` `resume_phase` to an advisory cache.

---

## 2. Current Resume Point Detection Logic

### 2.1 `/implement` Command (CHECKPOINT 1: GATE IN)

Location: `.opencode/commands/implement.md` (lines 295-303)

The command scans the latest plan file for phase status markers:

```markdown
- [NOT STARTED] → Start here
- [IN PROGRESS] → Resume here
- [COMPLETED] → Skip
- [PARTIAL] → Resume here
```

If all phases are `[COMPLETED]`, the task is considered done.

After detection, the command computes a `resume_phase` number and passes it as an argument to the skill:

```
args: "task_number={N} plan_path={path} resume_phase={phase number} ..."
```

### 2.2 How Skills Receive and Use `resume_phase`

**`skill-implementer`** (`.opencode/skills/skill-implementer/SKILL.md`):
- Accepts `resume_phase` in its invocation args (passed by `/implement`).
- **Does NOT reference `resume_phase` in its Stage 1-5 execution flow.** The skill delegates to `general-implementation-agent`, which is expected to parse the plan file itself.
- **Writes `resume_phase` to `state.json`** only in the partial postflight path (Stage 7, line 438):
  ```bash
  jq ... 'resume_phase: ($phase + 1)' specs/state.json
  ```

**`skill-lean-implementation`** (`.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`):
- Accepts `resume_phase` in delegation context (line 93).
- **Does NOT reference `resume_phase` in its Stage 1-4 execution flow.**
- **Does NOT write `resume_phase`** in its postflight (Stage 7 only handles completed/partial status without updating the field).

**Extension Skills** (`skill-neovim-implementation`, `skill-nix-implementation`, `skill-web-implementation`, `skill-founder-implement`, `skill-deck-implement`):
- All accept `resume_phase` as a parameter.
- Most do not actively use it in their pre-delegation logic; the subagent re-reads the plan.
- Several write `resume_phase` back to `state.json` on partial:
  - `skill-neovim-implementation` (`.claude/skills/skill-neovim-implementation/SKILL.md:232`)
  - `skill-nix-implementation` (`.claude/skills/skill-nix-implementation/SKILL.md:277`)
  - `skill-web-implementation` (`.opencode/extensions/web/skills/skill-web-implementation/SKILL.md:282`)

**`skill-team-implement`**:
- Accepts `resume_phase` as an input parameter (`.opencode/skills/skill-team-implement/SKILL.md:39`).
- Likely uses it to determine which wave to start, but the skill's internal logic is complex and may still re-scan the plan.

---

## 3. Example Plan Files with Phase Markers

### 3.1 Task 530 (Status Sync Fix)
`specs/archive/530_fix_opencode_status_sync/plans/01_status-sync-fix.md`

```markdown
### Phase 1: Fix Missing Postflight in skill-neovim-research [IN PROGRESS]
### Phase 2: Fix skill-neovim-implementation and skill-nix-implementation [NOT STARTED]
### Phase 3: Fix Extension Research Skills (skill-nix-research) [COMPLETED]
### Phase 4: Fix Team Skills [COMPLETED]
### Phase 5: Verification and Defensive Checks [IN PROGRESS]
```

### 3.2 Task 526 (Lean Extension Port)
`specs/archive/526_port_lean_extension_to_claude/plans/01_lean-port-plan.md`

```markdown
### Phase 1: Fix opencode-agents.json Path Bug [NOT STARTED]
### Phase 2: Backport Missing Index Entries to .opencode/ [NOT STARTED]
### Phase 3: Verify Skills, Manifest, and Cross-Reference [NOT STARTED]
### Phase 4: Final Validation and Summary [NOT STARTED]
```

These markers are the **actual ground truth** of what has been done. They are updated by the implementation subagent via `Edit` tool as it progresses through phases.

---

## 4. Relationship Between `state.json` `resume_phase` and Plan Markers

### 4.1 `resume_phase` Is Not Part of the Formal Schema

The authoritative schema reference (`.opencode/context/reference/state-management-schema.md`) documents:
- `project_number`, `project_name`, `status`, `task_type`, `effort`, `created`, `last_updated`, `dependencies`, `artifacts`, `next_artifact_number`, `completion_summary`, `roadmap_items`, `memory_candidates`.

**`resume_phase` is NOT listed.** It is an ad-hoc field added by skills.

### 4.2 How `resume_phase` Gets Set

Set during postflight when a subagent returns `partial` status:

**`skill-implementer` (Stage 7, partial path)**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson phase "$phases_completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase + 1)
  }' specs/state.json
```

**`skill-neovim-implementation`** (similar block):
```bash
resume_phase: ($phase + 1)
```

**`skill-nix-implementation`**:
```bash
resume_phase: ($phase | tonumber + 1)
```

The value is derived from `phases_completed` reported by the subagent in `.return-meta.json`, NOT from re-scanning the plan file.

### 4.3 How `resume_phase` Gets Stale

1. **Plan Revision (`/revise`)**: When a plan is revised, phase statuses may be reset or reorganized. `state.json` `resume_phase` is not automatically cleared.
2. **Manual Plan Editing**: A user or agent may manually update plan markers (e.g., marking a phase `[COMPLETED]` after a fix) without updating `state.json`.
3. **Crash Between Updates**: If a skill crashes after updating plan markers but before writing `state.json`, the two sources diverge.
4. **Subagent vs. Skill Disagreement**: The subagent may update plan markers to `[COMPLETED]` but report a different `phases_completed` count in metadata (e.g., due to off-by-one errors or wave-based execution in team mode).
5. **Task 107 Example**: `state.json` reported `resume_phase: 2`, but the plan file showed Phase 4 as `[PARTIAL]` and Phase 5 as `[COMPLETED]`. The agent had to reason about which source to trust, wasting tokens.

---

## 5. Proposed Mechanism: Plan Markers as Primary Source of Truth

### 5.1 Core Principle

> **Plan file phase status markers are the single source of truth for resume points.** `state.json` `resume_phase` becomes an advisory secondary cache. When sources disagree, plan markers win and a warning is logged.

### 5.2 Required Changes

#### A. Update `/implement` Command Specification

In `.opencode/commands/implement.md`:
1. Add an explicit declaration in CHECKPOINT 1:
   > "Plan file markers are the PRIMARY source of truth for resume points. `state.json` `resume_phase` is advisory."
2. Add a comparison step before delegation:
   - Scan plan for resume point → `plan_resume_phase`.
   - Read `state.json` `resume_phase` → `state_resume_phase`.
   - If they differ by more than 1 phase: log a warning, use `plan_resume_phase`, and optionally clear the stale `state_resume_phase`.

#### B. Update Skills to Ignore `resume_phase` Parameter

For `skill-implementer` and all extension implementation skills:
1. Remove `resume_phase` from the delegation context JSON passed to subagents, OR pass it with a documented advisory status.
2. Update subagent prompts to instruct them to **scan the plan file for markers** to find the resume point.
3. Remove the `resume_phase` update logic from postflight partial paths.

#### C. Update Subagent Definitions

For `general-implementation-agent`, `lean-implementation-agent`, `neovim-implementation-agent`, etc.:
1. Update their prompt instructions to state:
   > "To determine where to resume, scan the plan file for phase status markers. Do not rely on `resume_phase` from state.json."

#### D. Optionally Deprecate `resume_phase` in `state.json`

Two options:

**Option 1 (Recommended)**: Remove `resume_phase` entirely.
- Delete all jq blocks that write `resume_phase`.
- Remove the field from `state.json` entries.
- Update any validation scripts.

**Option 2**: Keep as advisory cache.
- Rename to `advisory_resume_phase`.
- Document clearly that it is NOT authoritative.
- Still remove the comparison logic from skills.

### 5.3 Impact Assessment

| Component | Change Required | Effort |
|-----------|----------------|--------|
| `.opencode/commands/implement.md` | Add primary-source declaration + comparison logic | Low |
| `skill-implementer` | Remove `resume_phase` from postflight; update delegation context | Low |
| `skill-lean-implementation` | Remove `resume_phase` from delegation context | Low |
| `skill-neovim-implementation` | Remove `resume_phase` postflight update | Low |
| `skill-nix-implementation` | Remove `resume_phase` postflight update | Low |
| `skill-web-implementation` | Remove `resume_phase` postflight update | Low |
| `skill-founder-implement` | Remove `resume_phase` usage | Low |
| `skill-deck-implement` | Remove `resume_phase` usage | Low |
| `skill-team-implement` | Review wave-start logic; may still need a hint | Medium |
| `state-management-schema.md` | Remove or deprecate `resume_phase` | Low |
| Agent definitions | Update prompts to scan plan markers | Low |

**Total Estimated Effort**: 1-2 hours (matches task estimate).

### 5.4 Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Subagents rely on `resume_phase` parameter | High | Update agent prompts to mandate plan scanning; test with a partial implementation |
| `skill-team-implement` uses `resume_phase` for wave scheduling | Medium | Review team skill logic; if needed, compute wave start from plan markers instead |
| Breaking existing tasks with stale `resume_phase` | Low | Since plan markers win, stale values are ignored; no breakage |
| Missing a jq block somewhere | Medium | Use `rg "resume_phase"` across all skills and commands to audit |

---

## 6. Audit of `resume_phase` References

A grep across the codebase found `resume_phase` in:

**Commands**:
- `.opencode/commands/implement.md` (3 references in args templates)
- `.opencode/extensions/core/commands/implement.md` (3 references)

**Skills (postflight writes)**:
- `.opencode/skills/skill-implementer/SKILL.md:438`
- `.claude/skills/skill-implementer/SKILL.md:438`
- `.claude/skills/skill-neovim-implementation/SKILL.md:232`
- `.claude/skills/skill-nix-implementation/SKILL.md:277`
- `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md:228`
- `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md:214`
- `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md:282`
- `.opencode/extensions/core/skills/skill-implementer/SKILL.md:438`
- `.opencode/extensions/core/context/patterns/inline-status-update.md:155`

**Skills (parameter acceptance)**:
- `.opencode/skills/skill-team-implement/SKILL.md:39`
- `.claude/skills/skill-team-implement/SKILL.md:39`
- `.opencode/extensions/core/skills/skill-team-implement/SKILL.md:39`
- `.opencode/extensions/present/skills/skill-slide-planning/SKILL.md:45`
- `.opencode/extensions/founder/skills/skill-deck-implement/SKILL.md:50`
- `.opencode/extensions/founder/skills/skill-founder-implement/SKILL.md:49`

**Agent definitions / context**:
- `.opencode/extensions/founder/agents/deck-builder-agent.md:82`
- `.opencode/extensions/founder/agents/founder-implement-agent.md:94,1525,1561`
- `.opencode/extensions/core/context/validation.md:28`
- `.opencode/extensions/core/context/processes/implementation-workflow.md:374`

**Historical data**:
- `specs/archive/state.json` (multiple entries with `resume_phase: N`)

All of the above should be reviewed and updated as part of the implementation.

---

## 7. Conclusion

The current dual-source design is fragile and has already caused real issues (Task 107). Plan file markers are inherently more reliable because:
- They are updated **in-place** by the subagent as it works.
- They are **human-readable** and easily verifiable.
- They survive plan revisions and manual edits.
- They do not require a secondary write to `state.json` that can fail or get stale.

Making plan markers the primary source of truth is a low-effort, high-reliability improvement that aligns with the system's existing checkpoint-based execution model.

**Next Step**: Proceed to implementation planning for Task 535.

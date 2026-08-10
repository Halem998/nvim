# Implementation Plan: Task #767

- **Task**: 767 - Make --hard mode a first-class CORE capability
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None (foundational; tasks 768, 769, 770 depend on this)
- **Research Inputs**: specs/767_core_hard_mode_first_class/reports/01_core-hard-mode-first-class.md
- **Artifacts**: plans/01_core-hard-mode-first-class.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan promotes the hard-mode capability to a first-class part of the core extension source
tree at `.claude/extensions/core/`. Today the 3 hard agents and the `skill-orchestrate-hard`
skill live only in the deployed `.claude/` tree (real files, not authored into core source), the
3 existing hard skills are not listed in the manifest, and there is no `routing_hard` section.
The plan copies the agent/skill files into the canonical source (fixing one hardcoded absolute
path), then updates `core/manifest.json` to declare the new agents, skills, and a forward-looking
`routing_hard` section mirroring the cslib schema. Each phase is sized to a single agent run and
ends with mechanical verification (file-existence checks, jq array membership assertions, JSON
well-formedness, and a doc-lint run).

### Research Integration

The research report (`01_core-hard-mode-first-class.md`) provides exact file inventories, the
cslib/lean `routing_hard` JSON schema, hard agent frontmatter details, and identifies the single
portability fix needed. Key facts integrated into this plan:
- 3 hard agents are missing from core source; copy them verbatim (Finding 1, 6).
- 3 hard skills already exist in core source with identical content; only manifest listing is
  needed (Finding 2). `skill-orchestrate-hard` must be authored from the deployed copy (Finding 5).
- `general-implementation-hard-agent.md` has the absolute path
  `bash /home/benjamin/.config/nvim/.claude/scripts/update-phase-status.sh` at 3 locations
  (verified: lines 126, 142, 180 in the deployed file) — change to `bash .claude/scripts/...`
  (Risk 1, Appendix).
- `routing_hard` for core covers general/meta/markdown across research/plan/implement (Finding 7).
- This task only needs the DECLARATIONS to be present and well-formed; routing RESOLUTION is
  task 768 (Finding 4, 8). Re-deployment is task 770 (Decision 6).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found / no roadmap context provided in delegation.

## Goals & Non-Goals

**Goals**:
- Copy the 3 hard agent files into `.claude/extensions/core/agents/` verbatim, fixing the
  hardcoded absolute path in `general-implementation-hard-agent.md` (in both the core source copy
  and the deployed file so they stay in lockstep).
- Author `skill-orchestrate-hard/SKILL.md` into `.claude/extensions/core/skills/` verbatim from
  the deployed copy.
- Add the 3 hard agents to `provides.agents` in `core/manifest.json`.
- Add the 4 hard skills to `provides.skills` in `core/manifest.json`.
- Add a well-formed `routing_hard` section to `core/manifest.json` covering general/meta/markdown
  x research/plan/implement.
- Verify all changes mechanically (file existence, jq membership, JSON validity, doc-lint).

**Non-Goals**:
- Implementing `routing_hard` RESOLUTION machinery in `command-route-skill.sh` or the
  research/plan/implement commands (that is task 768).
- Adding validation tooling for hard agents / routing_hard consistency (task 769).
- Re-deploying the core extension or syncing docs to the deployed tree beyond the single path fix
  required for lockstep (task 770).
- Modifying behavioral content of any copied agent/skill beyond the portability path fix.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Absolute path in general-implementation-hard-agent.md breaks portability | M | H | Replace all 3 occurrences with `bash .claude/scripts/...` in both source copy and deployed file; verify zero remaining matches via grep |
| Content drift between deployed and core source copies | M | M | Copy verbatim (only the path fix differs); after fix, diff source vs deployed should show only path lines |
| Malformed JSON when editing manifest by hand | H | M | Use jq for all manifest edits; validate with `jq empty` after each edit |
| routing_hard placed inconsistently (core has no `routing` key) | L | M | Add `routing_hard` as a new top-level key alongside existing keys; mirror cslib's exact value shape |
| Skill subdir authored without correct frontmatter | M | L | Copy SKILL.md byte-for-byte; verify frontmatter `name: skill-orchestrate-hard` present |
| Tasks 768-770 dispatched before 767 fully complete | M | L | Orchestrator handoff JSON clearly reports `planned`/completion status and blockers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint file sets
(agents/ vs skills/) and may run concurrently; Phase 3 (manifest) depends on the files existing;
Phase 4 (verification) depends on all prior phases.

---

### Phase 1: Copy Hard Agents into Core Source [COMPLETED]

**Goal**: Place the 3 hard agent files into `.claude/extensions/core/agents/` verbatim, with the
absolute-path portability fix applied to `general-implementation-hard-agent.md` (in both the new
source copy and the deployed file).

**Tasks**:
- [ ] Copy `.claude/agents/general-research-hard-agent.md` to
      `.claude/extensions/core/agents/general-research-hard-agent.md` verbatim
- [ ] Copy `.claude/agents/planner-hard-agent.md` to
      `.claude/extensions/core/agents/planner-hard-agent.md` verbatim
- [ ] Copy `.claude/agents/general-implementation-hard-agent.md` to
      `.claude/extensions/core/agents/general-implementation-hard-agent.md`
- [ ] In the new core-source `general-implementation-hard-agent.md`, replace all 3 occurrences of
      `bash /home/benjamin/.config/nvim/.claude/scripts/update-phase-status.sh` with
      `bash .claude/scripts/update-phase-status.sh`
- [ ] Apply the same path replacement to the deployed
      `.claude/agents/general-implementation-hard-agent.md` (lockstep, per Risk 1)

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/agents/general-research-hard-agent.md` - new file (verbatim copy)
- `.claude/extensions/core/agents/planner-hard-agent.md` - new file (verbatim copy)
- `.claude/extensions/core/agents/general-implementation-hard-agent.md` - new file (copy + path fix)
- `.claude/agents/general-implementation-hard-agent.md` - existing deployed file (path fix only)

**Verification**:
- All 3 files exist in `.claude/extensions/core/agents/` (test -f each)
- Frontmatter `name:` field correct in each copied file
  (`general-research-hard-agent`, `planner-hard-agent`, `general-implementation-hard-agent`)
- `grep -c "home/benjamin/.config/nvim/.claude/scripts" .claude/extensions/core/agents/general-implementation-hard-agent.md`
  returns 0
- `grep -c "home/benjamin/.config/nvim/.claude/scripts" .claude/agents/general-implementation-hard-agent.md`
  returns 0
- `grep -c "bash .claude/scripts/update-phase-status.sh" .claude/extensions/core/agents/general-implementation-hard-agent.md`
  returns 3
- `diff` of source vs deployed for the 2 unchanged agents shows no differences

---

### Phase 2: Author skill-orchestrate-hard into Core Source [COMPLETED]

**Goal**: Create `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` as a verbatim
copy of the deployed `.claude/skills/skill-orchestrate-hard/SKILL.md`.

**Tasks**:
- [ ] Create directory `.claude/extensions/core/skills/skill-orchestrate-hard/`
- [ ] Copy `.claude/skills/skill-orchestrate-hard/SKILL.md` to
      `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` verbatim
- [ ] Confirm no other files exist alongside the deployed SKILL.md that also need copying
      (the deployed dir is expected to contain only SKILL.md; copy any additional files found)

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - new file (verbatim copy)

**Verification**:
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` exists (test -f)
- `diff .claude/skills/skill-orchestrate-hard/SKILL.md .claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  shows no differences
- Frontmatter contains `name: skill-orchestrate-hard`
- File listing of deployed `skill-orchestrate-hard/` matches the new source dir (no missed files)

---

### Phase 3: Update core/manifest.json Declarations [COMPLETED]

**Goal**: Add the 3 hard agents to `provides.agents`, the 4 hard skills to `provides.skills`, and
a new `routing_hard` top-level section covering general/meta/markdown across all three operations.
All edits performed with jq to guarantee valid JSON.

**Tasks**:
- [ ] Add to `provides.agents` (preserving existing 8 entries):
      `general-research-hard-agent.md`, `general-implementation-hard-agent.md`,
      `planner-hard-agent.md`
- [ ] Add to `provides.skills` (preserving existing 19 entries):
      `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`,
      `skill-orchestrate-hard`
- [ ] Add a top-level `routing_hard` key with the schema below (mirroring cslib's 3-operation
      shape)
- [ ] Validate JSON well-formedness after each edit (`jq empty core/manifest.json`)

**routing_hard to add** (from research Finding 7):
```json
"routing_hard": {
  "research": {
    "general": "skill-researcher-hard",
    "meta": "skill-researcher-hard",
    "markdown": "skill-researcher-hard"
  },
  "plan": {
    "general": "skill-planner-hard",
    "meta": "skill-planner-hard",
    "markdown": "skill-planner-hard"
  },
  "implement": {
    "general": "skill-implementer-hard",
    "meta": "skill-implementer-hard",
    "markdown": "skill-implementer-hard"
  }
}
```

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Files to modify**:
- `.claude/extensions/core/manifest.json` - add agent entries, skill entries, routing_hard section

**Verification**:
- `jq empty .claude/extensions/core/manifest.json` exits 0 (valid JSON)
- `jq -e '.provides.agents | index("general-research-hard-agent.md")'` non-null; same for the
  other 2 hard agents
- `jq -e '.provides.skills | index("skill-orchestrate-hard")'` non-null; same for the other 3
  hard skills
- `jq -e '.routing_hard.research.general == "skill-researcher-hard"'` true
- `jq -e '.routing_hard.plan.meta == "skill-planner-hard"'` true
- `jq -e '.routing_hard.implement.markdown == "skill-implementer-hard"'` true
- `jq '.provides.agents | length'` returns 11; `jq '.provides.skills | length'` returns 23
- Each skill listed in `provides.skills` for hard mode has a corresponding directory under
  `.claude/extensions/core/skills/`

---

### Phase 4: Validate and Doc-Lint [COMPLETED]

**Goal**: Run end-to-end mechanical validation that all declarations are present, well-formed, and
internally consistent, then run the extension doc-lint to confirm no regressions.

**Tasks**:
- [ ] Re-run all Phase 1-3 verification assertions as a single consolidated check
- [ ] For each entry in `provides.agents`, assert the corresponding file exists in
      `.claude/extensions/core/agents/`
- [ ] For each entry in `provides.skills`, assert the corresponding directory exists in
      `.claude/extensions/core/skills/`
- [ ] For each skill referenced in `routing_hard`, assert it appears in `provides.skills`
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm exit code 0 (or that any
      reported issues are pre-existing and unrelated to this task's changes)

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:
- None (verification only; if doc-lint flags a manifest/README cross-reference gap introduced by
  this task, fix the offending file)

**Verification**:
- Consolidated jq + filesystem cross-check script passes (every provides entry has a backing
  file/dir; every routing_hard skill is in provides.skills)
- `bash .claude/scripts/check-extension-docs.sh` exits 0, or any non-zero exit is demonstrably
  attributable to pre-existing issues unrelated to task 767 (documented in the summary)

## Testing & Validation

- [ ] 3 hard agent files present in `.claude/extensions/core/agents/` with correct frontmatter
- [ ] Zero absolute-path references remain in either copy of general-implementation-hard-agent.md
- [ ] `skill-orchestrate-hard/SKILL.md` present in core source, identical to deployed
- [ ] `core/manifest.json` is valid JSON (`jq empty`)
- [ ] `provides.agents` includes all 3 hard agents (length 11)
- [ ] `provides.skills` includes all 4 hard skills (length 23)
- [ ] `routing_hard` present and well-formed for general/meta/markdown x research/plan/implement
- [ ] Every routing_hard skill reference exists in provides.skills
- [ ] `check-extension-docs.sh` passes (or only pre-existing failures)

## Artifacts & Outputs

- `.claude/extensions/core/agents/general-research-hard-agent.md` (new)
- `.claude/extensions/core/agents/planner-hard-agent.md` (new)
- `.claude/extensions/core/agents/general-implementation-hard-agent.md` (new, path-fixed)
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (new)
- `.claude/extensions/core/manifest.json` (updated: provides.agents, provides.skills, routing_hard)
- `.claude/agents/general-implementation-hard-agent.md` (updated: path fix for lockstep)
- `specs/767_core_hard_mode_first_class/.orchestrator-handoff.json` (updated at implementation
  completion)

## Rollback/Contingency

All changes are additive to the extension source plus one in-place path edit. To revert:
- `git checkout .claude/extensions/core/manifest.json` restores the manifest.
- `git checkout .claude/agents/general-implementation-hard-agent.md` restores the deployed file.
- Remove the newly created files under `.claude/extensions/core/agents/` (3 files) and
  `.claude/extensions/core/skills/skill-orchestrate-hard/`.
Because no resolution machinery reads core `routing_hard` yet (task 768), incomplete or reverted
changes here have no runtime effect on existing commands; the deployed tree continues to function.

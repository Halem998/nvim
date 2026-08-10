# Research Report: Task #767

**Task**: 767 - Make --hard mode a first-class CORE capability
**Started**: 2026-06-24T00:00:00Z
**Completed**: 2026-06-24T01:00:00Z
**Effort**: ~1 hour
**Dependencies**: None (foundational; 768, 769, 770 depend on this)
**Sources/Inputs**: Codebase (deployed tree, extension source tree, scripts)
**Artifacts**: specs/767_core_hard_mode_first_class/reports/01_core-hard-mode-first-class.md
**Standards**: report-format.md

---

## Executive Summary

- Three hard agent files exist only in the deployed `.claude/agents/` tree — NOT in the canonical
  extension source `.claude/extensions/core/agents/`; they must be copied (not symlinked) into
  source.
- Three hard skills (`skill-implementer-hard`, `skill-planner-hard`, `skill-researcher-hard`)
  already exist in `.claude/extensions/core/skills/` with content identical to their deployed
  counterparts — they just need to be listed in `provides.skills` in `core/manifest.json`.
- `skill-orchestrate-hard` does NOT exist in the core extension source; it exists only as a real
  file in `.claude/skills/skill-orchestrate-hard/`. It must be authored into
  `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` and then listed in
  `provides.skills`.
- Zero `provides.agents` entries for hard agents; zero `provides.skills` entries for hard skills;
  no `routing_hard` section exists in `core/manifest.json` — all three need to be added.
- The routing_hard schema follows cslib's pattern (research/plan/implement, each keyed by
  task_type), and should map general/meta/markdown to their respective hard skills.

---

## Context & Scope

This task targets the canonical extension source tree at
`/home/benjamin/.config/nvim/.claude/extensions/core/`. The goal is to make the hard-mode
capability (agents + skills) a first-class citizen of the core extension — so any project that
installs the core extension gets hard mode automatically. Currently hard-mode pieces were deployed
directly to the `.claude/` tree without being tracked in the extension source, which means they
are invisible to the extension install mechanism and won't propagate to new installations.

**Key architectural fact**: The core extension works differently from all other extensions.
Non-core extensions (cslib, lean, nix, nvim, etc.) install by creating symlinks:
`.claude/skills/skill-X -> ../extensions/EXT/skills/skill-X`. Core extension skills and agents
are real files in `.claude/skills/` and `.claude/agents/` respectively — the core extension IS
the deployed tree. Therefore "authoring into core source" means physically placing files in
`.claude/extensions/core/agents/` and `.claude/extensions/core/skills/`, and listing them in
`manifest.json` so the manifest-based deployment tooling recognizes them. When the core extension
is re-deployed (e.g., synced to another machine), the `provides.agents` and `provides.skills`
arrays drive what gets included.

---

## Findings

### 1. Exact File Inventory: Hard Agents

**Extension source** (`.claude/extensions/core/agents/`):
```
code-reviewer-agent.md
general-implementation-agent.md
general-research-agent.md
meta-builder-agent.md
planner-agent.md
README.md
reviser-agent.md
spawn-agent.md
synthesis-agent.md
```
**Missing from core source (present only in deployed `.claude/agents/`)**:
- `general-implementation-hard-agent.md`
- `general-research-hard-agent.md`
- `planner-hard-agent.md`

**Deployed `.claude/agents/`** (non-symlink files):
All 9 core source agents above, PLUS the 3 missing hard agents, PLUS
`neovim-implementation-agent.md` and `neovim-research-agent.md` (real files, owned by nvim
extension but content-identical to `extensions/nvim/agents/`).

The 3 hard agent files in `.claude/agents/` are REAL FILES (not symlinks). They were
hand-placed directly in the deployed tree without being authored into the core source.

### 2. Exact File Inventory: Hard Skills

**Extension source** (`.claude/extensions/core/skills/`):
```
skill-fix-it/
skill-git-workflow/
skill-implementer/
skill-implementer-hard/       <- exists in source
skill-meta/
skill-orchestrate/
skill-orchestrator/
skill-planner/
skill-planner-hard/           <- exists in source
skill-project-overview/
skill-refresh/
skill-researcher/
skill-researcher-hard/        <- exists in source
skill-reviser/
skill-spawn/
skill-status-sync/
skill-tag/
skill-team-implement/
skill-team-plan/
skill-team-research/
skill-todo/
skill-zulip/
```
**Missing from core source**:
- `skill-orchestrate-hard/`  <- NOT in source, IS in deployed tree

**Deployed `.claude/skills/`** (non-symlink directories — all core skills):
All core source skills above, PLUS `skill-orchestrate-hard/`, PLUS symlinks from cslib, lean,
nvim, nix, literature, zotero extensions.

**Content verification**: The 3 hard skills that do exist in core source (`skill-implementer-hard`,
`skill-planner-hard`, `skill-researcher-hard`) have content IDENTICAL to their deployed
counterparts (verified by md5sum). The deployed files are real directories, not symlinks.

### 3. Current core/manifest.json: What Is Missing

Current `provides.agents` (8 entries):
```json
[
  "code-reviewer-agent.md",
  "general-implementation-agent.md",
  "general-research-agent.md",
  "meta-builder-agent.md",
  "planner-agent.md",
  "reviser-agent.md",
  "spawn-agent.md",
  "synthesis-agent.md"
]
```
**Missing (3)**:
- `"general-implementation-hard-agent.md"`
- `"general-research-hard-agent.md"`
- `"planner-hard-agent.md"`

Current `provides.skills` (19 entries, partial):
```json
[
  "skill-fix-it",
  "skill-git-workflow",
  "skill-implementer",
  "skill-meta",
  "skill-orchestrate",
  "skill-orchestrator",
  "skill-planner",
  "skill-refresh",
  "skill-researcher",
  "skill-reviser",
  "skill-spawn",
  "skill-status-sync",
  "skill-tag",
  "skill-team-implement",
  "skill-team-plan",
  "skill-team-research",
  "skill-todo",
  "skill-zulip",
  "skill-project-overview"
]
```
**Missing (4)**:
- `"skill-implementer-hard"`
- `"skill-orchestrate-hard"`
- `"skill-planner-hard"`
- `"skill-researcher-hard"`

There is currently **no `routing_hard` section** in `core/manifest.json`.

### 4. How lean and cslib Declare Hard Agents, Hard Skills, and routing_hard

**Lean manifest** (`.claude/extensions/lean/manifest.json`):
```json
"provides": {
  "agents": [
    "lean-research-agent.md",
    "lean-implementation-agent.md",
    "lean-research-hard-agent.md",
    "lean-implementation-hard-agent.md"
  ],
  "skills": [
    "skill-lean-research",
    "skill-lean-implementation",
    "skill-lake-repair",
    "skill-lean-version",
    "skill-lean-research-hard",
    "skill-lean-implementation-hard"
  ]
},
"routing_hard": {
  "research": {
    "lean4": "skill-lean-research-hard"
  },
  "implement": {
    "lean4": "skill-lean-implementation-hard"
  }
}
```
Note: lean only declares research + implement in routing_hard (not plan), because lean uses
the base `skill-planner` for all lean tasks including hard mode.

**CSLib manifest** (`.claude/extensions/cslib/manifest.json`):
```json
"provides": {
  "agents": [
    "cslib-research-agent.md",
    "cslib-implementation-agent.md",
    "cslib-research-hard-agent.md",
    "cslib-implementation-hard-agent.md",
    "pr-review-research-agent.md",
    "pr-review-implementation-agent.md",
    "cslib-vet-agent.md"
  ],
  "skills": [
    "skill-cslib-research",
    "skill-cslib-implementation",
    "skill-pr-implementation",
    "skill-cslib-research-hard",
    "skill-cslib-implementation-hard",
    "skill-pr-review-research",
    "skill-pr-review-implementation",
    "skill-cslib-vet"
  ]
},
"routing_hard": {
  "research": {
    "cslib": "skill-cslib-research-hard",
    "pr": "skill-researcher-hard"
  },
  "plan": {
    "cslib": "skill-planner-hard",
    "pr": "skill-planner-hard"
  },
  "implement": {
    "cslib": "skill-cslib-implementation-hard",
    "pr": "skill-implementer-hard"
  }
}
```
Note: cslib declares all three operations in routing_hard (research, plan, implement).

**Schema shape**: `routing_hard` is a top-level object alongside `routing`, with keys
`"research"`, `"plan"`, `"implement"` (same operations as `routing`). Values are
`{ "task_type": "skill-name" }` maps, identical to the `routing` schema.

**Primary consumer**: `skill-orchestrate-hard/SKILL.md` reads `routing_hard` from extension
manifests (Stage 1b). The `/research --hard`, `/plan --hard`, `/implement --hard` commands do
NOT currently read `routing_hard` — they pass `effort_flag="hard"` as context to the resolved
standard skill, which in turn routes to the hard agent internally. Adding `routing_hard` to
core manifest is preparation for the routing infrastructure task (768) which will wire the
commands to actually use `routing_hard` for non-orchestrate hard routing.

### 5. skill-orchestrate-hard: Core Source vs Deployed

**Core source**: `skill-orchestrate-hard/` does NOT exist in
`.claude/extensions/core/skills/`. Only `skill-orchestrate/` is present.

**Deployed file**: `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate-hard/SKILL.md`
- File size: 19,588 bytes
- Created: Jun 12 10:35
- This is a REAL FILE (not a symlink)
- Frontmatter:
  ```
  ---
  name: skill-orchestrate-hard
  description: Full structural hard-mode orchestration state machine with per-phase dispatch (H1),
    adversarial verification (H4), convergence policing (H6), territory contracts (H7), and
    churn detection (H5). Invoke for /orchestrate --hard.
  allowed-tools: Agent, Bash, Read, Edit
  ---
  ```
- This is a FULL STRUCTURAL VARIANT, not a wrapper. It contains ~450 lines of bash-style
  pseudocode covering the full hard-mode orchestration loop (H1-H9 contracts).
- It references routing_hard from extension manifests at Stage 1b for agent resolution.
- Currently NOT symlinked to any extension source.

**Action required**: Copy the deployed `skill-orchestrate-hard/SKILL.md` verbatim into
`.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.

### 6. Hard Agent File Contents (for verbatim move)

#### general-research-hard-agent.md
- **Frontmatter**:
  - `name: general-research-hard-agent`
  - `description: Research general tasks using web search and codebase exploration with hard-mode behavioral contracts`
  - `model: sonnet`
- **Path assumptions**: References `@.claude/context/contracts/anti-analysis.md`,
  `@.claude/context/contracts/reference-grounding.md` (these context files already exist in
  the deployed tree; they need to be verified in extension source or deployed context)
- **File size**: 9,415 bytes
- **No path-specific assumptions** beyond standard `.claude/` context references that use
  `@` prefix (lazy-loaded, not hardcoded paths)

#### general-implementation-hard-agent.md
- **Frontmatter**:
  - `name: general-implementation-hard-agent`
  - `description: Implement general, meta, and markdown tasks from plans with hard-mode behavioral contracts`
  - `model: sonnet`
- **Path assumptions**: References `@.claude/context/contracts/anti-analysis.md`,
  `@.claude/context/contracts/wrap-up.md`, `@.claude/context/contracts/territory.md`,
  `@.claude/context/formats/handoff-artifact.md`, `@.claude/context/formats/progress-file.md`
- **One hardcoded path**: Stage 4A uses
  `bash /home/benjamin/.config/nvim/.claude/scripts/update-phase-status.sh` — this is an
  absolute path that will need to be changed to a relative path or `bash .claude/scripts/...`
  for portability
- **File size**: 11,256 bytes

#### planner-hard-agent.md
- **Frontmatter**:
  - `name: planner-hard-agent`
  - `description: Create phased implementation plans with hard-mode behavioral contracts for complex, deflection-prone tasks`
  - `model: opus`
- **Path assumptions**: References `@.claude/context/contracts/reference-grounding.md`,
  `@.claude/context/workflows/task-breakdown.md`
- **File size**: 9,401 bytes
- **No hardcoded absolute paths**

### 7. routing_hard Schema for Core Task Types

Based on cslib's pattern (research + plan + implement, all three operations), the core
`routing_hard` should cover `general`, `meta`, and `markdown` across all three operations:

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

**Rationale**: core task types (`general`, `meta`, `markdown`) all use the same base hard
agents (general-research-hard, planner-hard, general-implementation-hard) since these task
types have no domain-specific hard variants. This mirrors how the base `routing` maps them:
`general`/`meta`/`markdown` → `skill-researcher`/`skill-planner`/`skill-implementer`
respectively (via fallback since no routing entries exist for them in the current core manifest).

**Note**: The `routing_hard` for core is somewhat forward-looking — the resolution machinery
that reads it for `/research --hard`, `/plan --hard`, `/implement --hard` commands is not yet
built (that is task 768). However, `skill-orchestrate-hard` already reads it.

### 8. Key Architectural Finding: How Hard Routing Currently Works

The current routing path for `--hard` on standard commands is:
1. `/research N --hard` → parses `effort_flag="hard"` → calls `skill-researcher` with
   `effort_flag` in args
2. `skill-researcher` receives `effort_flag="hard"` → passes it as "prompt context for
   reasoning depth guidance" to `general-research-agent`

**The hard agent is NOT used for `/research --hard` on core tasks right now.** The `--hard`
flag is treated as a soft guidance hint to the standard agent, not a routing decision.

By contrast, `/orchestrate N --hard` → routes to `skill-orchestrate-hard` → which does read
`routing_hard` manifests to select the correct hard research/implement agents for each cycle.

This gap is what tasks 767+768 are addressing. Task 767 establishes the canonical source
(agents + skills in core extension). Task 768 will implement the routing_hard resolution in
`command-route-skill.sh` and the research/plan/implement commands.

---

## Decisions

1. **Move hard agents verbatim**: Copy all 3 hard agent `.md` files from `.claude/agents/` into
   `.claude/extensions/core/agents/` without modification, except fixing the absolute path in
   `general-implementation-hard-agent.md`.

2. **Author skill-orchestrate-hard into core source**: Copy the deployed
   `.claude/skills/skill-orchestrate-hard/SKILL.md` into
   `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` verbatim.

3. **Update provides.agents**: Add 3 hard agent entries to `core/manifest.json`.

4. **Update provides.skills**: Add 4 hard skill entries to `core/manifest.json`
   (the 3 existing in source + skill-orchestrate-hard after authoring).

5. **Add routing_hard**: Follow cslib's 3-operation schema covering general/meta/markdown.

6. **No re-deployment needed in task 767**: The plan should only modify the extension source
   and manifest. Task 770 handles re-deploying core and syncing docs.

---

## Risks & Mitigations

1. **Absolute path in general-implementation-hard-agent.md**: The script reference
   `bash /home/benjamin/.config/nvim/.claude/scripts/update-phase-status.sh` is hardcoded.
   Mitigation: Change to `bash .claude/scripts/update-phase-status.sh` (relative) in the
   core source copy, and also fix the deployed file to match.

2. **Content drift**: The 3 hard skills in core source are currently identical to deployed.
   The skill-orchestrate-hard copy must be taken from the deployed tree (canonical). Future
   maintenance: both must evolve in lockstep.

3. **Ordering of tasks 768/769/770**: Task 767 is foundational. Tasks 768-770 depend on the
   manifest changes made here being complete. If 767 is incomplete, 768 cannot implement
   routing_hard resolution correctly. The orchestrator handoff must clearly indicate success.

4. **No validation tooling yet**: `validate-wiring.sh` does not currently check hard agents
   or routing_hard consistency. Task 769 adds that guard. Until 769 is complete, the correctness
   of the manifest additions is not mechanically verified.

---

## Context Extension Recommendations

- **Topic**: Hard-mode architecture documentation
- **Gap**: No dedicated context file explaining the full hard-mode routing pipeline end-to-end
  (from `--hard` flag → command → skill → agent → routing_hard manifest → agent selection)
- **Recommendation**: Create `.claude/context/guides/hard-mode-routing.md` documenting the
  routing pipeline, routing_hard schema, and the relationship between routing and routing_hard.

---

## Appendix

### File Diffs Summary

| Item | Core Source | Deployed | Action |
|------|-------------|----------|--------|
| general-research-hard-agent.md | MISSING | Real file | Copy to core source |
| general-implementation-hard-agent.md | MISSING | Real file (has abs. path) | Copy to core source, fix path |
| planner-hard-agent.md | MISSING | Real file | Copy to core source |
| skill-implementer-hard/ | EXISTS (content identical) | Real dir | List in provides.skills |
| skill-planner-hard/ | EXISTS (content identical) | Real dir | List in provides.skills |
| skill-researcher-hard/ | EXISTS (content identical) | Real dir | List in provides.skills |
| skill-orchestrate-hard/ | MISSING | Real dir (19,588 bytes) | Author into core source, list |
| routing_hard in manifest | ABSENT | N/A | Add section |
| hard agents in provides.agents | 0 of 3 listed | N/A | Add 3 entries |
| hard skills in provides.skills | 0 of 4 listed | N/A | Add 4 entries |

### routing_hard Schema Reference

From cslib manifest (authoritative reference):
```json
"routing_hard": {
  "research": { "task_type": "skill-name" },
  "plan": { "task_type": "skill-name" },
  "implement": { "task_type": "skill-name" }
}
```

From lean manifest (research + implement only — lean uses base planner):
```json
"routing_hard": {
  "research": { "lean4": "skill-lean-research-hard" },
  "implement": { "lean4": "skill-lean-implementation-hard" }
}
```

### Absolute Path That Needs Fixing

In `general-implementation-hard-agent.md`, Stage 4A and Stage 5a:
```bash
# CURRENT (deployed):
bash /home/benjamin/.config/nvim/.claude/scripts/update-phase-status.sh ...

# REQUIRED (portable, for core source copy):
bash .claude/scripts/update-phase-status.sh ...
```
This same fix should be applied to the deployed file if it hasn't been already.

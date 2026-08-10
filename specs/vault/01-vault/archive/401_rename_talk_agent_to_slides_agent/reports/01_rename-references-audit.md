---
title: "Rename talk-agent to slides-agent: Reference Audit"
task: 401
date: 2026-04-10
status: researched
type: research
---

# Research Report: Task #401 - Rename talk-agent to slides-agent

**Task**: 401 - rename_talk_agent_to_slides_agent
**Started**: 2026-04-10
**Completed**: 2026-04-10
**Effort**: S (1-2 hours)
**Dependencies**: None
**Sources/Inputs**: Codebase grep/read over `.claude/extensions/present/`, top-level `.claude/context/`, top-level `.claude/` docs
**Artifacts**: specs/401_rename_talk_agent_to_slides_agent/reports/01_rename-references-audit.md
**Standards**: report-format.md

## Executive Summary

- The `/slides` command file was previously renamed from `talk.md` (per README/slides.md comments), but four other layers of "talk" naming remain: the agent file (`talk-agent.md`), the skill directory (`skill-talk/`), the task subtype key (`talk` / `present:talk`), and the opencode subagent key (`talk`).
- Identifier `talk` appears in **8 active files** (present extension + 1 top-level reference file); all other occurrences are in `specs/` history (reports, plans, archives) which are historical records and must NOT be modified.
- The rename is fully mechanical: two file-path renames (`agents/talk-agent.md` -> `agents/slides-agent.md`, `skills/skill-talk/` -> `skills/skill-slides/`) plus textual substitutions. One JSON structural change in `opencode-agents.json` (rename the `talk` subagent key to `slides`).
- Semantic "talk" (English noun: "research talk", "give a talk", "academic talks") must be preserved. The rename only targets **identifier** tokens: `talk-agent`, `skill-talk`, `/talk`, `"present:talk"`, `task_type: "talk"`, opencode `talk` key, and the agent file name.
- Library paths (`context/project/present/talk/...`, `talk-structure.md`, `talk/patterns/*.json`, `talk/contents/*`) are an **intentionally preserved data layer** per task 399's documented scope boundary. They should remain untouched unless the user explicitly expands scope. This report flags them as "preserve" and recommends the planner confirm scope with the user.
- One pre-existing bug discovered in `skill-talk/SKILL.md:95` (tautological validation `task_type != "present" || task_type != "talk"` mixing two fields into one variable) — cosmetic but should be noted for plan phase.

## Context & Scope

### In Scope (identifier rename)
- `.claude/extensions/present/agents/talk-agent.md` file (rename + internal edits)
- `.claude/extensions/present/skills/skill-talk/` directory (rename + internal edits)
- `.claude/extensions/present/manifest.json` (agent filename, skill name, routing keys)
- `.claude/extensions/present/EXTENSION.md` (skill-agent table, routing table)
- `.claude/extensions/present/README.md` (migration note update)
- `.claude/extensions/present/commands/slides.md` (skill references, migration note, routing table)
- `.claude/extensions/present/index-entries.json` (agent routing in `load_when`)
- `.claude/extensions/present/opencode-agents.json` (`talk` subagent key and prompt path)
- `.claude/context/reference/state-management-schema.md` (compound-value example)

### Out of Scope (preserve)
- `specs/` directory — all historical reports, plans, summaries, archives. Do not rewrite history.
- Semantic English "talk" in prose (e.g., "research talk", "conference talk", "give a talk", "talk type", "talk modes", "talk library", "Talk Modes" table header, "Academic Talks" feature name, "CONFERENCE: Research talk").
- The **talk library** data layer: `.claude/extensions/present/context/project/present/talk/**` directory, `talk-structure.md`, `talk/patterns/*.json`, `talk/contents/**`, `talk/themes/**`, `talk/components/**`. This was explicitly preserved by task 399 as a deliberate scope boundary (see `specs/399_consolidate_slides_commands/summaries/01_consolidate-slides-commands-summary.md:125`).
- `presentation-types.md` prose references to "talk" as an English noun.
- Forcing-data field name `forcing_data.talk_type` (enum values CONFERENCE|SEMINAR|DEFENSE|POSTER|JOURNAL_CLUB) — this is data schema, not an identifier, and changing it would require state.json migration.

### Decision Points (surface to user during /plan)
1. Should **`task_type: "talk"`** (the state.json field value and `forcing_data.talk_type` key) be renamed to `"slides"`? This would cascade to existing live tasks if any, and to forcing_data schema. **Recommendation**: preserve as `"talk"` since it's a semantic classification ("type of talk being created") not an identifier for the agent/command. The manifest routing key `present:talk` can then stay, or can be renamed to `present:slides` for consistency with the command. See Rename Map below, marked DECIDE.
2. Should **talk-library** file paths (`context/project/present/talk/`, `talk-structure.md`, `patterns/conference-standard.json` etc.) be renamed? **Recommendation**: NO, per task 399 scope boundary. Document as intentional in `slides.md`/`EXTENSION.md`.

## Findings

### Present Extension File Inventory

Files containing `talk` or `talk-agent` identifiers (non-library, non-prose):

| File | Identifier occurrences | Rename required |
|------|-----------------------|-----------------|
| `agents/talk-agent.md` | filename + 6 internal | YES (rename file + edit) |
| `skills/skill-talk/SKILL.md` | dirname + 17 internal | YES (rename dir + edit) |
| `commands/slides.md` | 6 (skill refs + migration note) | YES (edit) |
| `manifest.json` | 4 (agents list, skills list, 3 routing keys) | YES (edit) |
| `EXTENSION.md` | 2 (skill-agent table, routing table) | YES (edit) |
| `README.md` | 1 (migration note) | YES (edit) |
| `index-entries.json` | 2 (`agents: ["talk-agent"]`) | YES (edit) |
| `opencode-agents.json` | 2 (`"talk":` key + prompt path) | YES (edit) |

### Top-Level References

| File | Line | Content | Action |
|------|------|---------|--------|
| `.claude/context/reference/state-management-schema.md` | 84 | ``- **Compound values**: `present:grant`, `founder:deck`, `present:talk`, etc.`` | Edit if `present:talk` -> `present:slides` is chosen (Decision 1) |

No other top-level .claude/ files reference `talk-agent` or `skill-talk`. The merged `.claude/context/index.json` was searched — no hits (extension index entries are not statically merged in the tracked file).

### File-by-File Detail

#### `.claude/extensions/present/agents/talk-agent.md` (to be renamed to `slides-agent.md`)

Line-level changes:
- `2: name: talk-agent` -> `name: slides-agent`
- `3: description: Research talk material synthesis agent for academic presentations` -> **preserve** (semantic "talk")
- `7: # Talk Agent` -> `# Slides Agent` (or `# Slides Research Agent`)
- `11: Material synthesis agent for research talks. Invoked by \`skill-talk\` via the forked subagent pattern.` -> `... Invoked by \`skill-slides\` via the forked subagent pattern.` (preserve "research talks" prose)
- `17: - **Name**: talk-agent` -> `- **Name**: slides-agent`
- `19: - **Invoked By**: skill-talk (via Task tool)` -> `- **Invoked By**: skill-slides (via Task tool)`
- `86: "agent_type": "talk-agent",` -> `"agent_type": "slides-agent",`
- `88: "delegation_path": ["orchestrator", "talk", "skill-talk", "talk-agent"]` -> `["orchestrator", "slides", "skill-slides", "slides-agent"]`
- `242: "agent_type": "talk-agent",` -> `"agent_type": "slides-agent",`
- `245: "delegation_path": ["orchestrator", "talk", "skill-talk", "talk-agent"]` -> `["orchestrator", "slides", "skill-slides", "slides-agent"]`
- Preserve lines 46-61 (library paths: `talk/index.json`, `talk-structure.md`, `talk/patterns/*`, `talk/contents/*`) — these are library references (Decision 2: preserve).
- Preserve line 103: `"task_type": "talk"` (Decision 1: preserve) OR rename (DECIDE).
- Preserve lines 121-124 pattern table (library paths).
- Preserve lines 148, 198, 216, 236, 286 (semantic "talk content", "talk type", "talk_type").
- Stage 6 report output path `reports/{MM}_talk-research.md` -> `reports/{MM}_slides-research.md` (line 185, 235). DECIDE: report filename is cosmetic but breaks /slides command STAGE 2 Step 3 which greps for `*_talk-research.md`.

#### `.claude/extensions/present/skills/skill-talk/SKILL.md` (to be renamed to `skill-slides/SKILL.md`)

Directory rename: `skills/skill-talk/` -> `skills/skill-slides/`.

Line-level changes:
- `2: name: skill-talk` -> `name: skill-slides`
- `3: description: Research talk material synthesis and presentation assembly. Invoke for talk tasks.` -> `...Invoke for slides tasks.` (or preserve "talk tasks" as prose). DECIDE.
- `13: # Talk Skill` -> `# Slides Skill`
- `15: Thin wrapper that delegates talk research work to \`talk-agent\` subagent.` -> `... delegates slides research work to \`slides-agent\` subagent.` (preserve "research work" prose)
- `43: This skill routes to talk-agent with one of two workflow types:` -> `... routes to slides-agent ...`
- `45-47: talk_research workflow type` — DECIDE rename to `slides_research` (workflow_type is an internal identifier used in delegation context only; appears in agent file lines 106, 243). Recommend rename for consistency.
- `147: "skill": "skill-talk",` -> `"skill": "skill-slides",`
- `165: "delegation_path": ["orchestrator", "slides", "skill-talk"],` -> `["orchestrator", "slides", "skill-slides"]`
- `189: - subagent_type: "talk-agent"` -> `- subagent_type: "slides-agent"`
- `194: **DO NOT** use \`Skill(talk-agent)\` - this will FAIL.` -> `Skill(slides-agent)`
- `239-242: commit_action="complete talk research" / "assemble talk presentation"` — preserve (prose) OR rename to `slides` (DECIDE). Recommend preserve.
- Preserve lines 6-7 (library paths in YAML frontmatter comments).
- Preserve lines 35-36, 60, 74, 172, 302-303 (task_type value "talk", semantic "talk tasks").
- `95: if [ "$task_type" != "present" ] || [ "$task_type" != "talk" ]; then` — **pre-existing bug**: both conditions use `$task_type`, the first should be `$language`. Flag for planner.

#### `.claude/extensions/present/commands/slides.md`

Line-level changes:
- `23: **Note**: This command was previously named \`/talk\`.` -> preserve (migration note; accurate history).
- `154: Load existing task, validate language is "present" and task_type is "talk", then delegate to skill-talk for research.` -> `... delegate to skill-slides ...`
- `253: When input is a task number, delegate to skill-talk for research.` -> `... skill-slides ...`
- `272: skill: "skill-talk"` -> `skill: "skill-slides"`
- `428: | \`/research N\` | skill-talk | Synthesize materials into slide-mapped report |` -> `skill-slides`
- `430: | \`/implement N\` | skill-talk (assemble) | Generate Slidev presentation |` -> `skill-slides (assemble)`
- Preserve all prose references to "talk" (lines 18, 57, 59, 73, 195 task_type value, 264 "task_type is talk" comment, 308 similar, 400 "confirm talk design", 442 "for talk tasks").
- STAGE 2 Step 3 `ls specs/${padded_num}_${project_name}/reports/*_talk-research.md` (inside slides.md:323 — actually in the design stage). If agent report filename is renamed, this must match. Grep for that glob.

#### `.claude/extensions/present/manifest.json`

- `8: "agents": [..., "talk-agent.md"]` -> `"slides-agent.md"`
- `9: "skills": [..., "skill-talk"]` -> `"skill-slides"`
- `23: "present:talk": "skill-talk"` (research) -> `"present:slides": "skill-slides"` (DECIDE routing key)
- `31: "present:talk": "skill-planner"` (plan) -> `"present:slides": "skill-planner"`
- `39: "present:talk": "skill-talk"` (implement) -> `"present:slides": "skill-slides"`

#### `.claude/extensions/present/EXTENSION.md`

- `13: | skill-talk | talk-agent | opus | Research talk material synthesis and presentation assembly |` -> `| skill-slides | slides-agent | opus | Research talk material synthesis and presentation assembly |` (preserve description prose)
- `41: | \`present\` | \`talk\` | \`skill-talk\` | \`skill-talk\` | WebSearch, WebFetch, Read, Write, Edit |` -> `| \`present\` | \`slides\` | \`skill-slides\` | \`skill-slides\` | ...` (DECIDE: depends on task_type rename)
- `55: The talk library at \`context/project/present/talk/\` contains:` -> preserve (library, intentional)
- `56: **Patterns**: Slide structure definitions for each talk mode` -> preserve (prose)

#### `.claude/extensions/present/README.md`

- `81: **Note**: This command was previously named \`/talk\`.` -> preserve (migration note accurate).
- `88: - [context/project/present/talk/](...) - Talk library` -> preserve (library path).
- No identifier changes needed. (talk-agent not mentioned.)

#### `.claude/extensions/present/index-entries.json`

- `349: "agents": ["talk-agent"],` (presentation-types.md entry) -> `["slides-agent"]`
- `363: "agents": ["talk-agent"],` (talk-structure.md entry) -> `["slides-agent"]`
- `343, 344, 354, 357, 358`: topics/keywords with "talk" are semantic tags — preserve.
- `336-337, 350, 364`: `"commands": ["/slides"]` already correct.

#### `.claude/extensions/present/opencode-agents.json`

**Structural JSON change** (key rename):
- `63: "talk": {` -> `"slides": {`
- `66: "prompt": "{file:.opencode/agent/subagents/talk-agent.md}",` -> `"...slides-agent.md}"`

Note: This file is merged into repository-root `opencode.json` via `merge_targets.opencode_json`. The opencode integration exists in parallel (`.opencode/agent/subagents/talk-agent.md` presumably). The plan must check whether a corresponding file exists under `.opencode/` to rename.

#### `.claude/context/reference/state-management-schema.md`

- `84: - **Compound values**: \`present:grant\`, \`founder:deck\`, \`present:talk\`, etc.` -> `present:slides` (conditional on Decision 1).

## Rename Map

| Old identifier | New identifier | Locations (file:line) | Type |
|---|---|---|---|
| `agents/talk-agent.md` (filename) | `agents/slides-agent.md` | file rename | FS |
| `skills/skill-talk/` (dirname) | `skills/skill-slides/` | dir rename | FS |
| `talk-agent` (in YAML `name:`) | `slides-agent` | `agents/talk-agent.md:2` | Edit |
| `talk-agent` (token) | `slides-agent` | `agents/talk-agent.md:17,86,242`; `skills/skill-talk/SKILL.md:15,43,189,194`; `commands/slides.md` (none — uses skill-talk); `EXTENSION.md:13`; `manifest.json:8`; `index-entries.json:349,363`; `opencode-agents.json:66` | Edit |
| `skill-talk` (token) | `skill-slides` | `skills/skill-talk/SKILL.md:2,147,165`; `agents/talk-agent.md:11,19,88,245`; `commands/slides.md:154,253,272,428,430`; `manifest.json:9,23,39`; `EXTENSION.md:13,41` | Edit |
| `"talk"` (opencode agent key) | `"slides"` | `opencode-agents.json:63` | JSON key |
| `talk-agent.md` (path in prompt) | `slides-agent.md` | `opencode-agents.json:66` | Edit |
| `"present:talk"` (routing key) | `"present:slides"` | `manifest.json:23,31,39`; `.claude/context/reference/state-management-schema.md:84` | JSON key + doc (DECIDE) |
| `task_type: "talk"` (state.json field value) | `task_type: "slides"` | `commands/slides.md:195,264,308,424`; `skills/skill-talk/SKILL.md:60,74,95,172,302`; `agents/talk-agent.md:103`; `EXTENSION.md:41` | Edit (DECIDE — recommend preserve) |
| `talk_research` (workflow_type) | `slides_research` | `skills/skill-talk/SKILL.md:45-47,105-121,220-223,268`; `agents/talk-agent.md:106,243` | Edit (DECIDE — recommend rename) |
| `{MM}_talk-research.md` (report filename template) | `{MM}_slides-research.md` | `agents/talk-agent.md:185,235`; `commands/slides.md:286,323` (glob pattern) | Edit (DECIDE — recommend rename) |
| Semantic "talk" / "research talk" / "talk modes" / "talk library" | (preserve) | many lines across all files | NO CHANGE |
| `context/project/present/talk/` (library path) | (preserve) | all library content | NO CHANGE (task 399 boundary) |

### Preserve List (explicit non-rename)

| Token | Why | Examples |
|---|---|---|
| "Research talk" / "academic talk" / "give a talk" | English prose | slides.md:14,18,57; README.md:3,74; EXTENSION.md:2 header |
| "Talk Modes" / "Talk Library" table headers | Human-readable section titles | EXTENSION.md:43,53; README.md:79 |
| `forcing_data.talk_type` field + values | Data schema; not an identifier | slides.md:66, agent:107, schema-like structures |
| `talk-structure.md`, `talk/patterns/*`, `talk/contents/*` | Library data layer (task 399 scope) | agent:46-61,121-124; commands/slides.md library refs |
| `specs/**` historical records | Do not rewrite history | all `specs/archive/**` and `specs/39x_*` |
| Migration notes "previously named `/talk`" | Accurate migration history | slides.md:23; README.md:81 |
| `listen more than talk` | Entirely unrelated context (funder-research.md:181) | one hit, ignore |

## Decisions

1. **DECIDE during /plan**: Rename `task_type: "talk"` -> `"slides"`? Recommend PRESERVE. Rationale: `task_type` value is a human-meaningful classification ("this is a talk"), not an identifier bound to the agent name. Renaming cascades to any in-flight state.json entries and the forcing_data schema. The manifest routing key can still be `present:talk` while the command is `/slides` — this is the same pattern task 399 documented as intentional. However, **user task description suggests they want consistency** — recommend ASK USER in /plan preflight.
2. **DECIDE during /plan**: Rename routing keys `present:talk` -> `present:slides`? Recommend YES **only if Decision 1 = rename**. Routing keys and task_type values should stay aligned per `extension-task-types.md` convention.
3. **DECIDE during /plan**: Rename `workflow_type: "talk_research"` -> `"slides_research"`? Recommend YES. It's a pure internal identifier and cheap to update (5-7 lines across 2 files).
4. **DECIDE during /plan**: Rename report filename template `{MM}_talk-research.md` -> `{MM}_slides-research.md`? Recommend YES. Cosmetic but broken glob in slides.md:323 will fail if one is renamed without the other. Cheap to update together.
5. **CONFIRMED scope boundary**: Do NOT rename the `context/project/present/talk/` library layer. Document the name preservation in `EXTENSION.md` or `slides-agent.md` with a brief note ("library layer retains 'talk' in paths as an internal data-layer name").
6. **CONFIRMED out of scope**: Do NOT touch `specs/` history, including archive summaries from task 399 that explicitly document the preservation decision.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Accidentally substituting semantic "talk" (prose) | Medium | Medium | Use targeted `sed` / Edit calls on specific identifier strings (`talk-agent`, `skill-talk`, `/talk`, `"talk":`, `"present:talk"`) rather than bare `talk`. Never do `s/talk/slides/g`. Validate with post-rename grep for unchanged semantic occurrences. |
| Breaking the talk-library paths | High if rename is too broad | High | Explicitly preserve `context/project/present/talk/` and `talk-structure.md`. Audit with `rg 'talk' .claude/extensions/present/context/` after edits — should be unchanged. |
| Orphan state.json entries with `task_type: "talk"` | Low (no active talk tasks) | Medium | Check `specs/state.json` for any live task with `task_type: "talk"`; migrate if found. |
| Breaking `.opencode/` parallel tree | Medium | Low | `opencode-agents.json:66` references `.opencode/agent/subagents/talk-agent.md` — check if that file exists and rename. Task 400 summaries confirm opencode tree is maintained in parallel. |
| Task 399 archive summary becoming stale | N/A | Low | That summary documents an INTENTIONAL preservation; task 401 supersedes part of that decision. Add note to task 401 summary on completion referencing task 399's scope boundary. |
| Stale glob `*_talk-research.md` in slides.md:323 | High if partial rename | High | Rename agent report template AND slides.md glob together in same phase. |
| Pre-existing bug `skill-talk/SKILL.md:95` (tautological validation) | N/A | Low | Flag for planner; optional fix in same task or defer to separate task. |

## Recommendations for Planning Phase

1. **Preflight question to user** (mandatory): "Should `task_type: \"talk\"` and routing key `present:talk` also be renamed to `slides`, or preserved? (Recommend rename for consistency.)"
2. **Phase 1: File-system renames** (atomic, verifiable with `ls`):
   - `git mv .claude/extensions/present/agents/talk-agent.md .claude/extensions/present/agents/slides-agent.md`
   - `git mv .claude/extensions/present/skills/skill-talk .claude/extensions/present/skills/skill-slides`
3. **Phase 2: Content edits** inside the renamed files (YAML `name:`, headings, self-references, delegation paths).
4. **Phase 3: Manifest and routing updates** (`manifest.json`, `opencode-agents.json`, `index-entries.json`, `EXTENSION.md`, `README.md`).
5. **Phase 4: Cross-file references** (`commands/slides.md`, state-management-schema.md if applicable).
6. **Phase 5: Validation**:
   - `rg 'talk-agent' .claude/extensions/present/` -> should return 0 hits
   - `rg 'skill-talk' .claude/extensions/present/` -> should return 0 hits
   - `rg '\btalk\b' .claude/extensions/present/agents/ .claude/extensions/present/skills/ .claude/extensions/present/commands/ .claude/extensions/present/manifest.json .claude/extensions/present/EXTENSION.md .claude/extensions/present/README.md` -> only semantic/prose occurrences
   - `rg 'talk' .claude/extensions/present/context/project/present/talk/` -> unchanged (library layer)
   - `bash .claude/scripts/check-extension-docs.sh` -> passes
7. **Use the doc-lint script** `.claude/scripts/check-extension-docs.sh` as a Phase 5 gate.
8. **Optional fix**: `skill-slides/SKILL.md` line 95 tautology bug (both conditions read same var).

## Context Extension Recommendations

none (meta task — no new project context files needed)

## Appendix

### Search commands used
- `rg -n 'talk-agent' .` (full repo)
- `rg -n 'skill-talk' .claude/` (config tree)
- `rg -n '/talk\b' .claude/` (slash command reference)
- `rg -n 'present:talk' .`
- `rg -n 'talk\.md' .claude/`
- `rg -n '\btalk\b' .claude/extensions/present/`
- `find .claude/extensions/present -type f` (file enumeration)

### Cross-references
- Task 399 scope boundary: `specs/399_consolidate_slides_commands/summaries/01_consolidate-slides-commands-summary.md:125`
- Task 399 plan risk: `specs/399_consolidate_slides_commands/plans/01_consolidate-slides-commands.md:60`
- Task 390 initial creation: `specs/archive/390_create_talk_command_present/`
- Task 393 routing field unification: informs `present:talk` compound-key pattern

### File counts
- Active files requiring edits: 9 (8 in present extension + 1 top-level schema doc)
- Files to rename (FS operations): 2 (1 file + 1 directory)
- Historical files (preserve, no edits): all of `specs/`
- Library files (preserve per task 399): entire `context/project/present/talk/` subtree (~30 files)

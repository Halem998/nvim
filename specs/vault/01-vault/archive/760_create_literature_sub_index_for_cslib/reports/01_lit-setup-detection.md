# Research Report: Task #760

**Task**: 760 - Add interactive literature index setup detection to --lit flag
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:30:00Z
**Effort**: ~0.5h
**Dependencies**: None
**Sources/Inputs**: Codebase (skill-researcher, skill-base.sh, literature-briefing.sh, skill-fix-it, skill-literature)
**Artifacts**: specs/760_create_literature_sub_index_for_cslib/reports/01_lit-setup-detection.md
**Standards**: report-format.md

---

## Executive Summary

- The `--lit` flag is processed in each skill's Stage 4a by calling `literature-briefing.sh`; when `specs/literature-index.json` is missing, the script exits silently (exit 0, empty stdout), and skills silently produce no `lit_context`
- The clearest insertion point for interactive detection is **inside each skill's Stage 4a block**, immediately after the `lit_flag == "true"` check and before `literature-briefing.sh` is called — skills already run as direct Claude execution (not subagents), so AskUserQuestion is available in this context
- An alternative higher-level approach is a dedicated `literature-setup-detect.sh` helper script that all skills call when `lit_flag == "true"` and the sub-index is missing; the script would write detection output that the calling skill interprets to decide whether to present an AskUserQuestion prompt
- Programmatic task creation requires: reading `next_project_number` from `specs/state.json`, inserting a new entry, incrementing the counter, and calling `generate-todo.sh` — all patterns well-established in task.md
- Fork-orchestrate inline execution (Option b) maps to the existing `dispatch-agent.sh` fork pattern used in `skill-orchestrate` for blocker escalation

---

## Context & Scope

### What Was Researched

The entire `--lit` flag processing pipeline from user invocation through skill execution:
1. Parse-command-args.sh sets `LIT_FLAG`
2. Command (research.md, plan.md, implement.md) forwards `lit_flag` to skills via args
3. Each skill SKILL.md has an identical Stage 4a block that calls `literature-briefing.sh`
4. `literature-briefing.sh` silently exits when `specs/literature-index.json` is missing

Also researched:
- AskUserQuestion patterns in existing skills (skill-fix-it, skill-project-overview, skill-refresh, skill-zulip)
- Programmatic task creation flow from task.md
- Fork dispatch pattern from dispatch-agent.sh / skill-orchestrate
- The `specs/literature-index.json` schema and the global `~/Projects/Literature/index.json` structure

### Constraints

- Skills run directly as Claude (not subagents), so AskUserQuestion IS available in skill context
- The detection must not break the existing silent-exit behavior for non-`--lit` invocations
- The setup task (option a/b) needs to create a `meta`-type task (it modifies agent infrastructure) or a `general`-type research task depending on interpretation

---

## Findings

### Finding 1: The --lit Processing Pipeline

**Parse stage** (`parse-command-args.sh`):
```bash
if [[ "$remaining" =~ --lit ]]; then
  LIT_FLAG="true"
fi
```

**Command forwarding** (e.g., `research.md`):
- Extracts `lit_flag` from delegation context or arg string
- Passes `lit_flag` through to the Skill invocation args

**Skill Stage 4a** (identical pattern in all 6 skills: skill-researcher, skill-planner, skill-implementer, skill-researcher-hard, skill-planner-hard, skill-implementer-hard):
```bash
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

**literature-briefing.sh** silent exit:
```bash
# Lines 32-34
if [ ! -f "$SUB_INDEX" ]; then
  exit 0
fi
```
Where `SUB_INDEX="$PROJECT_ROOT/specs/literature-index.json"`.

### Finding 2: The Insertion Point

The detection must occur **before** `literature-briefing.sh` is called, when `lit_flag == "true"` and `specs/literature-index.json` is absent. This is skill-side Stage 4a.

The current code (all 6 skills):
```bash
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

Proposed insertion point:
```bash
if [ "$lit_flag" = "true" ]; then
  # NEW: detect missing sub-index and offer interactive setup
  if [ ! -f "specs/literature-index.json" ]; then
    # Present AskUserQuestion (see Finding 4)
    # Handle user choice (create task only, or create + orchestrate)
    # After setup or skip: continue with lit_context=""
  fi
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

**Alternative**: Extract into a shared helper script `literature-setup-detect.sh` that all 6 skills source, to avoid duplicating the detection logic.

### Finding 3: AskUserQuestion Pattern in Skills

Skills that use AskUserQuestion do so inline within their direct-execution flow. The canonical pattern from `skill-fix-it` and `skill-project-overview`:

```
AskUserQuestion with:
- question: "What would you like to do?"
- header: "Literature Setup"
- multiSelect: false
- options: [
    { label: "Skip", description: "Continue without literature context" },
    { label: "Create setup task", description: "Create task to populate literature index" },
    { label: "Create task and run it now", description: "Fork-orchestrate inline, then resume" }
  ]
```

The skill pauses at the AskUserQuestion tool call and resumes with the user's choice. Unlike subagent delegation, the skill itself IS the Claude conversation context, so interactive prompts work directly.

**Important constraint**: Only skills with `allowed-tools` including `AskUserQuestion` can use this. All 6 affected skills currently lack `AskUserQuestion` in their allowed-tools frontmatter — this must be added.

Current allowed-tools for skill-researcher:
```
allowed-tools: Agent, Bash, Edit, Read, Write
```
Required addition: `AskUserQuestion`

### Finding 4: Programmatic Task Creation

From `task.md`, the minimal steps to create a literature setup task programmatically:

```bash
# 1. Read next task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# 2. Create slug
slug="populate_literature_sub_index"

# 3. Build description
desc="Scan global Literature index (~/Projects/Literature/index.json), analyze repo task descriptions and domain, and populate specs/literature-index.json with relevant doc_ids and relevance annotations"

# 4. Insert into state.json
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg ts "$ts" \
   --arg desc "$desc" \
   --argjson num "$next_num" \
  '.next_project_number = ($num + 1) |
   .active_projects = [{
     "project_number": $num,
     "project_name": "populate_literature_sub_index",
     "status": "not_started",
     "task_type": "meta",
     "description": $desc,
     "created": $ts,
     "last_updated": $ts
   }] + .active_projects' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# 5. Regenerate TODO.md
bash .claude/scripts/generate-todo.sh
```

The setup task itself would be type `meta` (it modifies `.claude/` infrastructure by creating `specs/literature-index.json`).

### Finding 5: Fork-Orchestrate Inline Pattern (Option b)

The existing `dispatch-agent.sh` provides `invoke_agent_fork` for cache-warm fork dispatch used in `skill-orchestrate` for blocker escalation and drift inspection.

For option b (create task + orchestrate inline), the sequence is:
1. Create the setup task (as in Finding 4)
2. Use `dispatch_agent "" "$setup_prompt" "$context" "true"` to fork-dispatch the research
3. The fork runs in the same conversation context, analyzes the global index and repo tasks, and writes `specs/literature-index.json`
4. After fork returns, the original skill reads `lit_context` from `literature-briefing.sh`

**Caveat**: Fork dispatch in skills requires sourcing `dispatch-agent.sh` and having `Agent` in allowed-tools, which skill-researcher already has. The dispatch instructions are generated as JSON and the skill must interpret them to invoke the Agent tool (fork mode = omit `subagent_type`).

### Finding 6: Global Literature Index Structure

The `~/Projects/Literature/index.json` contains 222 entries total, 42 of which are parent-level documents (the rest are chunks/children). The relevant parent-document fields for the setup task to analyze:

```json
{
  "id": "blackburn_2002_book",
  "title": "Modal Logic (2002 Cambridge edition)",
  "keywords": ["modal logic", "Kripke semantics", ...],
  "summary": "Full text of...",
  "project_tags": ["BimodalLogic"],
  "authors": [...],
  "year": 2002,
  "doc_type": "book"
}
```

The `project_tags` field is the most useful for relevance detection — entries tagged `BimodalLogic` are relevant to formal logic repos. The setup research task should:
1. Read `project_tags` values from all parent entries in global index
2. Read task descriptions from `specs/state.json`
3. Match global index entries by keyword overlap between task descriptions and entry keywords/summary
4. Write matched entries to `specs/literature-index.json` with relevance annotations

### Finding 7: Sub-Index Schema

The `specs/literature-index.json` sub-index schema (from `literature-index.md`):
```json
{
  "project": "project_slug",
  "literature_dir": null,
  "created": "2026-06-23",
  "entries": [
    {
      "doc_id": "blackburn_2002_book",
      "relevance": "Core modal logic reference for BimodalLogic formalization",
      "added": "2026-06-23",
      "source": "discover"
    }
  ]
}
```

The `source` field should be `"discover"` for programmatically-added entries (vs `"manual"` for user-added).

---

## Recommendations

### Recommended Approach: Shared Helper Script + Skill Amendment

**Option**: Add a `literature-setup-detect.sh` script that all 6 skills call before `literature-briefing.sh`. The script:
- Accepts no arguments (reads `lit_flag` and checks for sub-index existence itself)
- Returns a structured exit code:
  - Exit 0: sub-index exists or `lit_flag` not set → caller continues normally
  - Exit 10: setup was skipped → caller continues with empty `lit_context`
  - Exit 20: setup task was created (option a) → caller should report task number and exit early
  - Exit 30: setup task was created and orchestrated (option b) → caller should re-run `literature-briefing.sh`

But this approach has a problem: the AskUserQuestion tool cannot be invoked from a subshell script — it requires direct Claude execution. The detection logic must live **inline in SKILL.md** (or in a Markdown section that gets incorporated into the SKILL.md execution context).

**Revised Recommendation**: Inline detection block in each skill's Stage 4a, sharing a helper bash script only for the task-creation side effect (not the interactive prompt).

### Implementation Plan (High Level)

1. **Add `AskUserQuestion` to allowed-tools** in all 6 skill SKILL.md frontmatter headers
2. **Add inline detection block** to Stage 4a in all 6 skills (identical code):
   ```
   if [ "$lit_flag" = "true" ] && [ ! -f "specs/literature-index.json" ]; then
     # Check global index exists
     # Present AskUserQuestion with 3 choices
     # On choice "Create task": call literature-create-setup-task.sh, report task N, continue with lit_context=""
     # On choice "Create task + run now": call literature-create-setup-task.sh, fork-orchestrate it, then call literature-briefing.sh
     # On choice "Skip": continue with lit_context=""
   fi
   ```
3. **Create `literature-create-setup-task.sh`** — a bash helper that does the programmatic task creation (state.json + TODO.md update), outputting the new task number to stdout
4. **Update skill-literature SKILL.md** — add `--subindex discover` mode that a research agent can invoke to scan global index and populate `specs/literature-index.json`

### Decision Points for Planning

1. **Which skills need the detection block**: All 6 that have Stage 4a? Only researcher/planner/implementer (3)? The hard variants would also call it.
2. **Fork dispatch vs named agent for Option b**: Fork is cache-warm but produces a separate context; named agent is fresher but slower.
3. **Task type for setup task**: `meta` (because it creates infrastructure) or `general` (because it's research)? `meta` is more accurate.
4. **What happens to the original command after option a**: Should the skill abort with a helpful message ("task N created, run /orchestrate N first, then retry with --lit") or should it proceed with `lit_context=""` after task creation?

---

## Decisions

- The AskUserQuestion must be inline in SKILL.md (not in a sourced shell script) since it's a Claude tool call
- All 6 skills (researcher, planner, implementer + hard variants) need identical Stage 4a amendments
- The task-creation side effect CAN be a bash helper script (`literature-create-setup-task.sh`)
- The sub-index schema uses `"source": "discover"` for agent-populated entries

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| 6 SKILL.md files need identical edits — divergence risk | Extract bash portion into a shared helper; only AskUserQuestion stays inline |
| Fork dispatch not always available (requires `FORK_SUBAGENT=1`) | Fall back to named `general-research-agent` via `dispatch-agent.sh` graceful degradation |
| User interrupts mid-setup but task was already created | Task created with `not_started` status — harmless; user can /todo abandon it |
| Global index is also missing (`~/Projects/Literature/index.json`) | Check for it before offering options; show informative message if missing |
| option b fork runs too long and times out before resuming original command | Option b is optional (user chooses); if fork times out, show task number and let user retry |

---

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh` — LIT_FLAG parsing
- `/home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh` — Silent exit behavior
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — Shared skill lifecycle functions
- `/home/benjamin/.config/nvim/.claude/scripts/dispatch-agent.sh` — Fork dispatch pattern
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` — Stage 4a insertion point
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` — Stage 4a (identical)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` — Stage 4a (identical)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher-hard/SKILL.md` — Stage 4a (identical)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner-hard/SKILL.md` — Stage 4a (identical)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer-hard/SKILL.md` — Stage 4a (identical)
- `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md` — AskUserQuestion pattern reference
- `/home/benjamin/.config/nvim/.claude/skills/skill-project-overview/SKILL.md` — AskUserQuestion pattern reference
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` — Fork dispatch usage
- `/home/benjamin/.config/nvim/.claude/commands/research.md` — lit_flag threading
- `/home/benjamin/.config/nvim/.claude/commands/task.md` — Programmatic task creation
- `/home/benjamin/.config/nvim/.claude/context/project/literature/domain/literature-index.md` — Sub-index schema
- `/home/benjamin/Projects/Literature/index.json` — Global index structure (222 entries, 42 parent docs)
- `/home/benjamin/.config/nvim/.claude/skills/skill-literature/SKILL.md` — Sub-index init/add operations

### Key Counts

- Skills needing Stage 4a amendment: 6 (researcher, planner, implementer × 2 effort modes)
- Skills already with AskUserQuestion in allowed-tools: 0 of the 6
- Global Literature index: 222 total entries, 42 parent documents
- Sub-index schema: 4 fields per entry (doc_id, relevance, added, source)

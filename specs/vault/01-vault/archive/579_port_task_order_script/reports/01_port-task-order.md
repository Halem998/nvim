# Research Report: Task #579

**Task**: 579 - Port generate-task-order.sh + task-order-format.md
**Started**: 2026-05-15T00:00:00Z
**Completed**: 2026-05-15T00:30:00Z
**Effort**: 1.5 hours estimated
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/Projects/ProofChecker/.claude/scripts/generate-task-order.sh` (834 lines, full read)
- `/home/benjamin/Projects/ProofChecker/.claude/context/formats/task-order-format.md` (396 lines, full read)
- `/home/benjamin/.config/nvim/.claude/context/formats/task-order-format.md` (296 lines — current core version)
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` (Phase 3 relevant sections)
- `/home/benjamin/.config/nvim/.claude/scripts/update-recommended-order.sh` (708 lines — existing Kahn's impl)
- `/home/benjamin/.config/nvim/specs/state.json` (current schema)
- `/home/benjamin/.config/nvim/specs/TODO.md` (current Task Order and Recommended Order sections)
**Artifacts**:
- `specs/579_port_task_order_script/reports/01_port-task-order.md` (this file)
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The ProofChecker `generate-task-order.sh` (834 lines) is nearly fully portable with only one ProofChecker-specific element: the `assign_topic_heuristic()` function (lines 208–231), which hardcodes ProofChecker domain keywords (lean4 concepts, bilateral logic, algebraic representation). This function should be **removed entirely** from the ported script, with topic assignment delegated 100% to the `topic` field in state.json.
- The ProofChecker `task-order-format.md` has two ProofChecker-specific sections: the **Topic Taxonomy table** (7 ProofChecker topics) and **examples** using ProofChecker task data. Both need replacement with generic equivalents.
- The current core `task-order-format.md` (296 lines) uses an old **flat category format** with manual arrow-chain dependency notation. It must be fully rewritten to the wave+tree+topic format from ProofChecker.
- The current core system has a `## Task Order` section in TODO.md that already uses the wave+grouped format (not the flat format) — suggesting a partial prior migration occurred. The new script must be compatible with this existing format.
- The `update-task-status.sh` Phase 3 in the core system uses a simple in-place status update pattern (grep for `**{N}** [STATUS]`). It needs to be extended with Mode B (full regeneration) for terminal transitions — but this is a separate task (581).
- `update-recommended-order.sh` (708 lines) already implements Kahn's algorithm for a different section (`## Recommended Order`). There is overlap in functionality but the two sections serve different purposes: Task Order = wave+topic grouped visualization; Recommended Order = flat priority table with action hints.

---

## Context & Scope

Task 579 requires:
1. Porting `generate-task-order.sh` from ProofChecker to `.claude/scripts/` in this repo
2. Rewriting `task-order-format.md` from the old flat-category format to the wave+tree+topic format

The scope is limited to the script and format doc. Integration into commands (task.md, todo.md, review.md), agents, and the `update-task-status.sh` Phase 3 rewrite are handled by tasks 582, 583, and 581 respectively.

**Constraint**: The current TODO.md already uses a wave+topic format (not the old flat format), so the new script must produce output matching the existing format. This means the format doc rewrite should document what is *already there* rather than defining a new format from scratch.

---

## Findings

### 1. ProofChecker Script Architecture (834 lines)

The script is organized into 11 clearly-delimited sections:

| Section | Lines | Description |
|---------|-------|-------------|
| Header comment | 1–20 | Usage documentation |
| Argument parsing | 32–69 | --print / --update-todo / --goal modes |
| Data extraction | 87–104 | `get_active_tasks()` — jq pipe to extract task data |
| Graph building | 116–171 | `build_graph()` — loads descriptions, status, clean deps |
| Topic loading | 180–202 | `load_topics()` — reads `topic` field + `active_topics` from state.json |
| Keyword heuristic | 208–231 | `assign_topic_heuristic()` — **ProofChecker-specific** |
| Kahn's algorithm | 239–299 | `compute_waves()` — in-degree BFS wave assignment |
| Union-Find | 305–344 | `compute_connected_components()` — CC for implicit grouping |
| Grouped section | 356–491 | `generate_grouped_section()` + `_print_topic_node()` — topic+DFS rendering |
| Wave table | 497–575 | `generate_wave_table()` — markdown table with wave/tasks/blocked/topics |
| DFS tree | 580–686 | `generate_dependency_tree()` — old-format fallback (preserved for debug) |
| Goal reading | 692–715 | `read_existing_goal()` — extracts Goal line from existing TODO.md |
| Section generation | 721–739 | `generate_section()` — assembles full section content |
| Section replacement | 745–794 | `replace_section()` — atomic TODO.md update |
| Main | 800–834 | Orchestration |

**Key design decisions**:
- Uses bash associative arrays (`declare -A`) extensively — requires bash 4+
- `get_active_tasks()` uses jq `select(.status == "X" | not)` pattern (safe from jq Issue #1132)
- Clean deps: filters out completed/abandoned/expanded task IDs from dependency lists
- Wave computation detects cycles (assigns wave 99, prints warning)
- Section replacement uses `head -n` + `tail -n +` + `mktemp` for atomic writes
- `generate_grouped_section()` uses global state variables (`_topic_section_visited`, `_globally_visited`, `_current_section_topic`) to avoid bash nameref issues in recursive DFS

### 2. ProofChecker-Specific Content in Script

**Single element requiring removal**: `assign_topic_heuristic()` (lines 208–231)

This function is called nowhere in the script itself — it is exported for use by *external callers* (task creation commands: `/task` Step 4.5, `meta-builder-agent` Stage 3.5, `skill-fix-it` Step 9.1, `/review` Section 5.6.3 per the ProofChecker format doc lines 122–124). The function hardcodes:

```bash
bilateral|acceptance|rejection
agent|architecture|demo|task_order|compliance|meta|rules
jonsson|tarski|stsa|lindenbaum|algebraic|boolean_algebra
ktype|normal_form|decidab|fmp|filtrat|doets|nequiv
ghfp|formula|module_org|boneyard|icc_finite|refactor|cleanup|reorgani
frame_hier|discrete.*frame|dense.*frame|integer.*frame|open_set|time_add|tense.*s5|temporal.*operator
completeness|sorry|represent|bfmcs|countermodel|canonical|parametric|chain|saturation
```

All keywords are Lean4/ProofChecker domain-specific. For the core agent system, there is no equivalent domain-specific keyword set.

**Recommended disposition**: Remove `assign_topic_heuristic()` entirely. The ported script does not need it — the script only reads the `topic` field from state.json (already set by task-creation commands). The topic *assignment* heuristic for the core system (task 580/583) belongs in those command files, not in the generation script.

**Other elements** — all portable without change:
- Argument parsing, path defaults (uses `${SCRIPT_DIR}/../..` relative paths — works in both repos)
- `build_graph()` — reads standard state.json fields: `project_number`, `status`, `description`, `project_name`, `dependencies`
- `load_topics()` — reads `topic` (per-task optional) and `active_topics` (top-level array) — both fields are universal
- `compute_waves()`, `compute_connected_components()` — pure graph algorithms
- `generate_grouped_section()`, `generate_wave_table()`, `generate_dependency_tree()` — pure rendering
- `read_existing_goal()`, `generate_section()`, `replace_section()` — pure I/O

### 3. Current Core State.json Schema vs ProofChecker

**ProofChecker schema** (present in active projects):
```json
{
  "project_number": 131,
  "project_name": "...",
  "status": "not_started",
  "task_type": "lean4",
  "description": "...",
  "dependencies": [123, 124],
  "topic": "formula-refactor",   // ← per-task optional field
  ...
}
```
Plus top-level: `"active_topics": ["completeness", "decidability", ...]`

**Current core nvim schema** (from state.json introspection):
```json
{
  "project_number": 87,
  "project_name": "...",
  "status": "researched",
  "task_type": "neovim",
  "created": "...",
  "last_updated": "...",
  "session_id": "...",
  "artifacts": [...]
}
```
Top-level keys: `active_projects`, `completed_projects`, `memory_health`, `next_project_number`, `repository_health`, `version`

**Missing fields for script compatibility**:
- `active_topics` — top-level array (currently `null`/absent)
- `topic` — per-task optional field (currently absent on all tasks)
- `dependencies` — per-task array (8 tasks currently have this, 5 with non-empty arrays)
- `description` — per-task optional string (absent from current core tasks; script falls back to `project_name`)

The script handles all missing fields gracefully with `// []` and `// ""` jq defaults. The `description` fallback to `project_name` means tasks without descriptions will display their slug instead of human-readable text.

### 4. ProofChecker Format Doc vs Current Core Format Doc

**ProofChecker format doc** (`task-order-format.md`, 396 lines) — the wave+tree+topic format:
- Documents wave table, grouped topic sections with DFS tree, cross-topic annotations
- Has ProofChecker-specific **Topic Taxonomy table** (7 canonical topics, lines 106–117)
- Has ProofChecker-specific **examples** using real ProofChecker task numbers/names
- References `assign_topic_heuristic()` as canonical for task-creation commands (lines 122–124)
- Documents `update-task-status.sh` integration: Mode A (in-place) + Mode B (full regen)

**Current core format doc** (`task-order-format.md`, 296 lines) — the old flat-category format:
- Documents numbered categories (Critical Path, Code Cleanup, Experimental, Deferred, Backlog)
- Uses arrow chain (`→`) dependency notation in code blocks
- Uses numbered/bulleted list entries: `1. **63** [RESEARCHED] -- Prove Box backward...`
- No wave table, no topic grouping, no DFS tree

**Current TODO.md Task Order section** (already in wave+grouped format):
```
## Task Order

*Updated 2026-05-15. 9 active tasks remaining.*

### Wave 1 (no dependencies)
- **579** [RESEARCHING] -- Port generate-task-order.sh + task-order-format.md
...
### Wave 2 (depends on Wave 1)
- **581** [NOT STARTED] -- Port update-task-status.sh Phase 3 rewrite (depends: 579)
...
### Pending (pre-existing)
- **500** [RESEARCHED] -- Add context: fork frontmatter...
```

This existing format differs slightly from the ProofChecker format:
- Uses `### Wave N (no dependencies)` / `### Wave N (depends on Wave 1)` headings instead of a wave **table** + `**Grouped by Topic**` grouped sections
- No topics assigned yet (no `topic` field on current tasks) — so it falls back to a simpler grouping
- Has a `### Pending (pre-existing)` category for tasks without dependency context

**Key insight**: The current TODO.md format was likely hand-edited or produced by a different script. The ported `generate-task-order.sh` will produce different output (full wave table + grouped-by-topic sections). The format doc rewrite must document the ProofChecker-style output as the new target format, replacing the current hand-crafted format.

### 5. Integration with update-task-status.sh

**Current core Phase 3** (lines 232–265): Uses in-place `sed` replacement on lines matching `^- \*\*${task_number}\*\* \[`.

This pattern is **incompatible** with the DFS tree format generated by `generate-task-order.sh`, where task entries look like:
```
579 [RESEARCHING] — Port generate-task-order.sh + task-order-format.md
  └─ 580 [NOT STARTED] — (agent-system: Port topic schema) (see above)
```
The current grep pattern `^- \*\*${task_number}\*\* \[` will not match this format.

However, this is a **task 581 concern**. Task 579 delivers the script; task 581 ports the Phase 3 rewrite. The format doc should document both Mode A (in-place regex) and Mode B (full regen) so task 581 has clear specs.

**ProofChecker's Mode A/B strategy** from format doc:
- Mode A (non-terminal): in-place sed on `^\s*(└─ )?{N} \[`
- Mode B (terminal + --clean): call `generate-task-order.sh --update-todo`

The core system's Phase 3 currently only has Mode A equivalent (via `**{N}** [` grep). Mode B is referenced in comments but not yet implemented (search shows the Mode B code in ProofChecker's update-task-status.sh but not in the core version).

### 6. Relationship to update-recommended-order.sh

The core system has `update-recommended-order.sh` (708 lines) which also implements Kahn's algorithm for the `## Recommended Order` section. This section uses a flat priority table format:
```
| Priority | Task | Status | Next Action |
|----------|------|--------|-------------|
| 1 | 500 | [RESEARCHED] | /plan 500 |
```

This is a **separate section** from `## Task Order`. They serve different purposes:
- `## Task Order`: visual wave+topic grouped dependency tree for understanding project structure
- `## Recommended Order`: flat priority table for daily workflow guidance

The ported `generate-task-order.sh` **replaces** the `## Task Order` section only. The `## Recommended Order` section and `update-recommended-order.sh` remain unchanged. There is no conflict.

---

## Decisions

1. **Remove `assign_topic_heuristic()` entirely** from the ported script. Topic inference for this project belongs in command files (tasks 582/583), not in the generation script. The script only reads topics from state.json.

2. **Port the script verbatim minus `assign_topic_heuristic()`**. All other functions are directly portable without modification. Path resolution uses `${SCRIPT_DIR}/../..` which works correctly for `.claude/scripts/` in both repos.

3. **Replace the core `task-order-format.md` in full**. The old flat-category format is obsolete (the format in TODO.md is already wave-based). The new doc should be based on ProofChecker's format doc with two changes: (a) replace ProofChecker Topic Taxonomy with generic explanation, (b) replace ProofChecker examples with generic ones.

4. **Keep `generate_dependency_tree()` in the ported script** (preserved for debugging as in ProofChecker). The function is not called from `generate_section()` but may be useful for debugging or as a fallback.

5. **The format doc should document** both the current TODO.md Task Order format AND the new generate-task-order.sh output format, noting the migration from hand-edited wave sections to auto-generated wave+topic sections.

---

## Recommendations

### Priority 1: Port generate-task-order.sh

Create `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`:
- Copy ProofChecker script verbatim
- Remove lines 208–231 (`assign_topic_heuristic()` function body and preceding comment block, lines ~204–231)
- Remove the Matching order comment at line 209
- No other changes needed — all other code is project-agnostic

**Verification**: Run with `--print` against the current `specs/state.json`:
```bash
.claude/scripts/generate-task-order.sh --print
```
Expected: wave table + grouped sections (with Uncategorized fallback since no topics assigned yet)

### Priority 2: Rewrite task-order-format.md

Target path: `/home/benjamin/.config/nvim/.claude/context/formats/task-order-format.md`

Replace the 296-line flat-category document with a new wave+tree+topic format document. Key sections to include:
- Placement (same as ProofChecker)
- Structure Elements: timestamp, goal, wave table, grouped sections
- Wave table format (identical to ProofChecker)
- Grouped topic sections format (identical to ProofChecker)
- DFS tree entry format (identical to ProofChecker)
- Status markers (identical)
- **Generic Topic section**: Explain that topics come from `active_topics` in state.json; no hardcoded taxonomy; projects define their own topics
- **Generic complete example**: Use agent-system style tasks (e.g., "Port task order script", "Update command integration") instead of ProofChecker Lean tasks
- Parsing patterns summary
- Script usage
- Generation algorithm
- update-task-status.sh integration (Mode A / Mode B)

**Remove from ProofChecker format doc**:
- Lines 106–124: Topic Taxonomy table (7 ProofChecker-specific topics) and `assign_topic_heuristic()` reference
- ProofChecker examples (lean task names like "Jonsson-Tarski representation", "Wire the TimelineQuot BFMCS")
- Lines 122–124: Cross-reference to `assign_topic_heuristic()` as canonical for task-creation commands

**Add to generic format doc**:
- Note that topics are entirely optional — if no `topic` fields exist, the script renders an `### Uncategorized` section (fallback behavior)
- Note that `active_topics` order controls render order; absence means topics render in encounter order
- Brief explanation of how to configure topics (edit state.json directly or via task-creation commands)

### Priority 3: Update update-task-status.sh Phase 3 (task 581)

After script is in place, task 581 should update Phase 3 to support:
- Mode A: change grep pattern from `^- \*\*${task_number}\*\* \[` to `^\s*(└─ )?${task_number} \[` (handles both old bullet format and new DFS tree format)
- Mode B: add terminal transition detection and call to `generate-task-order.sh --update-todo`

---

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| bash version < 4 (no associative arrays) | Low (Linux/NixOS environment) | Add version check at top of script |
| state.json missing `description` field on tasks | Medium (current core tasks lack it) | Script already falls back to `project_name` — acceptable |
| Existing TODO.md Task Order section format mismatch | Low | Script replaces entire section atomically; old hand-crafted format replaced on first run |
| `active_topics` absent from state.json | Medium (currently `null`) | Script handles gracefully — renders in encounter order |
| `topic` field absent on all tasks | Medium (currently absent) | Script renders `### Uncategorized` section — acceptable until topics assigned |
| `update-task-status.sh` Phase 3 incompatibility | High (known) | Task 581 will fix; the script itself doesn't depend on Phase 3 |
| `assign_topic_heuristic()` referenced by external callers (task 582/583) | Medium | Those tasks will implement their own heuristic; this is by design |

---

## Appendix

### Script Section Map (ProofChecker line references)

| Lines | Section | Portable? | Action |
|-------|---------|-----------|--------|
| 1–20 | Header comment | Yes (update paths) | Keep, update to reference core paths |
| 22–69 | Argument parsing | Yes | Keep verbatim |
| 87–104 | Data extraction | Yes | Keep verbatim |
| 116–171 | Graph building | Yes | Keep verbatim |
| 180–202 | Topic loading | Yes | Keep verbatim |
| 204–231 | Keyword heuristic | **NO** | **Remove entirely** |
| 239–299 | Kahn's algorithm | Yes | Keep verbatim |
| 305–344 | Union-Find | Yes | Keep verbatim |
| 356–491 | Grouped section | Yes | Keep verbatim |
| 497–575 | Wave table | Yes | Keep verbatim |
| 580–686 | DFS tree | Yes (debug) | Keep verbatim |
| 692–715 | Goal reading | Yes | Keep verbatim |
| 721–739 | Section generation | Yes | Keep verbatim |
| 745–794 | Section replacement | Yes | Keep verbatim |
| 800–834 | Main | Yes | Keep verbatim |

### Format Doc Change Matrix

| ProofChecker Section | Action | Reason |
|---------------------|--------|--------|
| Placement | Keep | Universal |
| Structure Elements | Keep | Universal |
| Dependency Waves Section | Keep | Universal |
| Grouped Topic Sections | Keep | Universal |
| Topic Taxonomy table (lines 106–117) | **Replace** | ProofChecker-specific topics |
| `assign_topic_heuristic()` reference (lines 122–124) | **Remove** | Not in ported script |
| Complete Example | **Replace** | ProofChecker task names |
| Parsing Patterns Summary | Keep | Universal |
| Generation section | Keep (update paths) | Universal algorithm |
| update-task-status.sh Integration | Keep | Universal pattern |
| Historical format appendix | **Replace** | Update to show old core flat-category format as historical |

### Key jq Patterns Used in Script (all use safe `| not` idiom)

```bash
# get_active_tasks() - line 88-93
select(.status == "completed" | not) |
select(.status == "abandoned" | not) |
select(.status == "expanded" | not)
```

This is already safe from jq Issue #1132 (`!=` escaping) — no changes needed.

### Current TODO.md Task Order vs ProofChecker Output Format

Current hand-crafted format:
```
### Wave 1 (no dependencies)
- **579** [RESEARCHING] -- Port generate-task-order.sh
```

ProofChecker script output (what generate-task-order.sh will produce):
```
**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 579,580 | -- | -- |

**Grouped by Topic** (indented = must complete first):

### Uncategorized
```
579 [RESEARCHING] — Port generate-task-order.sh + task-order-format.md
580 [RESEARCHING] — Port topic schema & rules
```
```

The format change from hand-crafted to generated output is intentional and expected. First run of `--update-todo` will replace the hand-crafted section.

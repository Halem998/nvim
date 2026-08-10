# Research Report: Task #582

**Task**: 582 - Port command integration (task.md, todo.md, review.md)
**Started**: 2026-05-15T00:00:00Z
**Completed**: 2026-05-15T00:30:00Z
**Effort**: 1-2 hours implementation
**Dependencies**: Task 579 (generate-task-order.sh ported), Task 580 (state-management-schema.md updated)
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/commands/task.md` (current nvim version)
- `/home/benjamin/.config/nvim/.claude/commands/todo.md` (current nvim version)
- `/home/benjamin/.config/nvim/.claude/commands/review.md` (current nvim version)
- `/home/benjamin/Projects/ProofChecker/.claude/commands/task.md` (ProofChecker reference)
- `/home/benjamin/Projects/ProofChecker/.claude/commands/todo.md` (ProofChecker reference)
- `/home/benjamin/Projects/ProofChecker/.claude/commands/review.md` (ProofChecker reference)
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` (already ported)
**Artifacts**:
- `specs/582_port_command_integration/reports/01_port-command-integration.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- **task.md** requires three targeted additions: Step 4.5 topic picker (generalized), updated Part C Task Order regen call, topic inheritance in expand/review modes, and topic backfill in sync mode.
- **todo.md** requires two additions: Step 5.8 post-archival Task Order regen and Step 5.8.8a post-vault regen.
- **review.md** requires replacing sections 6.5 through 6.7 (~330 lines of manual Task Order management) with a single `generate-task-order.sh` call plus a simplified goal-update prompt, AND generalizing the topic inference in section 5.6.3 from `.lean`-specific heuristics to extension-aware path matching.
- All changes are additive or replacements; no structural rewrites needed to existing sections.
- The ProofChecker versions contain hardcoded topic keywords (bilateral, algebraic-representation, etc.) that are ProofChecker-specific and must be generalized for the nvim-config context.

---

## Context & Scope

Tasks 579 and 580 have already ported:
- `generate-task-order.sh` (wave+tree+topic format, no hardcoded taxonomy)
- `state-management-schema.md` (`active_topics` array, per-task `topic` field)
- `state-management.md` (Task Order Synchronization section with regeneration triggers)

This task ports the command files to use these infrastructure pieces. The key constraint is that the nvim-config has a different set of topics than ProofChecker; the topic picker and inference logic must read `active_topics` from `state.json` dynamically instead of using hardcoded values.

---

## Findings

### task.md — Exact Differences

The nvim-config `task.md` and ProofChecker `task.md` are identical except for four places:

#### Difference 1: Step 4.5 (Topic Picker) — MISSING in nvim version

After step 4 (task_type detection), the ProofChecker version adds step **4.5** (lines 133–172):

```markdown
4.5 **Detect topic** from keywords (after task_type detection):

   Run keyword heuristic against the combined description text (same pattern as `assign_topic_heuristic()` in `.claude/scripts/generate-task-order.sh`). Pattern matching order (most specific first):
   - "bilateral", "acceptance", "rejection" → `bilateral`
   - "agent", "architecture", "demo", "task_order", "compliance", "meta", "rules" → `agent-system`
   [... 5 more ProofChecker-specific entries ...]

   Read existing topics from state.json:
   ...
   Present **AskUserQuestion** picker:
   ...
   Note: Show only topics from `active_topics` in state.json (not hardcoded list). Place the auto-inferred topic first with "(suggested)" suffix, omitting it from its regular position.
   ...
```

**Generalization needed**: The hardcoded keyword-to-topic mapping (bilateral, algebraic-representation, etc.) is ProofChecker-specific. For nvim-config, the step should read `active_topics` from `state.json` and optionally run a lightweight keyword heuristic against them. The canonical statement at the bottom of the ProofChecker step already says: *"Show only topics from `active_topics` in state.json (not hardcoded list)."* The picker options should be dynamically built from `active_topics`.

**Generalized version for nvim-config**:
- Remove all hardcoded topic keywords
- Keep: read `active_topics` from state.json, present AskUserQuestion picker with those topics plus "New topic..." and "Skip (no topic)" options
- Auto-inference can be skipped or simplified to "no suggestion" when `active_topics` is empty

#### Difference 2: Step 6 (state.json update) — MISSING topic field in nvim version

ProofChecker Step 6 (lines 180–197) adds the `topic` field to the jq command:

```bash
jq --arg ts "..." \
  --arg topic "$topic" \
  '.next_project_number = {NEW_NUMBER} |
   .active_projects = [{
     "project_number": {N},
     "project_name": "slug",
     "status": "not_started",
     "task_type": "detected",
     "topic": (if $topic != "" then $topic else null end),
     ...
   } | if .topic == null then del(.topic) else . end] + .active_projects' \
```

The nvim version does NOT include `--arg topic "$topic"` or the conditional topic field. This needs to be added.

#### Difference 3: Part C — Different regen call

nvim version (lines 178–183) uses the OLD pattern:
```bash
# Update Recommended Order section (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    add_to_recommended_order "$next_num" || echo "Note: Failed to update Recommended Order"
fi
```

ProofChecker version (lines 222–228) uses the NEW pattern:
```bash
# Update Task Order section (non-blocking)
gen_script=".claude/scripts/generate-task-order.sh"
"$gen_script" --update-todo specs/TODO.md specs/state.json 2>/dev/null || echo "Note: Failed to regenerate Task Order section (non-fatal)"
```

**Action**: Replace the old `update-recommended-order.sh` call with the new `generate-task-order.sh --update-todo` call.

#### Difference 4: Expand Mode Step 2.5 — Topic inheritance MISSING in nvim version

ProofChecker Expand Mode adds Step **2.5** (lines 315–324) between "Analyze description" and "Create 2-5 subtasks":

```markdown
2.5. **Read parent topic** for inheritance:
   ```bash
   parent_topic=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
     specs/state.json)
   ```
```

And Step 3 is updated to say "inheriting parent topic" and include the topic in the subtask jq entries.

The nvim version has no Step 2.5 and Step 3 does not mention topic inheritance.

#### Difference 5: Sync Mode Step 6.5 — Topic backfill MISSING in nvim version

After ProofChecker's Sync Mode Step 6 (regen Task Order), it adds Step **6.5** (lines 374–406):

```markdown
6.5. **Topic backfill** for tasks missing the `topic` field:

   Detect active tasks without a topic:
   ```bash
   missing_topics=$(jq -r '.active_projects[] |
     select(.status == "completed" | not) |
     select(.status == "abandoned" | not) |
     select(.status == "expanded" | not) |
     select(.topic == null or .topic == "") |
     "\(.project_number)|\(.project_name)"
   ' specs/state.json)
   ```

   [... keyword heuristic + AskUserQuestion multiSelect ...]
```

The nvim version sync mode ends at Step 6 with only the git commit. Step 6.5 (topic backfill) is entirely absent.

**Generalization needed**: The keyword heuristic in the ProofChecker backfill also references project-specific topics. For nvim-config, the heuristic should be removed or replaced with a purely picker-based approach (no auto-inference, just list untopiced tasks for the user to assign from `active_topics`).

#### Difference 6: Review Mode Step 7.5 — Topic inheritance MISSING in nvim version

ProofChecker's Review Mode adds Step **7.5** (lines 587–594) between the interactive selection and Step 8:

```markdown
### Step 7.5: Read Parent Topic for Inheritance

Before creating follow-up tasks, read the parent task's topic:
```bash
parent_topic=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
  specs/state.json)
```
```

And Step 8's jq command is updated to include `--arg topic "$parent_topic"` and the conditional topic field.

The nvim version has no Step 7.5 and Step 8's jq command does not include topic.

---

### todo.md — Exact Differences

The nvim-config `todo.md` and ProofChecker `todo.md` are nearly identical, with **two additions** in the ProofChecker version:

#### Difference 1: Step 5.8 — Post-archival Task Order Regeneration MISSING in nvim version

ProofChecker adds a new **Step 5.8** (lines 675–693) between Step 5.6 (Sync Repository Metrics) and Step 5.7 (Vault Operation):

```markdown
### 5.8. Regenerate Task Order

After syncing repository metrics, regenerate the Task Order section in TODO.md to reflect current task statuses.

**Run `generate-task-order.sh --update-todo`:**
```bash
# Regenerate Task Order (non-fatal -- continue if script unavailable or fails)
if [ -f ".claude/scripts/generate-task-order.sh" ]; then
  bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
    || { echo "Warning: Task Order regeneration failed (non-fatal)" >&2; }
else
  echo "Note: generate-task-order.sh not found -- skipping Task Order regeneration" >&2
fi
```

**Purpose**: Keep Task Order wave+tree format current with archived tasks removed and statuses updated.

**Non-fatal**: If the script fails for any reason (missing, error, bad state), log the warning and continue with remaining steps. Task Order regeneration failure does not block archival.
```

The nvim version goes directly from "5.6 Sync Repository Metrics" to "5.7 Vault Operation" with no Task Order regen step.

#### Difference 2: Step 5.8.8a — Post-vault Task Order Regen MISSING in nvim version

After ProofChecker's Step 5.8.8 (Reset state), it adds Step **5.8.8a** (lines 805–815):

```markdown
**Step 5.8.8a: Re-run Task Order Regeneration after Renumbering**:

After renumbering tasks and resetting state, the Task Order must be regenerated again because task numbers have changed:

```bash
# Regenerate Task Order with updated task numbers (non-fatal)
if [ -f ".claude/scripts/generate-task-order.sh" ]; then
  bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
    || { echo "Warning: Post-vault Task Order regeneration failed (non-fatal)" >&2; }
fi
```
```

The nvim version goes directly from Step 5.8.8 (Reset state) to Step 5.8.9 (Add transition comment), with no intermediate regen call.

#### Minor Difference: Git commit message note

ProofChecker's Step 6 git commit section (line 857) adds an extra note to append `", regenerate task order"` to the commit message when Task Order regeneration ran. The nvim version lacks this note. This is a minor cosmetic addition.

---

### review.md — Exact Differences

This is the most substantial change. The ProofChecker version replaces ~330 lines of manual Task Order management (sections 6.5, 6.6, 6.6.1 through 6.6.9, and much of 6.7) with a much shorter approach.

#### Difference 1: Section 2.6 — Updated parsing format

The nvim version's Section 2.6 describes parsing the OLD category-based format:
- Parses category subsections with `###` headers
- Parses ordered/unordered task entries
- Parses dependency chains from code blocks
- Builds `task_order_state` with `categories[]` and `dependency_graph`

The ProofChecker version updates Section 2.6 to parse the NEW wave+tree format:
- Parses a wave summary table
- Parses dependency tree entries (root tasks + indented children)
- Builds `task_order_state` with `waves[]` and `tree_entries[]`

This is necessary because `generate-task-order.sh` now produces the wave+tree format (ported in Task 579).

#### Difference 2: Section 5.6.3 — Topic inference generalization

The nvim version's Step 3 in Section 5.6.3 does NOT include topic inference at all. It just adds tasks to state.json without a `topic` field.

The ProofChecker version adds a step (lines 748–773) to infer topic from file path and keywords:

```markdown
**3. Infer topic from file path and description:**

Use the file-path heuristic to assign topic before writing state.json:
- Issues from `.claude/` or `specs/` files → `"agent-system"`
- Issues from `Theories/Bimodal/Metalogic/` files → run keyword heuristic on issue title
- Issues from `.lean` files → run keyword heuristic against issue title and description

Keyword heuristic order (bilateral > agent-system > algebraic-representation > decidability > formula-refactor > frame-extensions > completeness).
```

**Generalization needed**: The ProofChecker version uses `.lean`-specific heuristics and ProofChecker directory paths (`Theories/Bimodal/Metalogic/`). For nvim-config, the generalization should be:
- Issues from `.claude/` or `specs/` files → `"meta"` or `"agent-system"` (whichever matches active_topics)
- Issues from Lua files (`lua/`, `after/`) → check `active_topics` for neovim-related topics
- General: use `active_topics` from state.json and keyword matching against them
- Fall back to no topic if no match

The jq command in Step 4 of Section 5.6.3 also needs to include `--arg topic "$inferred_topic"` and the conditional topic field (same pattern as task.md Step 6).

#### Difference 3: Section 6.5 — REPLACED (330 lines → 30 lines)

**nvim version sections 6.5 through 6.6.9** (~330 lines, covering):
- 6.5: Prune Task Order (identify completed/abandoned tasks, remove entries, renumber ordered lists, update dependency chains, update timestamp, write updated section)
- 6.6: Insert New Tasks into Task Order (check existence, determine category placement, generate entries, insert into existing categories, create missing categories, update dependency chains, generate new if none exists, update timestamp, write)
- 6.6.1 through 6.6.9: Sub-steps for all the above

**ProofChecker version Section 6.5** (~30 lines):
```markdown
### 6.5. Regenerate Task Order

Regenerate the Task Order section in TODO.md using `generate-task-order.sh`. This replaces all manual pruning, insertion, and dependency chain management with a single script call.

**Skip condition**: If `task_order_state.exists == false` AND no tasks were created in Section 5.6, skip this section entirely.

**Run `generate-task-order.sh --update-todo`:**
```bash
# Regenerate Task Order from state.json (non-fatal)
if [ -f ".claude/scripts/generate-task-order.sh" ]; then
  bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
    || { echo "Warning: Task Order regeneration failed (non-fatal)" >&2; }
else
  echo "Note: generate-task-order.sh not found -- skipping Task Order regeneration" >&2
fi
```

**What the script does**:
[4 bullet points]

**Track result**:
- `task_order_regenerated`: true if script ran successfully, false if skipped or failed

**Non-fatal**: ...
```

**ProofChecker version Section 6.6** is now just a tombstone:
```markdown
### 6.6. (Removed)

Task insertion into the Task Order is now handled automatically by Section 6.5 (`generate-task-order.sh --update-todo`). The script reads `specs/state.json` directly, so any tasks created in Section 5.6 are already included in the regenerated Task Order. No separate insertion step is needed.
```

#### Difference 4: Section 6.7 — Simplified

The nvim version's 6.7 has:
- 6.7.1 Skip conditions (4 conditions)
- 6.7.2 Present Task Order Summary (all changes: pruned, added, categories)
- 6.7.3 Category Placement Override (with reassign and skip options)
- 6.7.4 Dependency Updates (multiSelect for each new task)
- 6.7.5 Apply Interactive Changes (category reassignments + dependency chain updates + renumber + regenerate chains)
- 6.7.6 Goal Statement Update (conditional on 5+ changes)

The ProofChecker version's 6.7 has:
- 6.7.1 Skip conditions (simplified: 2 conditions)
- 6.7.2 Present Task Order Summary (brief: just task count, waves, new tasks)
- **6.7.3 Goal Statement Update** (replaces 6.7.3-6.7.6 entirely, always presented when regen ran)

The complex category placement override (6.7.3), dependency declaration (6.7.4), chain regeneration (6.7.5) are entirely removed since the script handles all of that automatically.

#### Difference 5: Git commit message in Section 7

nvim version commit message:
```
Task Order: {pruned_count} pruned, {inserted_count} added, {reassigned_count} reassigned
```

ProofChecker version:
```
Task Order: {regenerated_or_skipped} (regenerated from state.json / skipped)
```

#### Difference 6: Standards Reference compliance table

nvim version dependency row:
```
| Dependencies | Yes | Interactive dependency selection (Section 6.7.4) |
```

ProofChecker version:
```
| Dependencies | Partial | Declared in state.json; Task Order generated by script |
```

Also, the note below the table is different — ProofChecker version references `generate-task-order.sh` and Section 6.7.3 (goal override only).

---

## Decisions

1. **topic.md Step 4.5 generalization**: Remove all ProofChecker-specific keyword mappings. The picker should dynamically show topics from `active_topics` in state.json. If `active_topics` is empty, the picker should still offer "New topic..." and "Skip (no topic)". No auto-inference heuristic needed for nvim-config initially (can be added later if topics are established).

2. **review.md section 5.6.3 generalization**: Replace ProofChecker path heuristics (`.lean`, `Theories/Bimodal/Metalogic/`) with extension-aware matching:
   - `.claude/`, `specs/` → infer topic `"meta"` if `"meta"` is in `active_topics`
   - `lua/`, `after/` → check `active_topics` for neovim-related topics
   - Fallback: no topic assigned

3. **review.md section 2.6 update**: Must update the Task Order parsing format from the old category-based format to the wave+tree format, since `generate-task-order.sh` now writes wave+tree. The `task_order_state` structure changes from `categories[]` to `waves[]` + `tree_entries[]`.

4. **Ordering of changes**: Implement in file order — task.md first (simplest, most self-contained), todo.md second (two additions only), review.md last (most complex replacement).

---

## Recommendations

1. **task.md** — Add 6 targeted changes in order:
   - After Step 4: Insert Step 4.5 (topic picker, reading from `active_topics` in state.json, no hardcoded keywords)
   - Step 6 jq: Add `--arg topic "$topic"` and conditional topic field
   - Part C: Replace `update-recommended-order.sh` call with `generate-task-order.sh --update-todo` call
   - Expand Mode: Add Step 2.5 (read parent topic) and update Step 3 to inherit topic
   - Sync Mode: After Step 6, add Step 6.5 (topic backfill via picker, no auto-inference for nvim-config)
   - Review Mode: Add Step 7.5 (read parent topic) and update Step 8 jq to include topic

2. **todo.md** — Add 2 targeted changes:
   - After Step 5.6: Insert Step 5.8 (Task Order regen after archival, non-fatal)
   - After Step 5.8.8: Insert Step 5.8.8a (re-run regen after vault renumbering, non-fatal)
   - Update git commit message note to append ", regenerate task order" when regen ran

3. **review.md** — Three changes:
   - Section 2.6: Replace old category-based parsing with wave+tree parsing format
   - Section 5.6.3 Step 3: Add extension-aware topic inference (generalized, no `.lean` paths)
   - Sections 6.5–6.7: Replace ~330 lines with ProofChecker's ~70-line simplified version (single script call + goal prompt)

---

## Risks & Mitigations

- **Risk**: The nvim-config currently has no `active_topics` in state.json. The topic picker will show an empty list.
  - **Mitigation**: Ensure the picker always offers "New topic..." and "Skip (no topic)" as fallback options even when `active_topics` is empty.

- **Risk**: The old `update-recommended-order.sh` script in task.md's Part C may not exist in nvim-config.
  - **Mitigation**: The new `generate-task-order.sh` is already ported (Task 579). The replacement call is non-fatal (`2>/dev/null || echo "Note: ..."`).

- **Risk**: The review.md section 2.6 format change (category-based → wave+tree) must stay consistent with what `generate-task-order.sh` actually produces.
  - **Mitigation**: Read the script's output format from `generate-task-order.sh` (already ported in Task 579) to confirm the parsing regexes. The ProofChecker version of 2.6 already has the correct wave+tree parsing regexes.

- **Risk**: Removing 330 lines from review.md sections 6.5–6.7 is irreversible without git.
  - **Mitigation**: Git tracks history; the old manual logic is recoverable if needed.

---

## Context Extension Recommendations

- **Topic**: `active_topics` initialization pattern for new projects
- **Gap**: No documented guidance on what to do when `active_topics` is empty and the first task is created
- **Recommendation**: Add a note to `state-management-schema.md` that `active_topics` defaults to `[]` and is populated organically as users add topics via the `/task` picker

---

## Appendix

### File Sizes (for reference)

- nvim `task.md`: 636 lines
- ProofChecker `task.md`: 740 lines (diff: +104 lines, all additions)
- nvim `todo.md`: 1014 lines
- ProofChecker `todo.md`: 1048 lines (diff: +34 lines, all additions)
- nvim `review.md`: 1570 lines
- ProofChecker `review.md`: 1025 lines (diff: -545 lines net — mostly section 6.5–6.7 replacement)

### Key Line Ranges for review.md Replacement

nvim review.md sections to be replaced:
- Section 6.5 (Prune Task Order): lines 842–964
- Section 6.6 (Insert New Tasks): lines 966–1172
- Section 6.7 (Interactive Management): lines 1174–1480
- Total: lines 842–1480 (~639 lines to replace with ~70 lines)

ProofChecker's replacement content:
- Section 6.5 (Regenerate Task Order): lines 813–841 (ProofChecker review.md)
- Section 6.6 (Removed): lines 842–844 (3-line tombstone)
- Section 6.7 (Simplified): lines 846–933 (ProofChecker review.md)

### Topic Picker AskUserQuestion Schema (generalized)

```json
{
  "question": "Assign a topic to this task?",
  "header": "Topic Assignment",
  "multiSelect": false,
  "options": [
    { "label": "{active_topic_1}", "description": "{description if available}" },
    "... one option per active_topics entry ...",
    { "label": "New topic...", "description": "Enter a custom topic name (will be added to active_topics)" },
    { "label": "Skip (no topic)", "description": "Task will appear under Uncategorized in Task Order" }
  ]
}
```

When auto-inference is available (e.g., keyword matched to a known topic), prepend:
```json
{ "label": "{inferred_topic} (suggested)", "description": "Auto-inferred from description" }
```
and omit that topic from its regular position.

When `active_topics` is empty, show only "New topic..." and "Skip (no topic)".

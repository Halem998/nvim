# Research Report: Task 563 — consult_auto_task_creation

- **Task**: 563 - Make /consult always create a task automatically
- **Started**: 2026-05-14T05:00:00Z
- **Completed**: 2026-05-14T05:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 562 (completed — interactive checklist format upgrade)
- **Sources/Inputs**:
  - `.claude/extensions/founder/commands/consult.md` (nvim extension)
  - `.claude/extensions/founder/skills/skill-consult/SKILL.md` (nvim extension)
  - `.claude/extensions/founder/agents/legal-analysis-agent.md` (nvim extension)
  - `Projects/Logos/Vision/.claude/commands/consult.md` (Vision project copy)
  - `Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` (Vision project copy)
  - `.claude/commands/task.md` — reference pattern for slug generation + state.json creation
  - `.claude/commands/research.md` — reference pattern for Gate In/Out structure
  - `specs/state.json` — current task state
  - `specs/TODO.md` — task list
- **Artifacts**: `specs/563_consult_auto_task_creation/reports/01_consult-auto-task-research.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

---

## Executive Summary

- The current `/consult` command operates in "standalone immediate-mode" — it only tracks artifacts if a task number is explicitly provided; otherwise all output is discarded after the temp-file is deleted.
- `skill-consult` implements this dual mode explicitly: task-attached mode stores artifacts in `specs/{NNN}_{SLUG}/`, while standalone mode uses a `/tmp/consult-meta-{session_id}.json` temp file that is deleted in Stage 8.
- The reference pattern for auto-task creation is fully specified in `task.md` (steps 1–8 of Create Task Mode): slug generation, state.json update, TODO.md update including frontmatter increment, and git commit.
- The required changes touch three files in the nvim extension (`consult.md`, `skill-consult/SKILL.md`) plus the same two files mirrored in the Vision project.
- The key design decision is where to create the task: Gate In of `consult.md` is the right location, because it has all information needed (session ID, domain flag, input content) before delegation occurs.
- Edge case: when the user provides a task number (to attach to existing task), skip auto-creation and use the existing task directory — this path is already supported and unchanged.

---

## Context & Scope

Task 563 builds directly on Task 562, which upgraded the `legal-analysis-agent` from a flat report format to an interactive per-finding checklist workflow. That task explicitly excluded task-creation behavior ("Implementing task creation behavior (that is task 563 scope)").

The current consultation system has two modes:

1. **Standalone mode**: No task created. Agent writes the report somewhere, skill-consult stores metadata in `/tmp/consult-meta-{session_id}.json`, then deletes it in Stage 8. The report path is logged briefly but not tracked anywhere persistent.
2. **Task-attached mode**: User provides `{N}` (existing task number) after the domain flag. Artifacts stored in `specs/{NNN}_{SLUG}/`. Git commit generated with task attribution.

The goal of Task 563 is to eliminate standalone mode and always create a task, making the task the default container for consultation artifacts.

---

## Findings

### Current `consult.md` Gate In Structure

**CHECKPOINT 1: GATE IN** contains four steps:
1. Generate session ID (`sess_{timestamp}_{hex}`)
2. Parse domain flag (`--legal`, error on unimplemented flags)
3. Detect input type (`task_number`, `file_path`, `inline_text`, or `design_question`)
4. Resolve task context (only executed when `input_type == "task_number"`)

The slug generation step is entirely absent. There is no mechanism to derive a task slug from the input content, and no state.json/TODO.md writes occur for non-task-number inputs.

**STAGE 2: DELEGATE** passes `task_number` to `skill-consult`; this is the only way a task context reaches the skill.

**CHECKPOINT 2: GATE OUT** displays a generic completion message and conditionally commits if `task_number` is set. It does not display a task number or next steps (like "Run /plan N") for the newly created task.

### Current `skill-consult/SKILL.md` Structure

**Stage 2 (Resolve Task Context)** implements the conditional:

```
if task_number is provided:
  Resolve task directory from state.json
  metadata_file = "${task_dir}/.return-meta.json"
else:
  # Standalone mode
  metadata_file = "/tmp/consult-meta-${session_id}.json"
```

**Stage 8 (Cleanup)** deletes the metadata file unconditionally:
```bash
rm -f "$metadata_file"
```

This cleanup is fine for the temp-file case (standalone mode) but should be retained or omitted carefully in the always-task mode (the metadata file in `specs/{NNN}_{SLUG}/` should not be deleted after linking).

**Stage 9 (Return)** currently says "Task attached: {task_number or 'standalone'}" — this field becomes always-populated once auto-task creation is in place.

### Reference Pattern: Task Creation (`task.md`)

The `/task` command Create Task Mode provides the exact pattern needed:

1. **Read `next_project_number`** from `specs/state.json`
2. **Parse description** and detect task_type from keywords
3. **Generate slug**: lowercase, underscores, max 50 chars, no special characters
4. **Update `state.json`** via jq: increment `next_project_number`, prepend entry to `active_projects`
5. **Update `TODO.md`**: (A) update frontmatter `next_project_number`, (B) prepend task entry after `## Tasks` line, (C) update Recommended Order section (non-blocking)
6. **Git commit**: `git add specs/` + commit

For `/consult`, the task description should be generated from the input (file path, text, or question), and the task_type should be `founder` (since the consultation comes from the founder extension domain).

### Slug Generation for `/consult`

The slug must be auto-generated from the input because the user does not provide an explicit description. The pattern from `task.md` (lowercase, replace spaces with underscores, remove special characters, max 50 chars) applies. For consult, an appropriate prefix should be used:

- File path input: derive from filename — e.g., `/path/to/legal-ai-example.typ` → `consult_legal_legal_ai_example`
- Inline text: truncate and slugify — e.g., `"Logos formally verifies..."` → `consult_legal_logos_formally_verifies`
- Design question: truncate and slugify — e.g., `How should I describe...` → `consult_legal_how_should_i_describe`
- Task number (existing): no slug generation needed, task already exists

A good pattern: `consult_{domain}_{slug_from_input}` where the slug portion is the first 30–35 characters of a slugified version of the input.

### Spec Directory and Artifact Location

The auto-created task directory follows standard naming: `specs/{NNN}_{SLUG}/`. The legal-analysis-agent already receives `metadata_file_path` and writes the report there. When a task is always created, the skill passes the task directory's `reports/` subdirectory as the report destination.

In `legal-analysis-agent.md` Stage 6, the report path is described as "typically `specs/{NNN}_{SLUG}/reports/{NN}_{short-slug}.md` if task-attached". With auto-task creation this is always the case — the "or a standalone path if immediate-mode" branch disappears.

### Gate Out Changes Needed

Currently CHECKPOINT 2: GATE OUT does not display a task number or next steps for non-task-attached invocations. After the change, every invocation creates a task, so the Gate Out should always display:

```
Legal design consultation complete.

Task: #{N} — {task_slug}
Input: {file path or description}
Translation gaps found: N
Consultation report: specs/{NNN}_{SLUG}/reports/...

Next: /plan {N}

Advisory: This consultation models attorney thinking but does not replace attorney review.
```

### Two-File Change Scope (nvim + Vision)

Both the nvim extension and the Vision project have their own copies of:
- `commands/consult.md`
- `skills/skill-consult/SKILL.md`

The `diff` confirms they are structurally identical except for Agent tool vs. Task tool references. Both copies must be updated in sync after the nvim extension is updated. The `legal-analysis-agent.md` file has the same mirroring requirement (as noted in Task 562's plan), but Stage 6's comment about "standalone path" may also need updating in that agent file.

### State.json Entry Format for `/consult` Tasks

Based on the `task.md` pattern, the state.json entry for a consult task should look like:

```json
{
  "project_number": {N},
  "project_name": "consult_legal_{slug}",
  "status": "not_started",
  "task_type": "founder",
  "description": "Legal design consultation: {input summary}",
  "created": "{ISO8601}",
  "last_updated": "{ISO8601}"
}
```

Note: Unlike regular tasks, the task will immediately transition to `implementing` (or a custom status) since the consultation begins right away. The status sequence is compressed: the task is created in Gate In, and the consultation is performed in the same command invocation.

### Edge Cases and Special Handling

1. **Task number provided (attach to existing task)**: No change in behavior. The existing `input_type == "task_number"` branch remains intact. Skip all auto-creation steps. Preserve existing artifact linking logic.

2. **Task creation failure**: If the jq/state.json update fails during Gate In, abort before delegation. Do not proceed with the consultation without a task context.

3. **Metadata file location**: The temp file cleanup (`rm -f "$metadata_file"`) in Stage 8 of skill-consult must not delete the task-directory metadata file. Either remove the cleanup stage entirely, or scope it to only clean up temp files (i.e., skip cleanup when a task directory was used).

4. **`specs/tmp/` directory**: The state.json update uses `specs/tmp/state.json` as a scratch file. Ensure this directory exists before the jq write. The pattern `mkdir -p specs/tmp` is needed.

5. **Status after consultation**: The auto-created task's status in state.json should remain `not_started` after the consultation completes. The consultation does not research or plan the task — it creates a task so artifacts are tracked. The user then runs `/plan N` separately.

6. **Vision project mirroring**: Both copies must be updated. The plan should include an explicit phase for copying the updated files from the nvim extension to the Vision project and verifying with diff.

---

## Decisions

- Auto-task creation belongs in **Gate In of `consult.md`**, not in `skill-consult`. The command is the orchestration layer that manages task lifecycle; the skill is a routing/wrapping layer.
- Task type for auto-created consult tasks: `founder` (matches the extension domain).
- Slug prefix convention: `consult_{domain}_{slug_from_input}` (e.g., `consult_legal_product_description`).
- Status after auto-creation: `not_started` (consultation is not a research or plan phase; it's a standalone consultation output).
- Metadata cleanup in skill Stage 8: Remove the `rm -f` or scope it to only temp files; never delete metadata files in task directories.

---

## Recommendations

1. **Update `consult.md` Gate In** (Step 4 becomes auto-task creation):
   - After detecting input type (Step 3), always check if `input_type == "task_number"` (existing task path) or not (auto-create path).
   - For auto-create: read `next_project_number`, generate slug from input, write state.json entry, write TODO.md entry, set `task_number` variable.
   - Pass `task_number` to skill just like the existing task-attached mode.

2. **Update `consult.md` Gate Out** to always show task number and "Next: /plan {N}":
   - Remove the conditional git commit (now it's always task-attached, so always commit).
   - Display: Task number, report path, next steps recommendation.

3. **Update `skill-consult/SKILL.md` Stage 2** to remove standalone mode:
   - Remove the `else` branch that sets `metadata_file` to `/tmp/...`.
   - Always derive `task_dir` from `task_number` (which is now always provided).
   - This simplifies the stage significantly.

4. **Update `skill-consult/SKILL.md` Stage 8 (Cleanup)**:
   - Remove the `rm -f "$metadata_file"` line entirely, OR scope it with a guard that only deletes temp files.
   - The metadata file in the task directory should persist for postflight artifact linking.

5. **Update `skill-consult/SKILL.md` Stage 9 (Return)**: Change "Task attached: {task_number or 'standalone'}" to always show the task number.

6. **Update `consult.md` Overview** documentation: Remove "standalone immediate-mode" description. Update syntax examples to show that bare invocations create a task. Keep the `{N}` syntax as "attach to existing task."

7. **Mirror changes to Vision project**: After updating nvim extension files, copy to `Projects/Logos/Vision/.claude/commands/consult.md` and `Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` (preserving the Task vs Agent tool difference in Vision).

8. **Update `legal-analysis-agent.md` Stage 6 comment**: Change "or a standalone path if immediate-mode" to reflect that the report always goes to a task directory. Both the nvim extension copy and Vision project copy need this update.

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Auto-task creates duplicate tasks if user runs `/consult` multiple times on same document | M | M | Acceptable: each consultation is a separate task. Document this in Overview. |
| `specs/tmp/` directory missing when jq writes to it | M | L | Add `mkdir -p specs/tmp` before jq command, same as task.md pattern |
| State.json `next_project_number` race condition in batch scenarios | L | L | Single-threaded command execution; not a real issue for `/consult` |
| Vision project copy gets out of sync after update | M | M | Explicit phase in implementation plan to copy and diff-verify |
| Metadata file deletion in Stage 8 removes task directory's metadata | H | M | Remove or guard the `rm -f` in Stage 8; critical to fix |
| Old invocations with task number (`/consult --legal 458`) break | H | L | Preserve existing `input_type == "task_number"` code path unchanged |

---

## Context Extension Recommendations

- No new context files are needed. The task.md slug generation and state.json update patterns are already well-documented in that command file and the create-task flow.

---

## Appendix

### Files to Modify

| File | Location | Change Summary |
|------|----------|---------------|
| `consult.md` | `.claude/extensions/founder/commands/consult.md` | Add auto-task creation in Gate In; update Gate Out |
| `skill-consult/SKILL.md` | `.claude/extensions/founder/skills/skill-consult/SKILL.md` | Remove standalone/temp-file mode; remove cleanup stage |
| `consult.md` (Vision) | `Projects/Logos/Vision/.claude/commands/consult.md` | Mirror nvim changes |
| `skill-consult/SKILL.md` (Vision) | `Projects/Logos/Vision/.claude/skills/skill-consult/SKILL.md` | Mirror nvim changes (preserve Task tool) |
| `legal-analysis-agent.md` | `.claude/extensions/founder/agents/legal-analysis-agent.md` | Update Stage 6 comment about standalone paths |
| `legal-analysis-agent.md` (Vision) | `Projects/Logos/Vision/.claude/agents/legal-analysis-agent.md` | Mirror agent update |

### Standalone Mode Removal Summary

The following text/code in `skill-consult/SKILL.md` is removed:

- Stage 2 `else` branch: `metadata_file="/tmp/consult-meta-${session_id}.json"`
- Stage 8: `rm -f "$metadata_file"` (entire cleanup stage removed or converted to no-op)
- Stage 9: `"Task attached: {task_number or 'standalone'}"` → `"Task attached: #{task_number}"`

### Gate In Addition Summary

New Step 4 in `consult.md` (replacing "Resolve Task Context if task number"):

```
if input_type == "task_number":
  # Existing path: resolve from state.json
  [unchanged]
else:
  # Auto-create path: generate task
  next_num = jq .next_project_number specs/state.json
  slug = "consult_{domain}_{slugify(input_first_40_chars)}"
  description = "Legal design consultation: {input summary}"
  [jq update state.json: prepend to active_projects, increment next_project_number]
  [sed update TODO.md frontmatter: increment next_project_number]
  [Edit TODO.md: prepend task entry after "## Tasks"]
  task_number = next_num
```

### Key Code Pattern (from task.md)

State.json update for new task creation:

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.next_project_number = {NEW_NUMBER} |
   .active_projects = [{
     "project_number": {N},
     "project_name": "slug",
     "status": "not_started",
     "task_type": "founder",
     "description": "...",
     "created": $ts,
     "last_updated": $ts
   }] + .active_projects' \
  specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

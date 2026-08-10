# Research Report: Task #583

**Task**: 583 - port_agent_skill_integration
**Started**: 2026-05-15T00:00:00Z
**Completed**: 2026-05-15T00:05:00Z
**Effort**: 30 minutes
**Dependencies**: Task #579 (generate-task-order.sh ported), Task #580 (topic schema ported)
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md` (current)
- `/home/benjamin/Projects/ProofChecker/.claude/agents/meta-builder-agent.md` (source)
- `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md` (current)
- `/home/benjamin/Projects/ProofChecker/.claude/skills/skill-fix-it/SKILL.md` (source)
- `/home/benjamin/.config/nvim/.claude/skills/skill-todo/SKILL.md` (current)
- `/home/benjamin/Projects/ProofChecker/.claude/skills/skill-todo/SKILL.md` (source)
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` (already ported)
- `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md` (already ported)
**Artifacts**:
- `specs/583_port_agent_skill_integration/reports/01_port-agent-skill.md`
**Standards**: report-format.md, artifact-formats.md

---

## Executive Summary

- Three files need changes: `meta-builder-agent.md`, `skill-fix-it/SKILL.md`, and `skill-todo/SKILL.md`.
- `meta-builder-agent.md` is missing two additions: a Topic column in the Stage 5 confirmation table and a `topic` field with auto-inference prose in the Stage 6 state.json entry block.
- `skill-fix-it/SKILL.md` is missing topic auto-inference logic in Step 9.1 and a Topic column in the Step 10 display table.
- `skill-todo/SKILL.md` is missing the entire Stage 10.5 RegenerateTaskOrder block and a commit-message note in Stage 15.
- All three diffs are small and surgical; the ProofChecker versions are the authoritative source.

---

## Context & Scope

Task 583 ports the final pieces of topic support into the three agent/skill files that were not touched by tasks 579 and 580. Tasks 579 and 580 ported `generate-task-order.sh` and the state schema documentation. This task ports the runtime behavior: how tasks get their `topic` field assigned (meta-builder, fix-it) and how the Task Order section is regenerated after archival (skill-todo).

The research compared the current nvim repo files line-by-line against the ProofChecker source to identify exact insertion points and text.

---

## Findings

### 1. meta-builder-agent.md

**Diff summary**: The ProofChecker version has two additions over the nvim version.

**Addition A — Stage 5 confirmation table (around line 566-569 in nvim file)**

Current nvim version (Interview Stage 5, `Tasks to Create` table header):
```
| # | Title | Language | Effort | Dependencies |
|---|-------|----------|--------|--------------|
| {N} | {title} | {lang} | {hrs} | None |
| {N} | {title} | {lang} | {hrs} | Task {M}, #{ext_task} |
```

ProofChecker version adds a `Topic` column:
```
| # | Title | Language | Topic | Effort | Dependencies |
|---|-------|----------|-------|--------|--------------|
| {N} | {title} | {lang} | {topic} | {hrs} | None |
| {N} | {title} | {lang} | {topic} | {hrs} | Task {M}, #{ext_task} |
```

Also adds a legend line below the table:
```
- Topics are auto-inferred from task title/description; user can revise by selecting "Revise"
```

**Exact insertion point**: The table in Interview Stage 5 is at nvim lines 566-569. The legend "Dependencies Legend" section currently has two bullet points; a third `- Topics are auto-inferred...` bullet is added.

**Addition B — Stage 6 state.json entry block (around line 676-690 in nvim file)**

ProofChecker adds an auto-inference prose paragraph before the state.json code block, and adds `"topic"` to the JSON example:

New prose (inserted before the `state.json Entry` block):
```
**Topic Auto-Inference**: Before building the state.json entry, run the keyword heuristic (same as `/task` Step 4.5) against each task's title and description. The inferred topic is shown in the Stage 5 confirmation table (Topic column). If the user selects "Revise", they can change topic assignments.
```

Updated state.json Entry block now includes `"topic"`:
```json
{
  "project_number": 36,
  "project_name": "task_slug",
  "status": "not_started",
  "task_type": "meta",
  "topic": "agent-system",
  "dependencies": [35, 34],
  "artifacts": []
}
```

Plus a note after the block:
```
Note: Include `"topic"` field only if a topic was inferred or assigned; omit if null/skipped.
```

**Exact insertion point**: After the "For each task" bash comment block (nvim lines 660-674), before the "**state.json Entry** (with dependencies):" heading.

---

### 2. skill-fix-it/SKILL.md

**Diff summary**: Two additions in Step 9.1 and Step 10.

**Addition A — Step 9.1 topic auto-inference block**

Current nvim version (Step 9: Update State Files, Step 9.1):
The state.json update section has a bash comment block for slug creation, then goes directly to the `has_note_dependency` JSON example blocks. There is no topic inference logic.

ProofChecker version adds a prose paragraph between the bash comments and the first JSON example:

```
**Topic Auto-Inference**: Before writing each task entry, infer topic from file path and description:
- Tags from `.claude/` files or `specs/` files → `"agent-system"`
- Tags from `.lean` files → run keyword heuristic against tag content and file name
- Use the same heuristic as `/task` Step 4.5
```

Then the JSON examples for the has_note_dependency states are updated to include `"topic"`:

For `has_note_dependency is TRUE` case:
```json
{
  "project_number": {N},
  "project_name": "{slug}",
  "status": "not_started",
  "task_type": "{task_type}",
  "topic": "{auto-inferred topic}",
  "dependencies": [learn_it_task_num]
}
```

For all other tasks:
```json
{
  "project_number": {N},
  "project_name": "{slug}",
  "status": "not_started",
  "task_type": "{task_type}",
  "topic": "{auto-inferred topic}"
}
```
With note: `Note: Omit "topic" field if topic cannot be inferred (empty string from heuristic).`

**Generalization note**: The ProofChecker version includes a `.lean` files heuristic. The task description says to generalize this (extension-aware path matching, no .lean-specific heuristic). The generalized form for this nvim repo would be:
- Tags from `.claude/` files or `specs/` files → `"agent-system"`
- Tags from extension paths (e.g., `.lua` files) → run keyword heuristic against tag content and file path
- Use the same heuristic as `/task` Step 4.5
However, since this repo does not have a `/task` Step 4.5 keyword heuristic (that exists in ProofChecker), the simplest generalization is:
- Tags from `.claude/` or `specs/` → `"agent-system"`
- Otherwise → no topic (omit field)

**Addition B — Step 10 display table**

Current nvim Step 10 table:
```
| # | Type | Title | Language |
|---|------|-------|----------|
| {N} | fix-it | Fix issues from FIX:/NOTE: tags | {lang} |
| {N+1} | learn-it | Update context files from NOTE: tags | meta |
| {N+2} | todo | {title} | {lang} |
| {N+3} | research | Research: {question title} | {lang} |
```

ProofChecker version adds a `Topic` column:
```
| # | Type | Title | Language | Topic |
|---|------|-------|----------|-------|
| {N} | fix-it | Fix issues from FIX:/NOTE: tags | {lang} | {topic} |
| {N+1} | learn-it | Update context files from NOTE: tags | meta | agent-system |
| {N+2} | todo | {title} | {lang} | {topic} |
| {N+3} | research | Research: {question title} | {lang} | {topic} |
```

**Exact insertion points**: nvim lines 507-519 (Step 9.1 state.json section), nvim lines 497-519 (display table at Step 10, around lines 498-519).

---

### 3. skill-todo/SKILL.md

**Diff summary**: One new stage (10.5) and a commit-message note in Stage 15.

**Addition A — Stage 10.5 RegenerateTaskOrder** (new stage inserted between Stage 10 and Stage 11)

This is a completely new stage in the ProofChecker version. Full content to insert after the closing `</stage>` tag of Stage 10 (vault_check_complete checkpoint):

```xml
  <stage id="10.5" name="RegenerateTaskOrder">
    <action>Regenerate Task Order section in TODO.md after task archival</action>
    <process>
      1. Run generate-task-order.sh --update-todo (non-fatal):
         ```bash
         if [ -f ".claude/scripts/generate-task-order.sh" ]; then
           bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
             || { echo "Warning: Task Order regeneration failed (non-fatal)" >&2; }
         else
           echo "Note: generate-task-order.sh not found -- skipping Task Order regeneration" >&2
         fi
         ```

      2. If vault operation was performed (vault_approved=true), run regeneration again after renumbering:
         ```bash
         # Post-vault re-run (non-fatal)
         if [ "$vault_approved" = "true" ] && [ -f ".claude/scripts/generate-task-order.sh" ]; then
           bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json \
             || { echo "Warning: Post-vault Task Order regeneration failed (non-fatal)" >&2; }
         fi
         ```

      3. Track result for commit message:
         - task_order_regenerated: true if script ran successfully, false if skipped or failed

      Note: This stage is non-fatal. If generate-task-order.sh is absent or fails, log the
      warning and proceed to Stage 11. Task archival is never blocked by Task Order regeneration.
    </process>
  </stage>
```

**Exact insertion point**: After the `</stage>` closing tag of Stage 10 (line 641 in nvim file, after the `<!-- CHECKPOINT: ... -->` comment), before the `<stage id="11"` opening tag.

**Addition B — Stage 15 commit message note**

Current nvim Stage 15 GitCommit process step 3:
```
3. Commit: `todo: archive {N} tasks` with counts for completed, abandoned, roadmap, orphans, misplaced, readme, memories
```

ProofChecker version adds:
```
3. Commit: `todo: archive {N} tasks` with counts for completed, abandoned, roadmap, orphans, misplaced, readme, memories
   - When task_order_regenerated=true (from Stage 10.5), append ", regenerate task order" to commit message
   - Example: `todo: archive 3 tasks, update 2 roadmap items, regenerate task order`
```

**Exact insertion point**: nvim line 722 (the commit: line in Stage 15).

---

### 4. generate-task-order.sh Interface (already ported)

The script already exists at `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`. The relevant interface for skill-todo Stage 10.5 is:
```bash
bash ".claude/scripts/generate-task-order.sh" --update-todo specs/TODO.md specs/state.json
```
This replaces the `## Task Order` section in `TODO.md` using data from `state.json`. Returns 0 on success, non-zero on failure. Non-fatal usage is handled by `|| { echo "Warning..." >&2; }`.

### 5. State Schema (already ported)

`state-management-schema.md` already documents both `active_topics` (top-level array) and the per-task `topic` field. The `agent-system` topic value is appropriate for tasks from `.claude/` and `specs/` paths in this repo.

---

## Decisions

- **Generalization of topic inference in skill-fix-it**: The ProofChecker version mentions `.lean` files specifically. For the nvim repo, the generalized rule is: `.claude/` or `specs/` paths → `"agent-system"`, otherwise no topic (omit field). The `.lean`-specific heuristic is not ported per the task description.
- **meta-builder-agent.md topic auto-inference**: The ProofChecker version references `/task` Step 4.5 keyword heuristic. Since this repo may not have an identical `/task` Step 4.5, the prose should reference the same heuristic pattern without being prescriptive about the exact step number.
- **skill-todo Stage 10.5 is non-fatal**: Both versions agree the stage must not block archival. If `generate-task-order.sh` is absent or fails, log warning and continue.

---

## Recommendations

1. **meta-builder-agent.md**: Make two edits:
   - Stage 5 table: add `Topic` column header and `{topic}` column to the 4-column table (making it 5 columns); add legend bullet.
   - Stage 6: insert topic auto-inference prose + update state.json JSON example to include `"topic"` field + add note about omitting null topics.

2. **skill-fix-it/SKILL.md**: Make two edits:
   - Step 9.1: insert topic auto-inference paragraph and update the two JSON example blocks to include `"topic"`.
   - Step 10: add `Topic` column to the display table (4 columns → 5 columns).

3. **skill-todo/SKILL.md**: Make two edits:
   - Insert new `<stage id="10.5">` block between Stage 10 and Stage 11.
   - Update Stage 15 step 3 commit message to reference `task_order_regenerated`.

---

## Risks & Mitigations

- **Risk**: The `/task` Step 4.5 cross-reference in meta-builder-agent.md and skill-fix-it may confuse implementers if that step doesn't exist in this repo's skill-task.
  - **Mitigation**: The prose says "run the keyword heuristic (same as `/task` Step 4.5)" — this is a forward reference. If `/task` doesn't have a Step 4.5, the implementer should either add it or simplify the inference rule.
- **Risk**: Stage 10.5 relies on `vault_approved` variable being set by Stage 10 vault sub-steps.
  - **Mitigation**: The post-vault re-run is guarded by `[ "$vault_approved" = "true" ]`, so if vault was not needed or was skipped, the second call is simply skipped. Low risk.
- **Risk**: The `## Task Order` section may not exist in TODO.md if generate-task-order.sh was never run.
  - **Mitigation**: The script already handles a missing section gracefully (prints WARNING and returns 1, which is caught by the non-fatal error handler).

---

## Appendix

### File Locations
- nvim meta-builder-agent: `/home/benjamin/.config/nvim/.claude/agents/meta-builder-agent.md`
- nvim skill-fix-it: `/home/benjamin/.config/nvim/.claude/skills/skill-fix-it/SKILL.md`
- nvim skill-todo: `/home/benjamin/.config/nvim/.claude/skills/skill-todo/SKILL.md`
- ProofChecker meta-builder-agent: `/home/benjamin/Projects/ProofChecker/.claude/agents/meta-builder-agent.md`
- ProofChecker skill-fix-it: `/home/benjamin/Projects/ProofChecker/.claude/skills/skill-fix-it/SKILL.md`
- ProofChecker skill-todo: `/home/benjamin/Projects/ProofChecker/.claude/skills/skill-todo/SKILL.md`
- generate-task-order.sh: `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh`
- state-management-schema.md: `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md`

### Key Line References (nvim files)

**meta-builder-agent.md**:
- Stage 5 table: lines 565-570 (4-column table with `| # | Title | Language | Effort | Dependencies |`)
- Stage 6 "For each task" section: lines 660-684 (state.json entry block)

**skill-fix-it/SKILL.md**:
- Step 9.1 state.json section: lines 435-462 (bash comment block + dependency JSON blocks)
- Step 10 display table: lines 498-519

**skill-todo/SKILL.md**:
- Stage 10 closing tag: line 641 (vault_check_complete checkpoint comment)
- Stage 11 opening tag: line 644
- Stage 15 step 3: line 722

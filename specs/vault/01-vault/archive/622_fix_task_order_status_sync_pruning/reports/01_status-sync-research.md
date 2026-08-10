# Research Report: Task #622

**Task**: 622 - Fix Task Order status sync and completed task pruning
**Started**: 2026-06-01T18:00:00Z
**Completed**: 2026-06-01T18:45:00Z
**Effort**: ~45 minutes
**Dependencies**: Task 620 (prior research on generate-task-order.sh and BimodalLogic Task Order)
**Sources/Inputs**: Codebase (scripts, skills, context, BimodalLogic project)
**Artifacts**: specs/622_fix_task_order_status_sync_pruning/reports/01_status-sync-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- **Sub-issue 1 (Phase 3 grep patterns)**: The Mode A grep pattern `^\s*(└─ )?${task_number} \[` in `update-task-status.sh` is **robust** against the wave+tree format. It correctly matches root-level and indented tree entries and does NOT accidentally match artifact link lines or Tasks section headings.
- **Sub-issue 2 (Mode B wiring)**: Mode B terminal-transition regeneration **is correctly wired** through `skill-implementer` (Stage 7 → `update-task-status.sh postflight implement` → Phase 3 Mode B). However, extension-specific implementers (lean, nvim) bypass `update-task-status.sh` entirely, so Mode B **never fires** for lean4 or neovim tasks.
- **Sub-issue 3 (artifact link injection)**: `link-artifact-todo.sh` **cannot** inject into the Task Order section (it anchors on `^### N\.` which only matches `## Tasks` entries). The contamination is caused by **agents directly editing the Task Order tree entries** as if they were Tasks section entries, because `artifact-linking-todo.md` lacks explicit prohibition on Task Order edits.

**Recommended fixes**:
1. Add explicit "ONLY target the `## Tasks` section; never edit Task Order entries" warning to `artifact-linking-todo.md`.
2. Update lean and nvim extension implementer SKILLs to call `update-task-status.sh postflight implement` (triggering Mode B) instead of bypassing it.
3. Optionally: add a post-Mode-A guard in `update-task-status.sh` that removes artifact link lines from Task Order entries after in-place status update.

---

## Context & Scope

Task 620 established:
- `generate-task-order.sh` correctly filters completed tasks
- The BimodalLogic Task Order had a stale hand-curated format that was never regenerated
- `link-artifact-todo.sh` uses `^### {N}.` which only matches `## Tasks` section

Task 622 focuses on:
1. Phase 3 grep pattern robustness against wave+tree format
2. Whether Mode B fires in practice (not just in documentation)
3. The actual code path for artifact link injection into Task Order entries

---

## Findings

### Sub-issue 1: update-task-status.sh Phase 3 Grep Pattern Analysis

**Phase 3 of `update-task-status.sh`** (lines 238–307) uses a two-mode strategy:

**Mode A: In-place status update** (non-terminal transitions):
```bash
order_line=$(grep -n -E "^\s*(└─ )?${task_number} \[" "$TODO_FILE" | head -1 | cut -d: -f1)
```

Testing this pattern against wave+tree format:
- `"233 [PLANNED] — desc"` → **matches** (root level, no indent)
- `"  └─ 233 [PLANNED] — desc"` → **matches** (depth-1 indent with `└─ `)
- `"    └─ 233 [PLANNED] — desc"` → **matches** (depth-2 indent)
- `"  - **Research**: [specs/233_...]"` → **does NOT match** (no task number before `[`)
- `"### 233. Task title"` → **does NOT match** (starts with `#` not digits/spaces)

The status extraction on the matched line:
```bash
current_order_status=$(sed -n "${order_line}p" "$TODO_FILE" | grep -oE '\[([A-Z ]+)\]' | head -1 | tr -d '[]')
```
The `\[([A-Z ]+)\]` pattern requires ALL-CAPS between brackets, so artifact link paths (`[specs/lower_case/...]`) are skipped correctly. `[PLANNED]`, `[NOT STARTED]`, etc. match correctly.

The replacement:
```bash
sed -i "${order_line}s/\[${current_order_status}\]/[${TODO_STATUS}]/" "$TODO_FILE"
```
Operates only on the matched line — artifact link lines on adjacent lines are unaffected.

**Verdict**: The Phase 3 Mode A patterns are robust. No fix needed here.

**Mode B: Full regeneration** (terminal transitions COMPLETED, ABANDONED, EXPANDED):
```bash
"$gen_script" --update-todo "$TODO_FILE" "$STATE_FILE"
```
Calls `generate-task-order.sh --update-todo` which reads `state.json` (already updated in Phase 1) and regenerates the entire `## Task Order` section. Since completed tasks are filtered by `select(.status == "completed" | not)`, Mode B correctly prunes completed tasks.

There is also a **fallback**: if the task isn't found in the Task Order tree via the grep pattern, it falls back to full regeneration (Mode B) regardless of terminal status.

### Sub-issue 2: Mode B Wiring — Where It Fires and Where It Doesn't

**Correct wiring path** (core extension `skill-implementer`):
```
skill-implementer Stage 7
  → update-task-status.sh postflight implement
    → Phase 1: state.json → "completed"
    → Phase 3: TODO_STATUS == "COMPLETED" → Mode B fires
      → generate-task-order.sh --update-todo
        → prunes completed task from Task Order
```

This path works correctly. Mode B is wired through `update-task-status.sh` which is called from `skill-implementer/SKILL.md` line 383.

**Broken wiring — extension implementers**:

Both `lean/skills/skill-lean-implementation/SKILL.md` and `skills/skill-neovim-implementation/SKILL.md` delegate artifact linking to `artifact-linking-todo.md` instructions and update state.json via `postflight-workflow.sh` (via `skill-base.sh`). **Neither calls `update-task-status.sh`**. The `postflight-workflow.sh` script updates state.json directly with jq and does NOT invoke `generate-task-order.sh`.

Evidence from BimodalLogic git history: commit `f99eca6d1` ("task 233: complete implementation") modified `specs/TODO.md` to:
1. Change `233 [PLANNED]` to `233 [COMPLETED]` **in-place** in the Task Order section (instead of triggering Mode B regeneration which would prune 233 entirely)
2. Add `- **Summary**: [...]` to the Task Order tree entry (instead of the `## Tasks` section)

This confirms Mode B did NOT fire for task 233 — the lean extension's implementer bypasses `update-task-status.sh`.

**Command-gate-out.sh**: Does call `update-task-status.sh` defensively, but only fires if the skill's metadata status didn't already reflect completion. For lean/nvim implementers, `postflight-workflow.sh` updates state.json directly to "completed", so `command-gate-out.sh`'s defensive correction checks `current_status != expected_status` — which is false (both are "completed") — and skips the correction.

**state-management.md Regeneration Triggers table** (line 89):
> `| Terminal status transition | Automated | generate-task-order.sh --update-todo (optional, via hooks) |`

The phrase "optional, via hooks" reveals this was always acknowledged as not-wired in the primary path. The Mode B code in `update-task-status.sh` IS the intended hook — but extension implementers bypass it.

### Sub-issue 3: Artifact Link Injection into Task Order

**`link-artifact-todo.sh` verdict**: Cannot inject into Task Order. The script anchors on:
```bash
heading_line=$(safe_grep -n "^### ${task_number}\." "$TODO_FILE" | head -1 | cut -d: -f1)
```
In the wave+tree Task Order format, task entries look like `233 [PLANNED] — desc` (no `### N.` prefix). The `^### 233\.` pattern only matches the Tasks section heading `### 233. S5 modal tableau rules...`. The script then operates within the bounded entry block between this heading and the next `### ` heading — staying inside `## Tasks`.

**Actual contamination source**: Direct agent edits to the Task Order section. When extension implementers (lean, nvim) apply the four-case Edit logic from `artifact-linking-todo.md` manually, they may:
1. See `233 [PLANNED] — desc` in the Task Order and recognize it as a task entry
2. Apply the four-case logic to it (since the document doesn't prohibit Task Order edits)
3. Insert artifact links immediately after the tree node line

`artifact-linking-todo.md` says "Read the task's entry in `specs/TODO.md`" but does NOT specify "find the `## Tasks` section heading `### N. Title`" as the anchor. An agent interpreting the document may use any visible task-reference as the target.

**Confirmed by BimodalLogic evidence**:
- `specs/TODO.md` lines 71-73 show artifact links embedded in the Task Order tree entry for task 233
- These lines have `  - **Research**:` / `  - **Plan**:` / `  - **Summary**:` indented under `233 [COMPLETED]`
- The same artifacts are correctly linked in the `## Tasks` section at lines 355-356
- The contamination appeared in commit `f99eca6d1` (lean extension implementer completing task 233)

---

## Decisions

1. The Phase 3 Mode A grep patterns need NO changes (they are already robust).
2. Mode B needs to fire for ALL task types, not just those using the core `skill-implementer`.
3. The documentation gap in `artifact-linking-todo.md` is the root cause of Task Order contamination.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Fixing lean/nvim skills to call `update-task-status.sh` may break existing behavior | Test on a non-critical task; the script is idempotent |
| Adding prohibition to `artifact-linking-todo.md` may not prevent all agent edits | Also add prohibition to lean/nvim implementer SKILLs directly |
| generate-task-order.sh regeneration wipes Task Order and rewrites from state.json | This is the intended behavior; only apply for terminal transitions |

---

## Recommendations for Implementation (Plan 01)

### Fix 1: Update `artifact-linking-todo.md` to Prohibit Task Order Edits

Add a prominent warning:
```
**IMPORTANT**: Apply this logic ONLY to task entries in the `## Tasks` section.
The anchor for finding the task entry is the `## Tasks` section heading `### {N}. {Title}`.
NEVER apply artifact linking to tree entries in the `## Task Order` section.
Task Order entries use format `{N} [STATUS] — desc` (no `### ` prefix) and must
not be manually edited — they are auto-generated by generate-task-order.sh.
```

### Fix 2: Update Extension Implementer SKILLs (lean, nvim) to Call `update-task-status.sh`

In `extensions/lean/skills/skill-lean-implementation/SKILL.md` and `skills/skill-neovim-implementation/SKILL.md`, replace the manual state.json + TODO.md update pattern with:
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
```
This ensures Mode B fires for terminal transitions regardless of task type.

### Fix 3 (Optional): Guard Against Existing Task Order Contamination

Add a post-processing step in `generate-task-order.sh` or `update-task-status.sh` Mode A that strips artifact link lines from Task Order tree entries before re-inserting the correct entry. Since `generate-task-order.sh` fully regenerates the section, this is automatically handled whenever Mode B fires or a full regeneration is triggered.

---

## Context Extension Recommendations

- **Topic**: Extension implementer skill conformance with centralized update scripts
- **Gap**: No documentation explicitly states that extension implementer skills must call `update-task-status.sh` (not just `postflight-workflow.sh`) to trigger Mode B Task Order regeneration.
- **Recommendation**: Add a note to `.claude/context/patterns/artifact-linking-todo.md` and the extension development guide specifying that `update-task-status.sh postflight implement` is required for Mode B to fire.

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/scripts/update-task-status.sh` — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/link-artifact-todo.sh` — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/generate-task-order.sh` — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-workflow.sh` — Full read
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-out.sh` — Full read
- `/home/benjamin/.config/nvim/.claude/extensions/core/skills/skill-implementer/SKILL.md` — Partial
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` — Grep
- `/home/benjamin/.config/nvim/.claude/skills/skill-neovim-implementation/SKILL.md` — Grep
- `/home/benjamin/.config/nvim/.claude/context/formats/task-order-format.md` — Partial
- `/home/benjamin/.config/nvim/.claude/context/patterns/artifact-linking-todo.md` — Full read
- `/home/benjamin/.config/nvim/.claude/rules/state-management.md` — Partial
- `/home/benjamin/Projects/BimodalLogic/specs/TODO.md` — Partial
- `/home/benjamin/Projects/BimodalLogic/specs/state.json` — jq queries
- BimodalLogic git log and diff history (commits f99eca6d1, 1a9b4c040)

### Key Grep Commands Used
```bash
grep -rn "generate-task-order" /home/benjamin/.config/nvim/.claude/ --include="*.sh" --include="*.md"
grep -rn "link-artifact-todo" /home/benjamin/.config/nvim/.claude/ --include="*.md" --include="*.sh"
grep -n "Task Order\|link-artifact" extensions/lean/skills/skill-lean-implementation/SKILL.md
```

### Empirical Tests
```bash
# Mode A grep pattern - tested directly:
echo "  └─ 233 [PLANNED] — test" | grep -E "^\s*(└─ )?233 \["  # match
echo "233 [PLANNED] — test" | grep -E "^\s*(└─ )?233 \["        # match
echo "  - **Research**: [specs/233_...]" | grep -E "^\s*(└─ )?233 \["  # no match
```

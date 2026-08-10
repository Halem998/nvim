# Research Report: Task #651

**Task**: 651 - Update rules and documentation for new state.json-first architecture
**Started**: 2026-06-10T00:00:00Z
**Completed**: 2026-06-10T00:30:00Z
**Effort**: 1 hour
**Dependencies**: Tasks 647, 648, 649, 650, 653
**Sources/Inputs**: Codebase exploration of .claude/rules/, .claude/skills/, .claude/commands/, .claude/extensions/core/, .claude/context/
**Artifacts**: - specs/651_update_rules_and_documentation/reports/01_docs-update-research.md
**Standards**: report-format.md

---

## Executive Summary

- 11 files need documentation updates to remove old dual-write / Edit-TODO.md instructions
- The archive-task.sh in `.claude/extensions/core/scripts/` still uses Python-based entry removal and needs to call generate-todo.sh instead
- The `command-lifecycle.md` and `system-overview.md` architecture docs extensively reference the two-phase dual-write pattern and need holistic rewrites
- `skill-status-sync/SKILL.md` (K1-K3) still instructs Edit-based TODO.md updates for all three operations
- Four extension skills (nix/neovim research/implement) still reference `artifact-linking-todo.md` for Edit-based artifact linking
- `skill-reviser/SKILL.md` (K10) instructs Edit tool to update description in TODO.md
- `skill-todo/SKILL.md` (K17-K20) uses Edit-based entry removal and sed-based vault renumbering
- `preflight-postflight.md` (context/workflows/) references old status-sync-manager delegation pattern
- Priority: fix skills and scripts first (active agents read them), then fix architecture docs

---

## Context & Scope

Tasks 647-650 and 653 completed a major architectural shift: state.json is now the single source of truth, and `generate-todo.sh` regenerates the entire TODO.md from state.json on every status change. This replaces the previous "dual-write" pattern where every status update required both a jq write to state.json AND an Edit tool call to TODO.md.

The audit code-named specific locations K1-K20 and C10-C11. This research maps all findings to those codes and adds additional files not covered by the original audit.

---

## Findings

### Category A: Already Updated (by Tasks 649/650/653)

These files were correctly updated and should NOT be modified:

| File | Status | Notes |
|------|--------|-------|
| `.claude/scripts/archive-task.sh` | **UPDATED** | Calls `generate-todo.sh` (line 113-118) — correctly implements new pipeline |
| `.claude/scripts/update-task-status.sh` | **UPDATED** | Has `PIPELINE_MODE=new` defaulting to generate-todo.sh; legacy awk/sed path retained as fallback |
| `.claude/scripts/skill-base.sh` | **UPDATED** | No longer edits TODO.md directly |
| `.claude/scripts/postflight-workflow.sh` | **UPDATED** | No longer edits TODO.md directly |
| `.claude/rules/artifact-formats.md` | **PARTIALLY UPDATED** | Lines 109-115: correctly says to call `generate-todo.sh`; the section title and prohibition note are accurate. No further changes needed here. |
| `.claude/commands/implement.md` | **PARTIALLY UPDATED** | Line 176 (Step 6): already says `bash .claude/scripts/generate-todo.sh` for defensive TODO.md correction — this is correct. Does NOT need the C10-C11 removal mentioned in the task description (those may have already been removed in task 649). |
| `skill-reviser/SKILL.md` Stage 8 | **UPDATED** | Line 383: already calls `generate-todo.sh` for artifact linking after plan revision. This part is correct. |

**Note on implement.md C10-C11**: The task description mentions removing "defensive TODO.md status correction (C10-C11)" from `commands/implement.md`. Reviewing the current file, Step 6 at line 176 now correctly says to call `generate-todo.sh` rather than using Edit tool directly. This appears to already be updated. The "defensive correction" instruction is now a generate-todo.sh call, which is the correct new pattern.

---

### Category B: Needs Updates (Active Issues)

#### B1: `.claude/rules/state-management.md` — MEDIUM PRIORITY

**Issue**: The "Two-Phase Update Pattern" section (lines 47-66) describes the old prepare+commit dual-write pattern that is no longer the correct approach.

**Lines to change**:
- Lines 47-66: Remove the entire "Two-Phase Update Pattern" section

**What to write instead**: Replace with a "State-First Update Pattern" section explaining:
- Write to state.json first
- Call `generate-todo.sh` to regenerate TODO.md from state.json
- Agents/skills must not Edit TODO.md directly

**Lines 8-9** ("File Synchronization" intro): The statement "Any update to one requires updating the other" is still accurate but could be clarified — agents update state.json only; generate-todo.sh handles TODO.md synchronization.

**Lines 103-105** ("Responsible Scripts" table): Already correct — references `update-task-status.sh` and `generate-task-order.sh` for task status changes. No change needed here.

---

#### B2: `.claude/extensions/core/rules/state-management.md` — MEDIUM PRIORITY

**Issue**: This is a copy/mirror of the main state-management.md and contains the same "Two-Phase Update Pattern" section (lines 42-61).

**Lines to change**: Same as B1 — remove lines 42-61 (Two-Phase Update Pattern section) and replace with State-First Update Pattern description.

---

#### B3: `.claude/context/workflows/command-lifecycle.md` — HIGH PRIORITY (INFORMATIONAL)

**Issue**: The entire document is built around "Two-Phase Status Update Pattern" and describes the old model where both TODO.md and state.json are updated by status-sync-manager. It also references `status-sync-manager` as a skill, which may be outdated.

**Key outdated sections**:
- Title itself: "Two-Phase Status Update Pattern" (line 1)
- Lines 54-178: Entire "Two-Phase Status Update Pattern" section
- Lines 182-251: "Implementation Details" (references `status-sync-manager` with timeout, validates `files_updated includes ["TODO.md", "state.json"]`)
- Lines 301-313: "Atomic Updates" for `/task` command — references "Edit tool" for TODO.md writes
- Lines 447: "All workflow subagents MUST implement two-phase status updates"

**What this document should say**: The new architecture is: (1) update state.json via jq, (2) call `update-task-status.sh` which calls `generate-todo.sh`, (3) TODO.md is fully regenerated. The "two-phase" concept still exists (preflight → work → postflight) but the dual-file synchronization is now automated via the script.

**Recommendation**: Rewrite the "Two-Phase Status Update Pattern" section to be "State-First Status Update Pattern". Keep the preflight/postflight distinction but describe the new mechanics.

---

#### B4: `.claude/extensions/core/context/workflows/command-lifecycle.md` — HIGH PRIORITY (INFORMATIONAL)

**Issue**: Identical copy of B3 above. Needs the same updates.

---

#### B5: `.claude/docs/architecture/system-overview.md` — LOW PRIORITY (INFORMATIONAL)

**Issue**: Lines 251-254 describe "two-phase commit" for state updates:
```
Updates use two-phase commit:
1. Write state.json first
2. Write TODO.md second
3. Rollback both on any failure
```

**Change**: Update step 2 from "Write TODO.md second" to "Regenerate TODO.md via generate-todo.sh" and remove step 3 (rollback is less relevant when TODO.md is derived).

---

#### B6: `.claude/extensions/core/docs/architecture/system-overview.md` — LOW PRIORITY

**Issue**: Identical copy of B5. Same lines 251-254 need the same update.

---

#### B7: `skill-status-sync/SKILL.md` — HIGH PRIORITY (K1-K3)

**Issue**: The skill still instructs Edit-based TODO.md manipulation across all three operations.

**Specific problems**:

1. **K1 — `preflight_update` operation** (lines 106-108):
   ```
   3. **Update TODO.md status marker**:
      - Find task entry: `grep -n "^### {task_number}\." specs/TODO.md`
      - Use Edit tool to change `[OLD_STATUS]` to `[NEW_STATUS]`
   ```
   **Fix**: Replace with: call `update-task-status.sh preflight {task_number} {operation} {session_id}` (the script now calls generate-todo.sh internally).

2. **K2 — `postflight_update` operation** (lines 155-159):
   ```
   3. **Update TODO.md status marker**:
      - Use Edit to change status: `[RESEARCHING]` -> `[RESEARCHED]`
   4. **Link artifacts in TODO.md**:
      - Add research/plan/summary links in appropriate location
   ```
   **Fix**: Replace with: call `update-task-status.sh postflight {task_number} {operation} {session_id}`, then call `generate-todo.sh` to regenerate TODO.md with artifact links.

3. **K3 — `artifact_link` operation** (lines 181-213):
   - Line 181-184: Idempotency check queries TODO.md directly — should query state.json instead
   - Lines 205-213: "Add link to TODO.md using Edit tool" with reference to `artifact-linking-todo.md`
   **Fix**: Remove Edit-based linking. Instead: add artifact to state.json, then call `generate-todo.sh`.

**Additional**: Line 4 `allowed-tools: Bash, Edit, Read` — `Edit` can be removed if no longer used for TODO.md manipulation. However, it may still be needed for the `description_updated` path in skill-reviser. For skill-status-sync specifically, `Edit` can be removed from allowed-tools.

---

#### B8: `skill-nix-implementation/SKILL.md` — HIGH PRIORITY (K4-K5)

**Issue**:

1. **K4 — Preflight** (line 44):
   ```
   **Update TODO.md**: Use Edit tool to change status marker from `[PLANNED]` to `[IMPLEMENTING]`.
   ```
   **Fix**: Remove this line. The `update-task-status.sh preflight` call on line 42 already handles this via generate-todo.sh.

2. **K5 — Postflight artifact linking** (line 267):
   ```
   TODO.md status already updated by script. Link artifact using count-aware format: apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`, `next_field=**Description**`.
   ```
   **Fix**: Replace with: add artifact to state.json (already done in Steps 4a-4b), then call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md with the artifact linked.

---

#### B9: `skill-neovim-implementation/SKILL.md` — HIGH PRIORITY (K6-K7)

**Issue**:

1. **K6 — Stage 8 artifact linking** (line 251):
   ```
   **Update TODO.md**: Link artifact using count-aware format. Apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`, `next_field=**Description**`.
   ```
   **Fix**: Replace with: add artifact to state.json artifacts array, then call `bash .claude/scripts/generate-todo.sh`.

2. **K7 — MUST NOT list** (line 319):
   ```
   - Updating TODO.md status marker via Edit
   ```
   **Fix**: Remove this bullet from the "postflight is LIMITED TO" section. The list should say "Calling generate-todo.sh to regenerate TODO.md" instead.

---

#### B10: `skill-nix-research/SKILL.md` — HIGH PRIORITY (K8)

**Issue — Stage 8** (line 180):
```
**Update TODO.md**: Link artifact using count-aware format. Apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`, `next_field=**Plan**`.
```
**Fix**: Replace with: add artifact to state.json, then call `bash .claude/scripts/generate-todo.sh`.

---

#### B11: `skill-neovim-research/SKILL.md` — HIGH PRIORITY (K9)

**Issue — Stage 8** (line 180): Identical to K8 above.
```
**Update TODO.md**: Link artifact using count-aware format. Apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`, `next_field=**Plan**`.
```
**Fix**: Same as K8 — replace with state.json update + generate-todo.sh call.

---

#### B12: `skill-reviser/SKILL.md` — HIGH PRIORITY (K10)

**Issue — Stage 7 description update path** (lines 317-319):
```
Then use Edit tool to update the description in TODO.md.
```
**Fix**: Replace with: after updating `description` field in state.json, call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md with the new description.

**Note**: Lines 380-384 (Stage 8, plan revision path) already correctly call `generate-todo.sh` — no change needed there.

---

#### B13: `skill-todo/SKILL.md` — HIGH PRIORITY (K17-K20)

**Issue 1 — K17-K18: Stage 10 entry removal** (lines 316-334):
The skill instructs Edit-based removal of TODO.md entries during archival:
```
3. Update specs/TODO.md:
   - Remove archived entries...
   - Use Edit tool to remove validated entries:
     edit_file("specs/TODO.md", old_entry_content, "")
```
**Fix**: Remove the entire sub-step 3 block within Stage 10. The `archive-task.sh` script (which already calls `generate-todo.sh`) handles this. After state.json removal (sub-step 2), call `archive-task.sh` or `generate-todo.sh` directly.

**Issue 2 — K19-K20: Vault renumbering via sed** (lines 618-698):
Sub-step 9.3 instructs TODO.md updates via sed:
```bash
# Update task headers: ### 1001. Title -> ### 1. Title
sed -i "s/^### ${old_num}\./### ${new_num}./" specs/TODO.md
# Update artifact links with directory references
sed -i "s|${old_padded}_|${new_padded}_|g" specs/TODO.md
sed -i "s|${old_num}_|${new_padded}_|g" specs/TODO.md
# Update dependency references
sed -i "s|Task #${old_num}|Task #${new_num}|g" specs/TODO.md
```
And sub-step 9.4 adds a vault transition comment via sed (lines 685-698).

**Fix**: After the state.json renumbering in 9.3 and 9.4, call `generate-todo.sh` once to regenerate TODO.md with correct task numbers, artifact paths, and vault comments. The sed-based TODO.md manipulation can be removed entirely, since generate-todo.sh will pick up all changes from state.json.

**Note**: The sed-based code updating TODO.md entries in vault (lines 618-635) should be deleted since generate-todo.sh will regenerate from state.json. The vault transition comment (lines 685-698) can be replaced with a `generate-todo.sh` call after state.json is updated.

---

#### B14: `.claude/extensions/core/scripts/archive-task.sh` — CRITICAL (outdated copy)

**Issue**: The extension copy of archive-task.sh (at `.claude/extensions/core/scripts/archive-task.sh`) uses Python-based TODO.md entry removal (lines 110-154 in the extension file). This is the old pattern.

**Current behavior** (lines 110-154 in extension copy):
```python
python3 - "$TODO_FILE" "$task_number" <<'PYEOF' 2>/dev/null || true
# ... Python code that finds and removes task block from TODO.md
```

**Fix**: Replace the entire "C. Update TODO.md" section with the new pattern from the main `archive-task.sh`:
```bash
# --- C. Regenerate TODO.md from state.json ---
GENERATE_TODO="$SCRIPT_DIR/generate-todo.sh"
if [ -f "$GENERATE_TODO" ]; then
  bash "$GENERATE_TODO" 2>/dev/null \
    || echo "Warning: generate-todo.sh failed (non-fatal)" >&2
  echo "Regenerated TODO.md after archiving task $task_number"
else
  echo "Note: generate-todo.sh not found -- skipping TODO.md regeneration" >&2
fi
```

---

#### B15: `.claude/context/workflows/preflight-postflight.md` — MEDIUM PRIORITY

**Issue**: This 589-line document describes the old architecture where `status-sync-manager` skill is delegated to for both preflight and postflight updates. It validates `files_updated includes TODO.md and state.json` (lines 87, 104, 208). It also references direct artifact linking in TODO.md (lines 219-220).

**Key outdated sections**:
- Lines 57-108: Pattern section delegates to `status-sync-manager` skill
- Lines 208, 219-220, 228: Verify `files_updated includes TODO.md and state.json`
- Line 290: "Link artifacts to TODO.md/state.json (command responsibility)" — now it's generate-todo.sh's responsibility

**Fix**: Update the pattern to use `update-task-status.sh` script calls instead of `status-sync-manager` delegation. Remove references to verifying that `files_updated includes TODO.md`. Update artifact linking description to say "update state.json artifacts array, then call generate-todo.sh."

**Note**: This file may be obsolete/superseded by the newer scripts. Check if it's still referenced from the context index.

---

#### B16: `.claude/CLAUDE.md` "State Synchronization" section — LOW PRIORITY

**Issue**: The "State Synchronization" section says:
> "Update state.json first (machine state), then TODO.md (user-facing)."

This still implies manual dual-write. The correct statement is: "Update state.json first, then call generate-todo.sh to regenerate TODO.md."

**Lines to change**: The single line "TODO.md and state.json must stay synchronized. Update state.json first (machine state), then TODO.md (user-facing)."

**Fix**: Change to: "TODO.md is generated from state.json. Update state.json first, then call `bash .claude/scripts/generate-todo.sh` to regenerate TODO.md."

---

### Summary Inventory by Priority

#### CRITICAL (executable scripts with wrong behavior)
| File | Issue | Lines |
|------|-------|-------|
| `.claude/extensions/core/scripts/archive-task.sh` | Python TODO.md entry removal (old pattern) | 110-154 |

#### HIGH PRIORITY (active skill instructions that agents follow)
| File | Code | Issue | Lines |
|------|------|-------|-------|
| `skill-status-sync/SKILL.md` | K1 | preflight_update: Edit TODO.md status | 106-108 |
| `skill-status-sync/SKILL.md` | K2 | postflight_update: Edit TODO.md status + artifact links | 155-159 |
| `skill-status-sync/SKILL.md` | K3 | artifact_link: Edit TODO.md links | 181-213 |
| `skill-nix-implementation/SKILL.md` | K4 | Preflight: Edit TODO.md status | 44 |
| `skill-nix-implementation/SKILL.md` | K5 | Postflight: artifact-linking-todo.md Edit pattern | 267 |
| `skill-neovim-implementation/SKILL.md` | K6 | Stage 8: artifact-linking-todo.md Edit pattern | 251 |
| `skill-neovim-implementation/SKILL.md` | K7 | MUST NOT list: "via Edit" language | 319 |
| `skill-nix-research/SKILL.md` | K8 | Stage 8: artifact-linking-todo.md Edit pattern | 180 |
| `skill-neovim-research/SKILL.md` | K9 | Stage 8: artifact-linking-todo.md Edit pattern | 180 |
| `skill-reviser/SKILL.md` | K10 | Description update: Edit TODO.md | 319 |
| `skill-todo/SKILL.md` | K17 | Stage 10: Edit-based entry removal | 316-334 |
| `skill-todo/SKILL.md` | K18 | Stage 10: Edit pattern with Lua pseudo-code | 328-332 |
| `skill-todo/SKILL.md` | K19 | Sub-step 9.3: sed-based TODO.md renumber | 618-635 |
| `skill-todo/SKILL.md` | K20 | Sub-step 9.4: sed-based vault comment | 685-698 |

#### MEDIUM PRIORITY (rules/docs that agents may consult)
| File | Issue | Lines |
|------|-------|-------|
| `.claude/rules/state-management.md` | Two-Phase Update Pattern section | 47-66 |
| `.claude/extensions/core/rules/state-management.md` | Two-Phase Update Pattern section (copy) | 42-61 |
| `.claude/context/workflows/preflight-postflight.md` | status-sync-manager delegation pattern | 57-108, 208, 219-228, 290 |
| `.claude/CLAUDE.md` | "Update state.json first, then TODO.md" | State Synchronization section |

#### LOW PRIORITY (architecture docs / user-facing docs)
| File | Issue | Lines |
|------|-------|-------|
| `.claude/context/workflows/command-lifecycle.md` | Entire "Two-Phase Status Update Pattern" | 1, 54-178, 182-251, 447 |
| `.claude/extensions/core/context/workflows/command-lifecycle.md` | Same (copy) | Same line ranges |
| `.claude/docs/architecture/system-overview.md` | "two-phase commit" for state updates | 251-254 |
| `.claude/extensions/core/docs/architecture/system-overview.md` | Same (copy) | Same line ranges |

---

## Decisions

- **Do not remove the "Two-Phase" terminology entirely from `command-lifecycle.md`** — the concept of preflight/postflight as two phases is still valid. Only the dual-file-write semantics need updating.
- **`commands/implement.md` line 176 is already correct** — the Step 6 defensive correction already calls `generate-todo.sh`. No change needed.
- **`skill-reviser/SKILL.md` Stage 8 (plan revision, line 383) is already correct** — calls `generate-todo.sh`. Only Stage 7 description-update path (line 319) needs fixing.
- **The main `archive-task.sh` is already updated** — only the extension copy at `.claude/extensions/core/scripts/archive-task.sh` needs updating.
- **`artifact-formats.md` is already updated** — the prohibition note and generate-todo.sh instruction are correct.

---

## Risks & Mitigations

- **Risk**: skill-todo K17-K20 changes require careful coordination — the vault renumber sed calls are interleaved with state.json updates. If generate-todo.sh is called too early (before all renumbering state.json writes complete), the generated TODO.md will use old numbers.
  - **Mitigation**: Call `generate-todo.sh` once after ALL state.json renumbering in 9.3-9.4 is complete, not in between steps.

- **Risk**: skill-status-sync is marked "standalone use only" — changes to it affect recovery and manual correction workflows.
  - **Mitigation**: Update the skill to call `update-task-status.sh` (which already handles the new pipeline) rather than removing the functional logic entirely.

- **Risk**: `command-lifecycle.md` and `preflight-postflight.md` are long documents that may be referenced by context discovery. A large rewrite could break context loading.
  - **Mitigation**: Update in-place, keeping section names/headings stable where possible; only rewrite the content.

---

## Context Extension Recommendations

- **Topic**: State update pipeline documentation
- **Gap**: No single authoritative document explains "update state.json → call generate-todo.sh → TODO.md regenerated". The closest is update-task-status.sh itself but there's no agent-facing context file.
- **Recommendation**: After task 651 completes, add a `state-first-architecture.md` to `.claude/context/patterns/` describing the new pipeline, which can replace the outdated references in command-lifecycle.md.

---

## Appendix

### Files Reviewed
1. `.claude/rules/state-management.md`
2. `.claude/rules/artifact-formats.md`
3. `.claude/rules/workflows.md` (no old patterns found)
4. `.claude/rules/plan-format-enforcement.md` (no old patterns found)
5. `.claude/skills/skill-status-sync/SKILL.md`
6. `.claude/skills/skill-nix-implementation/SKILL.md`
7. `.claude/skills/skill-neovim-implementation/SKILL.md`
8. `.claude/skills/skill-nix-research/SKILL.md`
9. `.claude/skills/skill-neovim-research/SKILL.md`
10. `.claude/skills/skill-reviser/SKILL.md`
11. `.claude/skills/skill-todo/SKILL.md`
12. `.claude/scripts/archive-task.sh` (main — already updated)
13. `.claude/extensions/core/scripts/archive-task.sh` (extension copy — needs update)
14. `.claude/commands/implement.md` (already updated)
15. `.claude/context/workflows/command-lifecycle.md`
16. `.claude/extensions/core/context/workflows/command-lifecycle.md`
17. `.claude/context/workflows/preflight-postflight.md`
18. `.claude/context/reference/workflow-diagrams.md` (no old patterns found)
19. `.claude/context/reference/state-management-schema.md` (no old patterns found)
20. `.claude/docs/architecture/system-overview.md`
21. `.claude/extensions/core/docs/architecture/system-overview.md`
22. `.claude/extensions/core/rules/state-management.md`
23. `.claude/CLAUDE.md` (State Synchronization section)

### Key New Scripts (Context)
- `generate-todo.sh` — generates full TODO.md from state.json
- `update-task-status.sh` — updates state.json + calls generate-todo.sh (PIPELINE_MODE=new default)
- `archive-task.sh` (main) — removes from state.json + calls generate-todo.sh
- `update-phase-status.sh` — updates plan phase markers (not TODO.md)

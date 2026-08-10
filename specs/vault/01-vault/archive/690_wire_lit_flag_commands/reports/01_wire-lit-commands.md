# Research Report: Task #690

**Task**: 690 - Wire --lit flag through /research, /plan, /implement, /orchestrate commands
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:05:00Z
**Effort**: 0.5 hours
**Dependencies**: Task 688 (COMPLETED) - LIT_FLAG added to parse-command-args.sh
**Sources/Inputs**: Codebase — .claude/commands/{research,plan,implement,orchestrate}.md, .claude/scripts/parse-command-args.sh, .claude/extensions/core/commands/
**Artifacts**: specs/690_wire_lit_flag_commands/reports/01_wire-lit-commands.md
**Standards**: report-format.md

## Executive Summary

- `parse-command-args.sh` already exports `LIT_FLAG` ("true"/"false") as of task 688
- `research.md` and `plan.md` use inline STAGE 1.5 flag parsing (no `parse-command-args.sh`); they need manual lit_flag extraction added as item 6 (after clean_flag) and must strip `--lit` from the focus_prompt removal step
- `implement.md` and `orchestrate.md` use `parse-command-args.sh` in STAGE 0, so LIT_FLAG is already parsed; they only need the export comment updated and lit_flag added to the skill args strings in STAGE 2
- All four command files have identical copies in `.claude/extensions/core/commands/` that must be synced

## Context & Scope

Task 688 added `--lit` parsing to `parse-command-args.sh`. Task 690 threads `LIT_FLAG`/`lit_flag` through the four workflow commands that delegate to skills. The flag is a literature-mode hint (e.g., for paper-to-code tasks). Task 689 handles the skill-layer changes (skill SKILL.md files) — those files are out of scope here.

---

## Findings

### research.md

**File**: `/home/benjamin/.config/nvim/.claude/commands/research.md`

**1. Options table** (line 30-39): Add `--lit` row after `--clean` row.

Current table ends at line 39:
```
| `--clean` | Skip automatic memory and roadmap retrieval | false |
```
Insert after line 39:
```
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based research | false |
```

**2. STAGE 1.5 PARSE FLAGS — item 5 (Extract Clean Flag)** (lines 301-305):

Current item 5 ends at line 305:
```
   If not present: `clean_flag = false`
```
Current item 6 is "Extract Focus Prompt" (line 307).

Insert new item 6 between "Extract Clean Flag" and "Extract Focus Prompt":

```
6. **Extract Lit Flag**
   Check remaining args for literature mode:
   - `--lit` -> `lit_flag = true` (literature-based task: paper-to-code, spec-to-implementation)

   If not present: `lit_flag = false`
```

Then renumber old item 6 "Extract Focus Prompt" to item 7, and update its `--lit` removal line.

**3. STAGE 1.5 PARSE FLAGS — item 6/7 (Extract Focus Prompt)** (lines 307-315):

The flag-stripping list currently removes:
- `--team`, `--team-size N`, `--fast`, `--hard`, `--haiku`, `--sonnet`, `--opus`, `--clean`

Add `--lit` to the removal list (line 313 after `--clean`):
```
   - Remove `--lit`
```

**4. STAGE 2: DELEGATE — skill args** (lines 392 and 396):

Line 392 (team mode):
```
args: "task_number={N} focus={focus_prompt} team_size={team_size} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"
```
Change to:
```
args: "task_number={N} focus={focus_prompt} team_size={team_size} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} lit_flag={lit_flag}"
```

Line 396 (single-agent mode):
```
args: "task_number={N} focus={focus_prompt} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"
```
Change to:
```
args: "task_number={N} focus={focus_prompt} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} lit_flag={lit_flag}"
```

---

### plan.md

**File**: `/home/benjamin/.config/nvim/.claude/commands/plan.md`

**1. Options table** (lines 29-34): Add `--lit` row after `--clean` row (line 34).

Current:
```
| `--clean` | Skip automatic memory retrieval | false |
```
Insert after line 34:
```
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based planning | false |
```

**2. STAGE 1.5 PARSE FLAGS — item 5 (Extract Clean Flag)** (lines 309-313):

Current item 5:
```
5. **Extract Clean Flag**
   Check remaining args for memory retrieval suppression:
   - `--clean` -> `clean_flag = true` (skip automatic memory retrieval)

   If not present: `clean_flag = false`
```

Current item 6 is "Extract Roadmap Flag" (lines 315-319). Insert new item 6 between Clean Flag and Roadmap Flag, and renumber Roadmap Flag to item 7:

```
6. **Extract Lit Flag**
   Check remaining args for literature mode:
   - `--lit` -> `lit_flag = true` (literature-based task: paper-to-code, spec-to-implementation)

   If not present: `lit_flag = false`
```

Note: plan.md does NOT have an explicit focus-prompt strip step (the flags section ends without a "Remove flags from remaining args" sub-step, as plan.md has no focus_prompt). No additional strip step needed.

**3. STAGE 2: DELEGATE — skill args** (lines 394, 398, 402):

Line 394 (team mode):
```
args: "task_number={N} research_path={...} prior_plan_path={...} team_size={team_size} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} roadmap_flag={roadmap_flag}"
```
Change to append `lit_flag={lit_flag}`.

Line 398 (extension-routed):
```
args: "task_number={N} research_path={...} prior_plan_path={...} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} roadmap_flag={roadmap_flag}"
```
Change to append `lit_flag={lit_flag}`.

Line 402 (default single-agent):
```
args: "task_number={N} research_path={...} prior_plan_path={...} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag} roadmap_flag={roadmap_flag}"
```
Change to append `lit_flag={lit_flag}`.

---

### implement.md

**File**: `/home/benjamin/.config/nvim/.claude/commands/implement.md`

**Architecture note**: `implement.md` already calls `parse-command-args.sh` at STAGE 0 (line 44), which exports `LIT_FLAG` after task 688. No new flag parsing step is needed.

**1. Options table** (lines 19-29): Add `--lit` row after `--clean` row (line 29).

Current:
```
| `--clean` | Skip automatic memory retrieval | false |
```
Insert after line 29:
```
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based implementation | false |
```

**2. STAGE 0 export comment** (lines 45-46):

Current:
```
# Exports: TASK_NUMBERS, REMAINING_ARGS, TEAM_MODE, TEAM_SIZE, EFFORT_FLAG, MODEL_FLAG,
#          CLEAN_FLAG, FORCE_FLAG, FOCUS_PROMPT
```
Change to:
```
# Exports: TASK_NUMBERS, REMAINING_ARGS, TEAM_MODE, TEAM_SIZE, EFFORT_FLAG, MODEL_FLAG,
#          CLEAN_FLAG, FORCE_FLAG, LIT_FLAG, FOCUS_PROMPT
```

**3. STAGE 2: DELEGATE — skill args** (lines 143 and 147):

Line 143 (team mode):
```
args: "task_number={N} plan_path={path} resume_phase={phase} team_size={TEAM_SIZE} session_id={SESSION_ID} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} clean_flag={CLEAN_FLAG} orchestrator_mode=false"
```
Change to append `lit_flag={LIT_FLAG}`.

Line 147 (single-agent mode):
```
args: "task_number={N} plan_path={path} resume_phase={phase} session_id={SESSION_ID} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} clean_flag={CLEAN_FLAG} orchestrator_mode=false"
```
Change to append `lit_flag={LIT_FLAG}`.

---

### orchestrate.md

**File**: `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md`

**Architecture note**: `orchestrate.md` already calls `parse-command-args.sh` at STAGE 0 (line 40), which exports `LIT_FLAG`. The command currently has no Options table (it only lists Arguments and Constraints). The delegation context is constructed at two places: single-task STAGE 2 (line 322) and multi-task STAGE 4 dispatch (lines 192-199).

**1. No Options table**: orchestrate.md does not have a flags options table. The `--lit` flag does not need to be documented here (the command passes through flags it receives to the skill; only flags the command itself processes need documentation). However, for consistency with the other commands it would be cleaner to add a brief Options section. Decision: add a minimal Options table.

Add after the `## Constraints` section (approximately after line 28), a new `## Options` section:

```markdown
## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based tasks | false |
```

**2. STAGE 2: DELEGATE — single-task skill args** (lines 322-323):

Current:
```
skill: "skill-orchestrate"
args: "task_number={N} session_id={SESSION_ID} orchestrator_mode=true"
```
Change to:
```
skill: "skill-orchestrate"
args: "task_number={N} session_id={SESSION_ID} orchestrator_mode=true lit_flag={LIT_FLAG}"
```

**3. STAGE 2: DELEGATE — single-task delegation context JSON** (lines 326-341):

Current JSON block ends at:
```json
  "orchestrator_mode": true,
  "focus_prompt": "{FOCUS_PROMPT}"
}
```
Add `"lit_flag": "{LIT_FLAG}"` before the closing brace:
```json
  "orchestrator_mode": true,
  "focus_prompt": "{FOCUS_PROMPT}",
  "lit_flag": "{LIT_FLAG}"
}
```

**4. MULTI-TASK DISPATCH — skill args** (line 198):

Current:
```
args: "multi_task_mode=true task_numbers={task_numbers_json} waves={waves_json} dependency_graph={dep_graph_json} session_id={batch_session_id} focus_prompt={focus_prompt}"
```
Change to append `lit_flag={LIT_FLAG}`.

**5. MULTI-TASK DISPATCH — delegation context JSON** (lines 201-211):

Current JSON ends with `"focus_prompt": "{focus_prompt}"`. Add:
```json
  "focus_prompt": "{focus_prompt}",
  "lit_flag": "{LIT_FLAG}"
```

---

## Extension Core Sync

All four command files have copies in `.claude/extensions/core/commands/` that mirror `.claude/commands/`:

| Source | Extension Core Copy |
|--------|---------------------|
| `.claude/commands/research.md` | `.claude/extensions/core/commands/research.md` |
| `.claude/commands/plan.md` | `.claude/extensions/core/commands/plan.md` |
| `.claude/commands/implement.md` | `.claude/extensions/core/commands/implement.md` |
| `.claude/commands/orchestrate.md` | `.claude/extensions/core/commands/orchestrate.md` |

**Action required**: After editing each `.claude/commands/*.md` file, copy it to the corresponding `.claude/extensions/core/commands/*.md` path. The extension core copies are load targets for the extension sync mechanism; they must be identical to the active command files.

---

## Decisions

1. `research.md` and `plan.md` parse flags inline (STAGE 1.5); a new numbered item for `lit_flag` is inserted after `clean_flag`, following the exact same pattern.
2. `implement.md` and `orchestrate.md` delegate to `parse-command-args.sh`; no new parse step is needed — only the export comment and skill args strings need updating.
3. `orchestrate.md` has no Options table; add a minimal one for consistency.
4. Naming convention: `research.md`/`plan.md` use lowercase `lit_flag` (inline variables); `implement.md`/`orchestrate.md` use uppercase `LIT_FLAG` (environment variable from parse-command-args.sh). The skill args string uses lowercase `lit_flag={LIT_FLAG}` per the pattern of other flags (`clean_flag={CLEAN_FLAG}`).

---

## Risks & Mitigations

- **research.md focus_prompt stripping**: Must add `--lit` to the flag-removal list in item 6/7, otherwise `--lit` leaks into the focus_prompt string. Mitigation: include explicit removal step.
- **plan.md roadmap item renumbering**: Inserting lit_flag as item 6 pushes roadmap_flag to item 7. Must update the numbering in the plan.md STAGE 1.5 section. Mitigation: explicitly renumber in the edit.
- **Extension core drift**: Forgetting to sync causes the extension loader to serve stale command content. Mitigation: sync immediately after each file edit, confirmed by diff check.

## Context Extension Recommendations

none

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/commands/research.md` — lines 30-39 (Options), 265-396 (STAGE 1.5, STAGE 2)
- `/home/benjamin/.config/nvim/.claude/commands/plan.md` — lines 29-34 (Options), 273-403 (STAGE 1.5, STAGE 2)
- `/home/benjamin/.config/nvim/.claude/commands/implement.md` — lines 19-29 (Options), 41-48 (STAGE 0), 116-150 (STAGE 2)
- `/home/benjamin/.config/nvim/.claude/commands/orchestrate.md` — lines 14-28 (Args/Constraints), 37-48 (STAGE 0), 192-211 (multi-task dispatch), 315-341 (STAGE 2 single)
- `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh` — lines 22, 75, 112-113, 129, 138 (LIT_FLAG handling)
- `/home/benjamin/.config/nvim/.claude/extensions/core/commands/` — directory listing confirms all four files present

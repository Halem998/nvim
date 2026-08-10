# Research Report: Task #689

**Task**: 689 - Add --lit context injection to skill preflight (researcher, planner, implementer)
**Started**: 2026-06-12T00:00:00Z
**Completed**: 2026-06-12T00:00:00Z
**Effort**: 1.5 hours estimated
**Dependencies**: Task 688 (COMPLETED) - LIT_FLAG added to parse-command-args.sh
**Sources/Inputs**: Codebase (.claude/scripts/memory-retrieve.sh, skill SKILL.md files, command files)
**Artifacts**: specs/689_lit_context_injection_skill_preflight/reports/01_lit-context-injection.md
**Standards**: report-format.md

---

## Executive Summary

- Task 688 has already added `LIT_FLAG` to `parse-command-args.sh` (line 113 sets `LIT_FLAG="true"` when `--lit` is present; exported at line 138). No changes needed there.
- The memory-retrieve.sh script provides a clear template: takes `description` and `task_type` args, scans an index, and outputs a `<memory-context>` block. The literature script should be simpler (no index needed — just scan `specs/literature/` directly).
- All three target skills (skill-researcher, skill-planner, skill-implementer) have identical Stage 4a patterns gated on `clean_flag`. The `lit_flag` injection should go in the same stage, parallel to memory retrieval.
- skill-orchestrate does NOT currently thread `clean_flag` through its dispatch context — the dispatch contexts at lines 203, 230, 253, 279 are schematic and do not include `clean_flag` or `lit_flag`. Threading `lit_flag` means adding it to the skill's Stage 1 extraction and then including it in each dispatch context JSON.
- Core extension copies at `.claude/extensions/core/skills/` are byte-for-byte identical to the main skill files (diff confirmed), so every change must be applied to BOTH locations.
- Recommended file selection strategy: read ALL files in `specs/literature/` up to a token budget (similar to memory approach), since literature files are typically few and curated by the user.

---

## Context & Scope

Task 689 adds a `--lit` flag pathway that injects content from `specs/literature/` into agent prompts, mirroring the existing `--clean` / memory-retrieve pattern. The feature requires:

1. A new `literature-retrieve.sh` script
2. Additions to Stage 4a in skill-researcher, skill-planner, and skill-implementer
3. Threading `lit_flag` through skill-orchestrate dispatch contexts
4. Syncing all changes to core extension copies

---

## Findings

### Codebase Patterns

#### memory-retrieve.sh Pattern (full script, lines 1-168)

The script:
- **Args**: `description` (required), `task_type` (required), `focus_prompt` (optional)
- **Exit codes**: exit 0 with content on stdout when entries found; exit 1 (empty stdout) when nothing found or index missing
- **Phase 1**: Keyword extraction from description + focus_prompt, scored against `.memory/memory-index.json` entries
- **Phase 2**: Greedy selection within TOKEN_BUDGET=2000, MAX_ENTRIES=5
- **Output format**: `<memory-context>\n...entries...\n</memory-context>` (printf '%b' "$output")
- **Side effect**: Updates retrieval_count and last_retrieved in memory-index.json

For `literature-retrieve.sh`, there is no index to score against. The simpler approach is:
- **Args**: `description` (required), `task_type` (required)
- **Phase 1**: Check `specs/literature/` exists and has files
- **Phase 2**: Read all files up to TOKEN_BUDGET, format as `<literature-context>` block
- **Output format**: `<literature-context>\n...file contents...\n</literature-context>`
- **No side effects** (no index to update)

#### Skill Injection Points (Stage 4a in each skill)

**skill-researcher/SKILL.md** (lines 124-143):
```
### Stage 4a: Memory Retrieval (Auto)
Skip if: clean_flag is true
Line 133: memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
```
Memory context injected in Stage 5 prompt (lines 219-225): placed after format spec, before task instructions. Empty block suppressed.

**skill-planner/SKILL.md** (lines 142-161):
```
### Stage 4a: Memory Retrieval (Auto)
Skip if: clean_flag is true
Line 151: memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
```
Memory context injected in Stage 5 prompt (lines 248-254): same placement pattern.

**skill-implementer/SKILL.md** (lines 139-158):
```
### Stage 4a: Memory Retrieval (Auto)
Skip if: clean_flag is true
Line 148: memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
```
Memory context injected in Stage 5 prompt (lines 234-240): same placement pattern.

All three have identical Stage 5 prompt injection logic with identical placement rules:
1. Delegation context JSON
2. `<artifact-format-specification>` block
3. `{memory_context}` block (if non-empty)
4. Task-specific instructions

The `lit_context` block should be placed at position 3.5 — after memory context, before task instructions. Alternatively it can go alongside memory context at the same position (either order is fine, memory first is conventional).

**Stage 4a expansion template** (to be added after memory retrieval in each skill):
```bash
# Literature context injection
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
fi
```

**Stage 5 prompt injection addition** (to be added after memory_context block):
```
{lit_context from Stage 4a -- already wrapped in <literature-context> tags}
Place AFTER memory context block (if any). Do NOT inject an empty block.
```

#### skill-orchestrate/SKILL.md — Dispatch Context Threading

The skill does NOT currently include `clean_flag` in dispatch contexts (confirmed by search). The dispatch contexts at the following locations are schematic/pseudocode:

- **Line 203** (`not_started` state): Research dispatch — `'{"task_number": N, "task_type": "T", "session_id": "S", "orchestrator_mode": false}'`
- **Line 230** (`researched` state): Plan dispatch — `'{"task_number": N, "task_type": "T", "session_id": "S", "research_artifacts": [...], "orchestrator_mode": false}'`
- **Line 253** (`planned`/`implementing` state): Implement dispatch — similar schematic
- **Line 279** (`partial` state, continuation): Implement dispatch — similar schematic

**Stage 1 extraction addition** (after line 57, where `focus_prompt` is extracted):
```bash
lit_flag=$(echo "$delegation_context" | jq -r '.lit_flag // "false"')
```

Each dispatch context should gain `"lit_flag": "$lit_flag"`. Example for research dispatch:
```
'{"task_number": N, "task_type": "T", "session_id": "S", "orchestrator_mode": false, "lit_flag": "'$lit_flag'"}'
```

**Multi-task mode (Stage MT-4)**: The dispatch contexts for research_tasks, plan_tasks, and implement_tasks at lines 911-919, 936-937, 962-968 also need `lit_flag` threaded through.

#### Command Files — lit_flag in Delegation Context

The command files (research.md, plan.md, implement.md) pass `clean_flag` in their Skill args but not `lit_flag` yet. These also need updating to pass `lit_flag` through. The `LIT_FLAG` variable is already exported by `parse-command-args.sh` (line 138), so the commands just need to include it in the `args:` string passed to the skill.

Currently in research.md (line 392):
```
args: "task_number={N} focus={focus_prompt} team_size={team_size} session_id={session_id} effort_flag={effort_flag} model_flag={model_flag} clean_flag={clean_flag}"
```
Needs:
```
args: "... clean_flag={clean_flag} lit_flag={lit_flag}"
```
Same pattern for plan.md (line 394, 398, 402) and implement.md (line 143, 147).

#### Core Extension Copies

Four files are byte-identical copies that must be updated in sync:
- `.claude/extensions/core/skills/skill-researcher/SKILL.md`
- `.claude/extensions/core/skills/skill-planner/SKILL.md`
- `.claude/extensions/core/skills/skill-implementer/SKILL.md`
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md`

The implementer should apply each change to both `skills/` and `extensions/core/skills/` locations, or use `cp` after editing the primary file.

### External Resources

No external resources needed. This is a pure codebase pattern-matching implementation.

### Recommendations

#### literature-retrieve.sh Design

**Simple "read-all-within-budget" approach** (recommended over keyword matching):
- Literature files in `specs/literature/` are curated by the user specifically for the task at hand. They are few in number and deliberately chosen. Keyword scoring would add complexity without benefit.
- Read all `.md`, `.txt`, `.pdf` (text-renderable) files in `specs/literature/`, accumulating token estimates. Stop when TOKEN_BUDGET (e.g., 4000 tokens) is reached.
- Token estimate: `wc -w file | awk '{print $1 * 1.3}'` (words × 1.3 ≈ tokens)
- Output format: `<literature-context>\n## {filename}\n{content}\n\n...\n</literature-context>`

**Script skeleton**:
```bash
#!/usr/bin/env bash
# literature-retrieve.sh - Inject specs/literature/ files as <literature-context> block
#
# Usage: literature-retrieve.sh <description> <task_type>
#
# Exit 0 with content on stdout when files found
# Exit 1 (empty stdout) when directory missing or empty
#
# Constants:
#   TOKEN_BUDGET=4000  - Maximum total tokens to include
#   MAX_FILES=10       - Maximum number of files

set -euo pipefail

TOKEN_BUDGET=4000
MAX_FILES=10

description="${1:-}"
task_type="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"

# Silently skip if directory doesn't exist
if [ ! -d "$LIT_DIR" ]; then
  exit 1
fi

# Find readable files
files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find "$LIT_DIR" -maxdepth 1 -type f \( -name "*.md" -o -name "*.txt" \) | sort)

if [ ${#files[@]} -eq 0 ]; then
  exit 1
fi

output="<literature-context>\n"
output+="The following literature files from specs/literature/ are provided for this task.\n\n"

total_tokens=0
file_count=0

for f in "${files[@]}"; do
  if [ "$file_count" -ge "$MAX_FILES" ]; then break; fi
  fname=$(basename "$f")
  word_count=$(wc -w < "$f")
  est_tokens=$(awk "BEGIN { printf \"%d\", $word_count * 1.3 }")
  if [ $((total_tokens + est_tokens)) -gt "$TOKEN_BUDGET" ]; then
    output+="### [Truncated: $fname exceeds budget]\n\n"
    break
  fi
  content=$(cat "$f")
  output+="### $fname\n$content\n\n"
  total_tokens=$((total_tokens + est_tokens))
  file_count=$((file_count + 1))
done

output+="</literature-context>"

if [ "$file_count" -eq 0 ]; then
  exit 1
fi

printf '%b' "$output"
exit 0
```

#### Change Summary by File

| File | Change | Notes |
|------|--------|-------|
| `.claude/scripts/literature-retrieve.sh` | CREATE new script | See skeleton above |
| `.claude/commands/research.md` | Add `lit_flag={lit_flag}` to args | ~3 lines (all arg variants) |
| `.claude/commands/plan.md` | Add `lit_flag={lit_flag}` to args | ~3 lines |
| `.claude/commands/implement.md` | Add `lit_flag={lit_flag}` to args | ~2 lines |
| `.claude/skills/skill-researcher/SKILL.md` | Stage 4a: add lit_context retrieval; Stage 5: add injection | ~15 lines |
| `.claude/skills/skill-planner/SKILL.md` | Same pattern | ~15 lines |
| `.claude/skills/skill-implementer/SKILL.md` | Same pattern | ~15 lines |
| `.claude/skills/skill-orchestrate/SKILL.md` | Stage 1: extract lit_flag; all dispatch contexts: add lit_flag; MT-4: add lit_flag | ~20 lines |
| `.claude/extensions/core/skills/skill-researcher/SKILL.md` | Mirror of skills/ change | Use `cp` after editing |
| `.claude/extensions/core/skills/skill-planner/SKILL.md` | Mirror of skills/ change | Use `cp` after editing |
| `.claude/extensions/core/skills/skill-implementer/SKILL.md` | Mirror of skills/ change | Use `cp` after editing |
| `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` | Mirror of skills/ change | Use `cp` after editing |

---

## Decisions

- **File selection strategy**: Read all files within budget (no keyword scoring). Literature files are user-curated; keyword scoring adds complexity without benefit.
- **Token budget**: 4000 for literature (higher than memory's 2000 because literature content is expected to be denser/more directly applicable).
- **Injection order**: Place `<literature-context>` AFTER `<memory-context>` in the prompt, since literature is task-specific and should be closer to the task instructions.
- **Core extension sync**: Use `cp` after editing primary skill files rather than editing both manually.
- **lit_flag gating**: Unlike memory which is skipped by `clean_flag`, literature injection is gated by `lit_flag == true`. The `clean_flag` does NOT suppress literature (they are independent).
- **`clean_flag` interaction**: `--clean --lit` should work: clean suppresses memory, lit still injects literature. The two gates are independent conditions.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Core extension copies drift from main skills | Use `cp` after each skill edit; verify with `diff` |
| Large literature files bloat context | TOKEN_BUDGET cap with truncation notice |
| skill-orchestrate dispatch contexts are schematic (pseudocode), not bash — changes are documentation-level | Document clearly in SKILL.md that these are schema examples; implementer must understand they update the description, not running code |
| Command files may have multiple arg-string lines per command (team, non-team, force variants) | All arg-string variants in each command file must be updated |

---

## Context Extension Recommendations

- **Topic**: Literature-context injection pattern
- **Gap**: No context file documents the `--lit` flag's behavior or the `<literature-context>` injection pattern for new skill authors.
- **Recommendation**: After implementation, add a brief entry to `.claude/context/patterns/` documenting the literature injection pattern analogously to how memory retrieval is documented.

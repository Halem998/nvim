# Research Report: Task #763

**Task**: 763 - Add --lit integration test script
**Started**: 2026-06-23T00:00:00Z
**Completed**: 2026-06-23T00:20:00Z
**Effort**: 30 minutes
**Dependencies**: Tasks 760, 761, 762 (completed)
**Sources/Inputs**: Codebase (skill SKILL.md files, agent .md files, scripts)
**Artifacts**: specs/763_add_lit_integration_test_script/reports/01_lit-pipeline-test-research.md
**Standards**: report-format.md

## Executive Summary

- The --lit pipeline involves three layers: (1) literature-briefing.sh script, (2) skill SKILL.md Stage 4a blocks, and (3) agent .md files with `<literature-briefing>` acknowledgment sections
- All testable claims can be verified via **static analysis** (grep/pattern matching) — no runtime execution of literature-briefing.sh is strictly required for correctness verification, though a runtime smoke test is valuable
- The interactive AskUserQuestion detection block lives only in the **general skills** (skill-researcher, skill-implementer, skill-planner, skill-researcher-hard, skill-implementer-hard) — NOT in the cslib skills (task 760 scope was general skills, task 761 scope was cslib skills which use silent-exit behavior)
- The test script should follow the `validate-wiring.sh` pattern: colored PASS/FAIL/WARN output, counters, summary at end, exit 1 on failures

## Context & Scope

Tasks 760-762 implemented the `--lit` pipeline for CSLib skills:

- **Task 760**: Created `literature-create-setup-task.sh` and added interactive AskUserQuestion detection to 6 skill Stage 4a blocks (general skills: skill-researcher, skill-planner, skill-implementer, and their hard variants — NOT the cslib skills)
- **Task 761**: Added Stage 4a lit_context retrieval (calling `literature-briefing.sh`) into 4 CSLib skill SKILL.md files: skill-cslib-research, skill-cslib-implementation, skill-cslib-research-hard, skill-cslib-implementation-hard
- **Task 762**: Added `## Literature Briefing Context` acknowledgment sections to 4 CSLib agent .md files: cslib-research-agent.md, cslib-implementation-agent.md, cslib-research-hard-agent.md, cslib-implementation-hard-agent.md

The test script should be placed at `.claude/scripts/test-lit-pipeline.sh`.

## Findings

### Codebase Patterns

#### 1. literature-briefing.sh Behavior

The script (`/home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh`) has these properties:
- Reads `specs/literature-index.json` (sub-index, per-repo)
- Reads `$LITERATURE_DIR/index.json` (global index, default `~/Projects/Literature/index.json`)
- Returns empty stdout (exit 0) when: sub-index missing, entries empty, global index missing
- Returns `<literature-briefing>...</literature-briefing>` block on stdout when entries resolve
- The sub-index schema: `{"entries": [{"doc_id": "<id>", "relevance": "<note>"}]}`
- The global index schema requires: entries with `id`, `title`, `authors`, `year`, `token_count`, `path` fields

For a **runtime test**, we need:
1. A temp directory to mock `LITERATURE_DIR` with a valid `index.json`
2. A temp `specs/literature-index.json` with matching `doc_id`
3. Set `LITERATURE_DIR` environment variable to temp dir
4. Verify stdout is non-empty and contains `<literature-briefing>`

The script uses `PROJECT_ROOT` derived from `SCRIPT_DIR/../..`, which means when running from `.claude/scripts/`, it resolves to the project root. The SUB_INDEX path is always `$PROJECT_ROOT/specs/literature-index.json`. This means:
- Runtime test must either create a real `specs/literature-index.json` (and clean up) OR run the script from a temp project tree

**Decision**: Use a temp directory that mimics the project structure, with `LITERATURE_DIR` override. Create a minimal temp project tree under `/tmp/test-lit-XXXXXX/` containing `.claude/scripts/` and `specs/`, then run the script from there. This avoids touching the real `specs/` directory.

However: the script uses `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` and derives PROJECT_ROOT as `SCRIPT_DIR/../..`, so the actual `.claude/scripts/literature-briefing.sh` will always resolve to the real project root. To test it with a mock sub-index, the cleanest approach is:
- Temporarily write a mock `specs/literature-index.json` in the real project root
- Run the script with `LITERATURE_DIR` pointing to a temp dir with a mock global index
- Capture output, then remove the temp sub-index

This is the standard pattern for integration tests on scripts that hardcode their own path.

#### 2. CSLib Skill Stage 4a Pattern

Verified in all 4 cslib skills:
- `skill-cslib-research/SKILL.md` lines 70-80: `lit_context=""` + `if [ "$lit_flag" = "true" ]; then lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""; fi`
- `skill-cslib-implementation/SKILL.md` lines 83-94: same pattern
- `skill-cslib-research-hard/SKILL.md` lines 129-140: same pattern
- `skill-cslib-implementation-hard/SKILL.md` lines 168-179: same pattern

**Test approach**: Static grep for:
- `lit_context=""` initialization
- `literature-briefing.sh` call within `if [ "$lit_flag" = "true" ]` block
- `memory_context` and `lit_context` in the Stage 4/5 prompt parameter description

#### 3. Agent `<literature-briefing>` Acknowledgment

Verified in all 4 cslib agents:
- `cslib-research-agent.md`: Lines 24-35 — `## Literature Briefing Context` section with `<literature-briefing>` block reference
- `cslib-implementation-agent.md`: Lines 22-28 — same section
- `cslib-research-hard-agent.md`: Line 45 — `<literature-briefing>` block mention in context list
- `cslib-implementation-hard-agent.md`: Line 48 — `<literature-briefing>` block mention

**Test approach**: Static grep for `literature-briefing` or `<literature-briefing>` in each agent file.

#### 4. Interactive Detection (Sub-Index Missing)

The AskUserQuestion detection block lives in the **general skills** only (task 760 scope), not in cslib skills. The cslib skills use the silent-exit behavior (delegated to `literature-briefing.sh` which exits 0 when sub-index missing).

The general skills (`skill-researcher`, `skill-implementer`) contain:
- Lines checking `if [ "$lit_flag" = "true" ] && [ ! -f "specs/literature-index.json" ]`
- Conditional checking `$GLOBAL_INDEX` existence
- AskUserQuestion pseudocode with 3 options

**Test approach**: Static grep in `skill-researcher/SKILL.md` and `skill-implementer/SKILL.md` for the detection pattern and `literature-create-setup-task.sh` reference.

#### 5. Existing Test Script Patterns

No existing `test-*.sh` scripts in `.claude/scripts/`. The `validate-wiring.sh` script provides the best style reference:
- Colors: GREEN/RED/YELLOW/BLUE
- Functions: `log_pass()`, `log_fail()`, `log_warn()`, `log_info()`
- Counters: `PASSED`, `FAILED`, `WARNINGS`
- Pattern: function per test group, summary at end, `exit 1` if `$FAILED -gt 0`
- No `set -euo pipefail` (so individual failures don't abort the whole run)

### External Resources

None needed — all behavior is defined by the codebase.

### Recommendations

#### Script Structure: `test-lit-pipeline.sh`

```
#!/usr/bin/env bash
# test-lit-pipeline.sh - Verify --lit pipeline wiring
# Usage: ./.claude/scripts/test-lit-pipeline.sh [--runtime] [--clean]

# Section A: literature-briefing.sh static checks
# Section B: CSLib skill Stage 4a pattern checks (4 files)
# Section C: CSLib agent <literature-briefing> acknowledgment checks (4 files)
# Section D: General skill interactive detection checks (skill-researcher, skill-implementer)
# Section E: literature-create-setup-task.sh existence and syntax
# Section F: Runtime smoke test (optional, requires --runtime flag OR auto-detects real global index)

# Teardown: remove temp sub-index if created
```

**Section A: Script Existence and Syntax**
- Check `literature-briefing.sh` exists and is executable
- Check `literature-create-setup-task.sh` exists and is executable
- Check `bash -n` (syntax check) passes for both scripts

**Section B: CSLib Skill Static Wiring (4 files)**
For each of: skill-cslib-research, skill-cslib-implementation, skill-cslib-research-hard, skill-cslib-implementation-hard:
- `grep -q 'lit_context=""'` — initialization present
- `grep -q 'literature-briefing.sh'` — briefing call present
- `grep -q 'lit_flag.*=.*true\|lit_flag" = "true"'` — gated on lit_flag

**Section C: CSLib Agent Acknowledgment (4 files)**
For each of: cslib-research-agent, cslib-implementation-agent, cslib-research-hard-agent, cslib-implementation-hard-agent:
- `grep -qi 'literature.briefing'` — acknowledgment section present

**Section D: General Skill Interactive Detection (2 files)**
For each of: skill-researcher, skill-implementer:
- `grep -q 'literature-index.json'` — sub-index detection present
- `grep -q 'literature-create-setup-task'` — setup task creation referenced

**Section E: Runtime Smoke Test (when --runtime flag passed or auto-triggered)**

The runtime test creates a controlled environment:
1. Create temp global Literature dir: `TMPDIR=$(mktemp -d) ; mkdir -p "$TMPDIR/Literature"`
2. Write minimal global index to `$TMPDIR/Literature/index.json`:
   ```json
   {"entries": [{"id": "test-doc-001", "title": "Test Paper", "authors": ["Author A"], "year": 2024, "token_count": 1000, "path": "sources/test-doc-001", "parent_doc": ""}]}
   ```
3. Write matching sub-index to `$PROJECT_ROOT/specs/literature-index.json` (backed up / removed at end):
   ```json
   {"entries": [{"doc_id": "test-doc-001", "relevance": "Test relevance note"}]}
   ```
4. Run: `LITERATURE_DIR="$TMPDIR/Literature" bash .claude/scripts/literature-briefing.sh`
5. Assert: output is non-empty AND contains `<literature-briefing>`
6. Assert: output contains `Test Paper`
7. Cleanup: `rm -f specs/literature-index.json; rm -rf "$TMPDIR"`

**Edge Case Sub-Tests (also in runtime section)**:
- Missing global index: set `LITERATURE_DIR` to empty temp dir, run script, assert empty stdout
- Empty sub-index: write `{"entries": []}` to sub-index, run script, assert empty stdout  
- Missing sub-index: ensure `specs/literature-index.json` absent, run script, assert empty stdout
- Invalid JSON sub-index: write `{invalid}` to sub-index, run script, assert exit 0 (graceful)

**Important safety note**: The runtime test writes to `specs/literature-index.json`. This file likely does not exist in the repo (confirmed). Use a trap for cleanup: `trap 'rm -f "$SUB_INDEX_BACKUP_PATH"; rm -rf "$TMPDIR"' EXIT`.

#### Test Flag Design

```bash
# Default: run static checks only (safe, fast)
# --runtime: also run runtime smoke test (requires tmp file writes)
# --clean: skip teardown (for debugging)
RUN_RUNTIME=false
if [[ "${1:-}" == "--runtime" ]]; then
  RUN_RUNTIME=true
fi
```

#### Exit Code Convention
- Exit 0: all tests passed (or passed with warnings)
- Exit 1: one or more tests failed

## Decisions

- Static checks are the default; runtime smoke test is opt-in via `--runtime` flag to avoid polluting `specs/` in routine use
- The test script should NOT check for AskUserQuestion in cslib skills (those intentionally use silent-exit behavior from literature-briefing.sh, not interactive detection)
- The interactive detection test should check general skills (skill-researcher, skill-implementer) as those are where task 760 made changes
- Use `validate-wiring.sh` color/counter pattern for consistency with existing scripts
- Cleanup via `trap ... EXIT` is essential to prevent leaving temp `specs/literature-index.json` behind

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Runtime test leaves `specs/literature-index.json` behind on failure | Use `trap 'cleanup' EXIT` to always remove temp file |
| Path resolution: `literature-briefing.sh` derives PROJECT_ROOT from SCRIPT_DIR, not cwd | Script must be run with correct cwd (project root), or invoked as `bash .claude/scripts/literature-briefing.sh` from project root |
| False positives in static grep: grep finds comment text, not actual code | Use tighter grep patterns checking for code-specific strings like `if [ "$lit_flag"` |
| cslib-research-hard comments reference old line numbers after task 761 insertions | Line numbers are not used in the test; grep by content only |
| Global Literature index not available on CI/test machines | Runtime test is opt-in (--runtime flag); static checks have no external deps |

## Context Extension Recommendations

None — the `--lit` pipeline is already documented in `.claude/CLAUDE.md` under "Literature Mode" and "Interactive Sub-Index Setup Detection" sections.

## Appendix

### Files Examined

- `.claude/scripts/literature-briefing.sh` — runtime behavior, sub-index and global index schema
- `.claude/scripts/literature-create-setup-task.sh` — helper script created in task 760
- `.claude/skills/skill-cslib-research/SKILL.md` — Stage 4a lit_context pattern (lines 69-82)
- `.claude/skills/skill-cslib-implementation/SKILL.md` — Stage 4a lit_context pattern (lines 83-94)
- `.claude/skills/skill-cslib-research-hard/SKILL.md` — Stage 4a lit_context extension (lines 129-140)
- `.claude/skills/skill-cslib-implementation-hard/SKILL.md` — Stage 4a lit_context extension (lines 168-179)
- `.claude/agents/cslib-research-agent.md` — Literature Briefing Context section (lines 24-35)
- `.claude/agents/cslib-implementation-agent.md` — Literature Briefing Context section (lines 22-28)
- `.claude/agents/cslib-research-hard-agent.md` — literature-briefing mention (line 45)
- `.claude/agents/cslib-implementation-hard-agent.md` — literature-briefing mention (line 48)
- `.claude/skills/skill-researcher/SKILL.md` — interactive detection block (lines 168-251)
- `.claude/skills/skill-implementer/SKILL.md` — interactive detection block (lines 161-204)
- `.claude/scripts/validate-wiring.sh` — style reference for test output format

### Key Grep Patterns for Static Tests

```bash
# Skill: lit_context initialized
grep -q 'lit_context=""' "$SKILL_FILE"

# Skill: briefing script called
grep -q 'literature-briefing.sh' "$SKILL_FILE"

# Skill: gated on lit_flag
grep -q 'lit_flag.*=.*true\|lit_flag" = "true"' "$SKILL_FILE"

# Agent: briefing section present  
grep -qi 'literature.briefing' "$AGENT_FILE"

# General skill: sub-index detection
grep -q 'literature-index.json' "$SKILL_FILE"

# General skill: setup task creation
grep -q 'literature-create-setup-task' "$SKILL_FILE"
```

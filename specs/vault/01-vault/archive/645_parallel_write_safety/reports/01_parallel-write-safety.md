# Research Report: Task #645

**Task**: 645 - Fix parallel write safety for state.json
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:30:00Z
**Effort**: ~45 minutes codebase analysis
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of `.claude/scripts/`, `.claude/skills/`, `.claude/commands/`, `.claude/context/patterns/`
**Artifacts**: specs/645_parallel_write_safety/reports/01_parallel-write-safety.md
**Standards**: report-format.md

---

## Executive Summary

- The shared `specs/tmp/state.json` temp path is used as the sole intermediate file for all state.json write operations across 40+ call sites, creating a classic last-write-wins race condition when the multi-task orchestrator dispatches agents in parallel.
- The race is real and exploitable: multi-task mode (`/orchestrate N,M,...`) dispatches up to 4 parallel subagents that all call `update-task-status.sh`, which all write through the same `specs/tmp/state.json` path.
- The recommended fix is a two-layer approach: (1) replace `specs/tmp/state.json` with `mktemp`-generated unique paths in the three shell scripts that actually execute writes at runtime (`update-task-status.sh`, `postflight-workflow.sh`, `skill-base.sh`), and (2) add `flock` on a lock file around the read-jq-write triplet in `update-task-status.sh`, which is the centralized write chokepoint for the multi-task scenario.
- TODO.md has a related but lower-severity problem: `link-artifact-todo.sh` uses `sed -i` (in-place) and `awk > tmp && mv` with a shared `$TODO_FILE.tmp` path, also vulnerable to concurrent corruption.

---

## Context & Scope

The multi-task orchestrator (`/orchestrate N,M,...`) dispatches up to 4 parallel subagents in a wave. Each subagent's lifecycle (research, plan, implement) calls `update-task-status.sh` for preflight and postflight status transitions. These calls are currently serialized within a wave only because the Agent tool invocations are dispatched in series in the SKILL.md pseudocode—but the *postflight* loop (lines 999-1082 of skill-orchestrate/SKILL.md) processes tasks sequentially after agents complete. The race occurs *between* the dispatched agents themselves, since each subagent may call into `skill-base.sh`'s postflight functions independently.

Additionally, a direct race exists at the orchestrator level: lines 1044-1051 of SKILL.md do inline `jq > specs/tmp/state.json && mv` for artifact linking, sequentially per task—but if two tasks complete near-simultaneously and their postflights run in parallel, both write through the same temp path.

---

## Findings

### 1. Complete Inventory of state.json Writers

**Shell script writers (runtime code):**

| File | Temp path used | Write pattern |
|------|---------------|---------------|
| `.claude/scripts/update-task-status.sh` | `$TMP_DIR/state.json.tmp` (= `specs/tmp/state.json.tmp`) | jq > tmp; mv tmp -> state.json |
| `.claude/scripts/postflight-workflow.sh` | `specs/tmp/state.json` (hardcoded) | jq > tmp; mv (3 times per call) |
| `.claude/scripts/skill-base.sh` `skill_link_artifacts()` | `specs/tmp/state.json` (hardcoded) | jq > tmp; mv (2 times per call) |
| `.claude/scripts/skill-base.sh` `skill_increment_artifact_number()` | **none** — Python direct write | `open('specs/state.json', 'w')` |
| `.claude/scripts/skill-base.sh` `skill_propagate_memory_candidates()` | **none** — Python direct write | `open('specs/state.json', 'w')` |
| `.claude/scripts/archive-task.sh` | `${STATE_FILE}.tmp` (= `specs/state.json.tmp`) | jq > tmp; mv |

**Inline jq in SKILL.md files (orchestrator pseudocode, executed by Claude):**

| File | Temp path | Notes |
|------|-----------|-------|
| `skills/skill-orchestrate/SKILL.md` lines 413-418, 1047-1051 | `specs/tmp/state.json` | Artifact linking for single and multi-task modes |
| `skills/skill-status-sync/SKILL.md` | `specs/tmp/state.json` | Recovery sync |
| `commands/task.md` | `specs/tmp/state.json` and `specs/state.json.tmp` | Task creation/update |
| `commands/implement.md` | `specs/tmp/state.json` | Phase state update |
| `commands/orchestrate.md` | `specs/tmp/state.json` | Orchestrator state |
| `context/patterns/inline-status-update.md` | `specs/tmp/state.json` | Documentation examples (not executed as scripts) |
| `context/patterns/jq-escaping-workarounds.md` | `specs/tmp/state.json` | Documentation examples |

**Key observation**: The SKILL.md inline code represents patterns that Claude executes directly via the Bash tool. In multi-task mode, the orchestrator's postflight loop (lines 1037-1058) runs *sequentially* per task in the orchestrating shell, so artifact linking there does NOT race with itself. The true race is between:
1. The parallel subagents each calling `update-task-status.sh` (preflight from each agent) or
2. The parallel agents writing state through their own `skill-base.sh` postflight calls before handing off.

### 2. The Shared Temp Path Problem

`update-task-status.sh` uses `$TMP_DIR/state.json.tmp` where:
```bash
TMP_DIR="$PROJECT_ROOT/specs/tmp"
```
So the path is always `specs/tmp/state.json.tmp`. Two agents calling this simultaneously:
- Agent A: `jq ... state.json > specs/tmp/state.json.tmp`
- Agent B: `jq ... state.json > specs/tmp/state.json.tmp`  ← overwrites A's output
- Agent A: `mv specs/tmp/state.json.tmp state.json`
- Agent B: `mv specs/tmp/state.json.tmp state.json`  ← B's changes survive, A's are lost

`postflight-workflow.sh` is even more vulnerable: it writes to `specs/tmp/state.json` (without `.tmp` suffix) 3 times in sequence within a single invocation, and each write reads the previously-written temp file.

### 3. Race Condition Anatomy

```
Time →     Agent A (task 640)                   Agent B (task 641)
T0         update-task-status.sh postflight
T0         reads state.json {640: implementing}  reads state.json {640: implementing}
T1         jq → specs/tmp/state.json.tmp         jq → specs/tmp/state.json.tmp
           {640: researched, 641: implementing}
T2                                               {640: implementing, 641: researched}
                                                 [A's write is now overwritten]
T3         mv state.json.tmp → state.json         mv state.json.tmp → state.json
                                                 [B wins; A's status change is lost]
T4         state.json = {640: implementing, 641: researched}
           Agent A's postflight update was silently lost
```

Result: Task 640 remains stuck at `implementing` even though agent A successfully completed research. Next orchestrator cycle sees it as still in-progress and may skip or re-dispatch it.

### 4. The Python Direct-Write Problem

`skill_increment_artifact_number()` and `skill_propagate_memory_candidates()` in `skill-base.sh` use Python's `open('specs/state.json', 'w')` directly with no temp file and no locking. This is worse than the jq pattern because:
- Truncates the file during write (open for write zeroes the file before writing)
- If Python crashes between open() and close(), state.json is left empty/corrupt
- No atomic swap: other readers see a partial write

### 5. The Centralized Update Path

The good news: `update-task-status.sh` is the *primary* write path for all status transitions:
- All lifecycle skills call it: `skill-orchestrate`, `skill-researcher`, `skill-planner`, `skill-implementer`, `skill-nix-research`, `skill-team-research`, `skill-team-plan`
- The multi-task orchestrator calls it per-task before and after dispatch
- Postflight scripts (research, plan, implement) have been consolidated into `postflight-workflow.sh`

Fixing `update-task-status.sh` with flock protects the most critical write path. `postflight-workflow.sh` and `skill-base.sh` also need fixing for completeness.

### 6. TODO.md Write Safety

TODO.md has a related problem. Three patterns are used:
- `link-artifact-todo.sh`: uses `sed -i` (modifies file in-place, no lock) and `awk > $TODO_FILE.tmp && mv` (shared tmp path)
- `update-task-status.sh`: uses `$TMP_DIR/todo.md.tmp` (same shared path problem as state.json)
- `generate-task-order.sh`: uses `mktemp` correctly (already safe)

The TODO.md race is lower severity because:
1. The orchestrator's postflight loop processes tasks sequentially (not in parallel)
2. Status markers are per-task and regex-matched by line number — two tasks writing different line numbers won't corrupt each other (sed -i is atomic per-line)
3. Artifact linking updates different task blocks (different line numbers)

However, the `todo.md.tmp` shared path in `update-task-status.sh` is still a race hazard if two agents update their respective tasks simultaneously.

### 7. flock Pattern Research

`flock` from util-linux 2.42 is available on this system. Standard mutex pattern:

```bash
LOCK_FILE="specs/.state.json.lock"
(
  flock -x -w 30 200 || { echo "Error: could not acquire state.json lock" >&2; exit 1; }
  # --- critical section: read, transform, write state.json ---
  tmp=$(mktemp "$TMP_DIR/state.XXXXXX.json")
  jq ... "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
) 200>"$LOCK_FILE"
```

Key considerations:
- `flock -x` acquires an exclusive (write) lock
- `-w 30` sets a 30-second timeout to prevent deadlock in case of crash (stale lock is cleaned by next `flock` call since it tests lock, not lock file presence)
- The FD 200 redirect is the lock mechanism: `200>"$LOCK_FILE"` opens the lock file on FD 200
- Lock file persists but is harmless (flock tests the lock, not the file's existence)
- All processes must use the same lock file path to coordinate

### 8. mktemp Pattern for Unique Temp Files

```bash
tmp=$(mktemp "$TMP_DIR/state.XXXXXX.json")
# Use $tmp for jq output, then atomic move
jq '...' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
# Cleanup on failure
trap 'rm -f "$tmp"' EXIT
```

`mktemp /path/state.XXXXXX.json` replaces the X's with random chars, guaranteeing uniqueness per process. The file is pre-created (exists but empty) so the `>` redirect won't fail on permission issues.

### 9. Scope Boundaries: Minimal vs. Comprehensive Fix

**Option A — Minimal fix (update-task-status.sh only)**:
- Add flock around the jq write in `update_state_json()` in `update-task-status.sh`
- Replace `$TMP_DIR/state.json.tmp` with `mktemp` in `update-task-status.sh`
- Covers: all lifecycle status transitions (the primary race scenario)
- Misses: postflight-workflow.sh, skill-base.sh Python writes, SKILL.md inline jq

**Option B — Centralized script fix (3 scripts)**:
- Fix `update-task-status.sh` (flock + mktemp)
- Fix `postflight-workflow.sh` (mktemp only, called sequentially in most cases)
- Fix `skill-base.sh` Python writes (use write-to-tmp-then-rename or add flock)
- Covers: all runtime script-level writes

**Option C — Comprehensive fix (scripts + SKILL.md patterns)**:
- Option B plus update the inline jq patterns in `skill-orchestrate/SKILL.md` and `skill-status-sync/SKILL.md`
- Update documentation in `context/patterns/inline-status-update.md` and `jq-escaping-workarounds.md`
- Most complete but highest diff surface

**Recommendation**: Option B. The inline SKILL.md patterns for artifact linking in the orchestrator run sequentially (the postflight loop iterates tasks one-at-a-time), so they don't race with each other. The Python writes in skill-base.sh are more dangerous than the shared temp path because they can corrupt on crash. Option B fixes the actual race paths without touching documentation examples.

---

## Decisions

- **Lock file location**: `specs/.state.json.lock` (dotfile in specs/, not deleted by cleanup scripts, not confused with state.json itself)
- **Lock timeout**: 30 seconds (generous for slow systems, still prevents infinite deadlock)
- **mktemp template**: `specs/tmp/state.XXXXXX.json` (keeps tmp in existing tmp dir, .json suffix for clarity)
- **Python fix approach**: Replace direct open/write with write-to-tmp-then-os.replace() (atomic on POSIX)
- **TODO.md fix**: Replace `$TMP_DIR/todo.md.tmp` with mktemp in `update-task-status.sh`; add flock on a separate `specs/.todo.md.lock` file around the update-task-status.sh TODO sections

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| flock not available on all platforms | Low | flock is util-linux; available on Linux (NixOS). macOS uses `shlock` or `lockf`. The system is Linux-only (NixOS confirmed). |
| Lock file left behind after crash | Negligible | flock releases on process exit/crash. Lock file can persist (harmless; flock re-acquires on next call). |
| Stale lock causing permanent deadlock | Low | `-w 30` timeout prevents infinite wait. Processes fail loudly after 30s. |
| Python writes bypass flock | High | flock in bash subshell won't protect Python writes. Python writes need their own mechanism (os.replace atomicity). |
| SKILL.md inline jq still racy | Medium | Acceptable: orchestrator postflight loop is sequential; parallel racing only happens between skill agents, which use update-task-status.sh (now protected). |
| mktemp template collision | None | mktemp guarantees uniqueness. |
| TODO.md `sed -i` race | Low | Tasks update different line ranges. Only a problem if two tasks have overlapping ranges (impossible for separate tasks). flock on TODO.md is optional. |

---

## Context Extension Recommendations

- **Topic**: Safe file write patterns for concurrent shell scripts
- **Gap**: No documentation in `.claude/context/patterns/` covers flock or unique temp file patterns; `inline-status-update.md` documents the racy pattern as the canonical approach
- **Recommendation**: Update `inline-status-update.md` to add a "Concurrent Write Safety" section showing flock + mktemp pattern; note that direct `specs/tmp/state.json` is deprecated in favor of mktemp

---

## Appendix

### Search Queries Used
- `grep -rn "specs/tmp/state" .claude/` — found 40+ call sites using shared temp path
- `grep -rn "state\.json" .claude/scripts/` — mapped all write locations
- `grep -n "with open\|json.dump" .claude/scripts/skill-base.sh` — found Python direct writes
- `flock --version` — confirmed util-linux 2.42 available
- `mktemp --version` — confirmed GNU coreutils 9.11 available

### Files Modified (to be done in implementation)

**Primary targets** (runtime write scripts):
1. `.claude/scripts/update-task-status.sh` — flock + mktemp
2. `.claude/scripts/postflight-workflow.sh` — mktemp (3 temp writes)
3. `.claude/scripts/skill-base.sh` — Python atomic write + mktemp for jq writes

**Secondary targets** (documentation update):
4. `.claude/context/patterns/inline-status-update.md` — note deprecated shared tmp path
5. `.claude/skills/skill-orchestrate/SKILL.md` — update inline jq artifact linking to use mktemp

### Call Graph Summary

```
/orchestrate N,M            → skill-orchestrate/SKILL.md (multi-task mode)
  → for each wave (sequential):
    → for each task in wave (parallel Agent tool calls):
      → each agent calls skill_preflight_update() → update-task-status.sh  [RACE HERE]
      → agent does work
      → each agent may call skill_link_artifacts() → skill-base.sh jq writes  [RACE HERE]
      → each agent may call skill_increment_artifact_number() → Python direct write  [RACE HERE]
    → orchestrator postflight loop (sequential):
      → update-task-status.sh postflight  [SAFE: sequential]
      → inline jq artifact linking  [SAFE: sequential]
```

### Key Finding: Where the Race Actually Happens

The agents dispatched in parallel by the multi-task orchestrator run in separate Claude contexts. Each context can:
1. Call `update-task-status.sh` directly (via skill preflight/postflight)
2. Execute `skill-base.sh` functions that write state.json

These concurrent writes all share the same `specs/tmp/state.json` intermediate path. The fix must protect these concurrent callers with a file mutex (`flock`).

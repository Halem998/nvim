# Research Report: Task #593 — Teammate B Findings

**Task**: 593 — Extract shared workflow utilities
**Focus**: Alternative patterns, prior art, migration strategy
**Teammate**: B (Alternative Approaches)
**Started**: 2026-05-22T00:00:00Z
**Completed**: 2026-05-22T00:00:00Z

---

## Key Findings

### 1. Three Postflight Scripts Already Exist — and Are Near-Identical

The `.claude/scripts/` directory already contains `postflight-research.sh`, `postflight-plan.sh`,
and `postflight-implement.sh`. These are 70-line scripts that are structurally identical, differing
only in 7 constant strings:

| Variable | research | plan | implement |
|----------|----------|------|-----------|
| `status` value | `"researched"` | `"planned"` | `"completed"` |
| artifact type filter | `"research"` | `"plan"` | `"summary"` |
| timestamp field | `researched: $ts` | `planned: $ts` | `implemented: $ts` |
| artifact type label | `"research"` | `"plan"` | `"summary"` |

**Critical observation**: These scripts are NOT currently used by the skill files. The skills
(`skill-researcher/SKILL.md`, `skill-implementer/SKILL.md`) contain their own inline jq commands
that reproduce the same logic. The postflight scripts appear to be an earlier extraction attempt
that was superseded by the more capable skill-internal postflight pattern.

**Implication**: The `postflight-workflow.sh` target in task 593 already has prior art sitting
unused in the repository. The implementation task can unify these three files into a single
parameterized script rather than starting from scratch.

---

### 2. Existing Scripts Use "Called as Subprocess" Pattern, Not "Sourced Library" Pattern

Every existing script in `.claude/scripts/` follows the same structural convention:
- `#!/usr/bin/env bash` shebang
- `set -euo pipefail` (or `set -e`)
- `SCRIPT_DIR` + `PROJECT_ROOT` derived via `cd "$(dirname "${BASH_SOURCE[0]}")"` idiom
- Positional argument parsing with explicit `$0` usage in usage strings
- Distinct exit codes documented in a header comment block
- Called as subprocess: `bash .claude/scripts/foo.sh arg1 arg2`

None of the existing scripts is designed to be sourced (no function-export-only pattern, no
`return` instead of `exit`, no guard like `[[ "${BASH_SOURCE[0]}" == "${0}" ]] || return`). The
`update-task-status.sh` script calls `generate-task-order.sh` as a subprocess rather than sourcing
it, confirming the subprocess-call idiom is the established convention.

**One exception**: `skill-implementer/SKILL.md` Stage 7 contains a `source` call for
`update-recommended-order.sh`:
```bash
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    remove_from_recommended_order "$task_number" ...
fi
```
This is anomalous — it sources a script to call a function, wrapped in an error-suppressing
`if source ... 2>/dev/null` guard. This pattern is fragile (silently fails if the script doesn't
export functions) and is not the dominant convention.

**Implication for task 593**: The architecture spec calls `parse-command-args.sh` and
`command-gate-in.sh` to be invoked with `source` (not as subprocesses). This would be a departure
from the established convention. Either:
(a) Accept the departure and document it explicitly, or
(b) Use subprocess-call pattern for these new scripts too, though that makes variable export harder

---

### 3. The Commands Are Markdown Files — Sourcing .sh Files Is Indirect

Commands in `.claude/commands/*.md` are markdown pseudo-code, not bash scripts. Claude Code
interprets these files as instruction sets, not as shell scripts that literally execute. When a
command says `source .claude/scripts/parse-command-args.sh`, it means "Claude should run this
bash command when executing this stage."

This has two practical consequences:

**a) Sourcing works fine when the command is interpreted.** When Claude executes the command, it
runs Bash tool calls. A `source` call in a Bash tool call works as normal bash sourcing. There is
no gotcha here specific to the .md-as-pseudocode format.

**b) The "source vs subprocess" distinction matters for variable export.** If `parse-command-args.sh`
needs to export `TASK_NUMBERS`, `TEAM_MODE`, `CLEAN_FLAG`, etc. into the calling script's
environment, it must be sourced (not called as a subprocess). A subprocess cannot modify the
parent's environment. The architecture spec's choice of `source` for `parse-command-args.sh` and
`command-gate-in.sh` is therefore correct.

**Key risk identified**: Claude's Bash tool resets `$cwd` between calls (documented in the agent
instructions: "agent threads always have their cwd reset between bash calls"). If a sourced script
relies on `SCRIPT_DIR` computed from `${BASH_SOURCE[0]}`, the path must be absolute. The existing
scripts compute `PROJECT_ROOT` via `cd "$(dirname "${BASH_SOURCE[0]}")"` — this is safe because
`BASH_SOURCE[0]` is always the script path, but the commands will need to know the correct
absolute path to the scripts directory when invoking `source`.

---

### 4. Alternative Decomposition: 3 Scripts vs 4 Scripts vs 1 Monolith

The proposed 4-script decomposition is:
- `parse-command-args.sh` — arg parsing
- `command-gate-in.sh` — session ID + task lookup + validation
- `command-gate-out.sh` — artifact verification + defensive status fix
- `postflight-workflow.sh` — unified postflight for the 3 legacy scripts

**Alternative A: 3 scripts** — Merge `command-gate-in.sh` and `command-gate-out.sh` into a single
`command-gate.sh` with a `--in` / `--out` flag. This reduces the file count but breaks the
single-responsibility principle. Gate-in and gate-out are called at different points in the
command flow and may have different callers in the future (e.g., `/orchestrate` may call gate-in
only). Keep them separate.

**Alternative B: 5 scripts** — Split `parse-command-args.sh` into `parse-task-numbers.sh`
(handles number parsing and range expansion) and `parse-flags.sh` (handles --team, --clean, etc.).
This would allow skills to reuse `parse-flags.sh` without pulling in task-number parsing. However,
the flags are command-specific (skills don't parse `$ARGUMENTS`; they receive pre-parsed context
from the command). No benefit over 4 scripts.

**Alternative C: Single `workflow-common.sh` monolith** — All gate logic in one file, sourced once.
This is simpler but creates a "god module" problem: any change to gate-in logic requires testing
gate-out, even when changes are independent. The architecture spec's 4-script decomposition is
more maintainable.

**Recommendation**: The 4-script decomposition is the right choice. The alternative analyses
confirm the design rather than pointing to a superior alternative.

---

### 5. Skills Also Benefit — But Differently

The skills (`skill-researcher`, `skill-planner`, `skill-implementer`) have their own pattern of
duplication — the lifecycle stages (preflight marker creation, artifact number reading, metadata
parsing, artifact linking, memory candidate propagation). The architecture spec addresses this
separately in Component 2 (`skill-base.sh`, task 594), not in task 593.

**Do the 4 shared command scripts help skills?**

- `parse-command-args.sh` — No. Skills receive pre-parsed context (task_number, session_id, flags)
  from the command. They never parse `$ARGUMENTS`.
- `command-gate-in.sh` — Partial. Skills run their own Stage 1 (input validation) and Stage 2
  (preflight status update), which overlaps with gate-in. However, skills call
  `update-task-status.sh` directly rather than going through a gate. Refactoring skills to use
  `command-gate-in.sh` would be a larger change (task 594 territory).
- `command-gate-out.sh` — No. Gate-out reads the skill's return metadata; this is command-layer
  responsibility, not skill-layer.
- `postflight-workflow.sh` — This is the one script that DOES benefit skills directly. The three
  legacy `postflight-*.sh` scripts are already thin wrappers around state.json jq operations that
  skills could call. However, the current skills bypass these scripts and inline equivalent jq.
  Unifying them into `postflight-workflow.sh` cleans up the orphaned scripts without changing skill
  behavior (until task 594).

**Implication**: Task 593 is correctly scoped to command-layer scripts. Skill-layer deduplication
is task 594. Do not conflate the two.

---

### 6. Migration Strategy: Incremental Command-by-Command Is Safe

The three command files (`research.md`, `plan.md`, `implement.md`) are independent. They do not
call each other. Each can adopt the shared scripts incrementally:

**Order recommendation**:
1. `research.md` first — shortest command (500L), lowest complexity, no continuation loop
2. `plan.md` second — similar complexity (531L)
3. `implement.md` last — most complex (612L), has continuation loop and force flag

Each command can be migrated and tested independently. There is no requirement to migrate all
three simultaneously. The shared scripts must be written before the first migration (obviously),
but once written, commands adopt them one at a time.

**Risk of incremental approach**: If `command-gate-in.sh` exports environment variables (SESSION_ID,
TASK_TYPE, etc.), and the gate script is modified after research.md adopts it but before plan.md
does, then the behavior of research.md and plan.md will briefly diverge. This is acceptable for
internal tools where the author controls the migration. Gate script changes should be complete
before migrating more than one command.

---

### 7. Observed Discrepancy: Gate-Out Contains Unsafe jq Pattern

In `research.md` CHECKPOINT 2, the defensive status check uses:
```bash
if [ "$current_status" = "researched" | not ]; then
```
This is pseudo-code mixing bash and jq syntax, but more importantly, the actual jq-based status
comparison elsewhere uses the `"| not"` pattern correctly. The gate-out script implementation must
use the safe jq pattern from `jq-escaping-workarounds.md`, specifically:
```bash
select(.status == "researched" | not)  # SAFE
# not: select(.status != "researched")  # UNSAFE - gets escaped as \!=
```
This is a known gotcha (Claude Code Issue #1132) that the gate-out script implementation must
handle carefully.

---

## Alternative Approaches Considered

### A. Single `workflow-common.sh` (All Gates in One File)

**Pros**: Simpler import — one source call per command.
**Cons**: God-module problem; gate-in and gate-out are invoked at different points (before vs after
skill delegation); harder to test; changing either gate requires loading both.
**Verdict**: Rejected. 4-script decomposition is superior.

### B. Subprocess-Call Pattern (No Sourcing)

**Pros**: Consistent with ALL existing scripts in `.claude/scripts/`; cleaner boundaries; no
variable export issues.
**Cons**: Cannot export TASK_NUMBERS, SESSION_ID, etc. to the caller's environment from a
subprocess. Would require tmpfile-based variable passing or JSON output parsing in each command.
This is significantly more complex than sourcing.
**Verdict**: Rejected for `parse-command-args.sh` and `command-gate-in.sh` (need env exports).
`command-gate-out.sh` and `postflight-workflow.sh` could use subprocess pattern — they don't need
to export variables, they only need to execute side effects.

### C. Skip `postflight-workflow.sh` (Retire 3 Legacy Scripts Instead)

Given that the 3 legacy `postflight-*.sh` scripts are already unused by the skills, they could
simply be deleted (or left as dead code). The skills call `update-task-status.sh` directly. The
task 593 spec calls for creating `postflight-workflow.sh` to replace them — but if nothing calls
the legacy scripts, replacing them doesn't reduce duplication; it just cleans up dead code.

**However**: Looking at the architecture spec (Component 2, task 594), `skill-base.sh` will call
`postflight-workflow.sh` as part of the unified skill lifecycle. So `postflight-workflow.sh` is a
dependency of task 594, not just a cleanup of task 593. This makes it important to create it now.

**Verdict**: The task 593 spec is correct. Create `postflight-workflow.sh`; it will be consumed
by task 594's `skill-base.sh`.

---

## Evidence and Examples

### Evidence 1: Three Postflight Scripts Are Structurally Identical

Files examined:
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-research.sh` (70L)
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-plan.sh` (70L)
- `/home/benjamin/.config/nvim/.claude/scripts/postflight-implement.sh` (70L)

All three: same `set -e`, same argument parsing, same task validation jq, same two-step jq update
pattern, same exit codes. Only status strings and artifact type labels differ.

### Evidence 2: Existing Scripts Are All Subprocess-Called

From `update-task-status.sh` (the most complex existing shared script):
```bash
"$gen_script" --update-todo "$TODO_FILE" "$STATE_FILE" || { echo "Warning: ..."; }
bash "$tts_script" --lifecycle "$STATE_STATUS" &
bash "$wezterm_script" "$WEZTERM_STATUS" &
bash "$rename_script" "${label} task ${task_number}: ${project_name}" 2>/dev/null || true
```
Every invocation of another script uses `bash script args` or `"$script" args` — never `source`.

The anomalous `source` in `skill-implementer/SKILL.md` Stage 7 (`source
"$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh"`) is the only counter-example, and it
uses `2>/dev/null` error suppression suggesting it's fragile.

### Evidence 3: Skills Don't Use the Postflight Scripts

`skill-researcher/SKILL.md` Stage 7 contains direct jq for artifact update — it does NOT call
`postflight-research.sh`. Verified by searching SKILL.md: no reference to postflight-research.sh.
The three legacy postflight scripts appear to predate the current skill-internal postflight pattern.

### Evidence 4: Command Files Are Already 500+ Lines

Line counts confirmed: research.md (500L), plan.md (531L), implement.md (612L). The architecture
spec's target of 150-200 lines per command represents a ~70% reduction.

### Evidence 5: Source Pattern Is Needed for Variable Export

The architecture spec for `parse-command-args.sh` exports: `TASK_NUMBERS`, `REMAINING_ARGS`,
`TEAM_MODE`, `TEAM_SIZE`, `EFFORT_FLAG`, `MODEL_FLAG`, `CLEAN_FLAG`, `FORCE_FLAG`, `FOCUS_PROMPT`.
These cannot be passed from a subprocess to the parent. The `source` idiom is the correct approach
for this use case.

---

## Confidence Level

**High confidence findings**:
- The 3 legacy postflight scripts exist, are near-identical, and are unused by skills (directly
  verified by reading all 3 scripts and checking skill files)
- All other existing scripts use subprocess-call pattern, not source (directly verified)
- Source pattern is required for variable-exporting scripts (bash semantics)
- Command-by-command incremental migration is safe (commands are independent)
- `postflight-workflow.sh` is needed by task 594's `skill-base.sh` (architecture spec confirms)

**Medium confidence findings**:
- The 4-script decomposition is optimal (alternatives analyzed but no authoritative external
  reference consulted)
- `command-gate-out.sh` and `postflight-workflow.sh` can use subprocess pattern without variable
  export needs (inferred from architecture spec signatures; would need implementation to confirm)

**Low confidence findings**:
- Exact behavior of cwd-reset between Bash tool calls with sourced scripts (documented but not
  directly tested; may require absolute path handling in the gate scripts)

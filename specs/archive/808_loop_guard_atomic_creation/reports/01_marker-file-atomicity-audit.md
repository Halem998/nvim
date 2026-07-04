# Research Report: Task #808

**Task**: 808 - Bring `.orchestrator-loop-guard` (and race-safe peer marker files) up to the atomic-creation standard established by task-lock.sh
**Started**: 2026-07-04T00:00:00Z
**Completed**: 2026-07-04T00:00:00Z
**Effort**: small-medium (one new task-lock.sh subcommand + 2 call-site edits, replicated across a dual-copy pair)
**Dependencies**: task 788 (introduced `task-lock.sh` and the atomic-`mkdir` primitive)
**Sources/Inputs**: Codebase (`.claude/scripts/task-lock.sh`, `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, `skill-base.sh`, all `.postflight-pending` call sites), `.claude/context/patterns/task-lock.md`, task 788/809/810 descriptions in `specs/state.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Exactly **two** marker files have the genuinely race-prone "check-then-create-with-resume" (TOCTOU) shape that task 788 flagged as unsafe: `.orchestrator-loop-guard` (both `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md`) and `.orchestrator-churn-state.json` (`skill-orchestrate-hard/SKILL.md` only). Both use `if [ -f "$file" ] && jq empty ...; then resume; else jq -n ... > "$file"; fi` — a plain `>` redirect has no `O_EXCL` semantics, so two racing writers can both take the `else` branch and both stomp a fresh zeroed state over the other's in-progress counters.
- `.postflight-pending` (~30+ call sites across `.claude/skills/`, `.claude/extensions/*/skills/`) is **not** in this TOCTOU category: every site unconditionally overwrites it with `cat > file << EOF` (no existence check, no branch), so a race there is a last-write-wins content clobber, not a lost-resume-state bug. It is also currently created only after `command-gate-in.sh`'s lock acquire for `/implement`/`/orchestrate`, but `/research`/`/plan`/`/revise` do not yet route through that gate (task 810's scope). Recommendation: leave `.postflight-pending` out of this task's remediation and let task 810 close its exposure by routing those three skills onto the shared, lock-protected gate scripts; revisit only if 810 finds a residual gap.
- `task-lock.sh`'s existing exclusivity primitive is `mkdir` (POSIX-atomic exclusive create) for the gate, paired with the codebase's established tmp-file-`mv` idiom for the payload write. The recommended remediation extracts this same two-step idiom into one new generic subcommand, `task-lock.sh init-marker <file_path>` (stdin = JSON content), so `.orchestrator-loop-guard` and `.orchestrator-churn-state.json` initialization calls this primitive instead of the bare `jq -n ... > file` pattern — no new locking mechanism, no competition with task-lock.sh's task-number lock or with 809's planned file-scope locking.
- Why this matters even though the outer task-number lock (from 788) already usually wraps this code path: `acquire`'s stale-override behavior is deliberately **not** a hard mutual exclusion guarantee — a second session can override a "stale" lock (default 30 min threshold) while the first session is still alive-but-slow, giving two live writers inside the same `if/else` block. `.orchestrator-loop-guard`/`.orchestrator-churn-state.json` need their own atomicity independent of the outer lock's best-effort exclusivity, exactly as task-lock.md's own follow-up note (below) already anticipates.
- Two dual-copy pairs must be edited in lockstep: `.claude/skills/{skill-orchestrate,skill-orchestrate-hard}/SKILL.md` ↔ `.claude/extensions/core/skills/{skill-orchestrate,skill-orchestrate-hard}/SKILL.md` (confirmed byte-identical today), and `.claude/scripts/task-lock.sh` ↔ `.claude/extensions/core/scripts/task-lock.sh` (also byte-identical today). `.claude/context/patterns/task-lock.md` ↔ `.claude/extensions/core/context/patterns/task-lock.md` should also be updated in lockstep to document the new subcommand and to retire its own "real, pre-existing gap" note once fixed.
- `.opencode/skills/skill-orchestrate/SKILL.md` is a **separately maintained, already-divergent** OpenCode mirror (different `allowed-tools`, different doc paths, different staging of multi-task mode) — it is explicitly out of this task's dual-copy-pair scope, which CLAUDE.md and the task description both define as `.claude` + `.claude/extensions/core` only.

## Context & Scope

Task 788 (`specs/788_concurrent_session_lock_commit_cadence/`) introduced `.claude/scripts/task-lock.sh`, a per-task-number concurrency lock built on `mkdir` for atomic-on-creation exclusivity (contrasted explicitly, in the script's own header and in `task-lock.md`, with the codebase's prevailing `jq -n ... > file` idiom, which is atomic-on-**replace** via `mv` but NOT atomic-on-**creation**). Task 788's own plan/doc artifacts flagged `.orchestrator-loop-guard` as a real, pre-existing gap left unfixed by that work:

> "**Atomic-creation guard for `.orchestrator-loop-guard`**: that file is still written via the non-atomic `jq -n > file` pattern with no `mkdir`-style exclusivity guard. A real, pre-existing gap, left untouched by this lock — a candidate follow-up could reuse this script's `mkdir` primitive." (`.claude/context/patterns/task-lock.md:167`)

This task's scope, per the delegation description: bring `.orchestrator-loop-guard` creation up to the same atomic standard, find and fix any *other* marker-file creation sites that are genuinely race-prone in the same way, reuse (never reimplement) `task-lock.sh`'s primitive, and keep the `.claude` ↔ `.claude/extensions/core` dual-copy pairs synchronized. `task-lock.sh` itself is out of scope (already atomic) except for the addition of one new subcommand that peer files can call into.

This task runs in a coordinated batch with 809 (extends `task-lock.sh` with file-scope-aware locking) and 810 (routes `/research`, `/plan`, `/revise` onto the shared gate scripts that already carry the task-lock wiring for `/implement`/`/orchestrate`). This report is written to compose with both: it proposes extending the *same* script (`task-lock.sh`) rather than a parallel mechanism, and it explicitly defers `.postflight-pending`'s exposure gap to 810 rather than duplicating a fix that 810's gate-script migration will already close by a different, more appropriate mechanism (bringing those three skills under lock protection, rather than making the marker file itself atomic).

## Findings

### Codebase Patterns

#### Inventory of marker-file creation sites

| File | Location(s) | Pattern | Classification |
|---|---|---|---|
| `.orchestrator-loop-guard` | `.claude/skills/skill-orchestrate/SKILL.md:105-131` (Stage 2) | `if [ -f "$loop_guard_file" ] && jq empty ...; then <resume>; else jq -n ... > "$loop_guard_file"; fi` | **Non-atomic, TOCTOU-vulnerable.** Two racing writers can both observe "absent" and both write a fresh `cycle_count:0` state, silently discarding the other's progress. |
| `.orchestrator-loop-guard` | `.claude/skills/skill-orchestrate-hard/SKILL.md:192-220` (Stage 2) | Same shape, plus `burnout_signals_this_session` field | **Non-atomic, TOCTOU-vulnerable.** Same failure mode as above. |
| `.orchestrator-churn-state.json` | `.claude/skills/skill-orchestrate-hard/SKILL.md:222-228` (Stage 2, hard-mode only) | `if [ -f "$churn_file" ] && jq empty ...; then <resume total_churn>; else jq -n '{...}' > "$churn_file"; fi` | **Non-atomic, TOCTOU-vulnerable.** Same shape as the loop guard; a race resets `total_churn`/`target_churn` counters used by H5/H6 convergence policing. |
| Updates to `.orchestrator-loop-guard` (per-cycle refresh) | `skill-orchestrate/SKILL.md:170,501`; `skill-orchestrate-hard/SKILL.md:262,299` | `jq ... "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"` | **Already atomic-on-replace** (tmp-file + `mv`), matching `task-lock.sh`'s own `write_holder` idiom. Not part of this task's fix — only the *initial* creation branch is unsafe. |
| `.postflight-pending` | ~30 sites: every `skill-*/SKILL.md` under `.claude/skills/` and `.claude/extensions/*/skills/` (e.g. `skill-researcher/SKILL.md:87`, `skill-planner/SKILL.md:95`, `skill-implementer/SKILL.md:92`) | `cat > "${task_dir}/.postflight-pending" << EOF ... EOF` (unconditional, no existence check) | **Non-atomic write, but not TOCTOU** — there is no create-vs-resume branch to race on; every invocation intentionally overwrites. Worst case under true concurrency is a last-write-wins content clobber (e.g. wrong `session_id` recorded), not a lost-counter bug. Currently only reliably lock-protected for `/implement`/`/orchestrate` (via `command-gate-in.sh`); `/research`/`/plan`/`/revise` are unprotected today — this is task 810's scope (gate-script sourcing), not this task's. |
| Canonical `.postflight-pending` writer function | `.claude/scripts/skill-base.sh:150-165` (`skill_create_postflight_marker`), mirrored `.claude/extensions/core/scripts/skill-base.sh:150-165` | Same `cat > ... << EOF` pattern, documented in `.claude/docs/guides/creating-skills.md:93` | Confirms the intended canonical writer already exists as one function; the ~30 SKILL.md sites inline the same literal bash block rather than invoking it (a duplication concern, but orthogonal to atomicity — out of this task's scope). |
| `.drift-inspection.json` | `skill-orchestrate/SKILL.md:420-423,522` | Written once per Agent-tool dispatch (forked agent writes it, orchestrator reads then `rm -f`s it); no existence-check branch | **Not TOCTOU-vulnerable** — single-writer-at-a-time by construction (one fork per drift check within one cycle). Out of scope. |
| `.orchestrator-handoff.json` | Written by whichever agent is currently dispatched (research/plan/implement agent), read by the orchestrator | No existence-check branch; each dispatch's agent is the sole writer for that dispatch | **Not TOCTOU-vulnerable.** Out of scope. |
| `specs/{NNN}_{SLUG}/.lock/` + `holder.json` | `.claude/scripts/task-lock.sh` (the reference implementation) | `mkdir` for exclusivity + tmp-file-`mv` for `holder.json` content | **Already atomic** — this is the standard, not a site to fix. Explicitly out of scope per task description. |

No other `if [ -f X ] && jq empty ...; else jq -n ... > X` "create-with-resume-branch" pattern was found elsewhere in `.claude/` for a *concurrency-sensitive* file. A broad `grep` for `jq empty` returns ~60 hits, but the overwhelming majority are one-shot JSON-validity checks on already-created files (task data, delegation context, plan artifacts) with no accompanying "else create fresh state" branch — i.e., they are read-time validation, not initialize-vs-resume races.

#### `task-lock.sh`'s atomic primitive (interface to reuse)

`.claude/scripts/task-lock.sh` (and its byte-identical mirror `.claude/extensions/core/scripts/task-lock.sh`) currently exposes four subcommands, dispatched via a `case` block at the bottom of the file:

```
task-lock.sh acquire <task_number> <operation> <session_id> [command]   # exit 0/1/2
task-lock.sh heartbeat <task_number> <session_id>                       # exit 0/2
task-lock.sh release <task_number> <session_id>                         # exit 0/2 (idempotent)
task-lock.sh check <task_number>                                        # exit 0/1/2/3 (diagnostic only)
```

The reusable primitive underneath `acquire` is two composed idioms, both already named and explained in the script's own comments and in `task-lock.md`:

1. **Exclusivity gate**: `mkdir "$lock_dir" 2>/dev/null` — POSIX-atomic exclusive create; fails immediately with no TOCTOU window if the directory already exists. This is the piece the non-atomic `.orchestrator-loop-guard`/`.orchestrator-churn-state.json` sites are missing.
2. **Content write**: `write_holder()` (task-lock.sh:104-121) — writes to `holder.json.tmp` then `mv`s over `holder.json`; atomic-on-replace, used for content that is written only by whichever writer currently holds the `mkdir`-gated directory.

`cmd_acquire`'s branch structure (task-lock.sh:150-186) is the exact shape to mirror for a new "atomic first-write, else read existing" primitive: `mkdir` succeeds → write once, done; `mkdir` fails and the target already has valid content → treat as "someone else won, use theirs"; `mkdir` fails and the target is missing/corrupt (crashed initializer) → warn and recover.

### External Resources

Not applicable — this is a self-contained internal shell-scripting concurrency question; no external library or documentation dependency exists beyond POSIX `mkdir`/`mv` atomicity guarantees, which `task-lock.sh`'s own header comments already correctly document (`mkdir` is exclusive-create, `mv` on the same filesystem is atomic-on-replace).

### Recommendations

**Add one new subcommand to `task-lock.sh`: `init-marker <file_path>`** (content supplied via stdin), applied identically to both `.claude/scripts/task-lock.sh` and `.claude/extensions/core/scripts/task-lock.sh`. Proposed contract, modeled directly on `cmd_acquire`'s existing branch structure so it is recognizably "the same primitive," not a new mechanism:

```
task-lock.sh init-marker <file_path>
  stdin: the JSON content to write if this call wins the race
  exit 0: this call created the file (caller should treat it as "fresh start")
  exit 1: the file already exists / another writer won the race (caller should
          read the existing file and treat it as "resume", exactly like today's
          `else` branch)
  exit 2: usage/write error
```

Implementation shape (mirrors `cmd_acquire`, reuses `mkdir` for the gate and tmp+`mv` for the payload — no new primitive):

1. `mkdir "${file_path}.init" 2>/dev/null` as the atomic exclusivity claim scoped to that one file (distinct from and orthogonal to the task-number `.lock/` directory — this claim is per-marker-file, not per-task, so it composes independently of whatever `acquire`/`release` state the task-number lock is in).
2. On `mkdir` success: read stdin, write via `"${file_path}.tmp"` then `mv` to `"$file_path"` (same idiom as `write_holder`), `rmdir "${file_path}.init"`, exit 0.
3. On `mkdir` failure: if `$file_path` now exists and is valid JSON, exit 1 (caller resumes from it). If it still doesn't exist after a brief bounded recheck (handles a crashed initializer leaving an orphaned `${file_path}.init`), warn to stderr, `rmdir` the stale claim, and retry step 1 once — mirroring `cmd_acquire`'s existing "holder.json missing; treat as recoverable" branch (task-lock.sh:160-165).

**Call-site changes** (both dual-copy locations for each):

- `skill-orchestrate/SKILL.md` Stage 2 (currently lines 111-131) and `skill-orchestrate-hard/SKILL.md` Stage 2 (currently lines 199-220): replace the bare `else jq -n ... > "$loop_guard_file"` branch with `jq -n ... | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"`; on exit 1, fall through to the same `jq -r '.cycle_count // 0' "$loop_guard_file"` read the `if`-branch already uses, so a lost init race degrades gracefully into a resume rather than a failure.
- `skill-orchestrate-hard/SKILL.md`'s churn-file block (currently lines 222-228): same substitution for `$churn_file`.
- No change needed to the per-cycle refresh sites (`skill-orchestrate/SKILL.md:170,501`; `skill-orchestrate-hard/SKILL.md:262,299`) — those already use tmp+`mv` and only run after the file is known to exist.
- Apply every call-site edit to both `.claude/skills/...` and `.claude/extensions/core/skills/...` copies in the same commit/PR to preserve the confirmed-identical dual-copy invariant.
- Update `.claude/context/patterns/task-lock.md` (and its mirror) to document the new `init-marker` subcommand under "Contract: acquire / heartbeat / release / check" (renaming that heading or adding a subsection) and to remove/update the "Atomic-creation guard for `.orchestrator-loop-guard`" gap note under Non-Goals, since it will no longer be a gap.

**Explicitly not recommended**: do not give `.postflight-pending` its own `init-marker` treatment in this task. It has no create-vs-resume branch to protect, so `init-marker` (designed for that exact branch shape) is a mismatched tool for it — the actual fix for its exposure window is lock coverage for `/research`/`/plan`/`/revise`, which is task 810's scope. Introducing an `init-marker` call for `.postflight-pending` here would be scope creep that duplicates/competes with 810's planned gate-script migration.

**Explicitly not recommended**: do not build a second locking primitive (e.g., a separate flock-based or PID-file-based scheme) for the loop guard. `init-marker` deliberately reuses `mkdir` + tmp/`mv`, the same two idioms already used by `task-lock.sh`'s `acquire`/`write_holder`, so there is exactly one atomicity primitive in the codebase, not two competing ones — this is also what keeps this task compatible with 809's file-scope-aware locking extension (809 extends the task-number lock's *scope of comparison*, not its *underlying primitive*; `init-marker` sits at a different, file-level granularity and does not need to know about 809's changes).

## Decisions

- Scope the fix to exactly two files: `.orchestrator-loop-guard` and `.orchestrator-churn-state.json` (both only in `skill-orchestrate`/`skill-orchestrate-hard`). No other marker file in the codebase exhibits the same TOCTOU-vulnerable "check absent, then create default state" shape tied to concurrency-sensitive state.
- Defer `.postflight-pending`'s non-lock-protected window (for `/research`/`/plan`/`/revise`) to task 810 rather than duplicating a fix here; note the dependency explicitly so a future planner does not attempt to solve the same problem twice with different mechanisms.
- Recommend a new `task-lock.sh` subcommand (`init-marker`) rather than a bespoke inline `mkdir` dance repeated at each of the two call sites, so there remains exactly one place (`task-lock.sh`) that implements the "atomic mkdir + tmp/mv write" idiom, consistent with `task-lock.md`'s own stated principle that "call sites NEVER reimplement lock logic inline."
- Treat `.opencode/skills/skill-orchestrate/SKILL.md` as out of scope: it is a separately-maintained, already-diverged mirror for a different runtime (OpenCode), not one of the `.claude` + `.claude/extensions/core` dual-copy pairs this task and its CLAUDE.md definition are scoped to.

## Risks & Mitigations

- **Risk**: adding `init-marker` to `task-lock.sh` could be mistaken for a second concurrency mechanism competing with the task-number lock. **Mitigation**: document in `task-lock.md` that `init-marker` operates at file-granularity (guards one marker file's first write) and is independent of, and composable with, the task-number `.lock/` directory — it does not replace `acquire`/`release`, it only protects a single-file's create-once-vs-resume race that can still occur even while the outer lock is held (during a stale-override, or from a future call site that forgets to acquire the outer lock first).
- **Risk**: forgetting to update both dual-copy locations for either `task-lock.sh` or the two `SKILL.md` files causes drift. **Mitigation**: this report explicitly enumerates all four files (`.claude/scripts/task-lock.sh`, `.claude/extensions/core/scripts/task-lock.sh`, and the two SKILL.md pairs) plus the `task-lock.md` doc pair; a planner/implementer should diff-verify byte-identity across each pair after editing, exactly as this research did before proposing changes.
- **Risk**: a crashed initializer could leave an orphaned `${file_path}.init` directory, permanently blocking future `init-marker` calls for that file. **Mitigation**: mirror `task-lock.sh`'s own existing pattern for the analogous case (`holder.json` missing inside an existing `.lock/` dir — task-lock.sh:160-165, "treat as recoverable and override"): `init-marker` should detect a stale `.init` claim with no resulting target file and self-heal by removing it and retrying once, with a visible `WARN:` message, never a silent failure and never a permanent lock-out.
- **Risk**: composing with 809 (file-scope-aware locking) or 810 (gate-script sourcing) if either lands first and changes call-site line numbers this report cites. **Mitigation**: this report's remediation is additive at the `task-lock.sh` level (new subcommand) and localized at the two `SKILL.md` call sites; it does not touch `command-gate-in.sh`/`command-gate-out.sh` (810's territory) or `acquire`'s file-scope comparison logic (809's territory), so it should merge cleanly regardless of ordering, modulo routine line-number drift in the diff.

## Context Extension Recommendations

- **Topic**: Generic atomic marker-file initialization
- **Gap**: `.claude/context/patterns/task-lock.md` currently documents only the task-number lock contract (`acquire`/`heartbeat`/`release`/`check`); it has no section for a lower-level, file-granularity "first write wins" primitive, even though this task's remediation adds one.
- **Recommendation**: when implemented, extend `task-lock.md` with an `init-marker` contract subsection (mirroring the existing `acquire` contract's numbered steps) so future marker-file authors reach for this primitive by default instead of reintroducing the `jq -n ... > file` pattern task 788 and this task are incrementally retiring.

## Appendix

### Search queries / commands used

- `grep -rn "orchestrator-loop-guard" .claude` (and `postflight-pending`, `jq empty`, `drift-inspection`, `orchestrator-churn-state`) across `.claude/` to enumerate all creation/reference sites.
- `diff .claude/skills/skill-orchestrate{,-hard}/SKILL.md .claude/extensions/core/skills/skill-orchestrate{,-hard}/SKILL.md` and the equivalent for `task-lock.sh` and `task-lock.md` — confirmed byte-identical dual-copy pairs today.
- `diff .claude/skills/skill-orchestrate/SKILL.md .opencode/skills/skill-orchestrate/SKILL.md` — confirmed the OpenCode mirror is already divergent and out of this task's dual-copy scope.
- Read `.claude/scripts/task-lock.sh` in full (the atomic primitive's reference implementation).
- Read `.claude/context/patterns/task-lock.md` in full (canonical spec, including the pre-existing gap note this task closes).
- Read `specs/state.json` entries for tasks 808/809/810 to confirm batch coherence and non-overlapping scope boundaries.

### Key file:line references

- `.claude/scripts/task-lock.sh:150-186` (`cmd_acquire`, the pattern to mirror)
- `.claude/scripts/task-lock.sh:104-121` (`write_holder`, the tmp+`mv` idiom to reuse)
- `.claude/skills/skill-orchestrate/SKILL.md:105-131` (Stage 2, loop guard — fix site 1)
- `.claude/skills/skill-orchestrate-hard/SKILL.md:192-220` (Stage 2, loop guard — fix site 2)
- `.claude/skills/skill-orchestrate-hard/SKILL.md:222-228` (Stage 2, churn state — fix site 3)
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` and `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — identical mirrors, same line numbers, fix sites 4-6
- `.claude/scripts/skill-base.sh:150-165` / `.claude/extensions/core/scripts/skill-base.sh:150-165` (`skill_create_postflight_marker`, out-of-scope reference)
- `.claude/context/patterns/task-lock.md:167` / `.claude/extensions/core/context/patterns/task-lock.md:167` (the pre-existing gap note this task closes)

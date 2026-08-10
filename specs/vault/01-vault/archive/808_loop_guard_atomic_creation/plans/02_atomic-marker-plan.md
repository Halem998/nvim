# Implementation Plan: Task #808

- **Task**: 808 - Bring `.orchestrator-loop-guard` (and race-safe peer marker files) up to the atomic-creation standard established by `task-lock.sh`
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: 788 (introduced `task-lock.sh` + the `mkdir`/tmp-`mv` primitive). Coordinated batch with 809 (extends `cmd_acquire` with file-scope overlap checks) and 810 (migrates `/research`,`/plan`,`/revise` onto shared gate scripts; owns `.postflight-pending`'s lock-coverage gap).
- **Research Inputs**: specs/808_loop_guard_atomic_creation/reports/01_marker-file-atomicity-audit.md
- **Artifacts**: plans/02_atomic-marker-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, artifact-formats.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three marker-file creation branches in the orchestrator skills use the non-atomic `jq -n ... > file`
pattern behind a `if [ -f X ]; then resume; else create; fi` guard. Because a plain `>` redirect has
no `O_EXCL` semantics, two racing writers can both take the `else` branch and both stomp a fresh
zeroed state over the other's in-progress counters (a TOCTOU lost-state bug that survives even the
task-number lock, since `acquire`'s stale-override deliberately permits two live writers). This plan
adds one new generic subcommand — `task-lock.sh init-marker <file_path>` (JSON content on stdin) —
that reuses `task-lock.sh`'s existing exclusivity idiom (`mkdir` gate + tmp-file-`mv` payload write),
then swaps the three vulnerable creation branches to call it, degrading gracefully to a resume-read
on a lost race (exit 1). Definition of done: all three sites are atomic-on-creation, a concurrent-
creation stress test proves exactly-one-winner semantics, `task-lock.md` documents the new subcommand
and retires its own known-gap note, and every dual-copy pair remains byte-identical.

### Research Integration

Integrates report `01_marker-file-atomicity-audit.md`. Key findings adopted verbatim:
- Exactly **two** files carry the TOCTOU "check-then-create-with-resume" shape:
  `.orchestrator-loop-guard` (both `skill-orchestrate` and `skill-orchestrate-hard`) and
  `.orchestrator-churn-state.json` (`skill-orchestrate-hard` only) — **three creation branches** total.
- The fix is a new `init-marker` subcommand modeled on `cmd_acquire`'s branch structure
  (`mkdir` success → write once, exit 0; `mkdir` fail + valid target → exit 1 "resume from theirs";
  `mkdir` fail + missing/corrupt target → warn, self-heal, retry once), NOT a second locking mechanism.
- The per-cycle refresh sites (`skill-orchestrate:170,501`; `skill-orchestrate-hard:262,299,551,568`)
  already use tmp+`mv` and run only after the file exists — **out of scope, do not touch**.
- `.postflight-pending` is NOT in this task's scope (no create-vs-resume branch to race; its lock-
  coverage window is task 810's territory).

### Prior Plan Reference

No prior plan. This is the first plan for task 808 (round 02: research report was 01).

### Roadmap Alignment

No `roadmap_flag` set for this dispatch; ROADMAP.md not consulted. No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Add `task-lock.sh init-marker <file_path>` (stdin=JSON) to **both** copies of `task-lock.sh`,
  byte-identically, reusing the existing `mkdir` + tmp-`mv` idiom (no new primitive).
- Swap all three TOCTOU creation branches (across four SKILL.md copies) to call `init-marker` with a
  resume-read fallback on exit 1, preserving the exact fields each existing resume branch reads.
- Update `.claude/context/patterns/task-lock.md` (and its mirror) to document `init-marker` and remove
  the stale "Atomic-creation guard for `.orchestrator-loop-guard`" gap note under Non-Goals.
- Verify with a concurrent-creation stress test and byte-identity diffs across all four dual-copy pairs.

**Non-Goals**:
- **Do NOT restructure `cmd_acquire`** (task-lock.sh:151-~200) — task 809 owns that region. `init-marker`
  is added as a new, self-contained function plus a new `case` arm; it does not read, call, or modify
  `cmd_acquire`, `write_holder`, or the task-number `.lock/` directory.
- **Do NOT touch `.postflight-pending`** or its lock-coverage gap — task 810's territory.
- **Do NOT change** the per-cycle refresh sites (they are already atomic-on-replace via tmp+`mv`).
- **Do NOT touch** the `.opencode/` orchestrate mirror (separately maintained, already divergent).
- No git commit, no state.json/TODO.md edit, no `.claude/` edits — this is a PLANNING dispatch only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit lands in only one copy of a dual-copy pair → drift | H | M | Every editing phase edits BOTH copies in the same phase and runs `diff -q` byte-identity as a verification gate before the phase is marked complete. |
| `init-marker` mistaken as a second concurrency mechanism competing with the task-number lock | M | M | Document in `task-lock.md` that it is file-granularity and composes independently of `.lock/`; place it in its own function and `case` arm, never entangled with `cmd_acquire`. |
| Crashed initializer leaves orphaned `${file_path}.init` dir → permanent lock-out | M | L | Mirror `cmd_acquire`'s "holder missing → recoverable" self-heal: on `mkdir` fail with no resulting target file after a bounded recheck, warn to stderr, `rmdir` the stale claim, retry once. Never silent, never permanent. |
| Lost-race exit-1 branch reads fewer fields than the original resume branch (e.g. drops `burnout_signals_this_session`) | M | M | Phase 2 tasks enumerate the exact fields each resume branch reads; the exit-1 fallback reuses the identical `jq` reads. Verification greps confirm parity. |
| 809/810 land first and shift cited line numbers | L | M | This plan's edits are additive at the `task-lock.sh` level (new function + `case` arm at the end of the dispatch block) and localized to the three `else` branches; anchor edits on unique code text, not line numbers. |
| Refresh site accidentally modified | M | L | Phase 2 verification greps confirm the four/six tmp+`mv` refresh sites are byte-unchanged. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Add `init-marker` subcommand to `task-lock.sh` (both copies) [COMPLETED]

**Goal**: Introduce a generic, atomic-on-creation `init-marker <file_path>` subcommand that reuses the
existing `mkdir` exclusivity gate + tmp-file-`mv` payload write, added byte-identically to both copies,
without touching `cmd_acquire`.

**Tasks**:
- [x] In `.claude/scripts/task-lock.sh`, add a new `cmd_init_marker()` function (place it after
      `cmd_check` / before the `# Dispatch` divider, so it does not intrude on `cmd_acquire`'s region).
      Contract:
      - Arg: `file_path`. Content: read from stdin.
      - `mkdir "${file_path}.init" 2>/dev/null` as the atomic per-file exclusivity claim (distinct from
        the task-number `.lock/` dir).
      - On `mkdir` success: read stdin, write to `"${file_path}.tmp"`, guard against empty jq output
        (mirror `write_holder`'s `[ ! -s ]` check), `mv` to `"$file_path"`, `rmdir "${file_path}.init"`,
        exit 0 ("caller treats as fresh start").
      - On `mkdir` failure: if `$file_path` exists and is valid JSON (`jq empty`), exit 1 ("caller
        resumes from existing"). If the target is still absent/corrupt after a bounded recheck (crashed
        initializer left an orphaned `.init`), print a `WARN:` to stderr, `rmdir "${file_path}.init"`,
        and retry the claim once; if the retry also fails, exit 2. *(completed: bounded recheck
        implemented as a 10x50ms poll loop distinguishing an actively-racing writer from a crashed one)*
      - Usage/write errors exit 2.
- [x] Add an `init-marker)` arm to the `case "$SUBCMD"` dispatch block (task-lock.sh:294-331), with a
      `[ "$#" -lt 1 ]` usage guard (`Usage: $0 init-marker <file_path>`, exit 2), calling
      `cmd_init_marker "$@"`. *(completed)*
- [x] Update the script's header comment block (the exit-code documentation near lines 30-50) to add the
      `init-marker` exit-code table (0=created, 1=already-exists/resume, 2=usage/write-error).
      *(completed)*
- [x] Apply the three edits above **identically** to `.claude/extensions/core/scripts/task-lock.sh`.
      *(completed: verified byte-identical via diff -q)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/task-lock.sh` - add `cmd_init_marker()`, `init-marker)` case arm, header comment
- `.claude/extensions/core/scripts/task-lock.sh` - identical mirror of the above

**Verification**:
- `bash -n` (syntax) passes on both copies.
- `diff -q .claude/scripts/task-lock.sh .claude/extensions/core/scripts/task-lock.sh` → IDENTICAL.
- Grep confirms `cmd_acquire` and `write_holder` are byte-unchanged (no accidental edit to 809's region).
- **Concurrent-creation stress test** (temp dir, run against the deployed copy):
  - Launch N=20 background writers that each pipe distinct JSON (e.g. `{"writer": $i}`) into
    `task-lock.sh init-marker "$tmpdir/marker.json"` simultaneously (`&` + `wait`), capturing each exit code.
  - Assert: exactly **one** writer exits 0; all others exit 1; the final `marker.json` is valid JSON
    equal to the winner's payload; no `marker.json.init` directory and no `marker.json.tmp` file remain.
  - Orphan-recovery test: pre-create `marker2.json.init` with no `marker2.json`, then run one
    `init-marker "$tmpdir/marker2.json"`; assert it self-heals (WARN to stderr), creates the file, exits 0.

---

### Phase 2: Swap the three TOCTOU creation branches to `init-marker` (four SKILL.md copies) [COMPLETED]

**Goal**: Replace each bare `else ... jq -n ... > "$file"` creation branch with an `init-marker` call
whose exit-1 (lost-race) path falls through to the same resume-read the `if`-branch already performs,
so a lost init race degrades into a resume rather than a clobber. Edit both dual-copy locations.

**Tasks**:
- [x] `skill-orchestrate/SKILL.md` Stage 2 (loop-guard else branch, lines ~115-130): replace the
      `jq -n ... '{...}' > "$loop_guard_file"` with
      `jq -n ... '{...}' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"`; on exit 1,
      set `cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")` (the same read the `if`-branch
      uses at line 113). Keep the `cycle_count=0` fresh-start assignment on exit 0. *(completed)*
- [x] `skill-orchestrate-hard/SKILL.md` Stage 2 (loop-guard else branch, lines ~203-219): same swap for
      `$loop_guard_file`; on exit 1, read **both** `cycle_count` and
      `burnout_signals_this_session` (the two fields the `if`-branch reads at lines 200-201), not just one.
      *(completed)*
- [x] `skill-orchestrate-hard/SKILL.md` Stage 2 (churn-state else branch, lines ~225-227): swap
      `jq -n '{...}' > "$churn_file"` to pipe through `init-marker "$churn_file"`; on exit 1, set
      `total_churn=$(jq -r '.total_churn // 0' "$churn_file")` (matching line 224's read). *(completed)*
- [x] Apply all three edits **identically** to the `extensions/core` mirrors:
      `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` and
      `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`. *(completed: verified byte-identical
      via diff -q)*
- [x] Confirm the per-cycle refresh sites (`skill-orchestrate:170,501`;
      `skill-orchestrate-hard:262,299,551,568`) are left untouched. *(completed: grep-verified all 6 tmp+mv
      refresh redirects present unchanged, only line numbers shifted)*

**Timing**: 0.75 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - loop-guard creation branch
- `.claude/skills/skill-orchestrate-hard/SKILL.md` - loop-guard + churn-state creation branches
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` - identical mirror
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - identical mirror

**Verification**:
- `diff -q` on both SKILL.md pairs → IDENTICAL.
- Grep confirms no bare `> "$loop_guard_file"` / `> "$churn_file"` **creation** redirect remains
  (only the tmp-file refresh redirects `> "${loop_guard_file}.tmp"` / `> "${churn_file}.tmp"` survive).
- Grep confirms each exit-1 fallback reads the identical field set as its paired `if`-branch
  (loop guard hard: both `cycle_count` and `burnout_signals_this_session`).
- Integration smoke test: run the Stage 2 bash block against a temp `TASK_DIR` twice in one shell
  (fresh then resume) and confirm the second run resumes (non-fresh) without clobbering counters.

---

### Phase 3: Document `init-marker` and retire the gap note in `task-lock.md` (both copies) [COMPLETED]

**Goal**: Add an `init-marker` contract subsection to the canonical pattern doc and remove the now-
obsolete "Atomic-creation guard for `.orchestrator-loop-guard`" Non-Goals note, keeping both copies
byte-identical.

**Tasks**:
- [x] In `.claude/context/patterns/task-lock.md`, add an `### init-marker <file_path>` subsection under
      the "Contract: acquire / heartbeat / release / check" section (and update that heading to include
      `init-marker`), describing: stdin=JSON content, exit 0=created/fresh, exit 1=exists/resume,
      exit 2=usage/write-error, the `mkdir "${file_path}.init"` gate + tmp-`mv` payload, and the orphan
      self-heal behavior. Explicitly note it is file-granularity and composes independently of the
      task-number `.lock/` directory (does not replace `acquire`/`release`). *(completed)*
- [x] Remove the "Atomic-creation guard for `.orchestrator-loop-guard`" bullet from the Non-Goals section
      (task-lock.md:167-170), since the gap is now closed. Optionally add a one-line back-reference noting
      it was addressed by task 808's `init-marker`. *(completed: reworded to a struck-through summary +
      CLOSED back-reference, avoiding the literal retired phrase per the grep verification gate)*
- [x] Add `.orchestrator-loop-guard` / `.orchestrator-churn-state.json` (and the two orchestrate SKILL.md
      files) to the "Consumers" / "Related Documentation" listing as `init-marker` call sites. *(completed)*
- [x] Apply all edits **identically** to `.claude/extensions/core/context/patterns/task-lock.md`.
      *(completed: verified byte-identical via diff -q)*

**Timing**: 0.5 hour

**Depends on**: 1

**Files to modify**:
- `.claude/context/patterns/task-lock.md` - add init-marker contract, retire gap note, update consumers
- `.claude/extensions/core/context/patterns/task-lock.md` - identical mirror

**Verification**:
- `diff -q` on the task-lock.md pair → IDENTICAL.
- Grep confirms the string "Atomic-creation guard for" no longer appears (gap note retired).
- Grep confirms an `init-marker` contract subsection now exists with the exit-code semantics.

## Testing & Validation

- [x] `bash -n` passes on both `task-lock.sh` copies. *(verified)*
- [x] Concurrent-creation stress test (Phase 1): N=20 parallel writers → exactly one exit 0, rest exit 1,
      final file = winner's valid JSON, no leftover `.init`/`.tmp` artifacts. *(verified: writer 2 exited 0,
      all 19 others exited 1, final marker.json == winner's payload, no leftovers)*
- [x] Orphan-recovery test (Phase 1): stale `.init` with missing target self-heals and creates the file.
      *(verified: WARN printed, exit 0, file created, no leftovers)*
- [x] Byte-identity across all four dual-copy pairs (`diff -q` IDENTICAL): `task-lock.sh`,
      `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`, `task-lock.md`. *(verified all 4)*
- [x] No bare creation `>` redirect remains at the three swapped sites; refresh sites unchanged.
      *(verified via grep)*
- [x] Exit-1 resume fallback reads the same fields as each paired `if`-branch (field-parity grep).
      *(verified: loop-guard hard reads both cycle_count and burnout_signals_this_session on exit 1)*
- [x] `cmd_acquire` / `write_holder` byte-unchanged (809 region untouched); `.postflight-pending`
      untouched (810 region untouched). *(verified: git diff shows no changes inside those functions;
      .postflight-pending not referenced anywhere in this task's edits)*
- [x] "Atomic-creation guard for" gap note removed from both `task-lock.md` copies; `init-marker`
      contract documented. *(verified: grep confirms the literal phrase no longer appears in either copy)*

## Artifacts & Outputs

- `specs/808_loop_guard_atomic_creation/plans/02_atomic-marker-plan.md` (this file)
- Modified (at implement time): `.claude/scripts/task-lock.sh` + core mirror;
  `.claude/skills/skill-orchestrate/SKILL.md` + core mirror;
  `.claude/skills/skill-orchestrate-hard/SKILL.md` + core mirror;
  `.claude/context/patterns/task-lock.md` + core mirror
- `specs/808_loop_guard_atomic_creation/summaries/02_atomic-marker-summary.md` (at implement time)

## Rollback/Contingency

All changes are additive and localized. To revert: `git checkout` the eight touched files (four dual-copy
pairs). Because `init-marker` is a new subcommand and a new `case` arm with no changes to existing
subcommands, reverting only the SKILL.md call-site edits (Phase 2) leaves a harmless unused subcommand in
`task-lock.sh` — safe partial rollback. If the concurrent-creation test fails in Phase 1, do not proceed to
Phase 2 (call sites depend on a correct primitive); fix the `cmd_init_marker` logic first. If a dual-copy
diff is non-identical at any phase gate, re-sync before marking the phase complete.

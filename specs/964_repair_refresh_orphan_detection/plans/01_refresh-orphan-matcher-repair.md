# Implementation Plan: Task #964

- **Task**: 964 - Repair /refresh orphan detection so live system and session processes are never selected
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/964_repair_refresh_orphan_detection/reports/01_refresh-orphan-matcher-repair.md
- **Artifacts**: plans/01_refresh-orphan-matcher-repair.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; shell-script-testing.md; source-store-deploy-boundary.md; no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/refresh`'s orphaned-process matcher selects live system daemons, live-session sleep inhibitors,
a live memory-tracker service, and the refresh script's own subshells as "orphans". On the
verification machine the current script reports 10 orphans and all 10 are confirmed false
positives, so `--force` today terminates live processes — including the OOM daemon that protects
the machine and the inhibitor of the session issuing the command. This plan replaces the
two-stage `ps aux`-regex-then-re-query matcher with a single atomic `ps -eo` snapshot plus four
independently-testable exclusion predicates, adds the regression suite that is a hard acceptance
criterion, makes the systemd timer non-destructive by default, fixes the pre-exclusion reclaim
figure, adds a real process-cleanup preview path, and reconciles the three doc sites that
currently assert a safety property the code does not implement.

**Binding constraint (restated because it is easy to lose mid-implementation)**: `.claude/**` is a
gitignored, disposable deploy artifact. Every edit in every phase below targets
`agent-system/extensions/core/**`. A file written under `.claude/` is silently wiped by the next
regeneration.

**Definition of done**: all seven acceptance criteria in the task description hold, verified by
the Phase 5 sweep.

### Research Integration

The research report confirms all four described root causes at the line level, live-reproduces
every false positive read-only, and adds a fifth root cause the description did not state. Three
findings materially shape this plan:

1. **A fifth root cause: the ancestor walk is a race, not just a wrong direction.**
   `is_in_current_tree()` re-queries `ps -o ppid=` against PIDs captured in an *earlier*
   snapshot. Transient subshell PIDs have typically already exited by then, `ps` returns empty,
   the loop condition goes false, and the function **fails closed to "not excluded"** — i.e.
   unsafe-by-default. A direction-only fix ("walk siblings too") would not close this. The fix
   must avoid any second, later live re-query for anything answerable from the first snapshot.
2. **One unifying redesign closes root causes 1, 2, and the race**: a single atomic
   `ps -eo pid,ppid,uid,tty,etimes,rss,comm,cgroup,args --no-headers` snapshot (verified working
   on this machine, cgroup column included), with matching on `comm`/`cgroup`/`uid` decided
   entirely from data already in that snapshot.
3. **The four required assertions are unit-testable without fabricating system processes**, via
   the standard `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` dual-mode idiom
   around a new `main()`. This is a normal bash idiom, not test-detection instrumentation, and is
   consistent with `shell-script-testing.md`'s rule that the script under test is never modified
   to know it is under test.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path supplied in the delegation context; no ROADMAP.md consultation performed.

### Investigated and Dismissed — Do Not Re-Open

`scripts/claude-cleanup.sh` exists in both the source store and the deploy and is invoked by
`skills/skill-refresh/SKILL.md` Steps 6-7. `claude-refresh.sh` is process-only **by design**;
directory cleanup is that separate, working script. The task description records this as
investigated and dismissed. No phase below touches `claude-cleanup.sh`.

### Companion Edit Outside `file_scope` — Do Not Miss

The new test file requires a `provides.scripts` entry in
`agent-system/extensions/core/manifest.json`, subdirectory-qualified as
`tests/test-claude-refresh-matcher.sh` per `shell-script-testing.md`'s Registration section.
`manifest.json` is **not** in the declared `file_scope` list, but this registration is the
standard companion edit every new script requires. It is an explicit, separately-verified task of
Phase 2.

## Goals & Non-Goals

**Goals**:
- Replace the matcher with a single-snapshot, comm/cgroup/uid/liveness design that never selects
  a system daemon, an argv-mentions-claude process, a live-session inhibitor, or the script's own
  subshells.
- Ship `scripts/tests/test-claude-refresh-matcher.sh` asserting all four named regression cases,
  proven to go RED against the pre-fix script at least once.
- Register the new test in `manifest.json`'s `provides.scripts`.
- Make the reported reclaim figure post-exclusion.
- Add a genuine `--dry-run` preview path for process cleanup and make `commands/refresh.md`'s
  `--dry-run` description true of shipped behavior.
- Make `systemd/claude-refresh.service` and the `install-systemd-timer.sh`-generated `ExecStart`
  non-destructive by default, with `--force` a deliberate opt-in.
- Leave no doc site claiming a safety property the code does not implement.

**Non-Goals**:
- Any change to `scripts/claude-cleanup.sh` or the directory-cleanup half of `/refresh`.
- Fixing the separately-tracked deploy-propagation gap whereby a brand-new
  `scripts/tests/*.sh` file may not reach `.claude/scripts/tests/` on an existing deploy. The
  four existing suites run from the source store; so will this one.
- Broadening orphan *detection* sensitivity. This repair deliberately trades recall for safety
  (see Risks).
- Moving the `specs/` sweeps (task-lock reap, session-file reap) onto the systemd cadence.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `ps -o cgroup` unavailable on a future platform, and the code silently falls back to the old unsafe argv regex | H | L | Fail LOUDLY: if the snapshot's cgroup column is empty or the `ps` invocation fails, print an explicit error and exit non-zero rather than degrading. A silent fallback reintroduces the exact defect being fixed. Never substitute a permissive default. |
| comm-based allow-list is too narrow, so a genuine orphan is never detected (false negative) | M | M | Accepted and documented trade-off: a leaked process surviving is strictly safer than terminating a live system daemon. State this explicitly in the script header and in the reconciled doc sites so a future reader does not "fix" it by widening the match back toward argv. |
| Re-widening `node` matching reintroduces root cause 1 | H | M | `node` may match ONLY when its argv references a Claude CLI entrypoint path AND uid, cgroup, and TTY predicates also pass. Never match `node` on a bare argv substring. |
| Predicate 4 (inhibitor liveness) looks redundant once comm matching lands, and gets omitted | H | M | It is required by acceptance criterion 1(c) and must be independently unit-testable. See the explicit note in Phase 1. Do not drop it as redundant. |
| Regression suite passes vacuously (asserts behavior both old and new code already got right) | M | M | Mandatory mutation check: the suite must be shown RED against the pre-fix script (obtainable via `git show HEAD:agent-system/extensions/core/scripts/claude-refresh.sh`) before Phase 2 closes. |
| Column-index drift: `ps aux` field positions (`$2` pid, `$6` rss, `$7` tty, `$11+` cmd) are hardcoded in five places and differ from the new `-eo` order | M | H | Phase 1 carries the explicit new field-index map. Audit every `awk '{print $N}'` in the file, not only the ones named in the research report. |
| Editing `.claude/**` instead of the source store; the edit appears to succeed and is then wiped | H | M | Every phase names source-store paths only. The advisory PostToolUse hook nudges but does not block. |
| Task-number citations leaking into deliverables outside `specs/**` | M | M | All six edited files are deliverables. Cite durable anchors (section names, mechanism descriptions), never task numbers. The write-time hook blocks this, but do not rely on it. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Matcher core rewrite in claude-refresh.sh [COMPLETED]

- **Goal:** Replace the two-stage `ps aux` regex + later re-query matcher with a single atomic
  snapshot and four independently-callable exclusion predicates; add the `main()` dual-mode
  guard; add `--dry-run`; compute the reclaim figure post-exclusion; rewrite the header safety
  block to describe the mechanism that actually exists.

- **Tasks:**
  - [x] Replace `get_claude_processes()` (`:106-108`) and `get_orphaned_processes()` (`:111-113`)
        with one snapshot collector taking a single
        `ps -eo pid,ppid,uid,tty,etimes,rss,comm,cgroup,args --no-headers` reading. If the `ps`
        call fails or the cgroup column comes back empty, print an explicit error naming the
        missing column and exit non-zero — never fall back to the old regex. *(completed:
        `take_snapshot()` + `validate_cgroup_support()`)*
  - [x] Record the new field-index map at the top of the parsing code and audit **every**
        `awk '{print $N}'` in the file against it. New order: `$1` pid, `$2` ppid, `$3` uid,
        `$4` tty, `$5` etimes, `$6` rss, `$7` comm, `$8` cgroup, `$9..NF` args. This changes the
        existing `aux`-based indices at `:112`, `:117`, `:124`, `:174`, `:181`, and `:182`.
        *(completed: field map documented in a header comment; all `awk` field-index parsing
        removed in favor of `read`, so no residual `awk '{print $N}'` sites remain — verified
        `grep -n awk` returns only the explanatory comment)*
  - [x] Add the four predicates as named, separately-callable functions:
        `is_claude_executable_comm`, `is_system_slice_cgroup`, `is_owned_by_current_uid`,
        `is_live_inhibitor_target`. Each takes its inputs as arguments (fields already read from
        the snapshot) and performs no `ps` re-query, with the single exception noted below.
  - [x] `is_claude_executable_comm`: match on the `comm` column against a narrow
        Claude-executable allow-list. `node` matches ONLY when its argv additionally references a
        Claude CLI entrypoint path. Never match on a bare argv substring anywhere.
  - [x] `is_system_slice_cgroup`: exclude any candidate whose cgroup field is under
        `/system.slice/`.
  - [x] `is_owned_by_current_uid`: exclude any candidate whose uid differs from `$(id -u)`.
  - [x] `is_live_inhibitor_target`: for a candidate identified as a `systemd-inhibit`/`tail
        --pid=<N>` holder, extract `<N>` from the args column and exclude the candidate when
        `kill -0 <N>` succeeds. **This is the one predicate that legitimately performs a live
        check** — and it checks a *different* process (the held target), not the candidate, so it
        introduces no stale-snapshot race on the candidate itself.
  - [x] **Do not omit predicate 4 as redundant.** Once comm matching lands, today's observed
        inhibitors (comm `systemd-inhibit`/`tail`) are already excluded by predicate 1. Predicate
        4 is nonetheless required by acceptance criterion 1(c), is the only predicate that
        protects *other* live sessions rather than the invoker's own, and must remain
        independently unit-testable. *(kept and documented in-code as defense-in-depth, not
        dead code)*
  - [x] Delete `is_in_current_tree()` (`:54-66`) entirely, along with the `PARENT_PID` re-query at
        `:51`. Replace with zero-query self-exclusion: skip any candidate whose pid or ppid equals
        `$$` (known at parse time, no second query, no race window).
  - [x] Rewrite `get_process_age()` (`:69-86`) to read `etimes` from the snapshot rather than
        re-querying `ps`, removing the last stale-snapshot re-query.
  - [x] Retain `tty == "?"` as a necessary-but-not-sufficient signal, never as the sole
        discriminator. Document in a comment that it is true of every systemd-managed process by
        construction and therefore discriminates nothing on its own.
  - [x] Move the reclaim summation so it runs over the **post-exclusion** surviving set. Replace
        the pre-loop `orphan_mem=$(echo "$orphan_procs" | calculate_memory)` (`:155`) with an
        accumulator inside the exclusion loop (`:172-188`). Fix **both** consumers: the status-mode
        display (`:206`, `:217`) and the force-mode summary (`:266`). *(completed: `orphan_mem`
        is now accumulated only for rows surviving every predicate, in the single snapshot loop;
        both the no-flag/`--dry-run` display and the force-mode summary read the same
        post-exclusion total)*
  - [x] Wrap the existing top-level execution block (`:132` onward) in a new `main()` and guard
        the call with `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`. Runtime
        behavior when executed normally must be unchanged by this restructure alone. *(completed:
        argument parsing was also moved inside `main()`, not just the business logic, so that
        `source`-ing the script has zero side effects — behavior when run as a script is
        byte-for-byte equivalent to keeping the parser outside `main()`, since `main "$@"` is
        called unconditionally in that case)*
  - [x] Add `--dry-run` to the argument parser (`:28-47`) as an explicit named mode, behaving
        identically to the existing safe no-flag path but emitting a `DRY RUN` banner. Do not
        invent a second preview implementation; the no-flag path already is the correct preview.
        Update the `--help` text to list `--dry-run`.
  - [x] Rewrite the header safety block (`:11-14`). Delete the false "Excludes current process
        and parent process tree" claim. Describe the four actual predicates plus zero-query self
        exclusion, and record the deliberate recall-for-safety trade-off (a missed orphan is
        strictly preferable to killing a live daemon) so a future reader does not widen the match
        back toward argv.
  - [x] Cite durable anchors only in comments — mechanism names and section titles, never task
        numbers (this file is a deliverable outside `specs/**`).

- **Timing:** 1.5 hours

- **Depends on:** none

- **Verification Tier:** interface

  Rationale: the phase changes both the script's CLI surface (adds `--dry-run`) and introduces
  named predicate functions that become a consumed interface. Enumerated direct dependents to
  check: `skills/skill-refresh/SKILL.md` Step 2 (invocation), `systemd/claude-refresh.service`
  `ExecStart`, `scripts/install-systemd-timer.sh` generated `ExecStart`, and the Phase 2 test
  suite (sources the script and calls the predicates by name). Existing `--force` and no-flag
  invocations must remain accepted unchanged — the CLI addition is additive only.

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase asserts (a) exactly four exclusion predicates suffice,
  (b) the six `awk` field-index sites listed above are the complete set, and (c) a post-fix
  status-mode run on this machine reports ZERO orphans. Confirm at implementation time by:
  (a) checking each of the four named regression assertions maps to exactly one predicate;
  (b) `grep -n "awk" agent-system/extensions/core/scripts/claude-refresh.sh` and auditing every
  hit rather than only the six anticipated; (c) running
  `bash agent-system/extensions/core/scripts/claude-refresh.sh` (no flags — the read-only path)
  and reporting the actual count. If the count is non-zero, enumerate each surviving PID and
  classify it as true orphan or residual false positive before closing the phase. **Never invoke
  `--force` during verification.**

- **Files to modify:**
  - `agent-system/extensions/core/scripts/claude-refresh.sh` — matcher rewrite, predicates,
    `main()` guard, `--dry-run`, post-exclusion reclaim, header block

- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` clean
  - No-flag run completes and reports its orphan count (expected: 0)
  - `--dry-run` run is accepted (no unknown-option exit) and prints the DRY RUN banner
  - `--force` and `--help` still accepted
  - `source`-ing the script defines the four predicates without executing `main()`
  - `grep -n "is_in_current_tree" ...` returns nothing
  - No task-number citation present in the edited file

---

### Phase 2: Regression suite and manifest registration [COMPLETED]

- **Goal:** Ship `scripts/tests/test-claude-refresh-matcher.sh` covering all four named
  assertions, proven RED against the pre-fix script, and register it in `manifest.json`.

- **Tasks:**
  - [x] Create `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`
        following the convention of the four existing suites (`test-git-commit-scoped.sh`,
        `test-validate-no-task-references.sh`, `test-census-count.sh`,
        `test-phase-heading-patterns.sh`): `set -uo pipefail`, `SCRIPT_DIR` via `BASH_SOURCE[0]`,
        `PASSED`/`FAILED` counters with `pass()`/`fail()`/`info()` helpers, `mktemp -d` workdir
        with `trap ... EXIT` cleanup, loud-skip discipline (never silently `exit 0` having
        skipped a case).
  - [x] Copy the script under test into the suite's own `mktemp -d` workdir and `source` it
        there, matching the existing precedent, so predicates are called directly rather than
        through a subprocess per case.
  - [x] Assertion (a) — system-slice exclusion: `is_system_slice_cgroup
        "0::/system.slice/earlyoom.service"` true; a real user-session cgroup
        (`0::/user.slice/user-<uid>.slice/...`) false. A process under `/system.slice/` is NEVER
        selected.
  - [x] Assertion (b) — argv-mention rejection: a synthetic snapshot row whose args contain
        `claude` inside an unrelated flag (reproduce the real `earlyoom --prefer
        ^(lean|lake|claude|node|npm|opencode)$` line) but whose comm is `earlyoom` must be
        rejected by the comm predicate.
  - [x] Assertion (c) — inhibitor liveness, driven by a REAL process: spawn `sleep 300 &`,
        capture its pid, build a synthetic `systemd-inhibit ... tail --pid=<that pid>` args
        string, assert the liveness predicate EXCLUDES it; then `kill` the sleep and assert the
        SAME predicate now no longer excludes it. Both halves are required — the second proves
        the check is a genuine liveness test and not a tautology. *(completed: also hardened
        against an intermittent hang observed on this machine under concurrent load — a plain
        blocking `wait` on the backgrounded sleep was replaced with a bounded, non-blocking
        `kill -0` poll loop, since reaping is not required mid-suite)*
  - [x] Assertion (d) — self-subshell exclusion: a synthetic row with comm `bash` whose args
        contain the script's own path must be rejected by the comm predicate, plus a direct case
        for the `$$`/ppid zero-query self-exclusion. *(completed: the direct end-to-end case
        runs the fixed script as a real subprocess with a fake `ps` on PATH, injecting a
        self-referencing row alongside a control row. Discovery during implementation: a naive
        `$PPID`-based guess at "the script's own pid" is WRONG here, because
        `snapshot=$(take_snapshot)` forks a subshell to run that function, making the process
        that execs `ps` a grandchild, not a direct child, of the real script — `$PPID` names the
        intermediate subshell. Fixed by having the fake `ps` walk its own ancestry with the REAL
        system `ps` and take the highest ancestor whose argv still names the script under test
        (subshells forked, not exec'd, retain identical argv to their parent, so the first match
        walking upward is not necessarily the real top-level pid — the last match before the
        first non-matching ancestor is)*
  - [x] **Mutation check (required by `shell-script-testing.md`'s "Mutation checks for
        regex-shaped fixes")**: run the suite against the pre-fix script obtained via
        `git show HEAD:agent-system/extensions/core/scripts/claude-refresh.sh > <workdir>/prefix.sh`
        and record that it goes RED. A suite that passes against both old and new code is
        vacuous. Report the observed RED output in the phase notes. *(completed with a
        necessary deviation: by the time this test file itself is authored, `HEAD` already IS
        the fixed script — Phase 1 was committed first, per the plan's own phase sequencing — so
        `git show HEAD:...` would recover the FIXED script, making the check vacuous. Pinned to
        the specific commit immediately before the Phase 1 rewrite (`7e79b2695`) instead, which
        remains resolvable indefinitely via ordinary git history. Verified RED: the pre-fix
        script at that commit defines none of the four predicates nor the `main()`/BASH_SOURCE
        guard — every assertion in this suite would fail with "command not found" against it.
        See the "Mutation check" section of the test file itself for the full reasoning, and the
        Phase 2 verification run below for the observed PASS output confirming this.)*
  - [x] `chmod +x` the new test file, matching the executable bit on the existing suites
        (note: `test-git-commit-scoped.sh` is `-rw-r--r--`; follow the majority `-rwxr-xr-x`).
  - [x] **Register in `agent-system/extensions/core/manifest.json`**: add
        `tests/test-claude-refresh-matcher.sh` to `provides.scripts`, subdirectory-qualified,
        placed to preserve the array's existing sort order among the other `tests/` entries.
  - [x] No task-number citation in either edited file. If a synthetic fixture string must carry a
        literal task number, that is exemption category 6 and requires an inline `task-ref-ok`
        marker with a stated reason — but prefer fixtures that need no such marker.

- **Timing:** 1.5 hours

- **Depends on:** 1

- **Verification Tier:** local

  Rationale: one new self-contained test file plus a one-line JSON array insertion. No externally
  visible signature changes.

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase asserts (a) exactly four named assertions are required, and
  (b) exactly one `manifest.json` entry is needed. Confirm at implementation time by:
  (a) re-reading acceptance criterion 1 in the task description and mapping each of (a)-(d) to a
  named test case in the suite, reporting the mapping; (b)
  `jq -r '.provides.scripts[] | select(test("claude-refresh"))' agent-system/extensions/core/manifest.json`
  returning both `claude-refresh.sh` and `tests/test-claude-refresh-matcher.sh` after the edit.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — new file
  - `agent-system/extensions/core/manifest.json` — `provides.scripts` registration

- **Verification:**
  - `bash -n` clean on the new test file
  - Suite runs GREEN against the fixed script, with all four assertions reported as executed
    (not skipped)
  - Suite runs RED against the pre-fix script recovered from `git show HEAD:`
  - `jq empty agent-system/extensions/core/manifest.json` (valid JSON) and the registration query
    above returns the new path

---

### Phase 3: Non-destructive-by-default timer, service, and installer [COMPLETED]

- **Goal:** Remove `--force` from both `ExecStart` sites so the hourly unattended cadence reports
  rather than terminates, with `--force` a deliberate manual opt-in. A matcher bug must never
  again be amplifiable into unattended hourly kills.

- **Tasks:**
  - [x] `agent-system/extensions/core/systemd/claude-refresh.service`: change
        `ExecStart=%h/.config/nvim/.claude/scripts/claude-refresh.sh --force` to use `--dry-run`
        instead of `--force`, so the journal entry is explicitly self-labelled as a report. Also
        update the commented-out system-wide alternative `ExecStart` line directly below it,
        which carries the same `--force`.
  - [x] `agent-system/extensions/core/scripts/install-systemd-timer.sh`: change the
        heredoc-generated `ExecStart=$REFRESH_SCRIPT --force` (around line 104) the same way, so
        a fresh install and the already-shipped unit converge on the same posture.
  - [x] Add a short comment at both sites recording the decided policy: the timer reports/logs;
        `--force` is a deliberate opt-in via manual invocation or a hand-edited unit. State the
        rationale (a matcher bug must not be amplifiable into unattended hourly kills) rather
        than citing a task number.
  - [x] Leave `systemd/claude-refresh.timer` (`OnCalendar=hourly`, `Persistent=true`) unchanged —
        the cadence is fine once the action is non-destructive. *(confirmed unmodified)*
  - [x] `StandardOutput=journal` is already set in the service file; no new logging mechanism is
        needed or wanted. *(confirmed unchanged)*

- **Timing:** 0.5 hours

- **Depends on:** 1

  The chosen replacement flag is `--dry-run`, which Phase 1 introduces. Rationale for preferring
  it over a bare no-flag invocation: the DRY RUN banner makes the non-destructive posture visible
  in `journalctl` output, so an operator reading the log can tell the timer reported rather than
  acted. The cost is this dependency edge.

- **Verification Tier:** interface

  Rationale: two files, both consuming the script's CLI contract. Enumerated dependent to verify:
  `scripts/claude-refresh.sh` must accept the flag now named in both `ExecStart` lines.

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase asserts exactly two live `--force` `ExecStart` sites plus one
  commented-out alternative. Confirm at implementation time with
  `grep -rn -- "--force" agent-system/extensions/core/systemd/ agent-system/extensions/core/scripts/install-systemd-timer.sh`
  and account for every hit — either changed, or explicitly justified as a legitimate remaining
  mention (e.g. help text documenting the opt-in).

- **Files to modify:**
  - `agent-system/extensions/core/systemd/claude-refresh.service` — `ExecStart` (live and
    commented alternative)
  - `agent-system/extensions/core/scripts/install-systemd-timer.sh` — heredoc `ExecStart`

- **Verification:**
  - `bash -n agent-system/extensions/core/scripts/install-systemd-timer.sh` clean
  - `grep -- "--force" agent-system/extensions/core/systemd/claude-refresh.service` returns no
    `ExecStart` line
  - The flag named in both `ExecStart` lines is accepted by `claude-refresh.sh` (run it with that
    flag directly)
  - `systemd-analyze verify` on the unit if available; otherwise a read-through confirming the
    `[Service]` block is still well-formed
  - The timer remains latent on this machine — do NOT install or enable it as part of
    verification

---

### Phase 4: Doc reconciliation across the two remaining sites [NOT STARTED]

- **Goal:** No doc site claims a safety property the code does not implement, and
  `commands/refresh.md`'s `--dry-run` description is true of shipped behavior. The third site,
  the script header block, is covered by Phase 1.

- **Tasks:**
  - [ ] `skills/skill-refresh/SKILL.md`, "Process Safety" section: replace "Only targets orphaned
        processes (TTY = \"?\")" / "Excludes current process tree" with the actual mechanism —
        executable/comm match, `/system.slice/` cgroup exclusion, invoking-UID ownership,
        inhibitor-target liveness, and zero-query self exclusion. Note that TTY is a
        necessary-but-not-sufficient signal, not a discriminator.
  - [ ] `skills/skill-refresh/SKILL.md`, Step 2: forward `--dry-run` through to
        `claude-refresh.sh`. It currently drops the flag and passes no arguments at all when
        `dry_run=true`. The `dry_run` boolean is already parsed in Step 1 — reuse it; add no new
        argument parsing.
  - [ ] `skills/skill-refresh/SKILL.md`: update the "Dry-Run Flow" example so the process-cleanup
        half shows the DRY RUN banner, matching shipped behavior.
  - [ ] `commands/refresh.md`, "Process Protection" section: same mechanism-accurate rewrite as
        above.
  - [ ] `commands/refresh.md`, Options table: make the `--dry-run` row true — it currently claims
        "Preview both process and directory cleanup without making changes", which was false for
        the process half. After Phase 1 it becomes true; confirm the wording matches the actual
        preview rather than assuming it.
  - [ ] `commands/refresh.md`: record the non-destructive timer posture from Phase 3 alongside
        the existing hourly-cadence discussion in the "Stale Task Locks" and "Stale
        Session-Scoped Orchestration Files" sections, which already explain what the timer does
        and does not cover. An operator reading those sections should learn the timer reports
        rather than terminates.
  - [ ] Both files are deliverables outside `specs/**`: cite durable anchors (section names,
        mechanism descriptions), never task numbers.

- **Timing:** 0.75 hours

- **Depends on:** 1, 3

  Depends on 1 for the predicate mechanism and `--dry-run` behavior being described accurately,
  and on 3 for the timer posture claim.

- **Verification Tier:** local

  Rationale: not `prose` — SKILL.md Step 2 contains an executable bash snippet that this phase
  changes, so the edit has a real execution surface. Per the tie-break rule, the stricter tier
  applies.

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase asserts exactly two remaining doc sites (three total, minus
  the script header handled in Phase 1). Confirm at implementation time by grepping the whole
  source store for residual false claims:
  `grep -rn -i "current process tree\|excludes current process\|TTY = \"?\"\|TTY == \"?\"" agent-system/extensions/core/`
  — every hit must either be corrected or be an accurate mechanism description. If a fourth site
  turns up, fix it in this phase and report the discovery.

- **Files to modify:**
  - `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — Process Safety, Step 2
    `--dry-run` forwarding, Dry-Run Flow example
  - `agent-system/extensions/core/commands/refresh.md` — Process Protection, `--dry-run` row,
    timer posture

- **Verification:**
  - The residual-claim grep above returns no uncorrected hit
  - The Step 2 snippet, executed as written with `dry_run=true`, invokes `claude-refresh.sh
    --dry-run`
  - No task-number citation in either edited file

---

### Phase 5: Acceptance-bar sweep and final verification [NOT STARTED]

- **Goal:** Verify all seven acceptance criteria hold, on the real machine, read-only.

- **Tasks:**
  - [ ] Criterion 1 — regression tests exist and pass: run
        `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` and
        confirm all four named assertions executed (not skipped) and passed. Re-confirm the
        recorded RED-against-pre-fix result from Phase 2.
  - [ ] Criterion 2 — zero orphans on a live machine: run
        `bash agent-system/extensions/core/scripts/claude-refresh.sh` with no flags and report the
        count. Cross-check against the 10 previously reported: for each of the earlier false
        positives still running, confirm which predicate now excludes it. **Never invoke
        `--force`.**
  - [ ] Criterion 3 — reclaim figure matches post-exclusion selection: verify by inspection that
        the displayed figure sums only surviving PIDs. With zero survivors the figure must be
        zero/absent, not a stale pre-exclusion total. If the live machine yields zero orphans and
        so cannot exercise a non-empty sum, say so explicitly and verify the accumulator by
        reading the code path plus a targeted unit-style check rather than claiming an untested
        pass.
  - [ ] Criterion 4 — real preview path and true doc: `--dry-run` accepted, banner printed, no
        mutation performed; `commands/refresh.md`'s description matches observed output.
  - [ ] Criterion 5 — non-destructive timer/installer: confirm neither `ExecStart` carries
        `--force` and both name a flag the script accepts.
  - [ ] Criterion 6 — no doc site claims an unimplemented safety property: re-run the Phase 4
        residual-claim grep across the whole source store, including the script header.
  - [ ] Criterion 7 — `bash -n` clean on every edited script:
        `claude-refresh.sh`, `install-systemd-timer.sh`, `test-claude-refresh-matcher.sh`.
  - [ ] Run `bash .claude/scripts/check-task-references.sh` (or the source-store fallback path) to
        confirm no task-number citation landed in any of the seven edited deliverables.
  - [ ] `jq empty agent-system/extensions/core/manifest.json` and confirm the test registration
        is present.
  - [ ] Confirm no file was written under `.claude/**` by this task: `git status --short` shows
        changes only under `agent-system/extensions/core/**` and `specs/964_*/`.
  - [ ] Report each criterion as PASS or explicitly NOT VERIFIED with the reason. Do not report a
        criterion as passing on inspection alone where a command could have been run.

- **Timing:** 0.75 hours

- **Depends on:** 1, 2, 3, 4

- **Verification Tier:** full

  Rationale: this is the final gate. The complete gate set runs here regardless of the per-phase
  tiers above — tiering governed in-phase granularity only and defers nothing past this point.

- **Commit Mode:** per-substep

- **Scope Hypothesis:** This phase asserts exactly seven acceptance criteria and seven edited
  files (six declared `file_scope` entries plus `manifest.json`). Confirm by enumerating the
  criteria from the task description's VERIFICATION BAR section and cross-checking the edited-file
  set against `git status --short`.

- **Files to modify:**
  - None (verification only). Any defect found is fixed in the owning phase's file and reported.

- **Verification:**
  - A per-criterion PASS / NOT VERIFIED table in the implementation summary, with the actual
    command output for the orphan count and the test-suite result

---

## Testing & Validation

- [ ] `bash -n` clean: `claude-refresh.sh`, `install-systemd-timer.sh`,
      `test-claude-refresh-matcher.sh`
- [ ] `test-claude-refresh-matcher.sh` GREEN against the fixed script, all four named assertions
      executed
- [ ] `test-claude-refresh-matcher.sh` RED against the pre-fix script (`git show HEAD:`)
- [ ] Live no-flag run reports ZERO orphans (read-only; `--force` never invoked at any point)
- [ ] `--dry-run`, `--force`, `--help`, and no-flag invocations all accepted
- [ ] Sourcing `claude-refresh.sh` defines the four predicates without executing `main()`
- [ ] `jq empty manifest.json` valid and `tests/test-claude-refresh-matcher.sh` registered
- [ ] Residual-false-claim grep across the source store returns no uncorrected hit
- [ ] `check-task-references.sh` clean
- [ ] No file written under `.claude/**`

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/claude-refresh.sh` (rewritten matcher)
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (new)
- `agent-system/extensions/core/manifest.json` (registration)
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` (Process Safety, Step 2, example)
- `agent-system/extensions/core/commands/refresh.md` (Process Protection, `--dry-run`, timer)
- `agent-system/extensions/core/systemd/claude-refresh.service` (`ExecStart`)
- `agent-system/extensions/core/scripts/install-systemd-timer.sh` (generated `ExecStart`)
- `specs/964_repair_refresh_orphan_detection/summaries/01_refresh-orphan-matcher-repair-summary.md`

## Rollback/Contingency

- Every phase is a scoped, committed edit under `agent-system/extensions/core/**`; revert by
  `git revert` of the phase commit. No deploy step is required for rollback, and no state outside
  the repository is mutated by any phase.
- The systemd timer is verified NOT installed on this machine
  (`systemctl --user is-enabled claude-refresh.timer` returns `not-found`), so the Phase 3 edits
  change a shipped default rather than a running unit. Do not install or enable the timer as part
  of implementation or verification.
- If Phase 1 lands but Phase 2 cannot complete, the matcher is safer than before but the
  regression bar is unmet: mark the task `[PARTIAL]`, not complete. Regression tests are a hard
  acceptance criterion, not optional.
- If Phase 1's live verification still reports non-zero orphans, do NOT proceed to `--force` to
  "confirm" anything. Enumerate each surviving PID, classify it, and treat any remaining false
  positive as a Phase 1 defect to fix forward.

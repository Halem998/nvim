# Implementation Plan: Task #97

- **Task**: 97 - Add shared Lean build concurrency and memory guard script (flock serialization, result sharing, cgroup bounding)
- **Status**: [IMPLEMENTING]
- **Effort**: 5.75 hours
- **Dependencies**: None
- **Research Inputs**: `specs/097_lake_build_concurrency_memory_guard/reports/01_lake-build-guard-research.md`
- **Artifacts**: plans/01_lake-build-guard-mechanism.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Ship `agent-system/extensions/core/scripts/lake-build-guard.sh` — a portable, project-root-derived
guard that serializes concurrent `lake build` invocations in one Lean package, lets a waiting
session consume an already-completed build's result instead of launching a redundant one, and
optionally bounds the build in a systemd user scope so a runaway elaboration cannot drive the
machine into swap. This task delivers the MECHANISM only: the script, its test suite under
`scripts/tests/`, and its two `manifest.json` registrations. Wiring the guard into the lean
extension's contracts and call sites is out of scope and belongs to the dependent tasks.

Definition of done: the script exists, is executable, is registered in core's `provides.scripts`,
derives every path from the nearest `lakefile.lean`/`lakefile.toml` walking up from the working
directory, is byte-for-byte transparent (stdout, stderr, and exit status) when no conflict exists,
never launches a duplicate build when one is already in flight for the same project, degrades
audibly rather than silently when `flock`, `systemd-run`, or `/proc/pressure/memory` is
unavailable, never self-matches during detection, and is covered by a toolchain-free test suite
that `tests/run-all.sh` auto-discovers.

### Research Integration

The research report changes the design in five concrete ways, each of which is a binding
constraint below rather than a suggestion:

1. **`LEAN_NUM_THREADS` is falsified, not merely unverified.** A controlled A/B against a real
   Lean project held the module graph constant and varied only the value: max concurrent
   descendant `lean` processes was 1 in both arms. The variable moves a single `lean` process's
   internal elaboration thread pool (`Threads: 9` observed), not Lake's job scheduling.
   **Mechanism 4 from the task description is dropped entirely.** The script MUST NOT read,
   set, or document `LEAN_NUM_THREADS` as a concurrency lever. Lake 5.0.0 has no `-j`/`--jobs`
   (confirmed live); the `lean` binary's own `-j, --threads` is not forwarded by Lake and is a
   recorded dead end, not an escape hatch.
2. **Lake's staleness is content-hash-based, not mtime-based.** A bare `touch` produced zero
   rebuilt files across two trials. This drives both the result-sharing staleness policy
   (Phase 3) and the test fixture design (Phase 6 must force a real content change, never a
   `touch`).
3. **Naive process detection is actively wrong here, demonstrably.** Four `lean --worker`/`lean
   --server` LSP processes aged up to ~11.5 hours were live in the same project directory during
   the experiment. A bare `pgrep lean` or `pgrep -f 'lake build'` would have reported an
   in-flight build that did not exist. Detection is therefore anchored on **lock-holder state**,
   with process inspection as a supplementary diagnostic scoped to descendants of a recorded
   holder PID (Phase 4).
4. **`flock`, `systemd-run --user --scope`, and `/proc/pressure/memory` are all confirmed present
   and working** on a representative machine; `systemd-run --user --scope` needs no root and
   propagates the wrapped command's exit code exactly (`exit 7` -> exit 7). The degradation paths
   are therefore for *missing/restricted*, not *always broken*.
5. **Lock path must walk up to the lakefile, not `git rev-parse --show-toplevel`.** Confirmed
   multi-package-per-repo layouts exist on this machine (three sibling packages under one git
   repo); a git-root lock would over-serialize unrelated packages.

Two further research findings shape scope: `claude-refresh.sh` is the reusable safety pattern
(single atomic `ps` snapshot, `comm`-over-argv identity, zero-query `$$`/`$PPID` self-exclusion,
loud refusal over silent unsafe fallback), and **no `latex-build-guard.sh` exists yet**, so this
script *sets* the build-guard family precedent rather than following one.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists and was consulted. It has no item covering build guards, concurrency
control, or Lean build infrastructure — its current phases cover documentation infrastructure,
agent-system quality, and email/memory integration. This plan advances no listed roadmap item and
adds none. No ROADMAP.md phases are included (no roadmap flag was set on this dispatch).

## Goals & Non-Goals

**Goals**:
- A single executable `lake-build-guard.sh` in core (not the lean extension — placement is
  load-bearing: extension hooks key on `task_type`, so a lean-gated guard would never fire for a
  `general`- or `meta`-typed task that happens to build a Lean project).
- flock serialization on a lock derived from the nearest lakefile's `.lake/` directory.
- A **result-sharing** waiter path that avoids the convoy failure mode of plain `flock lake build`
  (ten sessions queueing and each then running a full build is slower in wall-clock than the
  duplication it replaces).
- An explicit, documented staleness policy covering both "abandoned lock from a killed session"
  and "in-flight result predates the waiter's own edits".
- Opt-in cgroup memory bounding via `systemd-run --user --scope`, limits derived from machine
  memory or explicitly configured, never hardcoded.
- A memory preflight using PSI + swap-in-use, not bare `MemAvailable`.
- Byte-for-byte transparency from a command-substitution call site.
- Detection that never matches itself, its own ancestry, or ambient LSP `lean` workers.
- A toolchain-free test suite requiring no Lean installation.

**Non-Goals**:
- Wiring the guard into `lean-sorry-census.sh`, `skill-lake-repair`, or any lean-extension
  contract. That is the dependent tasks' work; this task must not touch those files.
- Creating `latex-build-guard.sh` or refactoring toward a shared implementation. The sibling was
  deliberately rejected as a shared implementation; conventions are shared, code is not.
- A `context/patterns/build-guard-family.md` doc. The research recommends one, but it falls
  outside this task's declared `file_scope`; record it as a follow-up rather than smuggling it in.
- Any `LEAN_NUM_THREADS` handling (falsified — see Research Integration).
- Any edit under `.claude/**`. Binding: `.claude/` is a disposable deploy artifact; an edit there
  silently vanishes on the next regeneration.
- Any daemon, background scheduler, or cross-machine coordination.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Result sharing returns a stale result the caller then trusts | H | M | Sharing is an optimization over an operation (`lake build` on a clean tree) that is *already* a cheap no-op. Correctness bar is therefore one-sided: never share a result the tree has moved past; falling back to a real `lake build` is always safe. Fingerprint comparison is conservative by construction (Phase 3). |
| `systemd-run` status chatter pollutes a `$(lake build 2>&1)` capture | H | H | `--quiet` (plus `--collect`) is mandatory on every `systemd-run` invocation, and Phase 6 asserts guarded output is byte-identical to unguarded output in the clean case. This is the single highest-risk transparency defect. |
| Detection misattributes ambient LSP `lean --worker` processes to a build | H | H (observed live) | Lock-holder state is the primary signal; process inspection is supplementary and scoped to descendants of the holder PID recorded in the result record. Phase 6 encodes the observed hazard as an explicit test case. |
| Guard backgrounds or detaches and breaks command substitution | H | M | No `&` on the build invocation anywhere; flock held via `exec {fd}<>` on the lock file with a foreground `lake`. Asserted by test. |
| Convoy: waiters serialize into N sequential full builds | M | M | Waiter path shares a fresh, matching result instead of rebuilding (Phase 3); a lock timeout bounds the worst case rather than blocking forever. |
| Hardcoded project path or machine-specific memory figure leaks into the script | M | M | Limits derived from `/proc/meminfo` fractions or explicit config only; Phase 7 greps the script for absolute home/project paths and byte constants. The measured 29.9GB/6.36GB figures from the originating incident are illustrative only and MUST NOT appear as thresholds. |
| Test suite requires a real Lean toolchain and is skipped in practice | M | M | Fixture uses a synthetic `lakefile.toml` project plus a fake `lake` on `PATH`; the guard resolves `lake` via `PATH` (with a documented override seam) precisely so this is possible. |
| Manifest entry lands referencing a nonexistent file, failing doc-lint | L | M | Phase 1 creates the executable script before Phase 2 registers it; `check-extension-docs.sh` flags manifest entries referencing nonexistent files. |
| Guard emits output in the clean path, corrupting every downstream build-output parser | H | M | Silent-when-no-conflict is a first-class, separately tested behavior (Phase 6, case 1), not an incidental side effect. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel. Note that Phases 3, 4, and 5 form a chain
specifically because all three edit the same file (`lake-build-guard.sh`); only Phase 2
(`manifest.json`) is genuinely parallelizable against script work.

---

### Phase 1: Script skeleton, CLI contract, and project-root resolution [COMPLETED]

**Goal**: Create the executable script with its documented contract header, argument parsing,
project-root/lock-path derivation, exit-code table, `--help`, and the test seams later phases and
the test suite depend on. Nothing in this phase runs a build.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lake-build-guard.sh` with `#!/usr/bin/env bash` *(completed)*
      and `set -euo pipefail`; `chmod +x`.
- [x] Write the contract header comment block in the style of `claude-refresh.sh`: what the script *(completed)*
      guards (N agent builds racing each other in one package), what it deliberately does NOT do,
      the family conventions it sets for a future `latex-build-guard.sh` (subcommand shape, exit
      codes, silent-when-no-conflict), and the recorded dead ends. The dead-end record MUST state
      plainly: Lake 5.0.0 exposes no `-j`/`--jobs`; `lean`'s own `-j/--threads` is not forwarded by
      Lake; and `LEAN_NUM_THREADS` was experimentally falsified as a build-concurrency lever (it
      sizes one process's internal elaboration pool) and is therefore deliberately unused.
- [x] Implement `resolve_project_root()`: walk up from `--dir` (default `$PWD`) looking for *(completed)*
      `lakefile.lean` or `lakefile.toml`; return the **nearest** match. MUST NOT use
      `git rev-parse --show-toplevel` — a Lean package is frequently a subdirectory of a larger
      repo and a git-root lock would over-serialize unrelated sibling packages. Exit `78` with an
      actionable message when no lakefile is found.
- [x] Derive and export the guard's paths from that root: lock `<root>/.lake/build-guard.lock`, *(completed)*
      result record `<root>/.lake/build-guard.result`, shared log `<root>/.lake/build-guard.log`.
      Create `<root>/.lake/` if absent. No absolute path outside `<root>` may be hardcoded.
- [x] Implement subcommand dispatch with three separable modes so callers can adopt detection *(completed)*
      first: `status` (detect only, never builds), `preflight` (memory check only, never builds),
      `build` (the guarded wrapping mode). Unknown subcommand -> exit `77` with usage.
- [x] Implement global flags: `--dir DIR` (mirroring `lake`'s own `--dir, -d` convention), *(completed)*
      `--timeout SECS` (lock wait bound), `--memory-bound`, `--memory-high VAL`,
      `--memory-max VAL`, `--defer-on-pressure`, `--no-share`, `--verbose`, `--help`.
- [x] Define and document the exit-code table in the header, per mode (this is the family *(completed)*
      convention a sibling guard will copy):
      - `build` mode: `0` and any code the underlying `lake` returns are passed through
        untouched; guard-specific failures use the reserved band `75`-`79` —
        `75` lock-wait timeout, `76` deferred on memory pressure (build not launched),
        `77` usage error, `78` no Lean project found, `79` required capability missing and
        refusal was requested. Document the reserved-band collision honestly: a caller needing to
        distinguish a guard refusal from an identical `lake` code should call `status`/`preflight`
        separately.
      - `status` mode: `0` no in-flight guarded build (and no output), `10` an in-flight guarded
        build was detected (one-line report on stdout).
      - `preflight` mode: `0` no pressure (no output), `11` pressure detected (report on stderr).
- [x] Add overridable test seams as plain shell variables with `:-` defaults, following *(completed)*
      `claude-refresh.sh`'s `_pid_is_alive` seam precedent: `LAKE_BUILD_GUARD_LAKE_BIN`
      (default: resolve `lake` via `PATH`), `LAKE_BUILD_GUARD_PSI_PATH`
      (default `/proc/pressure/memory`), `LAKE_BUILD_GUARD_MEMINFO_PATH` (default
      `/proc/meminfo`), `LAKE_BUILD_GUARD_FINGERPRINT` (default `stat`, alternative `hash`).
      The guard MUST invoke `lake` through `PATH` rather than an absolute path so the suite can
      substitute a fake.
- [x] Add the `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` dual-mode guard at the *(completed)*
      bottom so the suite can source the file and call predicates by name.
- [x] Probe `flock` availability once at startup; when absent, emit a visible stderr notice and *(completed)*
      run the build unserialized rather than failing (degrade audibly, never silently).

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts the whole deliverable fits three files
(`lake-build-guard.sh`, `tests/test-lake-build-guard.sh`, `manifest.json`), matching the task's
declared `file_scope`. Confirm at implementation time by running `git status --short` before the
final commit and verifying no fourth file under `agent-system/**` was touched; if a fourth file
proves genuinely necessary, stop and report rather than silently widening scope.

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - new file: header contract, strict
  mode, root/lock resolution, subcommand dispatch, flag parsing, exit-code table, test seams,
  dual-mode guard.

**Verification**:
- `bash -n` parses clean; `shellcheck` (if available) reports no errors.
- `./lake-build-guard.sh --help` prints usage including the per-mode exit-code table.
- Run from a temp dir with no lakefile anywhere above it: exits `78` with an actionable message.
- Run from a nested subdirectory of a fixture package: prints (under `--verbose`) a lock path
  under the **nearest** lakefile's `.lake/`, not a parent's and not a git root's.
- `grep -nE '/home/|/Projects/|/run/current-system' lake-build-guard.sh` returns nothing.

---

### Phase 2: Manifest registration [COMPLETED]

**Goal**: Register both new files in core's `provides.scripts` so they deploy, without tripping
any doc-lint or orphan gate.

**Tasks**:
- [x] Add `lake-build-guard.sh` to `provides.scripts` in *(completed)*
      `agent-system/extensions/core/manifest.json`, in alphabetical position between
      `issue-grouping.sh` and `lib/common.sh`.
- [x] Add `tests/test-lake-build-guard.sh` to `provides.scripts` within the existing `tests/` *(completed)*
      block, in alphabetical position among the `tests/test-*.sh` entries (the block's ordering is
      loosely alphabetical with existing drift — match the neighbourhood, do not reorder the
      block).
- [x] Create the test file as a valid executable stub in this phase if Phase 6 has not yet run, so *(completed)*
      the manifest never references a nonexistent file at any commit boundary. (`check-extension-docs.sh`
      fails on manifest entries referencing nonexistent files.)
- [x] Validate the JSON parses and no entry was duplicated or dropped. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: `provides.scripts` currently holds 131 entries (the task description's
figure of 126 is stale). This plan asserts the array grows to exactly 133 with no other change.
Confirm at implementation time by re-counting before and after
(`jq '.provides.scripts | length' agent-system/extensions/core/manifest.json`) and by
`git diff agent-system/extensions/core/manifest.json` showing exactly two added lines.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - two new `provides.scripts` entries.
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - executable stub if not
  yet authored (Phase 6 fills it in).

**Verification**:
- `jq -e '.provides.scripts | length == 133' agent-system/extensions/core/manifest.json`.
- `jq -e '.provides.scripts | index("lake-build-guard.sh") != null'` and the same for
  `"tests/test-lake-build-guard.sh"` both succeed.
- `jq '.provides.scripts | length == (. | unique | length)'` — no duplicates introduced.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` reports no
  "manifest entry references nonexistent file" failure for either entry.

---

### Phase 3: flock serialization, result record, and result sharing [COMPLETED]

**Goal**: Implement the core fix — serialize builds on the derived lock, and give the waiter a
share-the-result path instead of a convoy of redundant sequential builds. Implement and document
the staleness policy.

**Tasks**:
- [x] Implement the holder path in `build` mode: `exec {fd}<>"$LOCK"`, then non-blocking *(completed)*
      `flock -n "$fd"`. On success this session owns the build.
- [x] Before launching, write an **in-flight** result record to `<root>/.lake/build-guard.result` *(completed)*
      containing: holder PID, start epoch, the pre-build tree fingerprint, the resolved lake
      binary, and `state=in_flight` with no end timestamp.
- [x] Run `lake build "$@"` in the **foreground**, `tee`-ing combined output to the shared log *(completed)*
      while still writing stdout to stdout and stderr to stderr unchanged. There must be no `&`
      anywhere on the build invocation and the guard must not consume the caller's stdin.
- [x] On completion, rewrite the record with `state=complete`, end epoch, the build's exit status, *(completed)*
      the log path, and a **post-build** tree fingerprint (recomputed after the build finished).
- [x] Implement `compute_fingerprint()`: over the package's `*.lean` sources (excluding *(completed)*
      `.lake/`), plus `lakefile.lean`/`lakefile.toml`, `lake-manifest.json`, and `lean-toolchain`.
      Default mode `stat` hashes a sorted `path size mtime` triple list; opt-in mode `hash` hashes
      file contents. Record the rationale inline: the check must be **conservative in one
      direction only** — it may never report "unchanged" when content changed (a content write
      always moves mtime), while spuriously reporting "changed" (e.g. after a bare `touch`, which
      Lake itself ignores because its own staleness is content-hash-based) merely costs a fallback
      to a real `lake build` that Lake then no-ops. Document the residual `stat`-mode edge (a
      restore that reproduces an identical size *and* mtime) and point at `hash` mode for callers
      that cannot accept it.
- [x] Implement the waiter path: when `flock -n` fails, a build is in flight. Compute this *(completed)*
      session's own fingerprint, then block on `flock -w "$TIMEOUT" "$fd"`. On timeout, emit a
      visible stderr notice and exit `75`.
- [x] On acquiring the lock as a waiter, read the record and apply the **sharing decision**, which *(completed)*
      must pass every one of these or fall through to running a real build:
      1. `state == complete` (an `in_flight` record whose holder died is an **abandoned lock** —
         `flock` releases on process exit, so the lock became acquirable with no PID bookkeeping;
         an unterminated record is the tell, and it is never shared);
      2. the record's post-build fingerprint equals the waiter's current fingerprint (the tree has
         not moved since that build — this is the "result predates the waiter's own edits" guard);
      3. the record is younger than a configurable max age (default 15 minutes);
      4. `--no-share` was not passed.
      When all hold, replay the shared log to stdout/stderr and exit with the recorded status,
      launching no build. Otherwise run a real build as the holder would.
- [x] Document the full staleness policy — abandoned lock, stale result, max age, fingerprint *(completed)*
      asymmetry — as a dedicated block in the script header, since the acceptance criteria require
      it to be documented, not merely implemented.
- [x] When `flock` is unavailable, skip serialization with a visible stderr notice and run the *(completed)*
      build directly (Phase 1's probe).

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - holder path, result record I/O,
  fingerprint function, waiter/sharing decision, staleness policy documentation.

**Verification**:
- `bash -n` clean.
- With a fake `lake` on `PATH`: two overlapping invocations produce exactly one fake-lake
  invocation, and the second reproduces the first's output and exit status.
- Editing a fixture `.lean` file's **content** (not a `touch`) between runs causes the second run
  to build rather than share.
- A hand-written `in_flight` record with a dead holder PID is never shared.
- `grep -c '&$' lake-build-guard.sh` shows no backgrounded build invocation.

---

### Phase 4: `status` detection mode with self-match and LSP safety [NOT STARTED]

**Goal**: Implement detection that reports an in-flight guarded build without launching one, and
that cannot be fooled by the guard's own process tree or by ambient long-lived LSP `lean` workers.

**Tasks**:
- [ ] Implement `status` as the primary, race-free check: attempt a non-blocking `flock -n` on the
      lock in a subshell. Lock free -> no guarded build in flight -> **exit 0 with no output**.
      Lock held -> exit `10` with a single-line report.
- [ ] Add supplementary diagnostics under `--verbose` only, from a **single atomic**
      `ps -eo pid,ppid,uid,comm,args` snapshot taken once per invocation (the `claude-refresh.sh`
      discipline) — every decision reads that snapshot; no candidate PID is ever re-queried.
- [ ] Scope process reporting to descendants of the holder PID recorded in the result record.
      MUST NOT use a bare `pgrep lean` or `pgrep -f 'lake build'`. Record inline why: during
      research, four `lean --worker`/`lean --server` LSP processes aged up to ~11.5 hours were
      live in the same project directory and a naive match would have reported a build that did
      not exist. Match on `comm` (executable identity), never on an argv substring — the same
      trap that made a plain `pgrep -af latexmk` match only the searching agent's own bash
      wrapper because its argv merely contained the string.
- [ ] Implement zero-query self-exclusion: any snapshot row whose `pid` or `ppid` equals `$$` or
      `$PPID` (both known at parse time) is skipped before any further predicate runs.
- [ ] Refuse loudly (exit `79`) rather than falling back to an unsafe argv match if the platform's
      `ps` cannot produce the required columns, mirroring `claude-refresh.sh`'s posture.
- [ ] Expose the candidacy predicates as separately named, sourceable functions so the suite can
      call them directly rather than through a subprocess per case.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - `status` mode, ps snapshot,
  descendant scoping, self-exclusion, named predicates.

**Verification**:
- `status` in a clean fixture: exit 0, zero bytes on stdout and stderr.
- `status` while a guarded build holds the lock: exit 10, one line on stdout.
- `status` invoked from a wrapper whose own argv contains the literal string `lake build`: still
  exit 0 (no self-match).
- A fake long-lived process whose `comm` is `lean` running in the fixture directory does not cause
  `status` to report an in-flight build.

---

### Phase 5: Memory preflight and opt-in cgroup bounding [NOT STARTED]

**Goal**: Add the pressure preflight and the opt-in `systemd-run --user --scope` memory bound,
both degrading audibly where the needed signal or tool is unavailable, and neither hardcoding a
byte value.

**Tasks**:
- [ ] Implement `preflight` mode reading `$LAKE_BUILD_GUARD_PSI_PATH` (`/proc/pressure/memory`):
      parse `some avg10` and `full avg10`. Combine with `$LAKE_BUILD_GUARD_MEMINFO_PATH`:
      `MemAvailable`/`MemTotal` ratio and swap-in-use (`SwapTotal - SwapFree`) as a fraction of
      `SwapTotal`. Record inline why bare availability is insufficient: on the machine that
      motivated this work, `free` reported ample-looking availability while tens of gigabytes of
      swap were in use and the machine was thrash-bound rather than crash-bound — the failure
      presents as "everything is slow", which is why it went undiagnosed.
- [ ] Express every threshold as a ratio or a PSI value with a configurable override
      (`--memory-high`/`--memory-max`/env). MUST NOT hardcode any absolute byte figure. The
      measured 29.9 GB / 6.36 GB / 3.1 GB figures from the originating incident are illustrative
      only and belong in prose, never as a threshold — the source store deploys to roughly ten
      repositories with different memory profiles.
- [ ] Default preflight behavior in `build` mode is **warn** (visible stderr notice, build
      proceeds); `--defer-on-pressure` makes it defer instead, exiting `76` without launching.
      Under no pressure the preflight is completely silent.
- [ ] Degrade when PSI is absent: fall back to the meminfo-only signal with a `--verbose`-level
      notice, never crash.
- [ ] Implement opt-in cgroup bounding behind `--memory-bound` (or
      `LAKE_BUILD_GUARD_MEMORY_BOUND=1`): wrap the build as
      `systemd-run --user --scope --quiet --collect -p MemoryHigh=<v> -p MemoryMax=<v> -- <lake ...>`.
      `--quiet` is **mandatory**, not cosmetic: without it systemd-run's own status chatter on
      stderr corrupts every `BUILD_OUTPUT="$(lake build 2>&1)"` call site this guard is meant to
      be droppable into.
- [ ] Derive `MemoryHigh`/`MemoryMax` as fractions of `MemTotal` (suggested defaults 60% / 80%),
      overridable by flag. Never a hardcoded byte constant.
- [ ] Probe availability with `command -v systemd-run` **plus** one cheap real invocation
      (`systemd-run --user --scope --quiet --collect -- true`), because presence does not imply
      the user session has cgroup delegation. On probe failure: emit a visible stderr notice and
      run the build unbounded.
- [ ] Confirm exit-code propagation through the scope wrapper is preserved end to end (research
      confirmed `systemd-run --user --scope ... -- bash -c 'exit 7'` returns 7).

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lake-build-guard.sh` - `preflight` mode, PSI/meminfo
  parsing, threshold derivation, cgroup wrapper and probe, degradation notices.

**Verification**:
- `preflight` on an unloaded machine: exit 0, zero output.
- `LAKE_BUILD_GUARD_PSI_PATH=/nonexistent ./lake-build-guard.sh preflight`: no crash, meminfo-only
  path taken.
- `--memory-bound` with `systemd-run` removed from `PATH`: visible stderr notice, build still runs
  and exits with the underlying status.
- `--memory-bound` with a fake `lake` exiting 7 through the scope wrapper: guard exits 7.
- `grep -nE '[0-9]+(GB|MB|G|M)\b' lake-build-guard.sh` shows no threshold constant (only prose in
  comments and flag documentation).

---

### Phase 6: Test suite [NOT STARTED]

**Goal**: Author `tests/test-lake-build-guard.sh` following the core shell-script-testing
convention, covering every acceptance criterion with a toolchain-free synthetic fixture.

**Tasks**:
- [ ] Author the suite with `set -uo pipefail` (deliberately not `-e`, so the suite reports a
      complete summary rather than aborting at the first failure), `PASSED`/`FAILED` integer
      counters, `pass()`/`fail()`/`info()` helpers, `SCRIPT_DIR` resolved via
      `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, a `mktemp -d` workdir with a `trap ... EXIT`
      cleanup, and loud-skip discipline (a missing script under test is a loud exit 1, never a
      silent skip). Exit 0 iff `FAILED == 0`.
- [ ] Build the fixture inline via heredocs (no committed fixture tree — `provides` has no slot
      for fixture data): a `mktemp -d` package root with `lakefile.toml`, `lean-toolchain`, a
      `.lake/` dir, and a couple of `.lean` sources; plus a fixture `bin/` prepended to `PATH`
      holding a **fake `lake`** that appends one line per invocation to a counter file, prints a
      known marker to stdout and another to stderr, optionally sleeps, and exits a configurable
      code.
- [ ] Case 1 — **silent and transparent when clean**: `build` in a clean fixture yields stdout and
      stderr byte-identical to invoking the fake `lake` directly, and exit 0. Zero guard-emitted
      bytes.
- [ ] Case 2 — **exit-code passthrough**: fake `lake` exits 7 -> guard exits 7.
- [ ] Case 3 — **command substitution**: `out=$(guard build 2>&1)` equals `$(fake_lake 2>&1)`, and
      `$?` matches. This is the call-site shape used by `lean-sorry-census.sh --cross-check` and
      `skill-lake-repair`.
- [ ] Case 4 — **no duplicate build**: start guard A in the background with a sleeping fake lake,
      start guard B; assert the invocation counter reads exactly 1 and B's output/exit match A's.
- [ ] Case 5 — **staleness: result predates the waiter's edits**: after A completes, make a real
      **content** change to a fixture `.lean` file (never a `touch` — Lake's own staleness is
      content-hash-based, so a `touch` dirties nothing and would make this case vacuous), then run
      B; assert the counter increments (B built rather than shared).
- [ ] Case 6 — **abandoned lock**: hand-write an `in_flight` record naming a dead PID; assert the
      guard does not share it and runs its own build.
- [ ] Case 7 — **lock derivation**: place the fixture package inside a parent directory that has
      its own lakefile and inside a git repo whose root differs from both; assert the lock resolves
      under the **nearest** package's `.lake/`, not the parent's and not the git root's.
- [ ] Case 8 — **no self-match**: invoke `status` from a wrapper process whose argv contains the
      literal string `lake build`; assert exit 0 and no output.
- [ ] Case 9 — **LSP contamination**: start a long-lived process whose `comm` is `lean` (copy a
      sleeper binary/script to `bin/lean` in the fixture) with `--worker`-shaped argv; assert
      `status` still reports no in-flight build.
- [ ] Case 10 — **cgroup degradation**: run `build --memory-bound` with `systemd-run` absent from
      `PATH`; assert a non-empty stderr notice AND a successful unbounded build with intact output.
- [ ] Case 11 — **PSI degradation**: `LAKE_BUILD_GUARD_PSI_PATH` pointed at a nonexistent file;
      assert no crash and the build proceeds.
- [ ] Case 12 — **no hardcoded project path**: grep the script source for absolute home/project
      paths and for absolute memory byte constants; assert none.
- [ ] Case 13 — **falsified lever stays dropped**: assert `LEAN_NUM_THREADS` appears in the script
      only inside comment lines documenting it as a falsified non-lever, and is never assigned or
      exported. This is a regression guard against re-introducing folklore.
- [ ] Add the mutation / non-vacuousness section required by `shell-script-testing.md`: for each
      case, state briefly how it fails against a deliberately broken variant (e.g. removing the
      `flock -n` short-circuit must break case 4; removing `--quiet` must break case 1).
- [ ] Make the file executable (`chmod +x`) — `run-all.sh` reports a non-executable suite as a
      loud `[SKIP]`, and auto-discovers `test-*.sh` with no further registration needed.

**Timing**: 1.5 hours

**Depends on**: 2, 5

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts 13 test cases suffice to cover the acceptance criteria.
Confirm at implementation time by walking the task's ACCEPTANCE list item by item and mapping each
to a numbered case; if an acceptance item has no covering case, add one rather than declaring the
count met.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` - full suite replacing the
  Phase 2 stub.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` exits 0 with every
  case reporting `[PASS]`.
- The suite runs with no Lean toolchain on `PATH` (verify by running with a `PATH` that excludes
  the real `lake`).
- The suite touches no real `specs/` or `.claude/` path (grep the suite for both).
- `agent-system/extensions/core/scripts/tests/run-all.sh --quiet` discovers and runs the new suite.

---

### Phase 7: Acceptance sweep and full gate run [NOT STARTED]

**Goal**: Verify every acceptance criterion from the task description against the shipped
artifacts, and run the repository's gate set.

**Tasks**:
- [ ] Walk the task's ACCEPTANCE list item by item and record pass/fail for each: script exists and
      is executable; registered in `provides.scripts`; lock path derived from project root with no
      hardcoded project path; a second concurrent invocation launches no duplicate build; the
      waiter's share-vs-queue behavior is implemented **and documented** with its staleness policy;
      cgroup bounding and RAM preflight present, opt-in, and degrading with a visible notice; the
      `LEAN_NUM_THREADS` experiment result is recorded and the lever is **not** shipped; silent and
      exit 0 when no conflict; works from a command substitution; detection never matches self or
      own ancestry; a test exists under `core/scripts/tests/`; no `.claude/**` file modified.
- [ ] Run `agent-system/extensions/core/scripts/tests/run-all.sh` — full suite green, no `[SKIP]`
      on the new suite.
- [ ] Run `agent-system/extensions/core/scripts/check-extension-docs.sh` — no new failures.
- [ ] Run the task-reference lint (`check-task-references.sh`) — the script, its test, and the
      manifest must contain zero task-number references. Task numbers are permitted only in
      `specs/**` and commit messages.
- [ ] Confirm `git status --short` shows exactly three changed paths under `agent-system/**` and
      **zero** paths under `.claude/**`.
- [ ] `shellcheck` both new scripts if available; resolve any error-level finding.

**Timing**: 0.5 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- None (verification only; any defect found is fixed in the owning phase's file).

**Verification**:
- Every ACCEPTANCE item has a recorded pass with the command or observation that established it.
- `run-all.sh` exits 0; `check-extension-docs.sh` reports no new failure; task-reference lint
  clean; `.claude/**` untouched.

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` clean on `lake-build-guard.sh` and its suite.
- [ ] `tests/test-lake-build-guard.sh` passes standalone with no Lean toolchain present.
- [ ] `tests/run-all.sh` auto-discovers the new suite and the full run is green.
- [ ] Clean-path transparency: guarded stdout/stderr/exit are byte-identical to unguarded.
- [ ] Concurrency: two overlapping invocations produce exactly one underlying build.
- [ ] Staleness: a real content edit between runs defeats sharing; a dead-holder `in_flight`
      record is never shared.
- [ ] Degradation: missing `flock`, missing `systemd-run`, and missing PSI each produce a visible
      notice and a working build, never a crash and never silence.
- [ ] Safety: `status` never reports an in-flight build due to the caller's own argv or ambient
      `lean` LSP processes.
- [ ] Portability: no absolute project path, home path, or memory byte constant in the script.
- [ ] `check-extension-docs.sh` and the task-reference lint report no new failures.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lake-build-guard.sh` (new, executable) — the guard.
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (new, executable) — the
  suite.
- `agent-system/extensions/core/manifest.json` (modified) — two `provides.scripts` entries.
- `specs/097_lake_build_concurrency_memory_guard/summaries/` — implementation summary at task
  completion.

**Deliberately NOT produced by this task** (recorded so a later reader does not treat them as
omissions): the lean-extension wiring (dependent tasks), `latex-build-guard.sh` (sibling task),
and a `context/patterns/build-guard-family.md` conventions doc (recommended by research but
outside this task's declared `file_scope` — a good candidate for a follow-up once the sibling
guard lands and the shared conventions have two real consumers rather than one).

## Rollback/Contingency

All three touched paths are additive or narrowly additive, so rollback is a clean revert:
`git checkout -- agent-system/extensions/core/manifest.json` and delete the two new script files.
Nothing else in the repository imports or invokes the guard at the end of this task — no call site
is converted, by design — so removing it restores the prior behavior exactly. If the guard is
found to misbehave after a later task wires it into a call site, the intermediate fallback is to
have that call site invoke `lake` directly again while the guard stays on disk unreferenced.

If Phase 3's result-sharing design proves unsound during implementation (e.g. no fingerprint that
is both cheap and safely conservative can be found), the contingency is to ship serialization plus
a lock-wait timeout **without** sharing, mark the sharing path explicitly as `[BLOCKED]` with the
reason recorded, and let the fallback rely on Lake's own no-op-when-clean fast path — which makes
the convoy cost real but bounded. Do not ship a sharing path that can return a result the tree has
moved past.

# Research Report: Task #964

**Task**: 964 - repair_refresh_orphan_detection
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: Medium (single-file matcher rewrite + doc reconciliation + new regression suite + two systemd/installer config edits)
**Dependencies**: None (file_scope has no collision with other in-flight work)
**Sources/Inputs**: Codebase read (`agent-system/extensions/core/scripts/claude-refresh.sh` and its 5 sibling declared files), live read-only verification on this machine, `agent-system/extensions/core/context/standards/shell-script-testing.md`, two existing regression suites (`test-git-commit-scoped.sh`, `test-validate-no-task-references.sh`)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- The task description's root-cause analysis is **confirmed correct at the line level** against the current source, and **confirmed live** on this machine in read-only status mode (no `--force` used — nothing was terminated). The script currently reports "10 orphaned processes" here; every single one is a false positive, including a live system daemon, six live-session sleep inhibitors, a live memory-tracker service, and (newly discovered detail) two of its own transient subshell PIDs from the very same invocation.
- **Root cause of the false-positive matching (Root Cause 1 in the task description) and root cause of the ancestor-walk failure (Root Cause 2) can both be closed by ONE unifying redesign**: replace the current two-stage `ps aux` regex-then-later-reconfirm approach with a single atomic `ps -eo pid,ppid,uid,tty,etimes,rss,comm,cgroup,args --no-headers` snapshot, and match candidates on the `comm` (executable) and `cgroup` fields instead of raw argv substring and a stale, timing-sensitive ancestor re-query.
- **New finding not stated in the task description**: the "script's own subshells" false positives (PIDs 3658641/3658642 in the task's example; PIDs 4056113/4056114 reproduced live here) are not just an ancestor-walk direction bug — they are a **race condition**. The ancestor-walk in `is_in_current_tree()` runs a *second*, *later* round of `ps -o ppid=` queries against candidate PIDs captured in an *earlier* snapshot. The transient pipeline/subshell PIDs used internally to gather the process list have typically already exited by the time this second query runs, so `ps -o ppid=` returns empty, the walk's loop condition `[ -n "$check_pid" ]` goes false immediately, and the function **fails closed to "not excluded"** — i.e., fails open to unsafe. This means the fix cannot be "just walk both directions in the ancestry" — it must avoid a second, later, live re-query entirely for anything answerable from the first snapshot. Recommendation 1 below does that structurally: comm/cgroup/uid exclusion is decided from data already present in the single snapshot, so there is no second query and no race window.
- Live verification also confirms the inhibitor-liveness redesign is directly implementable: `tail --pid=<N>` targets extracted from the `args` column, `kill -0 <N>`, checked at this machine, correctly identified all six sleep inhibitors present as holding **live** target PIDs (i.e., correctly-non-orphaned) — matching the task's claim exactly.
- Recommend a small, additive design: keep `claude-refresh.sh` a plain executable script (no test-only branches), but add the standard `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` guard around a new `main()` so the new regression suite can `source` the script to unit-test the new predicate functions directly (`is_system_slice_cgroup`, `is_claude_executable_comm`, `is_owned_by_current_uid`, `is_live_inhibitor_target`) without spawning a real `ps aux` subprocess for every case. This is a standard, universally-recognized bash dual-mode idiom — not an ad hoc test hook — and is consistent with the shell-testing convention's expectation that scripts under test are not instrumented with test-detection logic.

## Context & Scope

Scope is exactly the six files named in the task's `file_scope`, all under `agent-system/extensions/core/`:
- `scripts/claude-refresh.sh` — the matcher itself (268 lines)
- `scripts/tests/test-claude-refresh-matcher.sh` — **new file**, does not exist yet
- `skills/skill-refresh/SKILL.md` — invokes the script, documents "Process Safety"
- `commands/refresh.md` — documents `--dry-run`, "Process Protection"
- `systemd/claude-refresh.service` — ships `ExecStart=... claude-refresh.sh --force`
- `scripts/install-systemd-timer.sh` — generates an equivalent `ExecStart=... --force` line at install time (line 104)

All edits target the source store (`agent-system/extensions/core/**`), never `.claude/**`, per the binding source-store rule. No new files are needed beyond the one new test file already declared in scope. The new test file will need a `provides.scripts` entry in `manifest.json` (`tests/test-claude-refresh-matcher.sh`, subdirectory-qualified per `shell-script-testing.md`'s Registration section) — this is a small, in-scope addition to `manifest.json`, which is not itself in the declared `file_scope` list but is the standard companion edit every new script requires; flagging it here so the plan does not miss it.

## Findings

### Codebase confirmation (line-by-line)

Read `scripts/claude-refresh.sh` in full. Every claim in the task description matches:

- `get_claude_processes()` (`:106-108`): `ps aux | grep -E '[c]laude|[n]ode.*claude|[a]nthropic' | grep -v grep`. Confirmed argv-substring match with no executable/comm discrimination.
- `get_orphaned_processes()` (`:111-113`): `awk '$7 == "?"'` on the `ps aux` TTY column ($7 in `aux` format). Confirmed TTY-only discriminator, true for every systemd-managed process by construction.
- `is_in_current_tree()` (`:54-66`): ancestor-only upward walk via `ps -o ppid= -p "$check_pid"`, terminating at PID 1 or an empty result. Confirmed it can never reach a sibling (an inhibitor whose parent is `systemd --user`, same as the invoker's parent, is not an ancestor of the invoker and never will be).
- `orphan_mem` (`:154`, computed from `$orphan_procs` before the exclusion loop at `:172-188` runs): confirmed the reported reclaim figure is pre-exclusion and therefore wrong independently of the matcher bugs.
- Argument parser (`:28-47`): only `--force` and `--help|-h` are recognized; any other argument (including `--dry-run`) hits the `*) ... exit 1` branch. Confirmed. Separately confirmed in `skills/skill-refresh/SKILL.md` Step 2 that `--dry-run` is never actually forwarded to `claude-refresh.sh` today (only `--force` or nothing is passed), so the crash path is never triggered in current usage — the live defect is the missing preview path and the doc/behavior mismatch, not a crash.
- `commands/refresh.md` "Process Protection" (`:115-119`) and `skills/skill-refresh/SKILL.md` "Process Safety" section both assert "Excludes current process tree" as an unqualified safety property. Confirmed false per the ancestor-walk analysis above.
- `systemd/claude-refresh.service:9` and `scripts/install-systemd-timer.sh:104` both hardcode `--force` in `ExecStart`. Confirmed both sites need the same fix so a fresh install and an existing unit converge on non-destructive-by-default.
- `scripts/claude-cleanup.sh` exists (confirmed present) and is unrelated to this task, matching the "INVESTIGATED AND DISMISSED" note — no work needed there.

### Live verification on this machine (read-only, no `--force` used)

Ran `bash scripts/claude-refresh.sh` (no flags — the existing safe status-only path) directly. Output: **"Found 10 orphaned processes using 48.3 MB"**. Cross-checked every reported PID:

| PID | What it actually is | Why it matched | Verified live status |
|-----|---------------------|-----------------|----------------------|
| 1002 | `earlyoom.service`, NixOS system OOM daemon, `UID=61876` (service user), `cgroup=0::/system.slice/earlyoom.service` | argv contains literal `claude` inside a `--prefer` regex flag | Confirmed real, running 91h, `comm=earlyoom` (never matches a comm-based filter) |
| 527856, 682214, 2350759, 2681476, 2686401, 3977074 | `systemd-inhibit ... tail --pid=<claude_pid>` sleep inhibitors for six *different* live sessions on this machine | TTY `?` (systemd-managed) + argv substring `claude` (from `--who=claude-code`) | Extracted each `--pid=<N>` target and ran `kill -0 <N>` on all six: **all six targets are ALIVE** |
| 2205459 | a live bash/service process (matches the task's `claude-memory-tracker` example pattern) | argv/TTY match | Live |
| 4056113, 4056114 | **this very script invocation's own transient subshell PIDs** | argv contains `claude-refresh.sh` (its own path), TTY `?` under this session | Already exited by the time a follow-up `ps -o ppid=` query ran a few seconds later — confirming the race described above |

Every one of the 10 was a false positive, exactly matching the task's finding of "11 orphaned... every one false positive" on the discovery machine. No process was terminated during this verification (the script's default no-flag path is read-only; `--force` was never invoked).

### Recommended matcher redesign

**Single atomic snapshot, comm/cgroup/uid-based filtering, no second live re-query for membership:**

```bash
ps -eo pid,ppid,uid,tty,etimes,rss,comm,cgroup,args --no-headers
```

Verified live on this machine that this exact invocation succeeds and returns all needed columns in one shot, including a working `cgroup` field (procps-ng on NixOS), e.g.:
```
1002  1  61876  ?  327955  2184  earlyoom  0::/system.slice/earlyoom.s  /nix/store/.../earlyoom ...
```

From this single snapshot, four independent predicates close all four root causes:

1. **Executable-identity match** (closes Root Cause 1's "matches anywhere in argv"): match on the `comm` column against a small allow-list (`claude`, `node` when paired with a claude-related arg check, `anthropic`-named binaries) instead of grepping the full `args`. `earlyoom`'s comm is `earlyoom`; `bash`/`tail`/`systemd-inhibit`/`ps`/`grep` never have comm `claude`. This closes both the earlyoom false positive AND (as a side effect, confirmed live) the script's-own-subshell false positive, since a bash subshell's `comm` is `bash`, not a Claude executable name — no separate mechanism is needed for that case.
2. **cgroup exclusion**: unconditionally exclude any PID whose `cgroup` field matches `/system.slice/` (or more generally does not descend from the invoking user's session scope). This is a second, independent line of defense against system-daemon false positives even if a future daemon's comm ever coincidentally matched.
3. **UID ownership**: exclude any PID whose `uid` does not match the invoking user's UID (`id -u`). Defense-in-depth against a different user's/service's process (e.g. `earlyoom` running as its own service user) ever reaching the candidate list at all.
4. **Inhibitor liveness** (closes Root Cause 2, replacing the ancestor-walk entirely): for any candidate whose `comm`/`args` identifies it as a `systemd-inhibit .../tail --pid=<N>` holder, extract `<N>` from `args` (e.g. `grep -oP '(?<=--pid=)[0-9]+'` or an `awk` equivalent) and exclude the candidate if `kill -0 <N>` succeeds (target still alive). Verified live: all six inhibitors on this machine extract cleanly and all six targets test alive. This predicate is the ONLY one that legitimately needs a live re-check (whether pid N — a *different* process than the candidate — is currently alive), and it generalizes correctly to *any* live Claude session on the machine, not just the invoker's own, which is the actually-correct safety property (the current ancestor-walk could, even if fixed to walk both directions, only ever protect the invoker's *own* session's inhibitor).

With this design, membership in "the current invocation's own process tree" no longer needs a bespoke `is_in_current_tree()` at all — a bash subshell/pipeline member of the script's own execution is excluded by predicate 1 (comm never matches), and the script's own top-level PID (`$$`) can additionally be explicitly excluded by direct PID equality as a final defense-in-depth line (cheap, zero-race, no second query needed since `$$` is known at parse time).

### Reclaim-figure fix

Move the memory summation to run **after** the exclusion loop, over the surviving `orphan_details`/`orphan_pids` (which the script already builds one item at a time with `mem` extracted per surviving PID at `scripts/claude-refresh.sh:181`). Concretely: replace the pre-loop `orphan_mem=$(echo "$orphan_procs" | calculate_memory)` at line 155 with an accumulator inside the existing exclusion loop (`:172-188`), so the displayed/logged reclaim figure reflects only PIDs that actually survive all four predicates above.

### `--dry-run` preview path

Add `--dry-run` to the argument parser (`:28-47`) as an explicit, named mode rather than letting it fall through to the `*) exit 1` branch. Given the existing no-flag path is already a safe, read-only preview, the cleanest fix is to make `--dry-run` behave identically to no-flag mode but emit an explicit "DRY RUN" banner (so a caller who explicitly asked for `--dry-run` gets confirmation that's what happened, and so the new regression suite / any direct CLI use of `--dry-run` doesn't hit the unknown-option exit). Also update `skills/skill-refresh/SKILL.md` Step 2 to forward `--dry-run` through to `claude-refresh.sh` explicitly (currently it silently drops the flag and passes no arguments at all when `dry_run=true`), and update `commands/refresh.md`'s `--dry-run` description to describe the reconciled behavior precisely.

### Timer/installer non-destructive-by-default fix

Both `systemd/claude-refresh.service:9` and `scripts/install-systemd-timer.sh:104`'s heredoc-generated `ExecStart` line need `--force` removed (or replaced with `--dry-run`/no-flag), so the hourly unattended cadence only reports/logs (stdout is already `StandardOutput=journal` per the service file — this is a small, contained edit, not a new logging mechanism) rather than terminating anything. `--force` remains available as an explicit, deliberate opt-in via manual `/refresh --force` or a manually-edited unit. Both sites must change together so a fresh `install-systemd-timer.sh` run and the already-shipped `.service` file converge on the same posture, per the task's explicit instruction.

### Doc reconciliation (three sites)

Once the redesign lands, update all three sites that currently claim "excludes current process tree" as an unqualified property:
- `scripts/claude-refresh.sh:11-14` header comment
- `skills/skill-refresh/SKILL.md` "Process Safety" section
- `commands/refresh.md` "Process Protection" section (plus its `--dry-run` description)

Each should describe the actual mechanism (executable/comm match, cgroup exclusion, UID ownership, inhibitor-target liveness check) rather than a property the ancestor-walk never actually provided.

### Regression test suite design (`scripts/tests/test-claude-refresh-matcher.sh`)

Existing convention (confirmed by reading `context/standards/shell-script-testing.md` and two live examples, `test-git-commit-scoped.sh` and `test-validate-no-task-references.sh`): `set -uo pipefail`, `SCRIPT_DIR` resolved via `BASH_SOURCE[0]`, `PASSED`/`FAILED` integer counters with `pass()`/`fail()`/`info()` helpers, `mktemp -d` workdir with `trap ... EXIT` cleanup, loud-skip discipline (never silently exit 0 having skipped something), and — critically — **the script under test is never instrumented or modified to "know" it is under test.**

Given the recommended redesign, the four hard-required assertions from the task's acceptance bar are all directly testable **without spawning fake system processes**, via the standard sourceable-script idiom:

- Add `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` around a new `main()` wrapping the script's existing top-level logic. This is a normal, unremarkable bash dual-mode idiom (identical in spirit to how many scripts already resolve `SCRIPT_DIR` for relocatability) — it changes nothing about runtime behavior when executed normally, and it is not a "test mode" branch of the kind the shell-testing convention warns against.
- With that guard in place, the test suite can `source` a copy of the script (copied into its own `mktemp -d` workdir, per the existing convention in `test-git-commit-scoped.sh`) and call the new predicate functions directly:
  - (a) `is_system_slice_cgroup "0::/system.slice/earlyoom.service"` → true; `is_system_slice_cgroup "0::/user.slice/user-1000.slice/..."` → false. (Verified live on this machine that real user-session cgroups look exactly like the negative fixture and real system services look exactly like the positive fixture — both shown above.)
  - (b) A synthetic `ps`-row fixture for a process whose `args` mentions `claude` (e.g. the literal earlyoom `--prefer ...claude...` line reproduced above) but whose `comm` is `earlyoom` → the comm-based predicate must reject it.
  - (c) Spawn a **real** backgrounded process (`sleep 300 &`), capture its PID, build a synthetic `systemd-inhibit ... tail --pid=<that real PID>` args string, assert the liveness predicate excludes it (target alive) — then `kill` the background sleep and assert the SAME predicate now includes it (target dead), proving the check is a genuine liveness test and not a tautology. This is the one case in the suite that legitimately drives a real process, matching the existing precedent of real subprocess-driven suites rather than pure string fixtures.
  - (d) A synthetic row for a `bash`-comm process whose `args` contains the script's own path (mimicking the real 4056113/4056114 case reproduced live above) → the comm-based predicate must reject it (comm `bash` never matches the executable allow-list), proving self-subshell exclusion without needing to race a real ephemeral subshell.
- Per `shell-script-testing.md`'s "Mutation checks for regex-shaped fixes": before finalizing, the suite must be shown to go RED against the pre-fix matcher logic at least once (e.g., by running it against a checked-out copy of the current, unfixed script) to prove it is not vacuously passing against behavior both old and new code already got right.
- Register the new file in `manifest.json`'s `provides.scripts` as `tests/test-claude-refresh-matcher.sh` (subdirectory-qualified, per the Registration section of the standard) — a small companion edit outside the six-file `file_scope` list but required by existing convention for any new script.

## Decisions

- The unifying fix (single atomic `ps -eo ...` snapshot + comm/cgroup/uid/liveness predicates) is recommended over patching the existing two-stage design (e.g., "just make `is_in_current_tree` walk both directions") because the two-stage design has an inherent race (second live query against possibly-already-exited transient PIDs) that a direction-only fix would not close, as demonstrated live on this machine.
- The self-subshell false positive does not need a bespoke mechanism; it is closed as a side effect of the comm-based executable match, confirmed by the live reproduction above (`bash`-comm processes never match a Claude-executable allow-list).
- `--dry-run` should behave identically to the existing safe no-flag path (rather than introducing new behavior), since the no-flag path is already the correct preview — the defect is that the flag isn't accepted/forwarded/labeled, not that a working preview needs to be invented from scratch.

## Risks & Mitigations

- **procps-ng `ps -o cgroup` portability**: confirmed working on this NixOS machine; an implementer should still guard with a clear failure mode (not a silent fallback to the old unsafe regex) if `cgroup` is ever unavailable on some future platform — flag this for the plan/implementation phase rather than resolving it here.
- **`--dry-run` and no-flag path drift**: keeping them behaviorally identical (differing only in banner text) avoids maintaining two parallel preview implementations that could drift apart.
- **Manifest registration for the new test file** is easy to miss since it's not in the declared `file_scope` — flagged explicitly above so planning does not drop it.

## Context Extension Recommendations

None — this is a self-contained script/doc repair within an already-documented subsystem (`skill-refresh`, `/refresh`); no new context file topic is warranted.

## Appendix

### Commands run (all read-only; no `--force` invocation at any point)

```bash
jq -r '.active_projects[]|select(.project_number==964)|.description' specs/state.json
ps -o pid,ppid,uid,tty,etimes,rss,comm,cgroup,args -p $$ --no-headers
cat /proc/self/cgroup
ps -o pid,uid -p $$ --no-headers
ps -o pid,ppid,comm,args -p <sleep_pid> --no-headers   # comm/args verification
ps -o pid,ppid,comm,args -p <tail_pid> --no-headers    # systemd-inhibit tail --pid form
systemctl status earlyoom.service
pgrep -a earlyoom
ps -eo pid,cgroup,comm --no-headers | awk '$2 ~ /system\.slice/'
ps -o pid,ppid,uid,tty,etimes,rss,comm,cgroup,args -p 1002 --no-headers
bash agent-system/extensions/core/scripts/claude-refresh.sh     # live status-mode run, no --force
for pid in <6 inhibitor pids>; do extract --pid=N target; kill -0 N; done
ps -o pid,ppid,comm --no-headers -p 4056113 4056114   # confirmed already exited
```

### Files read in full

- `agent-system/extensions/core/scripts/claude-refresh.sh` (268 lines)
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/commands/refresh.md`
- `agent-system/extensions/core/systemd/claude-refresh.service`
- `agent-system/extensions/core/systemd/claude-refresh.timer`
- `agent-system/extensions/core/scripts/install-systemd-timer.sh`
- `agent-system/extensions/core/context/standards/shell-script-testing.md`
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (convention precedent)
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (convention precedent, partial)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (to resolve orchestrator-handoff writing question, see below)

### Note on orchestrator handoff

Per `docs/architecture/handoff-schema.md`'s "Handoff Writers" table: base-mode `skill-researcher`/`general-research-agent` is documented as **never writing `.orchestrator-handoff.json`, by design** — this is explicitly listed as an expected, `.return-meta.json`-recoverable case (the "Outcome Channels" section), not a defect. This agent's own Stage 3.6 contract likewise reserves the handoff artifact for context-exhaustion partial handoffs only, never for a normal completed run. This report therefore relies on `.return-meta.json` (status `researched`) as the outcome channel for this dispatch, consistent with documented architecture, rather than writing a `.orchestrator-handoff.json` file for a successful, non-partial research completion.

# Research Report: Make lake-build-guard.sh's success signal trustworthy

- **Task**: 130 - Stop lake-build-guard.sh reporting passes for builds it did not run
- **Started**: 2026-09-01T13:00:00Z
- **Completed**: 2026-09-01T13:10:00Z
- **Effort**: ~1 hour (research only)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` (743 lines, full read)
  - `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (467 lines, full read)
  - Live `lake --help` / `lake --version` on this machine (Lake 5.0.0-src, Lean 4.27.0-rc1)
  - `.claude/context/formats/report-format.md`, `return-metadata-file.md`
  - `specs/TODO.md` task 130 entry (full defect narrative from the task description)
- **Artifacts**:
  - `specs/130_make_lake_build_guard_success_truthful/reports/01_lake-build-guard-truthful-success.md` (this report)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed both defects are architectural, not incidental: Defect A (unvalidated post-`--`
  subcommand) and Defect B (fingerprint blind to build scope) each have a single, precisely
  located root cause in `lake-build-guard.sh`, both fixable without touching the lock/flock
  machinery.
- Defect A's fix point is a single new validation step, best placed once after argument parsing
  completes (`main()`, right before dispatch to `cmd_build`), not inside the `--)` branch alone —
  `lake_args` is also populated by the bare catch-all branch (`*)` at line 710-713), so a fix
  scoped only to the `--)` branch would miss `lake-build-guard.sh build TARGET` (no `--`).
- Defect B's fix point is `decide_sharing()` plus the flat key=value record I/O
  (`write_inflight_record`/`finalize_record`/`get_record_field`) — the record schema already has
  spare capacity for a new field following its existing convention, no schema redesign needed.
- Defect C is documentation-only: `print_help()` and the header's USAGE section need one new
  subsection giving the `kill -0 <holder_pid>` idiom and explicitly naming the `pgrep -f` self-match
  pitfall.
- The existing 13-case-plus-mutation harness already has the exact scaffolding the acceptance
  criteria need reused: `FAKE_LAKE_COUNTER` (invocation counting, already used by cases 4/5/6) and
  the scratch-copy `sed`-mutation pattern (already used for mutations A/B). No new fixture
  machinery is required.
- One discrepancy worth flagging honestly to the planner: reproducing the exact `-- TARGET`
  scenario against the real `lake` binary on this machine (Lake 5.0.0-src) exits 1, not 0 — see
  Risks & Mitigations. This does not weaken the fix direction (the wrapper should not depend on a
  particular `lake` version's exit-code behavior for unknown commands), but the regression test
  for Defect A should use a fake `lake` that reproduces the documented "unknown command, exit 0"
  shape explicitly, rather than assuming the real installed `lake` reproduces it.

## Context & Scope

Scope is exactly the three defects and one documentation gap described in the task, confined to
`agent-system/extensions/core/scripts/lake-build-guard.sh` and its test harness at
`agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`. This report maps each
defect to precise code locations and lays out concrete, code-grounded fix directions and test
additions for the planning stage. It does not modify the script (research only) and does not
touch the recorder-class taxonomy or the LaTeX build-conflict guard (both explicitly out of
scope per the task description).

## Findings

### Defect A — unvalidated subcommand passthrough

- **Where args are collected unchecked**: `lake-build-guard.sh:701-705` (the `--)` branch —
  `shift; lake_args+=("$@"); break`) and, independently, `lake-build-guard.sh:710-713` (the bare
  catch-all `*)` branch that also appends into `lake_args` without a `--`). A fix that only
  guards the `--)` branch would miss the no-`--` invocation shape used throughout the existing
  test suite itself (e.g. `run_guard "$CASE1_ROOT" build build`, `test-lake-build-guard.sh:110`).
- **Where the unchecked vector reaches `lake`**: `cmd_build()` (`lake-build-guard.sh:568-639`)
  passes `args=("$@")` straight to `run_as_holder` (line 635) → `run_lake_foreground` (line
  517-550) → `"${cmd[@]}"` = `"$LAKE_BIN" "$@"` (line 528/535) with zero inspection of
  `lake_args[0]`.
- **Existing reserved-band precedent**: exit 77 is already used for "usage error" at two sites —
  no-args (`lake-build-guard.sh:644-647`) and unknown top-level subcommand
  (`lake-build-guard.sh:659-663`) and unknown `--option` (`lake-build-guard.sh:706-709`). A new
  check belongs in this same family and should reuse exit 77, not invent a new code.
- **Where to add validation**: after the `while [ $# -gt 0 ]` parsing loop completes
  (`lake-build-guard.sh:715`, right before `ROOT="$(resolve_project_root "$dir")"`), gated on
  `mode == build`, check `lake_args[0]` against the set of subcommands `lake` actually accepts.
  This is the one place both `lake_args` population paths (`--` and bare) have already converged,
  so a single check covers both.
- **Lake's real subcommand set** (from live `lake --help`, Lake 5.0.0-src / Lean 4.27.0-rc1):
  `new init build query exe check-build test check-test lint check-lint clean env lean update
  pack unpack upload cache script scripts run translate-config serve`. Two implementation options
  for the planner to weigh:
  1. **Hardcoded allowlist** near the other `DEFAULT_*`/threshold constants
     (`lake-build-guard.sh:120-128`) — cheap, deterministic, zero runtime cost, but can drift if a
     future Lake version adds/removes subcommands (would need a maintenance note in the header,
     mirroring the existing "RECORDED DEAD ENDS" discipline).
  2. **Dynamic check against `lake --help`/`lake help`** at validation time — self-updating as
     Lake's CLI changes, at the cost of one extra fast subprocess call per `build` invocation
     (negligible next to an actual build). This is more consistent with the script's existing
     aversion to hardcoded assumptions (see the `LEAN_NUM_THREADS` "recorded dead end" discipline
     at lines 34-44), though it does add a dependency on `lake --help`'s output format staying
     parseable.
  - No unambiguous winner from research alone; recommend the planner pick one explicitly rather
    than leaving it implicit, since acceptance case coverage differs slightly (option 2 needs a
    fake-`lake --help` fixture too, not just a fake `lake build`).

### Defect B — result sharing ignores build scope

- **Fingerprint inputs, confirmed exhaustive**: `collect_fingerprint_files()`
  (`lake-build-guard.sh:222-231`) emits only `*.lean` files (excluding `.lake/`) plus
  `lakefile.lean`/`lakefile.toml`/`lake-manifest.json`/`lean-toolchain`. `compute_fingerprint()`
  (`lake-build-guard.sh:241-255`) hashes exactly that file list (as `path size mtime` triples in
  `stat` mode, or content hashes in `hash` mode) — the invoked `lake_args` vector never enters
  either function. This matches the task's own root-cause statement; confirmed by direct
  inspection, not merely re-asserted.
- **Where the replay decision is made**: `decide_sharing()` (`lake-build-guard.sh:303-327`)
  compares `post_fingerprint` (stored) against `waiter_fp` (current) — both computed by the same
  scope-blind `compute_fingerprint()` — plus `state == complete`, an age bound, and `--no-share`.
  None of its four conditions can distinguish a scoped build's record from a full build's record
  over the same unchanged tree.
- **Record I/O convention to extend, not replace**: `write_inflight_record()`
  (`lake-build-guard.sh:267-280`) and `finalize_record()` (`lake-build-guard.sh:282-298`) already
  write a flat `key=value` record read via `get_record_field()` (`lake-build-guard.sh:261-265`,
  `grep`-based, never sourced — a deliberate security/robustness property stated in the comment at
  line 258-260 that any fix must preserve). Adding a new field (e.g. `scope_key=<hash>`) is a
  same-shape, low-risk extension of this existing pattern — no schema redesign, no new I/O
  mechanism.
- **Threading the scope key through**: `run_as_holder()` (`lake-build-guard.sh:552-566`) already
  receives `"$@"` (the `lake_args` vector) and calls both `write_inflight_record` and
  `finalize_record`; it is the natural place to compute a `scope_key` (e.g.
  `printf '%s\0' "$@" | sha256sum`, NUL-separated so no argument-boundary ambiguity) and pass it
  into both record-writers. `decide_sharing()` needs the waiter's own current `lake_args` to
  compute its own `scope_key` for comparison — currently `decide_sharing()` only receives
  `waiter_fp` (line 303-304, called from `cmd_build` at line 627 with just `"$current_fp"`); it
  will need a second parameter for the waiter's own args-derived scope key, and `cmd_build`
  already has `"${lake_args[@]}"` = `"$@"` in scope to supply it (`cmd_build()` signature at line
  568-571).
- **Replay must become audible**: `replay_shared_result()` (`lake-build-guard.sh:329-334`)
  currently emits zero guard-authored bytes (cats the two capture files verbatim), by design, per
  the header's "silent-when-no-conflict" convention (`lake-build-guard.sh:29-30`). The task's own
  framing is precise here: that convention is correct for the clean/fresh-build path (cases 1 and
  3 in the test suite assert exactly this) but should not extend to a replay. The replay branch in
  `cmd_build()` (`lake-build-guard.sh:627-632`) is the single call site where a one-line stderr
  notice (holder pid, build age, job/result size or similar) can be added immediately before
  `replay_shared_result()` without touching the byte-identical stdout/stderr capture replay
  itself — so it cannot break cases 1/3's stdout/stderr equality assertions (those assert on
  *stdout*, and case 4 — the one existing case that exercises the replay path — only diffs
  `.out`, not `.err`, so it stays green against an added stderr-only notice; confirmed by reading
  `test-lake-build-guard.sh:172-174`).
- **"Documented way for a caller to assert a genuine build ran"**: the header's exit-code
  contract (`lake-build-guard.sh:54-65`) is already fully committed to passing `lake`'s own exit
  code through untouched on the normal `build` path, so this cannot be repurposed as a replay
  signal. A stable, grep-able stderr marker prefix (e.g. `lake-build-guard: REPLAY:`) documented
  in the header/usage text is the natural mechanism — consistent with the family-conventions
  block's own "degrade audibly, never silently" precedent (`lake-build-guard.sh:31-32`), which
  already establishes stderr notices with a fixed `lake-build-guard:` prefix as the script's
  house style (see the `systemd-run` and PSI-unavailable notices at lines 373, 524, 583, 594).

### Defect C — broken wait idiom (documentation only)

- Confirmed no occurrence of the broken `pgrep -f "lake-build-guard.sh build"` idiom exists
  anywhere in the source store (only in the task's own description of what a caller might
  naively invent) — this is purely a usage-text gap.
- `cmd_status()`'s own doc comment (`lake-build-guard.sh:401-409`) already explains at length why
  `status` mode deliberately avoids any `pgrep`-based process scan (an ambient `lean --worker` or
  a caller whose own argv mentions "lake build" would produce false positives — this is exactly
  what test cases 8 and 9 guard against). The natural place for the correct idiom is immediately
  adjacent to that existing explanation and in `print_help()`'s output (`lake-build-guard.sh:130-165`)
  and/or the header's USAGE block (`lake-build-guard.sh:46-52`), so a reader who reaches for
  `status`'s exit-10 report or `kill -0` on the `holder_pid` field never needs to invent a poll
  loop from scratch. Concrete working idiom, derivable from what `status` already exposes: read
  `holder_pid` from the result record (or from `status --verbose`'s report line,
  `lake-build-guard.sh:426`), then `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`.

## Test Harness Findings

`test-lake-build-guard.sh` already contains every scaffolding piece the acceptance criteria need,
so no new fixture machinery is required — only new cases and (for A and B) new mutants, following
the file's own established patterns:

- **Invocation counting**: `FAKE_LAKE_COUNTER` (fake `lake` at `test-lake-build-guard.sh:80-89`,
  used by cases 4/5/6) is exactly the "invocation-count probe distinguishing genuine builds from
  replays" the task's acceptance criteria call for. Reusable as-is for the new scoped-vs-full-build
  cases.
- **Exit-code passthrough pattern**: case 2 (`test-lake-build-guard.sh:122-134`,
  `FAKE_LAKE_EXIT=7`) is the direct template for the "`-- build TARGET` still passes lake's own
  exit code through" acceptance bullet.
- **Grep-based text/regression checks**: cases 12 and 13
  (`test-lake-build-guard.sh:341-373`) are the direct template for a Defect C case (grep
  `print_help()`/header output for the `kill -0` idiom) — no runtime mutation needed for a
  documentation-only fix, consistent with the file's own stated rationale for treating some cases
  as inspection-only (`test-lake-build-guard.sh:443-454`).
- **Scratch-copy `sed` mutation pattern**: mutations A and B
  (`test-lake-build-guard.sh:392-441`) are the direct template for mutation coverage on Defects A
  and B — apply a targeted `sed` to a copy of the script, confirm the corresponding new case goes
  red against the mutant.
- **Fixture note for Defect A's mutation**: the default fake `lake`
  (`test-lake-build-guard.sh:76-89`) always echoes fixed markers and exits
  `${FAKE_LAKE_EXIT:-0}` regardless of its arguments — it does not itself distinguish a
  known from an unknown subcommand. A mutation test proving Defect A's fix is load-bearing (not
  vacuous) needs a dedicated fake `lake` variant that reproduces the documented "unknown command,
  exit 0" shape explicitly (i.e. bakes in `FAKE_LAKE_EXIT=0` with an "unknown command" stderr
  message), rather than relying on the real installed `lake`'s current exit-code behavior for
  unknown commands (see Risks & Mitigations below) or on the default fixture fake.

## Decisions

- Confirmed via direct code reading (not merely repeating the task's own claims) that Defect A
  and Defect B each have exactly one architectural root cause apiece, both already precisely
  named in the task description; this report adds exact line-level fix points and threading paths
  the planner can act on directly.
- Recommend the planner explicitly choose between the hardcoded-allowlist and dynamic-`lake
  --help`-check options for Defect A (Findings, Defect A) rather than leaving the choice
  implicit — the two imply different test-fixture shapes.
- Recommend a new `scope_key` record field (parallel to the existing `pre_fingerprint`/
  `post_fingerprint` fields) as the concrete mechanism for Defect B, computed from a NUL-joined
  hash of the invocation's `lake_args`, rather than folding the args into
  `compute_fingerprint()`'s existing hash — keeping the two concerns (tree staleness vs. build
  scope) as separately named, separately comparable fields is more debuggable and matches the
  script's existing convention of one named field per concern.
- Recommend the replay-audible notice be a single stderr line with a fixed, documented
  `lake-build-guard: REPLAY:`-prefixed marker, both to satisfy the "distinguishable without
  --no-share" acceptance bullet and to give a caller a stable grep target, consistent with the
  script's existing house style for stderr notices.

## Risks & Mitigations

- **Real-`lake` exit-code discrepancy** (transparency note): running `lake TARGET` directly
  against the real installed `lake` on this machine (Lake 5.0.0-src, Lean 4.27.0-rc1, outside any
  Lean project) exits 1 with `error: unknown command 'TARGET'`, not 0 as the task's defect record
  states. This does not contradict the defect's underlying architecture claim (the wrapper still
  performs zero validation of `lake_args[0]` and blindly passes `lake`'s current exit code
  through, whatever it happens to be for a given Lake version/invocation shape), but it does mean
  the exact `0`-exit reproduction may be specific to a different Lake version, invocation context
  (inside vs. outside a project directory), or a `lake exe`/`lake env`-style subcommand whose
  no-op case is more plausibly a 0-exit than `build`'s. **Mitigation**: do not gate Defect A's
  regression test on the real installed `lake`'s current behavior (which could drift with the
  next Lake upgrade in either direction and make the test flaky/vacuous); use a dedicated fake
  `lake` fixture that deterministically reproduces the "unknown command, exit 0" shape, as noted
  in Test Harness Findings above. The mechanism-level defect (no validation at all) is real and
  worth fixing regardless of which exit code any particular `lake` version currently happens to
  return for a bad subcommand.
- **Allowlist drift** (Defect A, if the hardcoded-allowlist option is chosen): Lake's subcommand
  set could change across versions, silently making the allowlist stale (rejecting a now-valid
  subcommand, or failing to reject a since-removed one). Mitigation: either pick the dynamic
  `lake --help`-check option instead, or, if hardcoding, add a header comment analogous to the
  existing "RECORDED DEAD ENDS" discipline noting the allowlist's source (`lake --help`, this
  Lake version) so a future maintainer knows to re-verify it after a Lake upgrade.
  Assess whether that is a third gap worth closing here or a separate concern, and record the
  judgment either way.
- **Scope-key hashing edge case**: an empty `lake_args` array (a bare `lake-build-guard.sh build`
  with no trailing args at all, invoking `"$LAKE_BIN"` with zero arguments) is a real, currently
  reachable invocation shape (distinct from Defect A's "garbage subcommand" case). Whether Defect
  A's validation should also reject a *zero-length* `lake_args` in `build` mode is a scope
  decision the acceptance criteria do not explicitly settle (they only require `-- TARGET` to
  fail and `-- build TARGET` to keep working) — flagging for the planner to decide explicitly
  rather than defaulting silently either way.

## Appendix

- Live `lake --help` subcommand enumeration (Lake 5.0.0-src+2fcce72, Lean 4.27.0-rc1): `new init
  build query exe check-build test check-test lint check-lint clean env lean update pack unpack
  upload cache script scripts run translate-config serve`.
- The recorder-class taxonomy gap (`OFF_SCHEMA_STATUS` as an imperfect fit, and
  `HOOK_REGEX_BOUNDARY_DEFECT` being hand-recorded only) noted in the task description is
  reconfirmed as out of scope for this task; no further investigation performed here per the
  task's own instruction.

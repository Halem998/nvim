# Implementation Plan: Make lake-build-guard.sh's success signal trustworthy

- **Task**: 130 - Stop lake-build-guard.sh reporting passes for builds it did not run
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/130_make_lake_build_guard_success_truthful/reports/01_lake-build-guard-truthful-success.md`
- **Artifacts**: plans/01_lake-build-guard-truthful-success.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`lake-build-guard.sh` reports exit 0 in two situations where no corresponding build ran: an
unvalidated subcommand vector is handed straight to `lake` (Defect A), and a completed result is
replayed for a differently-scoped build over an unchanged tree (Defect B), silently. A third gap
is documentation-only: the script never states the correct idiom for waiting on an in-flight
guarded build, and the obvious invention (`pgrep -f "lake-build-guard.sh build"`) self-matches
the polling shell and never terminates (Defect C). This plan fixes all three in the single
source-store copy of the script plus its single test harness, and — because this script's header
declares the FAMILY CONVENTIONS a not-yet-existing sibling guard will instantiate, and two of the
three fixes change those conventions — treats that header block as a deliverable to be rewritten,
not merely as context. Done means: the seven acceptance bullets in the task description hold, the
existing thirteen-case-plus-mutation harness is extended (never replaced) and fully green, and the
revised family conventions are stated explicitly in the header.

### Research Integration

The research report (`reports/01_lake-build-guard-truthful-success.md`) is integrated as follows:

- **Defect A fix point**: research established that `lake_args` is populated by *two* independent
  branches — the `--)` branch and the bare catch-all `*)` branch — and that both converge after
  the `while [ $# -gt 0 ]` parsing loop exits. Phase 1 places one validation step at that
  convergence point rather than inside either branch. A `--)`-only fix would miss
  `lake-build-guard.sh build TARGET` (no `--`), which is the invocation shape the existing suite
  itself uses throughout.
- **Exit-code reuse**: research confirmed exit 77 is already the established "usage error" code at
  three sites (no-args, unknown top-level subcommand, unknown `--option`). Phase 1 reuses it
  rather than opening a new code in the 75-79 reserved band.
- **Defect B fix points**: research confirmed by direct reading that `compute_fingerprint()` /
  `collect_fingerprint_files()` never see the `lake_args` vector, and that the flat `key=value`
  record read via `get_record_field()` (grep-based, never sourced) has spare capacity for a new
  field. Phase 2 adds a `scope_key` field following that existing convention exactly, and
  preserves the never-sourced property.
- **Threading path**: research identified `run_as_holder()` as already receiving `"$@"` and
  calling both record writers, and `cmd_build()` as already holding `"$@"` in scope to supply
  `decide_sharing()` a second parameter. Phase 2 uses precisely that path; no new plumbing.
- **Replay-notice safety**: research verified that case 1 and case 3 assert byte-equality on a
  *fresh build* path (no replay), and that case 4 — the one existing case exercising the replay
  path — diffs only `.out`, never `.err`. An stderr-only replay notice is therefore safe against
  all thirteen existing cases. Phase 3 relies on this and re-verifies it by running the suite.
- **Harness scaffolding already present**: research confirmed `FAKE_LAKE_COUNTER` (invocation
  counting), `FAKE_LAKE_EXIT` (exit passthrough), grep-based inspection-only cases (12/13), and
  the scratch-copy `sed`-mutation pattern (mutations A/B) all exist. Phases 5 and 6 extend these;
  no new fixture machinery is built.
- **Real-`lake` discrepancy taken as binding**: research found that `lake TARGET` on this machine
  (Lake 5.0.0-src, Lean 4.27.0-rc1) exits **1**, not the 0 the defect record states. This plan
  therefore forbids building Defect A's regression case on the real binary and requires a
  dedicated fake `lake` reproducing the "unknown command, exit 0" shape deterministically. See
  Risks & Mitigations.
- **Two decisions research deliberately left open** are settled below in
  "Decisions Settled By This Plan" rather than deferred to implementation.

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

`specs/ROADMAP.md` was consulted and contains no item this task advances. Its "Agent System
Quality" section covers lint/validation standards for extension structure and agent frontmatter,
neither of which this task touches. No roadmap phases are included (no roadmap flag was set), and
this plan MUST NOT modify ROADMAP.md.

## Decisions Settled By This Plan

The research report explicitly left three choices to planning. All three are settled here; the
implementer executes these decisions rather than re-litigating them.

### Decision 1 — Defect A validates against a hardcoded allowlist, not a dynamic `lake --help` probe

**Chosen**: a hardcoded allowlist constant sitting with the other `DEFAULT_*`/threshold constants,
plus an environment escape hatch.

**Rationale**:

1. **The dynamic probe trades one failure mode for two.** A validation step that parses another
   tool's help output acquires that tool's help-format stability as a new dependency: if
   `lake --help`'s layout changes, or the probe fails for any environmental reason, the guard
   either refuses a legitimate build (a false 77) or silently degrades back to no validation —
   which is the very defect being fixed. The allowlist has exactly one failure mode (drift), and
   it is directly mitigable.
2. **Blast radius on the harness is decisive.** The fixture fake `lake`
   (`build_fixture()` in `test-lake-build-guard.sh`) ignores its arguments entirely and always
   echoes fixed markers. A dynamic probe would call `"$LAKE_BIN" --help` and grep it, so the fake
   would return `STDOUT_MARKER`, no subcommand would ever validate, and **all thirteen existing
   cases would fail with exit 77** until the shared fixture were reworked. The task instruction is
   to extend the existing harness, not to rework the fixture contract every case depends on.
3. **Determinism and zero runtime cost** are consistent with the script's role as a transparent
   wrapper that must compose safely inside `$(... 2>&1)` call sites.

**Drift mitigation** (both parts are required, not optional):

- A header note in the style of the existing "RECORDED DEAD ENDS" block, naming the allowlist's
  provenance (`lake --help`, Lake 5.0.0-src+2fcce72 / Lean 4.27.0-rc1) and stating the obligation
  to re-verify it after a Lake upgrade.
- An escape hatch `LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS` (space-separated, `:-`-defaulted to empty,
  following the existing test-seam convention) so a caller hitting a newly-added Lake subcommand
  is never hard-blocked while waiting for a source-store update. This neutralizes the allowlist's
  only serious failure mode — a false refusal of legitimate work — without adding a subprocess or
  a help-format dependency. It MUST be documented in `print_help()` and the header alongside the
  allowlist, not buried.

**Allowlist contents** (from the research report's live enumeration): `new init build query exe
check-build test check-test lint check-lint clean env lean update pack unpack upload cache script
scripts run translate-config serve`.

**Flag-shaped first tokens are rejected too.** `lake_args[0]` beginning with `-` (e.g. a `--`
vector of `--version`) is not a subcommand and is not on the allowlist, so it exits 77. This is
deliberate and in scope: `lake --version` runs no build, yet under the current code it would
complete, finalize a `state=complete` record, and become shareable — the same false-pass class as
Defect A itself.

### Decision 2 — a zero-length `lake_args` in build mode is rejected (exit 77)

**Chosen**: reject. `lake-build-guard.sh build` with no trailing lake arguments exits 77 with a
usage message, identically to an unknown subcommand.

**Rationale**: invoking `"$LAKE_BIN"` with zero arguments does not run a build. If it exits 0, the
guard records a completed "build", makes that record shareable, and reports success for work that
never happened — definitionally the same defect class this task exists to close. Treating "no
subcommand at all" as a usage error is the only reading consistent with the fix for "wrong
subcommand".

**Safety**: verified non-breaking. The script's own header records as a non-goal that it wires
itself into no call site, and every build-mode invocation in the existing harness passes `build`
as `lake_args[0]` (confirmed by enumerating all `run_guard`/`"$GUARD"`/mutant invocations in
`test-lake-build-guard.sh`). There is no live caller to break, and settling this now — before the
sibling guard instantiates the convention — is why the sibling task depends on this one.

### Decision 3 — the replay notice names the record's own fields, and does not fabricate a job count

The task description suggests a notice "naming the replay and the job count". The job count is a
property of `lake`'s output text, not of anything the guard records; extracting it would require
parsing Lake's output format and would couple this guard to a format it deliberately passes
through untouched. **The notice therefore names holder pid, result age in seconds, and the
recorded exit status — all fields the guard already owns — and omits the job count.** The caller
gets what the acceptance bullet actually requires (a replay is distinguishable without
`--no-share`) via the stable marker prefix; a caller who needs the job count reads it from the
replayed stdout, which is byte-identical to the original build's.

## Goals & Non-Goals

**Goals**:

- An unknown or absent `lake` subcommand in build mode exits 77 before any build is attempted,
  through *both* argument-collection paths (`--` and bare).
- `-- build TARGET` continues to pass `lake`'s own exit code through untouched.
- A result is replayed only for an equivalently-scoped invocation: a scoped build followed by an
  unchanged-tree full build runs a real full build.
- An identical full build over an unchanged tree still replays (the sharing optimization survives;
  it is scoped, not disabled).
- A replay announces itself on stderr with a stable, documented, grep-able marker prefix.
- The correct `kill -0` wait idiom, and the `pgrep -f` self-match pitfall, appear in the script's
  usage text.
- The header's FAMILY CONVENTIONS block describes the *revised* contract, so the sibling guard
  that copies it does not instantiate the superseded one.
- Mutation coverage: reverting each fix reintroduces exactly the corresponding failure.

**Non-Goals**:

- Wiring the guard into any call site (an explicit non-goal in the script's own header; unchanged).
- Touching the recorder-class taxonomy or registering a new system-defect class. The taxonomy
  observation is *recorded* by this plan (Phase 6) for whoever next revises it; the sibling task
  owns the registration mechanism. Expanding scope here is forbidden.
- Creating, modifying, or designing `latex-build-guard.sh`. This plan settles conventions; the
  sibling task instantiates them.
- Redesigning the record schema, the lock/`flock` machinery, or `compute_fingerprint()`'s existing
  tree-staleness semantics. `scope_key` is added *alongside* the fingerprint, not folded into it.
- Any write under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Regression test for Defect A built on the real `lake` binary, whose current exit code for an unknown command is 1 (not the 0 the defect record asserts) — making the test vacuous now or flaky after a Lake upgrade | H | H | Phase 5 MUST use a dedicated fake `lake` variant that bakes in the "unknown command, exit 0" shape deterministically. The real binary MUST NOT appear in any new case. |
| Allowlist drift: a future Lake adds a subcommand the guard then refuses | M | M | `LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS` escape hatch plus a provenance/re-verification header note (Decision 1). |
| Replay notice breaks the byte-equality assertions in cases 1/3 | H | L | Notice is stderr-only and emitted only on the replay branch; cases 1/3 exercise a fresh build, and case 4 (the one replay case) diffs `.out` only. Verified by reading the harness; re-verified by running the full suite in every phase. |
| Doc-only edits trip the grep-based inspection cases 12a (`/home/`, `/Projects/`, `/run/current-system`) and 12b (`[0-9]+(GB|MB|G|M)`) | M | M | Phase 4 carries a `local` verification tier, not `prose`, precisely so the full harness runs after doc edits. Avoid absolute paths and byte-suffixed numerals in all new prose. |
| Records written before `scope_key` existed lack the field, and a permissive read would share across scopes | H | L | `decide_sharing()` treats a missing or empty `scope_key` as NOT shareable (fail closed). This matches the staleness policy's stated direction: failing any condition falls through to a real build, which is always safe. |
| `set -u` interaction when expanding a now-possibly-validated empty `lake_args` array | M | L | Decision 2 rejects the empty case before dispatch, so `cmd_build` never receives an empty vector in build mode. |
| Scope-key hash ambiguity across argument boundaries (`build A B` vs `build "A B"`) | M | L | Hash a NUL-separated join (`printf '%s\0' "$@"`), never a space-joined string. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 1-4 all
edit the single file `agent-system/extensions/core/scripts/lake-build-guard.sh`, and Phases 5-6
extend a harness whose new cases assert behavior introduced by the earlier phases.

---

### Phase 1: Validate the lake subcommand vector before dispatch (Defect A) [COMPLETED]

- **Goal:** No build-mode invocation reaches `lake` with an unrecognized or empty subcommand
  vector; both argument-collection paths are covered by one check.
- **Tasks:**
  - [x] Add a `LAKE_SUBCOMMANDS` allowlist constant alongside the existing `DEFAULT_*`/threshold *(completed)*
        constants, holding the 22 subcommands enumerated in Decision 1, with an adjacent comment
        recording its provenance (`lake --help`, Lake 5.0.0-src+2fcce72 / Lean 4.27.0-rc1) and the
        obligation to re-verify after a Lake upgrade, in the style of the existing
        "RECORDED DEAD ENDS" discipline.
  - [x] Add the `LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS` escape hatch, `:-`-defaulted to empty *(completed)*
        alongside the other `LAKE_BUILD_GUARD_*` seam variables, and unioned with the allowlist at
        validation time.
  - [x] In `main()`, immediately after the `while [ $# -gt 0 ]` parsing loop exits and **before** *(completed)*
        `ROOT="$(resolve_project_root "$dir")"`, add a validation step gated on `[ "$mode" = "build" ]`
        that exits 77 with a `lake-build-guard:`-prefixed stderr message when `lake_args` is empty,
        and when `lake_args[0]` is not in the unioned allowlist (flag-shaped tokens included; see
        Decision 1).
  - [x] Place the check before project-root resolution so an argument-validity error is reported *(completed)*
        as 77 rather than being masked by a 78 "no Lean project found".
  - [x] Update the `EXIT CODES` header block and `print_help()`'s exit-code lines so 77's *(completed)*
        description covers "bad flags/subcommand, including an unknown or missing lake subcommand
        in build mode".
- **Timing:** 45 minutes
- **Depends on:** none
- **Verification Tier:** local
- **Scope Hypothesis:** This phase asserts that exactly two branches populate `lake_args` (`--)`
  and the bare catch-all `*)`) and that both converge at one post-loop point. Confirm at
  implementation time by grepping the parsing loop for every `lake_args` assignment/append and
  verifying each occurrence lies inside the `while` loop that the new check follows; if a third
  population site exists, the check's placement must still dominate it, or the phase is not
  complete.
- **Files to modify:**
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` — allowlist constant, escape-hatch
    seam, post-parse validation step in `main()`, exit-code documentation in header and
    `print_help()`.
- **Verification:**
  - Run `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`; all thirteen
    existing cases and both mutations remain green (every existing build-mode invocation passes
    `build`, so none is newly rejected).
  - Manually confirm exit 77 for a build-mode invocation with a garbage subcommand via *both*
    shapes (`build -- TARGET` and `build TARGET`) against a scratch fixture.
  - Manually confirm exit 77 for `build` with no lake arguments.

---

### Phase 2: Key result sharing on build scope (Defect B, mechanism) [COMPLETED]

- **Goal:** A completed result is replayed only for an equivalently-scoped invocation; tree
  staleness and build scope remain two separately named, separately comparable record fields.
- **Tasks:**
  - [x] Add a `compute_scope_key()` helper next to the fingerprinting functions that hashes a *(completed)*
        NUL-separated join of the invocation's lake argument vector
        (`printf '%s\0' "$@" | sha256sum | awk '{print $1}'`), never a space-joined string.
  - [x] Add a `scope_key=` line to both `write_inflight_record()` and `finalize_record()`, *(completed)*
        following the existing flat `key=value` shape exactly; keep `get_record_field()`'s
        grep-based, never-sourced read path unchanged.
  - [x] Thread the scope key from `run_as_holder()` (which already receives `"$@"`) into both *(completed)*
        record writers; preserve `finalize_record()`'s existing pattern of re-reading carried-over
        fields from the in-flight record.
  - [x] Give `decide_sharing()` a second parameter (the waiter's own scope key) and add a fifth *(completed)*
        condition comparing it to the record's `scope_key`. Treat a missing or empty recorded
        `scope_key` as NOT shareable (fail closed).
  - [x] Update the call site in `cmd_build()` to compute its own scope key from the args already *(completed)*
        in scope and pass it to `decide_sharing()`.
  - [x] Update the header's STALENESS POLICY block: it currently enumerates four conditions and *(completed)*
        states them as authoritative. Add the scope condition as a fifth, and state plainly that
        the policy now governs both source change *and* build scope — the prior text was a policy
        about source change alone and never claimed otherwise.
- **Timing:** 1 hour
- **Depends on:** 1
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` — `compute_scope_key()`,
    `write_inflight_record()`, `finalize_record()`, `decide_sharing()`, `run_as_holder()`,
    `cmd_build()`, header STALENESS POLICY block.
- **Verification:**
  - Full harness green — in particular cases 4, 5, and 6, which all use an identical `build` arg
    vector and must therefore still share (case 4) or still reject (cases 5, 6) for their original
    reasons.
  - Manually confirm against a scratch fixture that a scoped invocation followed by a differently
    scoped one over an unchanged tree produces two real fake-`lake` invocations.
  - Manually confirm a hand-written `state=complete` record lacking `scope_key` is not replayed.

---

### Phase 3: Make replay audible and give callers a documented assertion (Defect B, reporting) [COMPLETED]

- **Goal:** A caller can tell a replayed result from a fresh build without passing `--no-share`,
  via a stable documented marker.
- **Tasks:**
  - [x] In `cmd_build()`, on the replay branch only, emit one stderr line immediately before *(completed)*
        `replay_shared_result()` with the fixed prefix `lake-build-guard: REPLAY:` naming the
        recorded holder pid, the result's age in seconds, and the recorded exit status (see
        Decision 3 — no job count).
  - [x] Leave `replay_shared_result()` itself untouched, so the replayed stdout/stderr bytes stay *(completed)*
        byte-identical to the original build's.
  - [x] Document the marker prefix in the header and in `print_help()` as a **stable contract** a *(completed)*
        caller may grep, and state the two ways to assert a genuine build ran: grep stderr for the
        absence of the marker, or pass `--no-share` to force one.
- **Timing:** 30 minutes
- **Depends on:** 2
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` — replay branch in `cmd_build()`,
    header, `print_help()`.
- **Verification:**
  - Full harness green. Cases 1 and 3 assert byte-equality on a fresh-build path and must be
    unaffected; case 4 exercises the replay path but diffs `.out` only, so an stderr-only notice
    leaves it green. If either goes red, the notice has leaked onto the wrong path — fix the
    placement, do not relax the assertion.
  - Manually confirm the marker appears on stderr for a replayed run and is absent for a fresh one.

---

### Phase 4: Document the wait idiom and rewrite the family conventions (Defect C + convention deliverable) [COMPLETED]

- **Goal:** The correct wait idiom is in the usage text, and the FAMILY CONVENTIONS block
  describes the revised contract rather than the superseded one.
- **Tasks:**
  - [x] Add a "WAITING ON AN IN-FLIGHT GUARDED BUILD" subsection to the header USAGE block **and** *(completed)*
        to `print_help()`'s output, giving the working idiom (read `holder_pid` from the result
        record or from `status --verbose`, then
        `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`) and naming the `pgrep -f`
        self-match pitfall explicitly — a poll on the guard's own command line matches the polling
        shell's own argv and never terminates. Place it adjacent to `cmd_status()`'s existing
        explanation of why `status` avoids process scans, so the two reinforce each other.
  - [x] Ensure the idiom is present in `print_help()`'s **output**, not only in a source comment: *(completed)*
        the acceptance bullet is about the usage text, and Phase 5's case greps the rendered help.
  - [x] Rewrite the FAMILY CONVENTIONS block to state the revised conventions explicitly. The *(completed)*
        sibling guard copies this block, so leaving it describing the old contract would propagate
        the defects. Specifically:
    - **exit-code shape**: state that the guard validates the wrapped command's own argument
      vector *before* dispatch and refuses an unrecognized or empty one in the reserved usage band
      — so the "passes the wrapped command's exit code through untouched" guarantee applies only
      to a command the guard actually recognized. Passthrough without prior validation is what
      produces a false pass.
    - **silent-when-no-conflict**: qualify it. Silence is correct for the clean/no-conflict path
      in every mode. A **replayed** result is not a no-conflict path: it MUST announce itself with
      a stable, documented stderr marker prefix, because a caller otherwise cannot distinguish a
      replay from a fresh run.
    - **new convention — result sharing keys on scope, not staleness alone**: a guard that shares
      a completed result MUST key that decision on a normalized form of the wrapped command's
      argument vector in addition to input staleness. Inputs unchanged does not imply the
      requested work is the same work.
    - Leave the subcommand-shape and degrade-audibly conventions as they stand; note that the
      replay marker follows the same fixed `lake-build-guard:` stderr-prefix house style that
      degrade-audibly already establishes.
- **Timing:** 40 minutes
- **Depends on:** 3
- **Verification Tier:** local
- **Commit Mode:** per-substep
- **Files to modify:**
  - `agent-system/extensions/core/scripts/lake-build-guard.sh` — header USAGE block, FAMILY
    CONVENTIONS block, `print_help()` heredoc, comment adjacent to `cmd_status()`.
- **Verification:**
  - Full harness green. This phase uses `local`, not `prose`, deliberately: cases 12a and 12b grep
    the *script source text* for absolute paths (`/home/`, `/Projects/`, `/run/current-system`)
    and byte-suffixed numerals (`[0-9]+(GB|MB|G|M)`), and case 13 asserts every `LEAN_NUM_THREADS`
    occurrence is comment-only. Prose edits can trip all three, so a diff read-through is not
    sufficient verification here.
  - Confirm `lake-build-guard.sh --help` output contains both `kill -0` and the `pgrep` pitfall
    warning.

---

### Phase 5: Extend the harness with the acceptance cases [IN PROGRESS]

- **Goal:** Every acceptance bullet is covered by a new case in the existing suite, using the
  suite's own established patterns.
- **Tasks:**
  - [ ] Add a `build_fixture_unknown_cmd()` variant (or an opt-in flag on `build_fixture()`)
        producing a fake `lake` that, given a first argument it does not recognize, prints
        `error: unknown command '<arg>'` to stderr and **exits 0** — deterministically reproducing
        the documented defect shape. The real `lake` binary MUST NOT be used (see Risks).
  - [ ] Case: `build -- TARGET` (unknown subcommand, via the `--` path) exits 77, and the fake
        `lake` counter records zero invocations.
  - [ ] Case: `build TARGET` (unknown subcommand, via the bare catch-all path) exits 77 — this is
        the case a `--)`-only fix would miss.
  - [ ] Case: `build` with no lake arguments exits 77 (Decision 2).
  - [ ] Case: `build -- build TARGET` with `FAKE_LAKE_EXIT=7` still exits 7 — exit-code
        passthrough survives validation, following case 2's template.
  - [ ] Case: a scoped build (`build Foo.Bar`) followed by an unchanged-tree full build (`build`)
        produces **2** fake-`lake` invocations, asserted via `FAKE_LAKE_COUNTER`, not by output
        inspection. Note that `Foo.Bar` follows `build`, so `lake_args[0]` is the valid `build`
        subcommand and Phase 1's validation does not interfere.
  - [ ] Case: a full build followed by an identical full build over an unchanged tree produces
        **1** invocation — the sharing optimization is preserved, not disabled.
  - [ ] Case: a replayed run emits the `lake-build-guard: REPLAY:` marker on stderr without
        `--no-share`, and a fresh run does not.
  - [ ] Case: `--help` output contains the `kill -0` wait idiom and the `pgrep` self-match warning
        (grep-based inspection case, following cases 12/13's template).
  - [ ] Update the suite's header comment: it currently says "the 13 acceptance-mapped cases below".
        Restate the count and add one line per new case to the fixture-model note where the new
        fake-`lake` variant needs explaining.
- **Timing:** 1 hour 15 minutes
- **Depends on:** 4
- **Verification Tier:** local
- **Scope Hypothesis:** This phase asserts eight new cases and one new fixture variant. The count
  is a hypothesis: confirm at implementation time by mapping each of the task's seven acceptance
  bullets to at least one new case and checking none is left uncovered; if a bullet needs two
  cases or one case covers two bullets, adjust the count and say so in the phase's completion
  note rather than forcing the number.
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — new fixture variant,
    new cases, header-comment count and fixture-model note.
- **Verification:**
  - Full suite green, with the new cases passing and all thirteen originals still passing.
  - Each new case fails if run against the pre-fix script (spot-checked here; proved mechanically
    in Phase 6).

---

### Phase 6: Mutation coverage, full-suite green, and the taxonomy observation [NOT STARTED]

- **Goal:** Each new case is proven non-vacuous by a targeted mutation, the whole suite is green,
  and the recorder-class observation is recorded without expanding scope.
- **Tasks:**
  - [ ] Mutation C (Defect A): on a scratch copy, `sed` the validation step out (or force its
        condition always-true) and confirm the `-- TARGET` and bare-`TARGET` cases go RED — the
        unknown subcommand reaches the fake `lake`, which exits 0, and the guard reports a pass.
        Follow mutations A/B's scratch-copy pattern exactly.
  - [ ] Mutation D (Defect B): on a scratch copy, `sed` the `scope_key` comparison out of
        `decide_sharing()` and confirm the scoped-then-full case goes RED (invocation count stays
        at 1 instead of reaching 2), while the identical-full-build case stays green — proving the
        fix is load-bearing *and* that it did not simply disable sharing.
  - [ ] Mutation E (replay notice): on a scratch copy, remove the `REPLAY:` stderr line and confirm
        the marker case goes RED.
  - [ ] Extend the by-inspection non-vacuousness `info` block with one line per remaining new case
        (the empty-args case and the `--help` idiom case), stating briefly how each fails — matching
        the existing block's format.
  - [ ] Run the complete suite; require zero failures. Investigate any mutation reported as
        "inconclusive" rather than accepting it.
  - [ ] Record the recorder-class taxonomy observation for whoever next revises the taxonomy: both
        originating events were filed as `OFF_SCHEMA_STATUS`, which does not fit "a tool reports
        success for work it did not do". Record it in this task's implementation summary under
        `specs/`, and nowhere else — a sibling task owns the registration mechanism, and adding a
        class here is out of scope. Do not create files outside `specs/**` for this.
- **Timing:** 50 minutes
- **Depends on:** 5
- **Verification Tier:** full
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — mutation section,
    by-inspection block.
  - `specs/130_make_lake_build_guard_success_truthful/summaries/` — implementation summary
    (created at task completion; carries the taxonomy observation).
- **Verification:**
  - `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` exits 0 with
    `Failed: 0`.
  - `bash -n` clean on both modified files.
  - `grep -rn '\.claude/' ` over the diff confirms no `.claude/**` path was written.
  - Repo task-reference lint clean: no task numbers in either modified file.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` exits 0,
      `Failed: 0`, with all thirteen original cases plus the new ones passing.
- [ ] `bash -n` passes on `lake-build-guard.sh` and `test-lake-build-guard.sh`.
- [ ] `-- TARGET` exits non-zero (77), and so does bare `TARGET` — both argument paths.
- [ ] `build` with no lake arguments exits 77.
- [ ] `-- build TARGET` with `FAKE_LAKE_EXIT=7` exits 7.
- [ ] Scoped-then-full over an unchanged tree: 2 fake-`lake` invocations.
- [ ] Full-then-identical-full over an unchanged tree: 1 fake-`lake` invocation.
- [ ] `lake-build-guard: REPLAY:` appears on stderr for a replay without `--no-share`, and is
      absent for a fresh build.
- [ ] `--help` output contains the `kill -0` idiom and the `pgrep` self-match warning.
- [ ] Each of mutations C, D, E turns the corresponding case RED.
- [ ] No file under `.claude/**` was created or modified.
- [ ] No task-number reference appears in either modified file (both live outside `specs/**`).
- [ ] The FAMILY CONVENTIONS block states the revised exit-code and replay-audibility conventions
      and the new scope-keyed-sharing convention.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lake-build-guard.sh` (modified) — subcommand validation,
  `scope_key` record field and sharing condition, audible replay notice, wait-idiom documentation,
  rewritten FAMILY CONVENTIONS block.
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` (modified) — new fixture
  variant, eight new acceptance cases, three new mutations.
- `specs/130_make_lake_build_guard_success_truthful/plans/01_lake-build-guard-truthful-success.md`
  (this file).
- `specs/130_make_lake_build_guard_success_truthful/summaries/NN_lake-build-guard-truthful-success-summary.md`
  (at completion; carries the taxonomy observation from Phase 6).

## Rollback/Contingency

Both modified files are tracked and each phase commits separately, so `git revert` of a single
phase commit restores the prior behavior of that one concern without disturbing the others. The
phases are ordered so that reverting a later one never leaves an earlier one inconsistent: Phase 1
(validation) is independent of Phase 2 (`scope_key`); Phase 3's notice is additive to Phase 2;
Phase 4 is documentation over Phases 1-3; Phases 5-6 touch only the harness.

Contingency if Phase 2 destabilizes sharing (cases 4/5/6 cannot be made green together): do not
weaken the new scope condition to force them green. Fall back to making `decide_sharing()`'s scope
comparison the *last* condition evaluated and add a `--verbose` trace line naming which condition
rejected sharing, then diagnose from that. Disabling sharing entirely is not an acceptable
resolution — the task's acceptance explicitly requires the optimization to survive.

Contingency if the allowlist proves too brittle in practice: the escape hatch
`LAKE_BUILD_GUARD_EXTRA_SUBCOMMANDS` unblocks any caller immediately without a code change, and
switching to the dynamic `lake --help` probe remains available as a follow-up — but it would
require reworking the shared fixture fake `lake` first (see Decision 1), which is why it is not
the initial choice.

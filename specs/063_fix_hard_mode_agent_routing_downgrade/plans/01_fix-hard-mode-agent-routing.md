# Implementation Plan: Fix the agent-side hard-mode routing downgrade

- **Task**: 63 - Fix the agent-side hard-mode routing downgrade that discards declared domain agents
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/063_fix_hard_mode_agent_routing_downgrade/reports/01_agent-routing-hard-mode-parity.md
- **Artifacts**: plans/01_fix-hard-mode-agent-routing.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`command-route-agent.sh` computes only the `routing_agents_hard` manifest block under
`effort_flag=hard`, and on a miss overwrites the result with the caller-supplied `default_agent` —
never consulting the extension's declared `routing_agents` entry at all. The consequence is that
`--hard` routes strictly worse than no flag for the 14 extensions that declare `routing_agents`
without `routing_agents_hard`. This plan brings the agent-side resolver to parity with the
already-correct skill-side resolver by implementing a three-rung ladder
(`routing_agents_hard` -> `routing_agents` -> `default_agent`) in the consumer script, rewrites the
script's own header comment which currently documents the defect as intentional, and amends the one
existing test assertion that pins the defective behavior as correct. Done means: `--hard` never
resolves to a less specific agent than the same call without `--hard`, the caller's hard default is
still honored on a genuine total miss, and the routing suite is green against the corrected
contract.

### Research Integration

The research report is verified ground truth and its conclusions are adopted without
relitigation:

- **Fix site is the consumer, not the library.** `routing_lookup()` in `manifest-routing-lib.sh`
  is a deliberate single-block primitive; composing multiple blocks into a fallback ladder is
  already each consumer's job (`command-route-skill.sh` does exactly this in its own file, not in
  the library). A library change would touch the already-correct skill resolver plus two
  validation callers for no reason; a consumer-only change touches exactly the one file with the
  defect. `manifest-routing-lib.sh` needs no change.
- **Ladder**: `routing_agents_hard` (hit, `via` from `routing_lookup`) -> `routing_agents` (hit,
  `via="hard-miss-standard-fallback"`) -> `default_agent` (`via="default"`). The via-string is
  reused verbatim from the skill side so `routing_trace` output is diagnostically comparable
  across both resolvers via grep/log-scanning.
- **Standard (non-hard) mode is unchanged**: single `routing_agents` lookup, else `default_agent`.
- **Line numbers have already drifted twice** (task description estimated `~62-68`; research found
  `46-65`; the verified current shape is at `46-69`). The implementer must re-read the whole file
  rather than patch mechanically against any cited line number.
- **Baseline**: `test-routing-resolution.sh` runs 18/18 PASS on unmodified source. Assert 3's
  neovim/nix semantic sub-checks currently pin the DEFECT, and its comment frames standard-block
  reuse as "a precedence-direction / fallback-source regression" — backwards post-fix, so the
  comment must be inverted, not merely have its expected strings swapped.
- **Caller safety confirmed**: only `skill-orchestrate` (standard, empty effort flag) and
  `skill-orchestrate-hard` (hard, with `general-research-hard-agent` / `planner-hard-agent` /
  `general-implementation-hard-agent` defaults) source this script. Both hard defaults survive
  unchanged as the ladder's rung-3 true-total-miss value, so no caller is weakened.
- **Verified inventory (14 of 19)** extensions declare `routing_agents` but no
  `routing_agents_hard`: email, epidemiology, filetypes, formal, founder, latex, memory, nix,
  nvim, present, python, typst, web, z3. (core, cslib, lean declare both.)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` in this repository; no roadmap phases required.

## Goals & Non-Goals

**Goals**:
- Implement the three-rung hard-mode ladder in `command-route-agent.sh`, with
  `via="hard-miss-standard-fallback"` on the standard-block rung.
- Leave standard (non-hard) resolution behaviorally identical.
- Rewrite the script's EDGE CASES header block so it documents the corrected ladder rather than
  asserting the discarded-domain-agent behavior was deliberate.
- Amend Assert 3's neovim/nix semantic sub-checks (and their framing comment) to pin the corrected
  contract, and add a fourth semantic case for the genuine total-miss rung that no current fixture
  exercises.
- Record, in a test comment, that `nix` is itself one of the 14 hard-block-less extensions, so a
  future task declaring `routing_agents_hard` for `nix` shifts that fixture's expected value from
  the standard-fallback path to the hard-hit path.
- Verify across a representative sample of the 14 affected extensions that `--hard` is never less
  specific than no flag.

**Non-Goals**:
- Changing `manifest-routing-lib.sh` — research established the composition belongs in the
  consumer; no library edit is required or wanted.
- Changing `command-route-skill.sh` — it is already correct and must be provably untouched.
- Extracting a shared `routing_lookup_with_fallback` helper — one call site only; the skill side's
  composition has an extra on-disk `-hard`-suffix probe with no agent-side analogue. Premature.
- Declaring new `routing_agents_hard` blocks for any of the 14 extensions — that is a separate
  contract-delivery concern.
- Updating `context/guides/manifest-routing-schema.md` / `hard-mode-routing.md` to document the
  two-block composition pattern. Research flagged this as a worthwhile follow-up doc pass; it is
  outside the declared file scope here and should be a separate task.
- Any write under `.claude/**`. That tree is a disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer patches against a cited line number that has drifted again | M | H | Phase 2 mandates a full re-read of the current file before any edit; no line-number-anchored patching. Line numbers have already drifted twice on this file. |
| The resolver fix and the test amendment are split across commits, leaving a committed red suite | M | M | Phase 2 declares `Commit Mode: atomic-batch` over both files as one pre-declared objective; the intermediate one-file state is expected red and MUST NOT be committed. |
| `_route_block` removal leaves a stale reference in the trailing `unset` list, leaking state into the sourcing shell | L | M | Explicit checklist item: `_route_block` is dropped from body and `unset` list; `_route_std_value` and `_route_std_via` are added to `unset`. Phase 3 greps for leaked `_route_*` variables after a sourced call. |
| A caller silently depended on the fall-through-to-default as intentional | H | L | Research grepped every SKILL.md: only the two orchestrate skills call this script, and both hard defaults are preserved as rung 3. Phase 3 re-confirms the call-site inventory rather than trusting the prior grep. |
| Assert 1 / Assert 2 / Assert 4 regress as collateral | M | L | None of them touch `routing_agents` fallback composition (Assert 1 exercises only the skill resolver, Assert 2 checks agent-file existence, Assert 4 uses a synthetic non-hard fixture). Phase 3 runs the full suite, not just Assert 3. |
| Edits land in `.claude/**` instead of the source store | H | L | Every phase names `agent-system/extensions/core/...` paths explicitly; Phase 3 verifies `git status` shows no `.claude/**` modification. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Capture the pre-fix routing baseline [NOT STARTED]

**Goal**: Record the exact pre-fix resolution matrix and suite result, so the corrected behavior in
Phase 3 can be compared against a measured before-state rather than an assumed one, and so the
current file shape is confirmed before any edit.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/command-route-agent.sh` in full and note the
      current line span of the effort-flag branch, the `routing_lookup` call, the `unset` list, and
      the EDGE CASES header block. Do not rely on any line number cited in the research report or
      task description.
- [ ] Run the suite from the repo root and record the pass/fail tally:
      `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`
      (expected: 18/18 PASS on unmodified source).
- [ ] With `ROUTE_MANIFEST_ROOT=agent-system`, record standard vs. hard resolution (both
      `AGENT_NAME` and the `via` in the trace) for op=research on at least: `typst`, `nvim`, `nix`,
      `python`, `latex`, `web`, `z3`, plus `formal:logic` (the compound-key reproduction), `lean4`
      (the hard-hit control), and one never-declared task_type such as `zzz-unrouted-test-type`
      (the total-miss control).
- [ ] Confirm the defect reproduces on both a simple and a compound task_type: hard resolves the
      caller default while standard resolves the extension's declared domain agent.
- [ ] Write the matrix as a working note under
      `specs/063_fix_hard_mode_agent_routing_downgrade/` (markdown, task-scoped scratch — not a
      declared artifact) for reuse in Phase 3.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the baseline suite is 18/18 PASS and that the defect
reproduces on the listed task types. Confirm by running the suite and the per-task_type sourced
calls directly; if the baseline is not 18/18, stop and report before editing anything — a
different baseline means the source store diverged from what research measured.

**Files to modify**:
- `specs/063_fix_hard_mode_agent_routing_downgrade/{working-note}.md` - new scratch note holding
  the pre-fix matrix (task-scoped, not a lifecycle artifact)

**Verification**:
- The suite result and the full before-matrix are recorded in the working note.
- No file under `agent-system/**` or `.claude/**` was modified in this phase (`git status --short`
  shows only the new note under `specs/`).

---

### Phase 2: Correct the ladder and pin the corrected contract in the tests [NOT STARTED]

**Goal**: Replace the single-block hard-mode lookup with the three-rung ladder, rewrite the header
comment that documents the defect as intentional, and amend the test assertions that pin the defect
— as one atomic batch, since either file alone leaves the suite red.

**Tasks**:
- [ ] In `command-route-agent.sh`, compute the standard-block lookup unconditionally up front,
      capturing both value and via into `_route_std_value` / `_route_std_via` (mirroring
      `command-route-skill.sh`'s composition shape).
- [ ] Under `effort_flag=hard`, run `routing_lookup "routing_agents_hard" ...`; on a hit take its
      value and via; on a miss with a non-empty `_route_std_value` take the standard value with
      `_route_via="hard-miss-standard-fallback"`; on a miss of both take `$_route_default_agent`
      with `_route_via="default"`.
- [ ] Under non-hard mode, take `_route_std_value` with `_route_std_via` when non-empty, else
      `$_route_default_agent` with `_route_via="default"` — behaviorally identical to today.
- [ ] Remove `_route_block` from the body and from the trailing `unset` list (it becomes unused);
      add `_route_std_value` and `_route_std_via` to the `unset` list. The script's NOTE header
      requires no state leak into the sourcing shell.
- [ ] Preserve the script's existing invariants: it is sourced not executed, it never calls `exit`,
      and it still exports `AGENT_NAME` and emits exactly one `routing_trace` call.
- [ ] Rewrite the EDGE CASES header block so it documents the three-rung ladder. Delete the
      sentence asserting the fall-through is "deliberately NOT to the standard (non-hard)
      routing_agents block ... matching the behavior of the case tables this script replaces" —
      that framing is what misdirected the previous reader.
- [ ] Update the `$4 = effort_flag` parameter comment: hard mode no longer resolves "against
      routing_agents_hard instead of routing_agents" but against `routing_agents_hard` first, then
      `routing_agents`, then the default.
- [ ] In `test-routing-resolution.sh`, rewrite the comment above the `for tt in neovim nix` loop:
      reuse of the standard block on a hard miss is now the CORRECT contract, not a
      precedence-direction regression. State what the loop now proves — hard mode falls back to the
      extension's own standard agent rather than the caller's generic hard default.
- [ ] Change the loop's expectations to per-task_type values: `neovim` -> `neovim-research-agent`,
      `nix` -> `nix-research-agent`. Assert on `via="hard-miss-standard-fallback"` as well as the
      agent name where the trace is observable, so the rung taken is pinned, not just the outcome.
- [ ] Add a comment recording the fixture coupling: `nix` is itself one of the extensions currently
      lacking a `routing_agents_hard` block, so if a future task declares one for `nix`, this
      fixture's expected value must move from `nix-research-agent` (standard-fallback rung) to that
      new hard-block value (hard-hit rung). The fixture is pinned to `nix`'s current absence of a
      hard block, not to `nix` as a permanent no-hard-block example.
- [ ] Add a fourth semantic case: a never-declared task_type (e.g. `zzz-unrouted-test-type`) with
      `effort_flag=hard` must still resolve to the passed-in `default_agent` — the true-total-miss
      rung, which no existing fixture exercises.
- [ ] Leave the lean4 sub-check (standard -> `lean-research-agent`, hard ->
      `lean-research-hard-agent`) unmodified. It remains the live proof that a
      `routing_agents_hard` HIT is read from a genuinely distinct block.
- [ ] Update the suite's expected-assertion count if it is asserted anywhere (the fourth semantic
      case adds one).

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts the declared file set is exactly two files
(`command-route-agent.sh`, `test-routing-resolution.sh`) and that `manifest-routing-lib.sh` needs
no change. Confirm at implementation time: if the ladder cannot be expressed without a library
edit, stop and report rather than silently widening the batch — retroactively widening a declared
atomic batch is prohibited.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-route-agent.sh` - three-rung hard-mode ladder;
  unconditional standard lookup; `_route_block` removed, `_route_std_value`/`_route_std_via` added
  and unset; EDGE CASES and `$4` parameter comments rewritten
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` - Assert 3 semantic
  neovim/nix sub-checks inverted to the corrected contract with per-task_type expectations and via
  assertions; fixture-coupling comment for `nix`; new fourth semantic total-miss case; lean4
  sub-check untouched

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` is fully green with
  the added assertion (19/19 or the suite's own updated total).
- `git diff --stat` shows exactly the two declared files changed — no
  `manifest-routing-lib.sh`, no `command-route-skill.sh`, no `.claude/**`.
- Sourced spot check: `research`/`neovim`/hard resolves `neovim-research-agent` with
  `via=hard-miss-standard-fallback`; `research`/`lean4`/hard still resolves
  `lean-research-hard-agent`; a never-declared task_type under hard still resolves the passed
  default.
- One atomic commit covering both files; no intermediate one-file commit.

---

### Phase 3: Acceptance verification across the affected extensions [NOT STARTED]

**Goal**: Prove the acceptance criteria hold in the aggregate, not just on the three test fixtures:
`--hard` is never less specific than no flag anywhere, callers are not weakened, and the
already-correct skill resolver is provably untouched.

**Tasks**:
- [ ] Re-run `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` and
      record the full green tally.
- [ ] Build the post-fix resolution matrix with `ROUTE_MANIFEST_ROOT=agent-system` over the same
      task types measured in Phase 1, and diff it against the Phase 1 working note. Every hard-mode
      row for the 14 hard-block-less extensions must now equal its standard-mode row (with
      `via=hard-miss-standard-fallback`); no standard-mode row may have changed at all.
- [ ] Spot-check op=plan and op=implement in addition to op=research for at least three of the 14
      extensions — the defect is per-(op, task_type), and the fixtures only exercise research.
- [ ] Confirm the compound-key case: `formal:logic` under hard now resolves the declared logic
      research agent rather than `general-research-agent`.
- [ ] Confirm the caller-default rung: with `default_agent=general-research-hard-agent` and a
      never-declared task_type, hard mode still resolves `general-research-hard-agent`.
- [ ] Re-derive the call-site inventory rather than trusting the research grep:
      `grep -rn 'command-route-agent\.sh' agent-system/extensions/*/skills/*/SKILL.md` should show
      only `skill-orchestrate` and `skill-orchestrate-hard`. Confirm both still pass their intended
      defaults.
- [ ] Verify no shell-state leak: after a sourced call, no `_route_*` variable remains set in the
      calling shell (including the removed `_route_block` and the new
      `_route_std_value`/`_route_std_via`).
- [ ] Run `agent-system/extensions/core/scripts/lint-routing-wiring.sh` if present, to confirm the
      other routing validation caller is unaffected.
- [ ] Confirm `git status --short` shows no modification under `.claude/**` and that
      `command-route-skill.sh` and `manifest-routing-lib.sh` are unmodified
      (`git diff --stat` on those two paths is empty).
- [ ] Delete or fold the Phase 1 working note into the implementation summary so no stray scratch
      file is left behind in the task directory.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts 14 extensions are affected and that only two SKILL.md
files call the resolver. Both are hypotheses inherited from research: re-derive the 14-extension
inventory with `jq 'has("routing_agents")'` / `jq 'has("routing_agents_hard")'` across
`agent-system/extensions/*/manifest.json`, and re-derive the call-site list with grep. Report any
divergence from 14 rather than assuming the research count still holds.

**Files to modify**:
- None (verification only; the Phase 1 working note is removed)

**Verification**:
- Post-fix matrix diffed against the Phase 1 baseline, with every hard-mode downgrade eliminated
  and every standard-mode resolution byte-identical to before.
- Full suite green; routing wiring lint clean.
- Skill-side resolver and shared library provably unmodified.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` fully green,
      including the new total-miss assertion.
- [ ] For every sampled extension among the 14, hard-mode resolution equals or exceeds standard-mode
      specificity — never falls below it.
- [ ] `lean4` under `--hard` still resolves `lean-research-hard-agent` (hard-hit rung intact).
- [ ] A never-declared task_type under `--hard` still resolves the caller-supplied
      `general-research-hard-agent` (total-miss rung intact).
- [ ] Standard (non-hard) resolution is unchanged for every sampled task type.
- [ ] `via=hard-miss-standard-fallback` appears in the agent-side `routing_trace` output, matching
      the skill-side vocabulary.
- [ ] No `_route_*` variable leaks into the sourcing shell.
- [ ] `manifest-routing-lib.sh`, `command-route-skill.sh`, and all of `.claude/**` are unmodified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/command-route-agent.sh` (modified — three-rung ladder and
  corrected header documentation)
- `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` (modified — Assert 3
  semantic sub-checks inverted, fixture-coupling comment added, fourth total-miss case added)
- `specs/063_fix_hard_mode_agent_routing_downgrade/summaries/01_{short-slug}-summary.md`
  (implementation summary, including the before/after resolution matrix)

## Rollback/Contingency

Both modified files are tracked in git and the change is confined to two files in one atomic
commit, so `git revert` of that commit restores the prior behavior exactly. No deploy step is part
of this task — `.claude/**` is regenerated from the source store independently, so reverting the
source-store commit is sufficient and no deployed state needs unwinding.

If the ladder turns out to require a change to `manifest-routing-lib.sh` (contradicting the
research finding), stop rather than widening the declared atomic batch: report the finding, and
re-plan with the shared library and both its consumers in scope, since a library change would put
the already-correct skill resolver at risk.

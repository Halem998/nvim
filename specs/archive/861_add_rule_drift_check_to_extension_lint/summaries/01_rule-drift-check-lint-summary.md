# Implementation Summary: Rule Drift Check for Extension Lint

**Completed**: 2026-07-14
**Duration**: ~45 minutes

## Overview

Added `check_deployed_rule_drift()` to `check-extension-docs.sh` as a near-verbatim mirror of
the existing `check_deployed_script_drift()`, and wired it into the per-extension dispatch block
adjacent to `check_undeclared_rules`. The function compares each `provides.rules` entry's
deployed copy (`.claude/rules/<name>`) against its extension-source copy (`<ext>/rules/<name>`),
failing on content mismatch when both exist, and emitting an info/skip note (never a fail) when
the deployed copy is absent.

## What Changed

- `.claude/scripts/check-extension-docs.sh` — added `check_deployed_rule_drift()` immediately
  after `check_deployed_script_drift()`, added one dispatch call in the per-extension block next
  to `check_undeclared_rules`, and added a header-comment bullet describing the new check.
- `.claude/extensions/core/scripts/check-extension-docs.sh` — identical content (dual write,
  confirmed byte-identical via `diff -q` after every editing step).

## Decisions

- Followed the plan's "no parameterized helper" decision: the new function is a standalone
  near-duplicate of `check_deployed_script_drift`, not a shared `check_deployed_content_drift`
  helper, per the plan's Recorded Decision section.

## Plan Deviations

- **Phase 3 negative-path revert**: the plan specified `git checkout -- .claude/rules/nix.md` to
  revert the deliberate test mutation. This was blocked by the `guard-destructive-git.sh`
  PreToolUse hook (which treats `git checkout --` as a destructive command that discards
  uncommitted changes). Used `bash .claude/scripts/git-snapshot.sh` (the hook's own suggested
  remediation) followed by a precise `Edit`-tool removal of the single appended test line,
  confirmed clean via `git diff` (empty output, matches HEAD exactly). Full detail in
  `specs/861_add_rule_drift_check_to_extension_lint/progress/phase-3-progress.json`
  `deviations` array.
  - **Notable side effect, resolved**: `git-snapshot.sh`'s `git stash` is repo-wide, not scoped
    to a single path. In this shared multi-agent session it briefly stashed concurrent
    uncommitted work-in-progress from another active agent on `.claude/scripts/manage-topics.sh`
    (unrelated to this task), which surfaced as a transient, unrelated `deployed script content
    drift` FAIL on the post-revert verification re-run. `git stash pop` immediately restored the
    other agent's work and the transient failure disappeared on the next re-run; confirmed the
    two `manage-topics.sh` copies were byte-identical again before proceeding. No production
    code, check logic, or other agent's work was altered or lost.

## Verification

- Build: N/A (bash script, no build step)
- Tests: `bash -n` passes on both copies; full script run passes — see below
- Files verified: Yes

### Baseline (Phase 1, measured before any edit)

- `diff -q` of the two pre-existing copies: no output (identical).
- `bash .claude/scripts/check-extension-docs.sh` — exit code `0`, `PASS: all extensions OK`,
  output captured to `/tmp/lint-baseline.txt`.

### Post-change verification (Phase 3)

- **Assertion (a) — exit code parity**: post-change run exits `0`, matching baseline.
- **Assertion (b) — new check reports as expected**: `core`, `nix`, `nvim` (deployed rules
  present and matching) show no drift line and no info note (silent pass, matching
  `check_deployed_script_drift`'s convention). `cslib`, `latex`, `lean`, `web` (rules not
  deployed in this repo) each emit `rule not deployed, skipping drift check: <name>` info notes.
  Zero `deployed rule content drift` fail lines anywhere.
- **Assertion (c) — no self-drift**: no `deployed script content drift ... scripts/check-extension-docs.sh`
  line in the output; `diff -q` of the two script copies confirms no output (identical).
- **Baseline diff**: `diff /tmp/lint-baseline.txt /tmp/lint-after.txt` shows only the 6 new
  info-note lines (2 for `cslib`, 1 for `latex`, 2 for `lean`, 1 for `web`) — no extension's
  PASS/FAIL status changed and no previously-passing check regressed.
- **Negative-path check**: appended a byte to `.claude/rules/nix.md` (a deployed rule with a
  matching extension source), re-ran the script — got `FAIL: deployed rule content drift
  (deployed != extension source): rules/nix.md` and exit code `1`, proving the check genuinely
  detects drift rather than being a silent no-op. Reverted the mutation (see Plan Deviations
  above) and re-ran — exit code `0` again, output identical to the Phase 3 after-state
  (`diff /tmp/lint-after.txt /tmp/lint-restored2.txt` empty).
- **Working tree scope**: this task's file scope (`.claude/scripts/check-extension-docs.sh`,
  `.claude/extensions/core/scripts/check-extension-docs.sh`, and the transiently-mutated
  `.claude/rules/nix.md`) is fully clean and matches HEAD. Other files shown modified in
  `git status --short` belong to concurrent work by other active agents in this shared session
  and are outside this task's scope.
- No task-number references were introduced by this change (pre-existing references to prior
  unrelated tasks in the file predate this edit and were not touched).

## Notes

Research established zero live rule drift across all 8 currently-deployed `provides.rules`
entries; the new check landed cleanly with no FAILs, confirming that expectation. The negative-path
test is the strongest evidence the check works: it is not simply "clean because nothing to find"
but demonstrably catches injected drift and clears once resolved.

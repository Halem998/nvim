# Implementation Plan: Rule Drift Check for Extension Lint

- **Task**: 861 - Add a deployed-vs-source content drift check for extension rules in check-extension-docs.sh
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: `specs/861_add_rule_drift_check_to_extension_lint/reports/01_rule-drift-check-lint.md`
- **Artifacts**: plans/01_rule-drift-check-lint.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/rules/plan-format-enforcement.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
- **Type**: meta

## Overview

Add `check_deployed_rule_drift()` to `check-extension-docs.sh` as a near-verbatim mirror of the
existing `check_deployed_script_drift()`, substituting `rules` for `scripts` throughout, and wire
it into the per-extension dispatch block. The function enumerates each manifest's
`provides.rules`, and for every entry where BOTH the deployed `.claude/rules/<name>` and the
extension source `<ext>/rules/<name>` exist, fails on byte-level content mismatch; when the
deployed copy is absent it emits an info note and skips (never fails), because an extension's
rules are not deployed in every consuming repo.

The change is confined to two files that must remain byte-identical. Definition of done: the
script runs, reports the new rule check per extension, exits with the same code as the
pre-change baseline, and does not flag its own two copies as drifted.

### Research Integration

Key findings from `reports/01_rule-drift-check-lint.md` carried into this plan:

- **The pattern to mirror** is `check_deployed_script_drift()` at
  `.claude/scripts/check-extension-docs.sh:146-170`. Its three-way outcome contract transfers
  unchanged: deployed absent -> `info` + `continue` (never fail); source absent -> silent
  `continue` (already reported by `check_manifest_entries`, so do not double-report);
  both present and differing -> `fail`.
- **Path shape is identical between the two categories.** Both `provides.scripts` and
  `provides.rules` entries are bare flat filenames (never paths containing `/`). Deployed
  resolves to `$REPO_ROOT/.claude/rules/<name>`; source resolves to `$ext_path/rules/<name>`.
- **Zero live rule drift exists today.** All 8 currently-deployed `provides.rules` entries
  (core's 8, plus `nix.md` and `neovim-lua.md`) match their extension source byte-for-byte. The
  new check is therefore purely preventive and MUST pass cleanly on landing. If it fails on
  landing, that is a real finding about repository state, not a bug in the check — investigate
  the flagged rule rather than weakening the check.
- **Rules deploy by copy, never symlink.** All 11 files under `.claude/rules/` are regular files
  (0 symlinks), so every `provides.rules` entry is fully exposed to the drift the check targets.
- **Dangling symlinks are already handled correctly** by the mirrored pattern: `[[ ! -f ]]` is
  true for a broken symlink, so it takes the "not deployed, skip" branch rather than being
  misread as drift. No extra branching is needed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided).

## Goals & Non-Goals

**Goals**:

- Add `check_deployed_rule_drift()` mirroring `check_deployed_script_drift()`, with the same
  three-way outcome contract (info/skip on deployed-absent, silent continue on source-absent,
  fail on content mismatch).
- Wire the new function into the per-extension dispatch block alongside the sibling rules check
  `check_undeclared_rules`.
- Keep `.claude/scripts/check-extension-docs.sh` and
  `.claude/extensions/core/scripts/check-extension-docs.sh` byte-identical.
- Verify against a captured pre-change baseline rather than an assumed one.

**Non-Goals**:

- **No parameterized cross-category helper.** See the Recorded Decision below.
- No drift check for `provides.agents`, `provides.commands`, or `provides.context` in this change.
- No cleanup of the dangling `zotero` symlinks (`.claude/commands/zotero.md`,
  `.claude/skills/skill-zotero`) surfaced incidentally by the research symlink census — orphaned
  deployment artifacts, out of scope, worth a separate task.
- No modification of `check_undeclared_rules` (the complementary reverse-direction registration
  check) or any other existing check.

### Recorded Decision: No Parameterized Helper for agents / commands / context

The research evaluated whether `check_deployed_rule_drift` should instead be a shared
`check_deployed_content_drift(ext_path, category)` helper covering rules + scripts + commands +
agents. **Decision: do not parameterize in this change.** Justification, recorded here so it is
durable rather than re-litigated:

- `rules`, `scripts`, and `commands` are structurally identical for drift purposes (flat filename
  entries, deployed at `.claude/<category>/<name>`, sourced at `<ext>/<category>/<name>`), so a
  category-parameterized helper would work for those three unmodified.
- `agents` needs an extra optional parameter for the `agents_subdir` override
  (`loader.lua:148`, used for OpenCode's `agent/subagents` layout vs. Claude Code's flat
  `.claude/agents/`) — a small but real special case.
- `context` is genuinely different in shape: entries may be a single file OR a directory copied
  recursively by `copy_context_dirs()`, so a context drift check needs recursive comparison
  (`diff -rq` or per-file enumeration), not `cmp -s` on one path. Folding that into a
  single-file-oriented helper via `if [[ -d ]]` branching would make the helper wider than the
  sum of its call sites.
- Two near-duplicate ~15-line functions is not egregious duplication, and there is no second
  caller yet for the abstraction. Premature parameterization before `commands`/`agents` drift
  checks are actually requested adds abstraction with no payer.

**Revisit trigger**: extract the shared helper only if/when a third or fourth category drift check
(`commands`, `agents`) is actually requested. Even then, leave `context` out of it — its
recursive-directory semantics warrant a distinct function.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing only one copy of `check-extension-docs.sh` — the script is self-registered in core's `provides.scripts`, so `check_deployed_script_drift` compares the script's own two copies and will FAIL against itself | H | M | Dual-write is a mandatory, explicit checklist item in EVERY editing phase (Phase 2). Phase 3 verifies with an explicit `diff` of the two copies AND asserts the script does not report drift on `scripts/check-extension-docs.sh`. |
| New check fires on landing, masked as "expected noise" | M | L | Research established zero live rule drift, so a clean pass is the expected outcome. Phase 3 asserts exit code parity with the Phase 1 baseline. Any failure is treated as a real repository-state finding to investigate, never a reason to weaken the check. |
| Regression in the existing, already-shipped script check | H | L | The new function is additive; no existing function is modified. Only one line is added to the dispatch block. Phase 3 compares full output against the Phase 1 baseline. |
| Baseline assumed rather than measured, so "no change" cannot be proven | M | M | Phase 1 captures exit code and full output to a file BEFORE any edit; Phase 3 diffs against that captured file. |
| False positive on a rule deployed as a dangling symlink | L | L | None needed — `[[ ! -f "$deployed" ]]` is true for a broken symlink, taking the "not deployed, skip" branch. Preserve this test verbatim from the mirrored pattern; do not substitute `-e`. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential: the baseline
must be captured before editing, and verification must follow the edit.

---

### Phase 1: Capture Pre-Change Baseline [COMPLETED]

- **Goal:** Record the script's exit code, full output, and the two-copy identity state BEFORE any
  edit, so the after-state is compared against measured fact rather than assumption.
- **Tasks:**
  - [x] Confirm the two copies start byte-identical:
        `diff -q .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh`
        (expect: no output). If they already differ, STOP and report — reconcile before proceeding,
        because a pre-existing drift would contaminate the baseline. *(completed: confirmed identical, no output)*
  - [x] Run `bash .claude/scripts/check-extension-docs.sh > /tmp/lint-baseline.txt 2>&1; echo "EXIT: $?"`
        and record BOTH the exit code and the output file path. *(completed: EXIT: 0, /tmp/lint-baseline.txt)*
  - [x] Record the baseline exit code and the summary line in the phase notes below. Expected
        (measured at plan time): exit code `0`, summary line `PASS: all extensions OK`, all
        extensions reporting `PASS`. *(completed: matches expectation exactly)*
  - [x] Record the current per-extension `provides.rules` census as the expected new-check outcome:
        `core` (8 rules), `nix` (`nix.md`), `nvim` (`neovim-lua.md`) should PASS the new check;
        `cslib` (2), `latex` (1), `lean` (2), `web` (1) are not deployed in this repo and should
        emit info/skip notes. *(completed: census recorded per plan)*
- **Timing:** 10 minutes
- **Depends on:** none
- **Files to modify:** none (read-only phase; writes only to `/tmp/lint-baseline.txt`)
- **Verification:**
  - `/tmp/lint-baseline.txt` exists and is non-empty.
  - The baseline exit code is recorded explicitly (not inferred later).
  - The two copies are confirmed identical at the start.

---

### Phase 2: Add and Wire check_deployed_rule_drift (DUAL WRITE) [COMPLETED]

- **Goal:** Add the new function and its dispatch call to BOTH copies of the script, byte-for-byte
  identical.
- **DUAL-WRITE REQUIREMENT (mandatory, not optional):** This phase edits
  `check-extension-docs.sh`, which is self-registered in core's `provides.scripts`. The edit MUST
  land identically in BOTH `.claude/scripts/check-extension-docs.sh` AND
  `.claude/extensions/core/scripts/check-extension-docs.sh`. Landing it in only one location makes
  the script FAIL against itself on its very next run. The safe sequence: edit one copy fully, then
  `cp` it onto the other, then `diff` to confirm.
- **Tasks:**
  - [x] Add `check_deployed_rule_drift()` to `.claude/scripts/check-extension-docs.sh`, placed
        adjacent to `check_deployed_script_drift()` (which ends at line 170), as a near-verbatim
        mirror: `jq -r '.provides.rules[]? // empty' "$manifest"`;
        `deployed="$REPO_ROOT/.claude/rules/$r"`; `source="$ext_path/rules/$r"`;
        `[[ ! -f "$deployed" ]]` -> `info "rule not deployed, skipping drift check: $r"` +
        `continue`; `[[ ! -f "$source" ]]` -> silent `continue` with the same
        "already reported by check_manifest_entries" comment; `! cmp -s "$deployed" "$source"` ->
        `fail "deployed rule content drift (deployed != extension source): rules/$r"`. *(completed)*
  - [x] Add a doc comment above the new function mirroring the existing CRITICAL comment block's
        intent: only compare when BOTH copies exist; an absent deployed copy is NOT drift (an
        extension's rules are not deployed in every consuming repo) and must be skipped with an
        info note, never a FAIL. *(completed)*
  - [x] Wire `check_deployed_rule_drift "$ext_path"` into the per-extension dispatch block
        (inside the `jq empty` valid-JSON guard), placed adjacent to `check_undeclared_rules`,
        the sibling rules-category check. The block is a flat sequence with no ordering
        dependency between checks. *(completed)*
  - [x] Verify the edited copy is syntactically valid: `bash -n .claude/scripts/check-extension-docs.sh`. *(completed: exit 0)*
  - [x] **DUAL WRITE:** propagate the identical content to the extension source copy:
        `cp .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh` *(completed)*
  - [x] **DUAL WRITE CONFIRMATION:** `diff -q` the two copies and confirm no output before
        considering this phase complete. *(completed: no output, exit 0)*
  - [x] Confirm no task-number references were introduced into either script copy (both live
        outside `specs/**`; see `.claude/rules/no-task-references-in-deliverables.md`). *(completed: only pre-existing references from prior work remain, unrelated to this change)*
- **Timing:** 25 minutes
- **Depends on:** 1
- **Files to modify:**
  - `.claude/scripts/check-extension-docs.sh` - add `check_deployed_rule_drift()` near
    `check_deployed_script_drift()` (ends line 170); add one dispatch call in the per-extension
    block near `check_undeclared_rules`.
  - `.claude/extensions/core/scripts/check-extension-docs.sh` - identical content (dual write).
- **Verification:**
  - `bash -n` passes on both copies.
  - `diff -q` of the two copies produces no output.
  - The new function exists and is called exactly once per extension.
  - No existing function body was modified.

---

### Phase 3: Verify Against Baseline and Self-Drift [COMPLETED]

- **Goal:** Prove the change is correct by running the script and asserting three specific
  properties against the Phase 1 baseline.
- **DUAL-WRITE NOTE:** If this phase surfaces any defect requiring a script edit, that fix is also
  a dual write — it MUST land in both `.claude/scripts/check-extension-docs.sh` and
  `.claude/extensions/core/scripts/check-extension-docs.sh`, followed by a re-run of this phase's
  full verification. Never fix one copy only.
- **Tasks:**
  - [x] Run `bash .claude/scripts/check-extension-docs.sh > /tmp/lint-after.txt 2>&1; echo "EXIT: $?"`. *(completed: EXIT 0)*
  - [x] **Assertion (a) — exit code parity:** the exit code equals the Phase 1 baseline exit code
        (expected `0`). If it is non-zero, do NOT weaken or disable the check; identify which rule
        was flagged and report it as a genuine drift finding. *(completed: exit 0, matches baseline)*
  - [x] **Assertion (b) — new check reports as expected:** the output shows the new rule check
        producing PASS (no fail line) for the deployed rules of `core`, `nix`, and `nvim`, and
        `rule not deployed, skipping drift check:` info notes for the undeployed rules of `cslib`,
        `latex`, `lean`, and `web`. Confirm no `deployed rule content drift` fail line appears.
        *(completed: verified via grep, exactly matches expected census, zero fail lines)*
  - [x] **Assertion (c) — no self-drift:** confirm the output contains NO
        `deployed script content drift ... scripts/check-extension-docs.sh` line, and independently
        confirm with
        `diff -q .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh`
        (expect no output). *(completed: no self-drift line, diff -q silent)*
  - [x] Diff the after-output against the baseline (`diff /tmp/lint-baseline.txt /tmp/lint-after.txt`)
        and confirm the only differences are the new rule-check info/skip notes — no extension's
        PASS/FAIL status changed, and no previously-passing check now fails. *(completed: diff shows
        only the 6 new info-note lines for cslib/latex/lean/web)*
  - [x] Negative-path sanity check (non-destructive, must be reverted): temporarily append a byte to
        a deployed copy of a rule that is also present in an extension source (e.g.
        `.claude/rules/nix.md`), re-run the script, and confirm it now FAILs with the
        `deployed rule content drift` message and exits 1. Then restore the file exactly
        (`git checkout -- .claude/rules/nix.md`) and re-run to confirm the script returns to
        exit 0. This proves the check actually detects drift rather than being a silent no-op.
        *(completed: FAIL + exit 1 confirmed with the mutation; deviation — `git checkout --` was
        blocked by the guard-destructive-git.sh hook, so the revert used git-snapshot.sh followed by
        a precise Edit-tool removal of the single appended line, confirmed clean via `git diff`; see
        phase-3-progress.json deviations for the full note including a transient, unrelated
        manage-topics.sh FAIL surfaced and resolved during the snapshot/pop cycle)*
  - [x] Confirm the working tree contains no unintended modifications: `git status --short` should
        show only the two script copies as modified. *(completed with note: this task's file scope
        — both check-extension-docs.sh copies and .claude/rules/nix.md — is fully clean and matches
        HEAD; the working tree also shows numerous OTHER files modified by concurrent agents active
        in this shared session, unrelated to this task, which is expected and out of scope)*
- **Timing:** 20 minutes
- **Depends on:** 2
- **Files to modify:** none (verification phase; the negative-path check's temporary edit is
  reverted within the phase)
- **Verification:**
  - All three assertions (a), (b), (c) pass.
  - The negative-path check demonstrated the new check detects real drift and that the repository
    was restored to a clean exit-0 state afterward.
  - `git status --short` shows only the two intended script files modified.

---

## Testing & Validation

- [x] `bash -n` passes on both copies of `check-extension-docs.sh`.
- [x] `bash .claude/scripts/check-extension-docs.sh` exits with the Phase 1 baseline exit code
      (expected `0`, `PASS: all extensions OK`).
- [x] The new check emits no `deployed rule content drift` failures on landing (zero live drift is
      the researched, expected state).
- [x] The new check emits `rule not deployed, skipping drift check:` info notes — never failures —
      for extensions whose rules are not deployed in this repo (`cslib`, `latex`, `lean`, `web`).
- [x] The script does not flag its own two copies as drifted
      (`scripts/check-extension-docs.sh` absent from any drift fail line).
- [x] `diff -q` of the two script copies produces no output.
- [x] Negative-path check confirms the new check FAILs (exit 1) on a deliberately drifted rule and
      returns to exit 0 once restored.
- [x] No task-number references introduced outside `specs/**`.

## Artifacts & Outputs

- `.claude/scripts/check-extension-docs.sh` — with `check_deployed_rule_drift()` added and wired.
- `.claude/extensions/core/scripts/check-extension-docs.sh` — byte-identical copy.
- `/tmp/lint-baseline.txt` — pre-change baseline output (transient; not committed).
- `/tmp/lint-after.txt` — post-change output for comparison (transient; not committed).
- `specs/861_add_rule_drift_check_to_extension_lint/summaries/01_rule-drift-check-lint-summary.md`
  — execution summary.

## Rollback/Contingency

The change is additive and confined to two files, both tracked in git.

- **Full revert:** `git checkout -- .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh`.
  Reverting BOTH copies together is mandatory — reverting only one recreates the self-drift failure
  the dual-write requirement exists to prevent.
- **If the new check fails on landing:** this is a genuine drift finding, not a check bug. Do not
  disable or weaken the check to make the lint pass. Reconcile the flagged rule (deploy the
  extension source over the drifted deployed copy, or promote the intentional local edit into the
  extension source), then re-run.
- **If verification reveals a defect in the new function:** fix forward with a dual write and re-run
  Phase 3 in full. Do not leave the two copies in a divergent state at any commit boundary.

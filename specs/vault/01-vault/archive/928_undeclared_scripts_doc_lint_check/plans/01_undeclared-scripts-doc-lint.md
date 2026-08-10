# Implementation Plan: Task #928

- **Task**: 928 - Add a disk-driven check_undeclared_scripts check to the extension doc-lint
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 885, 926
- **Research Inputs**: specs/928_undeclared_scripts_doc_lint_check/reports/01_undeclared-scripts-check.md
- **Artifacts**: plans/01_undeclared-scripts-doc-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/core/scripts/check-extension-docs.sh` has no disk-driven
undeclared-scripts check: a file present in an extension's `scripts/` tree but absent from that
extension's `provides.scripts[]` never deploys, and no existing rule reports it. This plan adds
`check_undeclared_scripts` (Rule Q), mirroring `check_undeclared_skills` (Rule A) and
`check_undeclared_rules` (Rule H) but recursing and matching by full relative path, then resolves
the three genuine latent defects the new check exposes so the doc-lint gate returns to green in
the same change. Definition of done: the source-store doc-lint run exits 0 with Rule Q active, and
the three previously-undeployable lifecycle-hook scripts are declared in their manifests.

**SOURCE-STORE RULE (binding)**: every edit targets `agent-system/extensions/**`. The `.claude/`
tree is a gitignored, disposable deploy artifact and MUST NOT be edited.

### Research Integration

The research report supplied the verified function body, the registration site, and four findings
this plan depends on:

1. **Rule letter Q is next.** The index comment block enumerates A through P in first-introduced
   order.
2. **Trailing-slash gotcha (non-obvious, verified by live simulation).** The per-extension loop is
   `for ext_path in "$EXT_DIR"/*/`, so `ext_path` carries a **trailing slash**. A string prefix
   strip (`${script_file#"$ext_path"/scripts/}`) then builds a double-slash prefix that never
   matches what `find` returns, and the check degrades to reporting every script in every
   extension as undeclared. Rules A/H never hit this because they use globs, where a doubled
   slash is harmless. Normalize first: `ext_path_norm="${ext_path%/}"`.
3. **The DECISION REQUIRED question is resolved empirically, not assumed.** No loader path
   deploys a lifecycle-hook script named in a manifest's top-level `hooks` object:
   `copy_manifest()` deploys only `manifest.json` into `.claude/extensions/<name>/`, and
   `copy_scripts()` deploys `provides.scripts` entries flatly into `.claude/scripts/`. The three
   baseline findings are therefore TRUE POSITIVES, fixed by declaring the files — never by adding
   a blanket hooks-object exclusion.
4. **A residual runtime gap survives this change and must be disclosed, not glossed.** Even once
   declared, the lifecycle hooks still will not fire, for two independent reasons in
   `skill-base.sh`: `skill_run_extension_hook` resolves `hook_path` under
   `.claude/extensions/<name>/`, which no deploy path ever populates with a `scripts/` subtree;
   and `skill_get_extension_dir` queries `.claude-extensions.json` for a `.loaded_extensions[]`
   key the live file does not have. Both are out of this task's declared `file_scope` and are
   handled by Phase 3's disclosure obligation, not by silent scope creep.

Baseline independently re-confirmed while writing this plan (2026-07-27): the simulated matching
logic reports exactly `nix/nix-context.sh`, `nix/nix-preflight.sh`, `nvim/nvim-context.sh`, and
the source-store doc-lint currently exits 0 with all 20 extensions PASS.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` was not set, so no
roadmap phases are included and no roadmap alignment is asserted. `specs/ROADMAP.md` exists but
was deliberately not consulted or modified.

## Goals & Non-Goals

**Goals**:
- Add `check_undeclared_scripts` (Rule Q) to `check-extension-docs.sh`, using the `fail` helper,
  registered in the per-extension check loop adjacent to Rules A and H.
- Recurse over `scripts/`, matching by FULL RELATIVE PATH, covering ALL regular files regardless
  of extension (`.sh`, `.py`, `.sql`, dotfiles), exempting `deprecated/` and NOT exempting
  `tests/`.
- Resolve the three baseline findings by declaring the files in `nix` and `nvim`
  `provides.scripts`, so the doc-lint gate ends green.
- Disclose, in the implementation summary, the residual `skill-base.sh` hook-runtime gap that
  this change does not fix.

**Non-Goals**:
- Fixing `skill_run_extension_hook`'s deploy-path resolution or `skill_get_extension_dir`'s
  `.claude-extensions.json` schema query. Both are in `skill-base.sh`, outside the declared
  `file_scope`, and the choice between "hook reads from flat `.claude/scripts/`" and "a new deploy
  step populates `.claude/extensions/<name>/scripts/`" is a design decision this task does not own.
- Adding any hooks-object exclusion to silence Rule Q. A check tuned until it reports zero is
  worth nothing.
- Making Rule Q assert that a `hooks`-object-referenced path also appears in `provides.scripts`.
  No such structural coupling exists today; introducing one is a separate decision.
- Repairing the pre-existing task-number citation in the Rule E function comment. It predates this
  change and is outside what this task's ask implies; the newly authored Rule Q comment must
  itself carry no task-number citation.
- Any edit under `.claude/`, and any regeneration/deploy step.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Trailing-slash prefix-strip bug silently produces universal false positives | H | M | Phase 1 verification asserts the finding COUNT is exactly 3 and names all 3, not merely "findings appeared". A wrong-normalization implementation reports dozens and fails this gate immediately. |
| Implementer stops at "doc-lint green" and reports the lifecycle hooks as fixed | M | M | Phase 3 makes the residual-gap disclosure an explicit deliverable with its own checklist item; the summary must state what was and was not fixed. |
| Adding entries to `provides.scripts` trips another doc-lint rule | M | L | Verified: Rule F (`check_deployed_script_drift`) emits `info` not `fail` when the deployed copy is absent; Rule M enumerates only deployed files; Rule O is guarded by `routing_exempt: true` and neither extension has it. Phase 2's full-run verification is the backstop. |
| A hooks-object exclusion is added to make the check pass | H | L | Named as an explicit Non-Goal and re-stated in Phase 2's tasks; the fix direction is fixed by the research's empirical loader trace. |
| An edit lands under `.claude/` instead of the source store | H | L | Phase-level task text names absolute source-store paths only; Phase 3 verifies `git status` shows no `.claude/` modifications. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add Rule Q (check_undeclared_scripts) [COMPLETED]

**Goal**: `check-extension-docs.sh` gains a working recursive disk-to-manifest scripts check that
reports exactly the three known-undeclared files and nothing else.

**Tasks**:
- [x] Add the `check_undeclared_scripts()` function to
      `agent-system/extensions/core/scripts/check-extension-docs.sh`, placed immediately after
      `check_undeclared_rules()` so the source order matches the registration order. *(completed)*
- [x] Normalize the trailing slash before the prefix strip: `local ext_path_norm="${ext_path%/}"`,
      then `rel_path="${script_file#"$ext_path_norm"/scripts/}"`. This is the single most
      failure-prone line in the phase. *(completed)*
- [x] Enumerate with `find "$ext_path/scripts" -type f | sort` fed through a `while IFS= read -r`
      loop -- not a `*.sh` glob, and not a bare glob (which misses dotfiles and nested paths).
      *(completed)*
- [x] Early-return when `scripts/` does not exist: `[[ -d "$ext_path/scripts" ]] || return 0`.
      *(completed)*
- [x] Skip `deprecated/*` by relative-path prefix (`case "$rel_path" in deprecated/*) continue ;; esac`).
      Do NOT skip `tests/`. *(completed)*
- [x] Membership-test with `jq -e --arg s "$rel_path" '.provides.scripts[]? | select(. == $s)'`
      against the extension's manifest, matching Rules A/H. *(completed)*
- [x] Report misses via `fail` (not `advisory`, not `orphan_report`), with the message form
      `script file on disk NOT in provides.scripts: scripts/$rel_path`. *(completed)*
- [x] Write the function comment explaining: why full-relative-path matching (entries legitimately
      carry a path prefix), why all file types (`provides.scripts` already holds `.py`/`.sql`/a
      dotfile), why `deprecated/` is exempt, and how this differs from Rule E (reference-driven,
      `.sh`/`.sql`-only) and Rule M (deployed-file-driven, structurally blind to never-deployed
      files). Cite durable anchors -- rule letters, function names, file names. **No task-number
      citations** (`.claude/rules/no-task-references-in-deliverables.md`). *(completed)*
- [x] Add the index line `#   Q - check_undeclared_scripts            : script file on disk not in
      provides.scripts` to the rule-letter index comment block, after the existing `P` entry.
      *(completed)*
- [x] Register `check_undeclared_scripts "$ext_path"` in the per-extension loop's check list,
      immediately after `check_undeclared_rules "$ext_path"`. *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Rule Q is asserted to produce **exactly 3** findings across all 20
extensions -- `nix: scripts/nix-context.sh`, `nix: scripts/nix-preflight.sh`,
`nvim: scripts/nvim-context.sh` -- and zero findings for every other extension, `literature`
(nested `tests/`, a `deprecated/` subtree, `.py`/`.sql`/dotfile entries) included. Confirm at
implementation time by running the command below and counting the `NOT in provides.scripts`
lines: the count MUST be 3 and the three paths MUST match. A larger count (especially one
proportional to the whole tree) indicates the trailing-slash normalization was missed; a count
of 0 indicates the check is not running or not registered. Do not proceed to Phase 2 on any other
result.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - add Rule Q function, index
  entry, and loop registration

**Verification**:
```bash
cd /home/benjamin/.config/nvim
bash -n agent-system/extensions/core/scripts/check-extension-docs.sh
REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh 2>&1 \
  | grep "NOT in provides.scripts"
```
- `bash -n` parses clean.
- The grep emits exactly 3 lines, naming `scripts/nix-context.sh`, `scripts/nix-preflight.sh`,
  and `scripts/nvim-context.sh`.
- The full run now exits non-zero with `nix` and `nvim` marked FAIL and all 18 other extensions
  still PASS (this is the expected, temporary red state that Phase 2 closes).

---

### Phase 2: Resolve the three baseline findings [COMPLETED]

**Goal**: The three lifecycle-hook scripts are declared in their extensions' `provides.scripts`,
and the source-store doc-lint returns to a clean exit 0.

**Tasks**:
- [x] Set `provides.scripts` to `["nix-preflight.sh", "nix-context.sh"]` in
      `agent-system/extensions/nix/manifest.json` (currently `[]`). *(completed)*
- [x] Set `provides.scripts` to `["nvim-context.sh"]` in
      `agent-system/extensions/nvim/manifest.json` (currently `[]`). *(completed)*
- [x] Leave each manifest's top-level `hooks` object exactly as-is -- it is a separate mechanism
      from `provides.scripts` and this change does not couple them. *(completed)*
- [x] Confirm both files remain valid JSON and that formatting matches the surrounding manifest
      style (indentation, key order within `provides`). *(completed)*
- [x] Do NOT add any hooks-object exclusion to Rule Q. *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: Exactly **2 manifest files** and **3 declared entries** are asserted to be
required, and no other extension is asserted to need a manifest change. Confirm by re-running the
Phase 1 grep after the edits and observing zero remaining `NOT in provides.scripts` lines: any
residual line identifies a file this hypothesis missed, and any newly-red extension identifies a
downstream rule this hypothesis did not account for.

**Files to modify**:
- `agent-system/extensions/nix/manifest.json` - populate `provides.scripts`
- `agent-system/extensions/nvim/manifest.json` - populate `provides.scripts`

**Verification** (the `interface` tier's enumerated one-hop dependents are the doc-lint rules that
read `provides.scripts` -- Rule E, Rule F, Rule M, Rule O, `check_manifest_entries` -- all of which
this single command exercises together):
```bash
cd /home/benjamin/.config/nvim
jq empty agent-system/extensions/nix/manifest.json
jq empty agent-system/extensions/nvim/manifest.json
REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh; echo "EXIT=$?"
```
- Both `jq empty` calls succeed.
- `EXIT=0`, `PASS: all extensions OK`, and `nix`/`nvim` both back to PASS.
- No new FAIL appears for any other extension.
- Rule F is expected to emit an `info` line noting these scripts are not deployed. That is
  informational, not a failure, and must not be "fixed" by deploying anything.

---

### Phase 3: Full-tree verification, source-store audit, and residual-gap disclosure [COMPLETED]

**Goal**: The change is confirmed complete and correctly scoped, and the residual lifecycle-hook
runtime gap is recorded rather than left to look fixed.

**Tasks**:
- [x] Re-run the full source-store doc-lint and confirm exit 0 with all extensions PASS.
      *(deviation: altered — exit is 1, not 0: `core` FAILs with 2 Rule F "deployed script
      content drift" hits, `scripts/check-extension-docs.sh` and `scripts/roadmap-integration.sh`.
      Both are edited-source-but-unregenerated-deploy-tree conditions outside this task's Non-Goals
      boundary ("Any edit under `.claude/`, and any regeneration/deploy step"), not Rule Q defects
      -- see the residual-gap disclosure below and in the summary. `nix` and `nvim` are both PASS,
      and Rule Q's own 3 baseline findings are fully resolved, which is what this phase owns.)*
- [x] Confirm Rule Q actually fires by injecting a temporary probe: create an empty scratch file
      under one extension's `scripts/`, confirm the run reports it and exits non-zero, then remove
      the scratch file and confirm the run returns to exit 0. A check that passes only because it
      never runs is the exact failure class this task exists to prevent.
      *(deviation: altered — probe cycle confirmed liveness via a FAILURE-COUNT delta instead of a
      0-exit return, because the baseline itself is non-zero (see prior item): injecting
      `agent-system/extensions/nix/scripts/.scratch-probe-928.sh` moved the total from 2 to 3
      FAIL(s) with a new `NOT in provides.scripts` line naming the probe file; removing it returned
      the count to exactly 2, matching the pre-probe baseline byte-for-byte. This proves Rule Q
      runs and detects an injected file, which is the property this check exists to verify.)*
- [x] Confirm `deprecated/` is still exempt and `tests/` is still in scope, by checking that
      `literature` remains PASS while its `scripts/tests/*` entries are declared and its
      `scripts/deprecated/*` entries are not. *(completed: literature stays PASS;
      `scripts/deprecated/{README.md,zotero-index-add.sh,zotero-index-remove.sh}` are on disk and
      undeclared yet unflagged, and `scripts/tests/{generate-test-fixtures.py,
      test-literature-convert.sh}` are declared and in scope.)*
- [x] Verify `git status --short` shows changes ONLY under `agent-system/extensions/` and
      `specs/928_undeclared_scripts_doc_lint_check/` -- no `.claude/` paths. *(completed: no
      `.claude/` path appears in `git status --short`; `.claude/` is gitignored by `.gitignore:6`
      and was never staged.)*
- [x] Grep the three modified files for task-number citation patterns (`task [0-9]`,
      `tasks [0-9]`) introduced by this change; the newly authored Rule Q comment must have none.
      *(completed: the grep on `check-extension-docs.sh` surfaces only pre-existing Rule E/G
      citations at lines 190, 725, 793, 806, 826 -- all predating this change; the Rule Q function
      body has zero matches. Both manifest.json files have zero matches.)*
- [x] Record in the implementation summary, explicitly: Rule Q is added and the three manifest
      declarations resolve the doc-lint findings, BUT the `nix`/`nvim` lifecycle hooks still do
      not fire at runtime, for the two `skill-base.sh` reasons in the research report
      (`hook_path` resolves under `.claude/extensions/<name>/`, which no deploy path populates
      with a `scripts/` subtree; `skill_get_extension_dir` queries a `.loaded_extensions[]` key
      absent from the live `.claude-extensions.json` schema). State that this is deliberately out
      of scope and warrants a follow-up task against `skill-base.sh`. *(completed; see summary.)*

**Timing**: 25 minutes

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- None (verification and summary-authoring phase)

**Verification**:
```bash
cd /home/benjamin/.config/nvim
REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet; echo "EXIT=$?"
git status --short
grep -nE '\btasks? [0-9]+' agent-system/extensions/core/scripts/check-extension-docs.sh
```
- `EXIT=0` with all extensions PASS.
- `git status --short` lists no `.claude/` path.
- The grep surfaces only the pre-existing Rule E citation (explicitly out of scope), never a line
  authored by this change.
- The probe injection/removal cycle demonstrated a non-zero then zero exit.
- The summary contains the residual-gap disclosure.

---

## Testing & Validation

- [ ] `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh` parses clean.
- [ ] Rule Q reports exactly the 3 expected findings before the manifest fix (count asserted, not
      just presence).
- [ ] Rule Q reports 0 findings after the manifest fix.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0
      with all 20 extensions PASS.
- [ ] Temporary-probe cycle proves Rule Q is live (non-zero with probe, zero after removal).
- [ ] `literature` stays PASS, proving `deprecated/` exemption and `tests/` inclusion both hold.
- [ ] Both edited manifests are valid JSON.
- [ ] No file under `.claude/` was modified.
- [ ] No task-number citation was introduced outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/check-extension-docs.sh` (modified: Rule Q function,
  index entry, loop registration)
- `agent-system/extensions/nix/manifest.json` (modified: `provides.scripts` populated)
- `agent-system/extensions/nvim/manifest.json` (modified: `provides.scripts` populated)
- `specs/928_undeclared_scripts_doc_lint_check/summaries/01_undeclared-scripts-doc-lint-summary.md`
  (new; MUST carry the Phase 3 residual-gap disclosure)

## Rollback/Contingency

All three edits are small and independently revertible with `git checkout` against the three
source-store paths (the working tree must be clean or snapshotted first, per
`.claude/rules/git-workflow.md`'s "No Destructive Git on Uncommitted Work").

- If Phase 1's finding count is not exactly 3, do not proceed to Phase 2. Re-examine the
  trailing-slash normalization first -- it is the known cause of a large count -- and the loop
  registration second, which is the known cause of a zero count.
- If Phase 2 turns another extension red, revert the two manifest edits, identify which rule
  newly fires against a declared-but-undeployed entry, and resolve that before re-applying.
  Silencing Rule Q is not an available remedy.
- Reverting only Phase 2 leaves the gate red by design (Rule Q correctly reporting 3 real
  defects); reverting Phase 1 as well restores the pre-change green baseline.

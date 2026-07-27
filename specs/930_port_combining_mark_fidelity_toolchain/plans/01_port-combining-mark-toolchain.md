# Implementation Plan: Task #930

- **Task**: 930 - Port the combining-mark fidelity toolchain into the literature extension source
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: 928 (verification-ordering edge only -- see Overview; does NOT gate Phases 1-2)
- **Research Inputs**: specs/930_port_combining_mark_fidelity_toolchain/reports/01_combining-mark-toolchain-port.md
- **Artifacts**: plans/01_port-combining-mark-toolchain.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Rescue a combining-mark (U+0338 COMBINING LONG SOLIDUS OVERLAY) fidelity toolchain that currently
exists ONLY inside `/home/benjamin/Projects/BimodalLogic/.claude/scripts/`, a gitignored deploy
tree destroyed by the next extension reload in that repo, and land it in the agent-system source
of truth at `agent-system/extensions/literature/`. The port is a straight byte-for-byte file copy
of 6 files (4 new, 2 modified -- both modified files are clean supersets, no merge required) plus
4 new flat entries in `provides.scripts`. Definition of done: all 6 files present in
`agent-system/extensions/literature/scripts/` byte-identical to the deploy-tree originals, all 4
new files registered in the manifest, doc-lint clean for the literature extension in the
undeclared-script and orphan categories, and `literature-convert.sh --self-test` passing from a
deployed (not source-tree) copy.

**SOURCE-STORE RULE (binding, applies to every phase)**: the agent-system SOURCE of truth is
`agent-system/extensions/`. The `.claude/` tree is a GITIGNORED, DISPOSABLE deploy artifact. ALL
edits MUST target `agent-system/extensions/**` and NEVER `.claude/**`. The deploy-verification
work in Phase 4 uses a scratch directory precisely so that no write lands in `.claude/`.

**Urgency drives phase ordering**: Phases 1 and 2 (copy + manifest registration) are the
rescue-critical core and are front-loaded. Nothing in them requires the doc-lint dependency. If
task 928 were unavailable, Phases 1-2 still proceed and Phase 3 re-runs later. In practice
`agent-system/extensions/core/scripts/check-extension-docs.sh` is already on disk with the
`check_referenced_scripts_declared`, `check_flat_category_orphans`, and
`check_deployed_script_drift` checks present, so Phase 3 is expected to be runnable immediately.

### Research Integration

The research report is the authoritative content-compared re-census and supersedes the census
embedded in the task description. Findings integrated into this plan:

- **6 divergent files, not 4+1.** `literature-fidelity-audit.sh` escalated after the originating
  census and is now 22,458 B downstream vs. 18,685 B upstream (additive-only combining-mark
  signal). It joins `literature-convert.sh` as a MODIFIED file.
- **All 6 are straight copies.** No merge, no reconciliation. `literature-convert.sh` is +113/-1
  where the single removal is a relocated `SCRIPT_DIR` assignment.
- **False positives excluded.** `literature-audit.sh`, `zotero-export-status.sh`,
  `zotero-search.sh`, `zotero-setup.sh` are stale-downstream (upstream is AHEAD -- porting them
  backward regresses landed fixes). `literature-retrieve.sh` lives under
  `extensions/core/scripts/` and predates this work.
- **Manifest registration covers both `.py` modules.** `provides.scripts` already carries `.py`
  and `.sql` entries, so a shell-only assumption would drop the two modules both new tools import.
- **All 4 new files are flat/unprefixed** -- they live directly in `scripts/`, not `scripts/tests/`.
- **Permissions**: the two new `.py` modules are 644 downstream; the existing `.py` entry
  (`literature-decode-font-offset.py`) is 755 upstream. Neither module has a shebang and both are
  reached only via `sys.path.insert`, so 644 is functionally correct; `chmod +x` is a low-cost
  consistency fix, not a requirement.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided and no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Land all 6 divergent files byte-for-byte into `agent-system/extensions/literature/scripts/`
  before the disposable deploy tree is reloaded away.
- Register the 4 new files (including BOTH `.py` modules) as flat entries in
  `agent-system/extensions/literature/manifest.json` -> `provides.scripts`.
- Verify the port mechanically: post-copy `cmp`, manifest completeness, doc-lint categories,
  a deploy-shaped content match, and a functional `--self-test` from a deployed copy.
- Make the two new user-facing tools discoverable in the extension's own documentation.

**Non-Goals**:
- Porting `literature-audit.sh`, `zotero-export-status.sh`, `zotero-search.sh`, or
  `zotero-setup.sh` -- these are stale-downstream and copying them would regress upstream.
- Porting or relocating `literature-retrieve.sh` -- belongs to the `core` extension.
- Investigating `zotero-index-add.sh` / `zotero-index-remove.sh` (downstream-only, unrelated to
  the combining-mark toolchain). If real unported work, they warrant a separate task.
- Reading, reviewing, refactoring, or improving the ported code. This is a rescue copy; the
  content is authoritative as-is.
- Any write to `.claude/**` in this repo or any other.
- Refreshing this repo's own deployed `.claude/scripts/` copies (a picker-driven user action).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deploy tree reloaded away before the copy lands | H | M | Phase 1 is front-loaded and self-contained; it commits immediately on green. If a source file is already gone at Phase 1, record it as a hard failure with the file named -- do not silently reduce the file set. |
| `literature-fidelity-audit.sh` (or another file) drifts again between research and implementation | M | M | Phase 1 re-`cmp`s every source file immediately before writing and records observed sizes; a size/content change from the census is reported, and the CURRENT downstream content is what gets copied. |
| Accidentally porting a stale-downstream file, regressing landed upstream fixes | H | L | The 6-file allowlist in Phase 1 is exact and closed. The 5 excluded files are named explicitly in Non-Goals and in the Phase 1 task list as MUST NOT touch. |
| Forgetting manifest registration, making the port silently inert | H | L | Phase 2 is a distinct phase with its own verification; Phase 3's doc-lint independently catches the undeclared-script class. |
| Registering only the `.sh` files and dropping the two `.py` modules | H | L | Phase 2's task list enumerates all 4 by name and its verification asserts a 33 -> 37 count with an explicit per-name membership check. |
| Editing `.claude/**` instead of `agent-system/**` | H | L | Stated as a binding rule in the Overview and repeated per phase; Phase 4 deploy verification uses a scratch directory rather than `.claude/`. |
| Doc-lint reports drift FAILs for the two modified files | L | H | Expected and benign: this repo's deployed `.claude/scripts/` copies are pre-port. Phase 3 pre-declares these two as the ONLY tolerated failures and requires zero failures in every other category. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Rescue Copy of the 6 Divergent Files [COMPLETED]

**Goal**: Get every divergent file out of the disposable deploy tree and into the agent-system
source of truth, byte-for-byte, before it can be destroyed.

**Tasks**:
- [x] Set `DOWN=/home/benjamin/Projects/BimodalLogic/.claude/scripts` and
      `UP=/home/benjamin/.config/nvim/agent-system/extensions/literature/scripts`. Confirm `$DOWN`
      still exists; if it is gone, STOP and report -- do not fabricate content. *(completed: $DOWN confirmed present)*
- [x] Freshness re-check: for each of the 6 files, record the current downstream byte size and,
      for the 2 MODIFIED files, run `cmp -s "$UP/<f>" "$DOWN/<f>"` and confirm they still differ.
      Report any file whose size differs from the census values below. *(completed: all 6 sizes match census exactly; both modified files confirmed differing; no 7th differing literature* file found)*
- [x] Copy the 4 NEW files (`cp` preserving content exactly):
      `literature_combining_overlay.py` (4,267 B), `literature_combining_detect.py` (16,541 B),
      `literature-combining-audit.sh` (6,585 B), `literature-repair-combining.sh` (18,177 B). *(completed)*
- [x] Copy the 2 MODIFIED files, overwriting upstream:
      `literature-convert.sh` (34,500 B, was 30,073 B),
      `literature-fidelity-audit.sh` (22,458 B, was 18,685 B). *(completed)*
- [x] MUST NOT touch: `literature-audit.sh`, `zotero-export-status.sh`, `zotero-search.sh`,
      `zotero-setup.sh` (stale-downstream, upstream is ahead), `literature-retrieve.sh`
      (belongs to the `core` extension). *(completed: none touched, confirmed via git status --short)*
- [x] Set permissions: `chmod 755` on the 4 `.sh` files (2 new + 2 modified) and `chmod 755` on
      the two new `.py` modules for consistency with the existing `literature-decode-font-offset.py`
      convention. Note in the commit that 644 would also be functionally correct -- neither module
      has a shebang and both are import-only. *(completed: 755 applied to all 6)*
- [x] Commit the copy immediately on green (per-substep), before starting Phase 2. *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly 6 divergent files with the sizes listed above,
and asserts 5 named files are false positives that must not be touched. Confirm at implementation
time by re-running `cmp -s "$DOWN/<f>" "$UP/<f>"` per file BEFORE writing (the 6 must differ or be
absent upstream) and AFTER writing (all 6 must be byte-identical). If a 7th `literature*` file is
found to differ, do NOT silently port it -- report it and check it against the stale-downstream
exclusion criteria (older downstream mtime + upstream containing an unrelated newer fix) first.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature_combining_overlay.py` - new file
- `agent-system/extensions/literature/scripts/literature_combining_detect.py` - new file
- `agent-system/extensions/literature/scripts/literature-combining-audit.sh` - new file
- `agent-system/extensions/literature/scripts/literature-repair-combining.sh` - new file
- `agent-system/extensions/literature/scripts/literature-convert.sh` - overwritten with the
  downstream superset (adds `compose_combining_overlays` import, `--self-test` branch, widened
  overlay regex, relocated `SCRIPT_DIR`)
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` - overwritten with the
  downstream superset (adds `combining_mark_check()`, three new TSV columns, extended
  diff-suppression/persistence)

**Verification**:
- `cmp` each of the 6 written files against its `$DOWN` original: all 6 report no difference.
- `ls -l` confirms 755 on all 6.
- No file outside the 6-file allowlist has been modified (`git status --short` shows only these
  6 paths under `agent-system/`).

---

### Phase 2: Manifest Registration [COMPLETED]

**Goal**: Register the 4 new files in `provides.scripts` so the port actually deploys. An
unregistered script never deploys, making an unregistered port indistinguishable from no port.

**Tasks**:
- [x] Add 4 flat, unprefixed entries to
      `agent-system/extensions/literature/manifest.json` -> `provides.scripts`:
      `literature_combining_overlay.py`, `literature_combining_detect.py`,
      `literature-combining-audit.sh`, `literature-repair-combining.sh`. *(completed)*
- [x] Insert them adjacent to the existing fidelity/convert cluster
      (`literature-fidelity-audit.sh` / `literature-build-index.sh` / `literature-convert.sh` /
      `literature-normalize-authors.sh`) -- the array is grouped by feature cluster, not
      alphabetized, and all four belong to that conversion/fidelity pipeline. *(completed: inserted immediately after literature-convert.sh, before literature-chunk.sh)*
- [x] Do NOT add entries for `literature-convert.sh` or `literature-fidelity-audit.sh` -- both are
      already registered; only their content changed. *(completed: confirmed no duplicate entries added)*
- [x] Do NOT use a path prefix. All four live directly in `scripts/`. The `tests/` prefix
      convention applies only to files under `scripts/tests/`. *(completed: no prefix used)*
- [x] Validate the file is still well-formed JSON. *(completed: json.load succeeds)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts `provides.scripts` currently has 33 entries and will have
37 after the edit, and that exactly 4 entries are added. Confirm by reading the count before and
after with
`python3 -c "import json;print(len(json.load(open('agent-system/extensions/literature/manifest.json'))['provides']['scripts']))"`
and by asserting per-name membership for all four new names -- a count check alone would not catch
adding the same name twice or adding a `.sh` while dropping a `.py`.

**Files to modify**:
- `agent-system/extensions/literature/manifest.json` - 4 new `provides.scripts` entries

**Verification**:
- JSON parses cleanly.
- Entry count is 37.
- All four new names are present exactly once each, with no path prefix.
- Every entry in `provides.scripts` resolves to an existing file under
  `agent-system/extensions/literature/scripts/` (no entry references a nonexistent file).
- Conversely, every one of the 6 ported files appears in `provides.scripts`.

---

### Phase 3: Doc-Lint Verification [COMPLETED]

**Goal**: Mechanically confirm the port is not silently inert -- specifically that no ported
script is undeclared and no declared entry is an orphan.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` from the repo root.
      *(completed: the source-tree invocation self-detects and errors with a redirect instruction
      because the script's own `../..` resolution requires a deployed tree; ran the pre-existing
      deployed copy at `.claude/scripts/check-extension-docs.sh` instead, per its own instruction
      -- read-only, no writes under `.claude/**`)*
- [x] Confirm the literature extension is clean in the "referenced but undeclared" category
      (`check_referenced_scripts_declared`) -- a script named in docs/skills/agents but missing
      from `provides.scripts`. *(completed: zero occurrences for literature)*
- [x] Confirm the literature extension is clean in the "flat category orphans" category
      (`check_flat_category_orphans`) -- a deployed artifact with no `provides.scripts` source.
      *(completed: zero occurrences for literature)*
- [x] Confirm `check_manifest_entries` reports no declared-but-missing files for the literature
      extension. *(completed: zero occurrences)*
- [x] Record the pre-declared expected drift outcome (see Scope Hypothesis) rather than treating a
      nonzero overall exit code as an automatic port failure. *(completed: overall exit was 0;
      literature reported PASS in the final summary; the two pre-declared drift files aren't even
      deployed in this repo's `.claude/scripts/`, so drift check was skipped rather than failed --
      better than the tolerated outcome, not worse)*
- [ ] If the doc-lint script is unavailable or its checks are not yet present, mark this phase
      `[PARTIAL]`, leave Phases 1, 2, 4, 5 landed, and record that verification re-runs later. Do
      NOT roll back the port to wait on a lint. *(deviation: skipped -- condition not met, the
      doc-lint script was available and ran clean)*

**Timing**: 20 minutes

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that the ONLY tolerated doc-lint failures attributable to
this port are `check_deployed_script_drift` FAILs for `literature-convert.sh` and
`literature-fidelity-audit.sh` -- expected because this repo's own deployed `.claude/scripts/`
copies are pre-port and only a picker-driven extension reload (a user action, explicitly a
Non-Goal here) refreshes them. The 4 new files are not yet deployed here and should produce
`script not deployed, skipping drift check` info lines, not failures. Confirm by reading the
actual failure list: any failure naming a file outside these two, or any failure in a category
other than deployed-script drift, is a real defect and must be fixed before the phase closes.
Pre-existing failures in unrelated extensions are out of scope -- confirm they also occur on a
pre-port checkout rather than assuming it.

**Files to modify**:
- None (read-only verification phase)

**Verification**:
- Zero failures in the undeclared-script, flat-orphan, and manifest-entry categories for the
  literature extension.
- The complete set of literature-attributable failures equals the two pre-declared drift entries,
  or is empty.

---

### Phase 4: Deploy-Shaped Content Match and Functional Self-Test [NOT STARTED]

**Goal**: Prove the ported files survive a deploy intact and actually run from a deployed
location -- catching deploy-time path and import failures that a source-tree run would mask.

**Tasks**:
- [ ] Create a scratch deploy directory (e.g. under the session scratchpad). Do NOT write into
      `.claude/` in this or any repo.
- [ ] Simulate the deploy the way the loader does: for every entry in
      `agent-system/extensions/literature/manifest.json` -> `provides.scripts`, copy
      `agent-system/extensions/literature/scripts/<entry>` to `<scratch>/<entry>`, preserving
      relative path for prefixed entries. A missing source file at this step is a manifest defect,
      not a copy error -- report it.
- [ ] Confirm all 6 ported files landed in the scratch deploy with content matching the extension
      source (`cmp` each) and with executable permissions on the `.sh` files.
- [ ] Run `literature-convert.sh --self-test` FROM THE SCRATCH DEPLOY (not from the source tree),
      so that `SCRIPT_DIR`-relative `sys.path.insert` resolution of
      `literature_combining_overlay.py` is exercised as deployed.
- [ ] Confirm every fixture check the script reports prints `[self-test] PASS` with zero failures,
      and that the script's exit code is 0.
- [ ] If a check fails, treat it as a real port defect (a missed file, a permissions problem, or a
      missing manifest entry) -- do not edit the ported script content to make the test pass. The
      copied content is authoritative.

**Timing**: 40 minutes

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The research names roughly 7 fixture checks
(mark-immediately-before-base, mark-space-before-base, mark-tab-before-base,
mark-after-base-canonical-order, accented-letter-non-interference, newline-must-not-reorder, plus
corpus-derived base additions). That count is a hypothesis, not a contract. Confirm by reading the
actual `--self-test` output: the binding criterion is zero failures and exit code 0 across
whatever checks the script actually reports, NOT a match to the number 7. A count mismatch is
worth noting in the summary but is not by itself a failure.

**Files to modify**:
- None under version control (scratch deploy directory only)

**Verification**:
- All 6 ported files present in the scratch deploy, `cmp`-identical to the extension source.
- Both new `.py` modules present in the scratch deploy (their absence would be the exact
  manifest-omission failure mode this phase exists to catch).
- `literature-convert.sh --self-test` exits 0 with zero reported failures.

---

### Phase 5: Document the New Tools in the Extension README [NOT STARTED]

**Goal**: Make the two new user-facing tools discoverable. Two shell tools landing with no mention
in any extension documentation would be undiscoverable to anyone who did not write them.

**Tasks**:
- [ ] Add rows to the `## Provided Artifacts` table in
      `agent-system/extensions/literature/README.md`:
      - `scripts/literature-combining-audit.sh` - read-only corpus-wide detector for silently
        dropped combining marks (a bare U+0338 grep cannot find the silent-drop class)
      - `scripts/literature-repair-combining.sh` - backup-guarded, anchored, dry-run-default
        in-place repair engine for detected occurrences
- [ ] Briefly note that both import the shared `literature_combining_detect.py` module so
      detection and repair locate and classify occurrences identically, and that
      `literature-convert.sh` composes overlays inline via `literature_combining_overlay.py` with
      a `--self-test` fixture mode.
- [ ] Keep the addition compact -- a table row plus at most a short paragraph. Do not restructure
      the README.
- [ ] Honor the no-task-references-in-deliverables rule: no task-number citations anywhere in
      `agent-system/extensions/literature/README.md`. Cite durable anchors (script filenames,
      section headings) instead.
- [ ] Editing the README also clears the `check_readme_vs_manifest` "README.md older than
      manifest.json" drift WARN introduced by Phase 2.

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/literature/README.md` - 2 new `## Provided Artifacts` rows plus a short
  explanatory note

**Verification**:
- Both new tool names appear in the README.
- Every `.sh` filename newly referenced in the README is declared in `provides.scripts` (otherwise
  `check_referenced_scripts_declared` would newly fail).
- Diff read-through confirms every changed hunk is prose/table content, with no structural
  reorganization and no task-number citations.

---

## Testing & Validation

- [ ] All 6 ported files `cmp`-identical to their deploy-tree originals (Phase 1).
- [ ] `provides.scripts` contains 37 entries, including all 4 new flat names, with every entry
      resolving to an existing file (Phase 2).
- [ ] `check-extension-docs.sh` reports zero literature-extension failures in the
      undeclared-script, flat-orphan, and manifest-entry categories (Phase 3).
- [ ] Scratch deploy reproduces all 6 files with matching content and executable `.sh`
      permissions (Phase 4).
- [ ] `literature-convert.sh --self-test` exits 0 with zero failures from the deployed copy
      (Phase 4).
- [ ] No file under `.claude/**` modified in any phase (`git status` plus a check of the gitignored
      deploy tree).
- [ ] No stale-downstream file (`literature-audit.sh`, `zotero-export-status.sh`,
      `zotero-search.sh`, `zotero-setup.sh`, `literature-retrieve.sh`) modified.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature_combining_overlay.py` (new)
- `agent-system/extensions/literature/scripts/literature_combining_detect.py` (new)
- `agent-system/extensions/literature/scripts/literature-combining-audit.sh` (new)
- `agent-system/extensions/literature/scripts/literature-repair-combining.sh` (new)
- `agent-system/extensions/literature/scripts/literature-convert.sh` (overwritten)
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` (overwritten)
- `agent-system/extensions/literature/manifest.json` (4 new `provides.scripts` entries)
- `agent-system/extensions/literature/README.md` (documentation rows)
- `specs/930_port_combining_mark_fidelity_toolchain/summaries/01_port-combining-mark-toolchain-summary.md`

## Rollback/Contingency

- **Phase 1 or 2 fails**: `git checkout` the affected `agent-system/` paths from HEAD (the tree is
  clean at phase start because Phase 1 commits before Phase 2 begins). The 4 new files are
  untracked additions and can simply be removed. WARNING: rolling back Phase 1 re-exposes the
  original risk -- the deploy tree may be destroyed before a retry. Prefer fixing forward.
- **Phase 3 blocked** (doc-lint unavailable or incomplete): mark Phase 3 `[PARTIAL]`, leave all
  other phases landed and committed, and record that doc-lint verification re-runs once available.
  Do NOT roll back the port to wait on a lint.
- **Phase 4 self-test fails**: the failure is diagnostic of the port (missing file, missing
  manifest entry, wrong permissions), not of the ported code. Fix the port, re-run. Never edit
  ported script content to satisfy the test.
- **Phase 5 fails or is skipped**: purely documentation; leaves Phases 1-4 fully valid. Roll back
  the README hunk alone.
- **Whole-task rollback**: revert the task's commits under `agent-system/extensions/literature/`.
  This returns the extension to its pre-port state and permanently loses the rescued work if the
  downstream deploy tree has since been reloaded.

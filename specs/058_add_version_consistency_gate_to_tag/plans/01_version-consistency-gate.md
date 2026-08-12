# Implementation Plan: Version-Consistency Gate for /tag

- **Task**: 58 - Add a version-consistency preflight gate to /tag so a tag can never be created or pushed while the package being released declares a different version
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: `specs/058_add_version_consistency_gate_to_tag/reports/01_version-consistency-gate.md`
- **Artifacts**: plans/01_version-consistency-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/tag` computes the next semantic version purely from `git describe --tags --abbrev=0` and never
consults any package manifest, so a repo whose `pyproject.toml` / `package.json` / `Cargo.toml`
declares a different version can be tagged and pushed to production with the divergence caught
only downstream in CI — after the tag already exists on the remote. This plan inserts a new
**Step 3.5: Validate Version Consistency** into `agent-system/extensions/core/skills/skill-tag/SKILL.md`,
placed immediately after Step 3 (where `new_version` first exists) and before Step 4 / Step 5's
`--dry-run` `exit 0`, so all four invocation paths (dry-run, interactive, `--force`, and the new
explicit opt-out) traverse it identically. The gate detects a declared version across five
ecosystem manifest formats via bounded-depth discovery, fails closed on mismatch with an
actionable message naming both versions and the file to edit, and prints an explicit visible
notice when no version is declared. Definition of done: the gate is present in the source store,
its behavior is verified against fixtures covering match / mismatch / no-manifest / subdirectory-
manifest / non-static-version cases, and `commands/tag.md`'s documented Workflow and Requirements
lists name it.

### Research Integration

Findings from `reports/01_version-consistency-gate.md` carried directly into this plan:

- **Insertion point is forced, not chosen.** Step 5's dry-run branch is a literal
  `if [ "$dry_run" = true ]; then ... exit 0; fi` placed *before* the Force/Interactive branches.
  Any gate at or after Step 5 would never fire under `--dry-run`, violating requirement (5). The
  gate must sit between Step 3 and Step 4. Step 3 is also the first point at which `new_version`
  exists, so the window is exactly one step wide.
- **Five extraction commands are sandbox-verified** and portable (`sed`/`grep`/`jq` only, no
  GNU-`awk`-specific 3-arg `match()`): pyproject.toml `[project]`, setup.cfg `[metadata]`,
  setup.py literal-kwarg heuristic, package.json via `jq -r '.version // empty'`, Cargo.toml
  `[package]`. `jq` is already a hard dependency of this skill (Step 7), so no new tool is added.
- **Both "no static version" cases fall through correctly to empty**, not to a false match: PEP 621
  `dynamic = ["version"]` (no `version =` line in `[project]`), and Cargo
  `version.workspace = true` (the `.` after `version` breaks the `^version[[:space:]]*=` anchor).
  These are honest "not declared here" answers, not bugs — and for `setuptools-scm`-managed
  projects the check would be circular anyway, since their version derives *from* git tags.
- **The manifest is not reliably at the repo root.** The real observed failure (ModelChecker)
  declares its version in `code/pyproject.toml`. A root-only search would silently skip the gate on
  the exact failure this task exists to catch. Discovery must be bounded-depth from
  `git rev-parse --show-toplevel`, excluding vendor/build directories (`node_modules` above all —
  unbounded recursion in a Node repo finds thousands of `package.json` files).
- **No lint enforces SKILL.md/tag.md prose parity.** `check-extension-docs.sh`'s 36 checks operate
  at the manifest/deploy level (file existence, symlink integrity, deploy drift), never comparing
  a skill's step content against its paired command doc's lists. Doc parity here is a manual
  authoring obligation with no safety net, which is why it gets its own phase rather than being a
  footnote inside another one.
- **Requirements-list precedent already exists** for listing a non-Step-2 check: the "no existing
  tag with computed version" bullet corresponds to a Step 3 check. Appending a version-consistency
  bullet needs no restructuring.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` in the delegation context).

## Decision Record

Two design decisions the task description required be settled here rather than left to the
implementer, plus three open questions the research report surfaced without resolving.

### DR-1: Report-and-stop, NOT auto-bump (requirement 4)

**Decision**: The gate reports the mismatch and exits non-zero. It never edits a manifest, never
creates a commit, and never offers to do either.

**Rationale**:

1. **Consistency with every other `/tag` failure mode.** Dirty working tree, detached HEAD, behind
   remote, and tag-already-exists are all report-and-stop. None auto-fixes. A gate that auto-fixed
   would be the single odd one out in a command whose failure philosophy is otherwise uniform.
2. **Blast radius.** `/tag`'s documented job is "create and push a semantic version tag." Writing
   to a source file is a categorically different operation from tagging, and would arrive as a
   surprising side effect of a command named `tag`. This matters more than usual here because
   `/tag` is `user-only: true` precisely on the grounds that deployment is a human judgment call —
   silently widening what it mutates cuts against that posture.
3. **Auto-bump cannot stop at "edit the file."** For the tag to point at a commit where manifest
   and tag agree, the bump needs its own commit. That forces one of two bad outcomes: an extra
   `git push` before the tag push (widening the already-pushed-now-must-clean-up window this task
   exists to *shrink*), or folding the bump into the commit the user is tagging (rewriting or
   amending history the user did not ask to touch).
4. **Safe in-place rewriting is a harder problem than reading.** Preserving exact formatting while
   editing TOML/JSON is nontrivial, and `setup.py`'s version can be an arbitrary Python
   expression — the same free-form-ness that makes the *read* side a best-effort heuristic makes
   the *write* side unsafe by construction.
5. **Multi-manifest ambiguity.** With more than one manifest discovered, auto-bump must decide
   which to write. Report-and-stop simply lists them all and lets the human decide.

**Cost accepted**: the user runs one extra edit-commit-rerun cycle on a mismatch. This is the same
cost already paid for a dirty working tree, and is strictly recoverable — unlike a bad push.

### DR-2: Update both lists in `commands/tag.md` (requirement 6)

**Decision**: Yes to both. Append a fifth Requirements bullet, and insert a new numbered Workflow
item between current items 2 (Compute Version) and 3 (Display Summary), matching the gate's actual
position in `SKILL.md`. Also add `--skip-version-check` to the Usage flag table.

**Rationale**: The Requirements list is the user-facing statement of what must hold before a tag is
created; a gate that can block tagging and is absent from that list makes the documented contract
false. The Workflow list is a positional mirror of `SKILL.md`'s steps — leaving it at 7 items while
`SKILL.md` has 8 makes the numbering silently misleading about where the check runs, which matters
because the *position* (before the dry-run exit) is the whole point of requirement (5). Research
confirmed no lint catches this drift, so it is stated here as an explicit deliverable with its own
phase rather than trusted to memory.

### DR-3: All discovered manifests are checked, ANY mismatch fails

**Open question from research** (multiple manifests found — check all, or prioritize?).
**Decision**: check every discovered manifest that yields a non-empty declared version; any single
mismatch fails the gate; the error lists every manifest found with its declared version.

**Rationale**: A priority order would require the gate to guess which manifest is "the real release
artifact," and guessing wrong reintroduces exactly the silent-skip failure this task exists to
close. Checking all is strictly safer and needs no heuristic. Cross-manifest disagreement
(independent of the tag) is caught as a free consequence: at most one of two disagreeing manifests
can equal the tag, so the other fails.

### DR-4: Exact string equality on the bare version; suffix mismatches are real mismatches

**Open question from research** (pre-release/build-metadata suffixes). **Decision**: strip a
leading `v` from both sides, then compare with exact string equality. A declared `1.3.1-rc1`
against a computed `v1.3.1` is reported as a mismatch.

**Rationale**: Step 3 can only ever produce a plain `vMAJOR.MINOR.PATCH` — its arithmetic has no
path to emitting a suffix. So a suffixed manifest version genuinely does not match what is being
tagged, and reporting it is correct rather than a false positive. Inventing a normalization rule
that quietly equates `1.3.1-rc1` with `v1.3.1` would make the gate lie about a real divergence.
DR-5 provides the escape hatch for the case where the user knows better.

### DR-5: An explicit `--skip-version-check` opt-out exists and announces itself loudly

**Decision**: add a `--skip-version-check` flag. Default is fail-closed; the flag is the only way
past a mismatch, and using it prints a prominent warning naming both versions.

**Rationale**: Without an escape hatch, fail-closed is not merely strict — it makes certain
legitimate releases impossible (a deliberately-suffixed manifest under DR-4, a manifest whose
version is intentionally decoupled from the deploy tag). An explicit, named, loudly-logged flag
preserves the fail-closed default while keeping the human in control, consistent with `/tag`'s
`user-only` posture. Crucially it is **not** a silent bypass: the warning names both versions, so
the transcript still records the divergence. This is the same shape as the existing `--force`
flag — an explicit user override of a safety prompt, not a change to the default.

### DR-6: `setup.py` non-match is treated as "no version declared", not as an error

**Decision**: when the `setup.py` heuristic finds no literal string version, that file contributes
nothing (falls into the no-version-declared path); it does not fail the gate.

**Rationale**: `setup.py`'s version is an arbitrary Python expression and cannot be statically
parsed in general. A false *extraction* would block a perfectly good release; a missed extraction
only forgoes a check that never worked for that file. The asymmetry favors missing over
false-blocking. Poetry-only `[tool.poetry]` pyproject files are treated the same way (out of scope
for the first cut; they fall through to no-version-declared) — noted in the skipped-check notice
so the transcript is honest about what was and was not inspected.

## Goals & Non-Goals

**Goals**:
- A version-consistency gate in `skill-tag/SKILL.md` that runs before `git tag` (Step 6), before
  `git push` (Step 6), and before Step 5's `--dry-run` `exit 0`.
- Ecosystem-general manifest detection: Python (`pyproject.toml` `[project]`, `setup.cfg`
  `[metadata]`, `setup.py` heuristic), Node (`package.json`), Rust (`Cargo.toml` `[package]`),
  discovered by bounded-depth search from the repo root with vendor-directory exclusions.
- Fail-closed on mismatch, with a message naming the computed tag version, the declared version,
  and the manifest path to edit.
- An explicit, visible "no declared version found — skipping consistency check" notice: neither
  silence nor failure.
- Repos with no manifest at all (this Lua/Nix repo included) keep working with no behavior change
  beyond the added notice line.
- `commands/tag.md`'s Workflow, Requirements, and Usage flag table agree with the implemented gate.

**Non-Goals**:
- Auto-bumping or otherwise writing to any manifest file (see DR-1).
- Adding a doc-parity lint check to `check-extension-docs.sh` — the research confirmed none exists,
  and the task's file scope covers only the two skill-tag/tag.md files. A follow-up task is the
  right home for that.
- Supporting Poetry-only `[tool.poetry]` pyproject layouts, workspace-root Cargo resolution, or
  monorepo per-package version policies (see DR-6).
- Any change to Steps 1, 2, 6, 7, or 8 beyond the `--skip-version-check` flag parse in Step 1 and
  the flag-table row in Command Syntax.
- Extracting the extraction commands into a shared reusable context file. The research report
  recommends this as a follow-up; it is out of this task's file scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Root-only manifest search silently skips the gate on the exact real-world failure (subdirectory `code/pyproject.toml`) | H | M | Bounded-depth (`-maxdepth 3`) discovery from `git rev-parse --show-toplevel`, explicitly fixture-tested against a subdirectory manifest in Phase 1 |
| Unbounded recursive search finds thousands of `node_modules/**/package.json` and hangs or produces garbage | H | M | Hard `-maxdepth` plus explicit `-not -path` exclusions for `node_modules`, `.git`, `dist`, `build`, `target`, `__pycache__`, `.venv`, `venv`; fixture-tested against a repo containing a `node_modules` tree |
| False-positive extraction blocks a legitimate release | H | L | DR-6 (setup.py non-match = no version); `[project]`-scoped `sed` range prevents matching a `[tool.poetry]` version; both non-static cases verified to yield empty; `--skip-version-check` escape hatch (DR-5) |
| Gate placed at or after Step 5 and therefore never fires under `--dry-run` | M | M | Insertion point is fixed by this plan as Step 3.5, strictly between Step 3 and Step 4; Phase 5 verification explicitly exercises the dry-run path |
| `commands/tag.md` drifts from the implemented gate because no lint catches it | M | M | Dedicated phase (Phase 4) with its own verification criteria; parity re-checked in Phase 5's end-to-end gate |
| Non-portable shell (GNU-only flags) breaks on a contributor's BSD/macOS toolchain | M | L | Only `sed`/`grep`/`jq`/`find -maxdepth` used, all verified portable in research; Phase 1 tests the fragment as an executable script before it is embedded |
| Edits land in `.claude/**` and are wiped by the next deploy | H | L | Source-store rule restated in every phase's file list; Phase 5 verifies via redeploy that the deployed copy matches the source |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Build and Fixture-Verify the Detection Fragment [NOT STARTED]

**Goal**: Produce a working, portable shell fragment that discovers manifests and extracts declared
versions, proven against fixtures covering every case in the research report — *before* embedding
it in `SKILL.md`. This front-loads all the portability and false-match risk into a phase where the
source store is untouched and iteration is cheap.

**Tasks**:
- [ ] Create a scratch fixture tree under the session scratchpad (not the repo) with these cases:
  1. root `pyproject.toml` with `[project]` `version = "1.3.0"` AND a later `[tool.poetry]` table
     declaring `9.9.9` (proves the `[project]`-scoped `sed` range does not false-match Poetry)
  2. **subdirectory** `code/pyproject.toml` (the real observed-failure shape)
  3. `pyproject.toml` with PEP 621 `dynamic = ["version"]` (must yield empty)
  4. `setup.cfg` with `[metadata]` `version = 3.2.1` (unquoted)
  5. `setup.py` with a literal `version="4.5.6"` kwarg
  6. `setup.py` computing its version programmatically (must yield empty, per DR-6)
  7. `package.json` with `"version": "2.1.0"`, plus a `node_modules/` subtree containing several
     decoy `package.json` files (proves exclusion works)
  8. `Cargo.toml` with `[package]` `version = "0.4.2"`
  9. `Cargo.toml` with `version.workspace = true` (must yield empty)
  10. a directory with no manifest at all (must yield the no-version-declared path)
- [ ] Write the discovery command: `find "$repo_root" -maxdepth 3` with `-not -path` exclusions for
      `node_modules`, `.git`, `dist`, `build`, `target`, `__pycache__`, `.venv`, `venv`, and
      `-name` clauses for the five manifest filenames.
- [ ] Write a `extract_declared_version <file>` dispatch that branches on basename and applies the
      matching sandbox-verified command from the research report verbatim (do not re-derive them —
      transcribe from `reports/01_version-consistency-gate.md` "External Resources" section).
- [ ] Run the fragment against all 10 fixtures; record actual output per fixture.
- [ ] Confirm the exclusion list actually suppresses `node_modules` decoys (case 7) rather than
      merely being present in the command text.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a 10-case fixture set and a 5-format extraction dispatch.
Both are hypotheses derived from the research report's ecosystem survey, not confirmed facts.
Confirm at implementation time by running the fragment against every fixture and recording the
observed output for each; if a case behaves differently than the report documents, the report's
finding — not the fixture — is what must be re-checked, and the divergence noted in the summary.

**Files to modify**:
- None in the repository. All work lands in the session scratchpad directory. This is deliberate:
  no source-store file is touched until the logic is proven.

**Verification**:
- All 10 fixtures produce the expected output: cases 1, 2, 4, 5, 7, 8 yield the declared version
  string; cases 3, 6, 9, 10 yield empty.
- Case 1 yields `1.3.0`, NOT `9.9.9` (the Poetry false-match guard holds).
- Case 2's manifest is found at depth 2, proving root-only search would have missed it.
- Case 7's decoy `node_modules` manifests do not appear in the discovery output.
- The fragment uses only `sed`, `grep`, `jq`, and `find -maxdepth` — grep the fragment for `awk` to
  confirm none was introduced.

---

### Phase 2: Insert Step 3.5 into skill-tag/SKILL.md [NOT STARTED]

**Goal**: Embed the verified fragment as a complete new `### Step 3.5: Validate Version
Consistency` section, wire the `--skip-version-check` flag through Step 1, and add the flag to the
Command Syntax table — so the gate exists end to end in one coherent state.

**Tasks**:
- [ ] In Step 1 (Parse Arguments), add `skip_version_check=false` alongside the existing defaults
      and a `if [[ "$*" == *"--skip-version-check"* ]]; then skip_version_check=true; fi` block,
      matching the existing flag-parse style exactly.
- [ ] Add a `--skip-version-check` row to the Command Syntax flag table near the top of the file.
- [ ] Insert a new `### Step 3.5: Validate Version Consistency` section immediately after Step 3's
      closing code fence and immediately before `### Step 4: Display Summary`. This position is
      non-negotiable: it is the only placement where `new_version` exists AND the dry-run `exit 0`
      has not yet run.
- [ ] The new section opens with `echo ""` / `echo "=== Validating Version Consistency ==="` /
      `echo ""`, matching the `=== Section ===` banner convention used by Steps 2, 3, 4, 6, 7.
- [ ] Body order within the block:
  1. `new_version_bare="${new_version#v}"`
  2. discovery `find` into a manifest list
  3. loop calling the extraction dispatch; collect `path:version` pairs where version is non-empty
  4. if no pairs collected: print the explicit skip notice naming which filenames were checked, then
     fall through (do NOT exit non-zero)
  5. if any pair's version (with a leading `v` stripped) differs from `new_version_bare`: print the
     mismatch error naming both versions and every manifest found, then `exit 1` — unless
     `skip_version_check=true`, in which case print the loud override warning and fall through
  6. if all pairs match: print a one-line confirmation naming the manifest(s) and version
- [ ] Do not renumber Steps 4-8. `3.5` is used deliberately to keep the existing step numbers and
      their cross-references stable.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly one file is modified and that the insertion point
sits between Step 3's closing fence and the `### Step 4: Display Summary` heading. Confirm at
implementation time by grepping the file for `^### Step ` and checking the new heading's ordinal
position, and by confirming `git status --short` shows exactly one modified path.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — new Step 3.5 section; Step 1 flag
  parse; Command Syntax flag-table row. **Source store only.** Do not edit
  `.claude/skills/skill-tag/SKILL.md`; it is a disposable deploy artifact and any edit there is
  wiped by the next regeneration.

**Verification**:
- `grep -n '^### Step' agent-system/extensions/core/skills/skill-tag/SKILL.md` shows Step 3.5
  between Step 3 and Step 4, with Steps 4-8 unrenumbered.
- The Step 3.5 block appears strictly above the `if [ "$dry_run" = true ]` line — verify by
  comparing the two line numbers, not by reading impressionistically.
- The block references `$new_version` (defined in Step 3) and `$skip_version_check` (defined in
  Step 1); neither is used before its definition.
- Both `exit 1` on mismatch and fall-through on no-version-declared are present and distinguishable.
- `git status --short` shows only the one expected file modified.

---

### Phase 3: Error Handling Transcripts in SKILL.md [NOT STARTED]

**Goal**: Document the gate's three new user-visible outcomes in the file's `## Error Handling`
section, in the same shape as the three transcripts already there — so the failure message a user
will actually see is specified, not left to improvisation at runtime.

**Tasks**:
- [ ] Add a `### Version Mismatch` transcript after the existing `### Tag Already Exists`
      transcript, following the established `=== Section ===` / `Error: ...` / blank /
      `Resolution: ...` shape. It must name (a) the computed tag version, (b) the declared version,
      (c) the manifest file path. Use the report's recommended wording as the base:
      `Error: Declared package version (1.3.0) does not match computed tag (v1.3.1).` followed by
      `Declared in: code/pyproject.toml (version = "1.3.0")` and a `Resolution:` line instructing
      the user to update that file, commit, and re-run.
- [ ] Add a `### No Declared Version Found` transcript showing the skip notice. This is not an
      error, so mark it explicitly as an informational outcome and place it so a reader does not
      mistake it for a failure. It must enumerate the filenames that were checked.
- [ ] Add a `### Version Check Skipped by Flag` transcript showing the `--skip-version-check`
      override warning, including both divergent versions (the flag suppresses the *block*, not the
      *disclosure*).
- [ ] Use a subdirectory manifest path (`code/pyproject.toml`) in the mismatch example rather than a
      root path, so the documentation itself carries the "manifests are not always at the root"
      lesson.
- [ ] Use no task numbers anywhere in these transcripts — this file is a deliverable outside
      `specs/**`, so task-number references are prohibited. Cite behavior, not provenance.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — `## Error Handling` section only.
  Source store only; never `.claude/**`.

**Verification**:
- Three new `###` subsections exist under `## Error Handling`.
- Each transcript's wording matches what the Phase 2 code actually prints — diff the `echo` strings
  in Step 3.5 against the transcript text token by token; a transcript that documents a message the
  code does not emit is worse than no transcript.
- `grep -nEi 'task [0-9]|tasks [0-9]' agent-system/extensions/core/skills/skill-tag/SKILL.md`
  returns nothing.
- All edits lie inside the `## Error Handling` prose region (this is what the `prose` tier asserts);
  confirm no `echo` inside a Step's executable block was altered by this phase.

---

### Phase 4: Doc Parity in commands/tag.md [NOT STARTED]

**Goal**: Make the documented contract in `commands/tag.md` agree with the implemented gate, per
DR-2. No lint enforces this, so it is verified by hand against the Phase 2 output.

**Tasks**:
- [ ] Insert a new Workflow item between current item 2 (**Compute Version**) and current item 3
      (**Display Summary**): `**Validate Version Consistency**: Compare declared package version
      against computed tag; fail on mismatch`. Renumber the following items 4-8.
- [ ] Append a fifth Requirements bullet: declared package version (if any manifest declares one)
      matches the computed tag version. Phrase it to make the conditionality explicit — a repo with
      no manifest satisfies this requirement vacuously, and the bullet must not read as though a
      manifest is now mandatory.
- [ ] Add a `--skip-version-check` row to the Usage flag table, describing it as an explicit
      override that still reports the divergence.
- [ ] Confirm the new Workflow item's position matches the gate's actual position in `SKILL.md`
      (before Display Summary, before the dry-run exit) — the ordering is the load-bearing part.
- [ ] No task numbers anywhere in this file.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts three edit sites in one file (Workflow list, Requirements
list, Usage flag table). Confirm at implementation time by grepping the file for `## Workflow`,
`## Requirements`, and the flag table, and verifying each contains the new entry; if a fourth site
mentioning the step sequence exists, it must be updated too rather than left stale.

**Files to modify**:
- `agent-system/extensions/core/commands/tag.md` — Workflow list, Requirements list, Usage flag
  table. **Source store only.** Never `.claude/commands/tag.md`.

**Verification**:
- The Workflow list has 8 numbered items, sequentially numbered with no duplicates or gaps.
- The new Workflow item sits at position 3, before **Display Summary**.
- The Requirements list has 5 bullets, and the new one reads as conditional (vacuously satisfied
  when no manifest exists), not as a new mandatory-manifest requirement.
- The Usage flag table in `commands/tag.md` and the Command Syntax flag table in `SKILL.md` list the
  same flag set — compare them directly; this cross-file agreement is what the `interface` tier is
  asserting here.
- `grep -nEi 'task [0-9]|tasks [0-9]' agent-system/extensions/core/commands/tag.md` returns nothing.

---

### Phase 5: End-to-End Verification and Deploy Check [NOT STARTED]

**Goal**: Confirm the gate behaves correctly on all four invocation paths against real fixture
repos, that the source-store edits survive a redeploy, and that the full repo gate set passes.

**Tasks**:
- [ ] Build three throwaway git repos in the scratchpad, each with a real tag history so
      `git describe --tags --abbrev=0` returns a value:
  - **R1 (match)**: `pyproject.toml` declaring the version the gate will compute
  - **R2 (mismatch, subdirectory)**: `code/pyproject.toml` declaring a stale version — the real
    observed-failure shape
  - **R3 (no manifest)**: Lua/Nix-style repo with no manifest at all
- [ ] Extract the Step 3.5 block from `SKILL.md` into a runnable harness script (prepending the
      Step 1 and Step 3 variable setup) and run it in each repo under each of: default, `--dry-run`,
      `--force`, `--skip-version-check`.
- [ ] Record the 12-cell outcome matrix (3 repos x 4 modes) with actual exit codes and output.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` (or the repo's equivalent regeneration path) and
      confirm `.claude/skills/skill-tag/SKILL.md` and `.claude/commands/tag.md` now contain the new
      content — proving the edits went to the source store and not to the deploy artifact.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm no new
      findings versus a pre-change baseline (capture the baseline before the redeploy if not
      already captured).
- [ ] Run the repo-wide task-reference lint (`check-task-references.sh`) and confirm clean.
- [ ] Commit each green sub-step as it lands, per the commit-per-green-substep mandate.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts a 12-cell outcome matrix over 3 fixture repos and 4
invocation modes. Confirm at implementation time by actually running all 12 and recording each
result; a cell that cannot be run must be reported as unrun, never inferred from an adjacent cell.

**Files to modify**:
- None. This phase is verification only; any defect it finds is fixed by returning to the owning
  phase (2, 3, or 4), not by patching in place here.

**Verification**:
- **R2 under `--dry-run` exits non-zero with the mismatch message.** This is the single most
  important cell in the matrix: it is simultaneously the requirement-(5) proof (dry-run reaches the
  gate) and the requirement-(2) proof (subdirectory manifests are found). If only one cell is
  checked, it is this one.
- R2 fails under default, `--force`, and `--dry-run`; R2 under `--skip-version-check` proceeds but
  prints the warning naming both versions.
- R1 passes silently-but-confirmingly under all four modes (prints the match confirmation, exits 0).
- R3 prints the explicit skip notice under all four modes and exits 0 — never silence, never
  failure.
- Deployed `.claude/` copies match the source-store files after redeploy.
- `check-extension-docs.sh` shows no new findings; task-reference lint clean.

---

## Testing & Validation

- [ ] All 10 Phase 1 fixtures produce the documented extraction result (6 versions, 4 empties).
- [ ] The `[project]`-scoped extraction returns `1.3.0`, not `9.9.9`, on the mixed Poetry fixture.
- [ ] `node_modules` decoys are excluded from discovery.
- [ ] A subdirectory manifest at depth 2 is discovered.
- [ ] Step 3.5's line number precedes the `if [ "$dry_run" = true ]` line number in `SKILL.md`.
- [ ] The 12-cell matrix (R1/R2/R3 x default/`--dry-run`/`--force`/`--skip-version-check`) is fully
      executed and recorded, with R2-under-`--dry-run` failing closed.
- [ ] No-manifest repo (R3) behavior is unchanged apart from the added notice line.
- [ ] Error transcripts in `SKILL.md` match the strings the code actually emits.
- [ ] `commands/tag.md` Workflow has 8 items, Requirements has 5 bullets, flag tables agree across
      both files.
- [ ] `check-extension-docs.sh` clean relative to baseline.
- [ ] No task-number references in either modified file.
- [ ] Redeploy propagates both files into `.claude/`.

## Artifacts & Outputs

- `specs/058_add_version_consistency_gate_to_tag/plans/01_version-consistency-gate.md` (this file)
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — new Step 3.5, `--skip-version-check`
  parse, Command Syntax row, three Error Handling transcripts
- `agent-system/extensions/core/commands/tag.md` — Workflow item 3, fifth Requirements bullet,
  Usage flag-table row
- `specs/058_add_version_consistency_gate_to_tag/summaries/01_version-consistency-gate-summary.md`
  (produced by the implementation phase; must include the 12-cell outcome matrix)

## Rollback/Contingency

Both modified files are markdown in the source store with no build or runtime dependents, so
rollback is a plain `git revert` of the phase commits — followed by a redeploy to restore the
`.claude/` copies. No state, schema, or migration is involved.

Contingency by phase:
- **Phase 1 finds an extraction command behaves differently than the research report documents**:
  stop and re-verify the report's finding against the actual fixture before adjusting anything. The
  fragment is not embedded until every fixture passes, so a divergence here costs nothing beyond
  the scratchpad.
- **Phase 5 finds the gate does not fire under `--dry-run`**: the insertion point is wrong. Return
  to Phase 2 and move the block; do not work around it by adding a second check inside Step 5, which
  would leave two divergent copies of the gate logic.
- **Discovery proves too slow or noisy on a large real repo**: reduce `-maxdepth` from 3 to 2 and
  re-run Phase 1's case 2 to confirm the subdirectory manifest is still found. Do not respond by
  reverting to a root-only search — that reintroduces the exact silent-skip failure this work
  exists to close.

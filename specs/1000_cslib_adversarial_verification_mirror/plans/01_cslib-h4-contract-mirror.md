# Implementation Plan: CSLib Adversarial-Verification Mirror

- **Task**: 1000 - Give cslib its own adversarial-verification contract copy and union-valued index entry
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: 991, 992 (both completed; their decomposition recorded this gap as a follow-on)
- **Research Inputs**: specs/1000_cslib_adversarial_verification_mirror/reports/01_cslib-adversarial-verification-mirror.md
- **Artifacts**: plans/01_cslib-h4-contract-mirror.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase authored both deliverables directly in the working tree and verified them, but
left them **uncommitted**. This plan therefore does not re-author the contract mirror from
scratch; its job is to re-confirm that the two working-tree changes still exist and still pass the
stated verification bar, correct any drift found, and claim both paths via `modified_files` so the
implement postflight commit actually captures them. The definition of done is: doc-lint gate
passes, the union-valued `load_when.agents` and the declared `line_count` are re-confirmed against
the file on disk, and both paths appear in the agent's reported `modified_files`.

### Research Integration

The research report (`reports/01_cslib-adversarial-verification-mirror.md`) settled every open
design question, and none of them are re-opened here:

- **Content strategy**: near-verbatim mirror of core's contract, not a cslib-specialized rewrite
  and not a stub. Rationale: the deploy tree collapses both extensions' `contracts/*.md` onto one
  shared path (`.claude/context/contracts/adversarial-verification.md`), and `merge.lua`'s
  `append_index_entries` upserts **by path** — whichever extension is processed last supplies both
  the file content and the whole index-entry object. A lean-style rewrite would silently change
  `general-research-hard-agent`'s contract as a side effect of loading an unrelated extension.
- **Union-valued `load_when.agents`**: `["general-research-hard-agent",
  "cslib-research-hard-agent"]`, verified by a headless-Neovim simulation of the upsert (core's
  entry applied first, cslib's second) to survive the merge rather than replace core's hook.
- **Ordering**: source file first, index entry second — Rule R (`check_line_count_accuracy`, hard
  gate) rejects an index entry with no resolvable source file at `<ext>/context/<path>`.
- **`lean-research-hard-agent` deliberately excluded** from the union: lean's own entry is a
  separate task's file scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- Re-verify that `agent-system/extensions/cslib/context/contracts/adversarial-verification.md`
  exists in the working tree and its actual line count matches the `line_count` declared in
  `agent-system/extensions/cslib/index-entries.json`.
- Re-verify the index entry's `load_when.agents` is still the two-name union, and that the entry
  shape matches lean's contract-mirror precedent.
- Re-run `check-extension-docs.sh` and confirm `cslib PASS`; correct any failure found.
- Re-run `validate-context-budgets.sh` and confirm no new violation naming
  `cslib-research-hard-agent`.
- Claim both paths in `modified_files` so the postflight commit captures them.

**Non-Goals**:
- Re-designing the content strategy (settled in research: near-verbatim mirror).
- Editing core's or lean's `index-entries.json`, or adding `lean-research-hard-agent` to the union
  — out of file scope.
- Redesigning `merge.lua`'s upsert-by-path behavior (a known, documented dormant risk; this task
  works correctly within it, it does not fix it).
- Any write under `.claude/**`. That tree is a disposable deploy artifact; all edits go to
  `agent-system/extensions/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Working-tree changes were reverted or lost between research and implement | H | L | Phase 1 checks existence first and, if absent, re-authors from the research report's recorded structure (header + core's four sections + Domain Specialization) before proceeding |
| `line_count` drifts from actual `wc -l` after any correction edit | H | M | Phase 1 re-measures with `wc -l` after every edit and re-runs the Rule R gate; never trusts the declared value |
| An edit accidentally lands in `.claude/` instead of `agent-system/extensions/` | H | L | All Tasks name absolute source-store paths; the advisory PostToolUse hook also flags `.claude/**` targets |
| Doc-lint or budget script emits a pre-existing unrelated failure and is misread as caused by this change | M | M | Phase 2 compares against the research report's recorded baseline (8 pre-existing budget violations, none naming `cslib-research-hard-agent`; cslib is not a loaded extension in this repo) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Verify and Reconcile the Working-Tree Deliverables [COMPLETED]

**Goal**: Confirm both working-tree changes still exist and are internally consistent (file
present, `line_count` accurate, union-valued `agents`, correct entry shape); make any corrections
needed so the Rule R hard gate passes.

**Tasks**:
- [x] Run `git status --short -- agent-system/extensions/cslib/` and record what is present. Expect
      an untracked `agent-system/extensions/cslib/context/contracts/` directory and a modified
      `agent-system/extensions/cslib/index-entries.json`. *(completed: confirmed exactly these two
      paths, nothing else)*
- [x] Read `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` and
      confirm it contains: the explanatory header (what the file is; why it is deliberately NOT
      cslib-specialized, citing the shared-path collision; where genuinely cslib-only H4 behavior
      belongs), the Claim Verification Bar, Confidence Level Taxonomy, Contradiction Resolution
      Protocol, and Forbidden Verification Outputs sections, and the Domain Specialization section
      naming both cslib and lean4. *(completed: all sections present; body verbatim-matches core's
      from `## Claim Verification Bar` through `## Domain Specialization` except the closing
      attribution lines)*
- [x] If the file is missing, re-author it at that exact path following the structure recorded in
      the research report's Recommendations section, sourcing the four contract sections verbatim
      from `agent-system/extensions/core/context/contracts/adversarial-verification.md`.
      *(completed: file was present, no re-authoring needed)*
- [x] Confirm the file's cross-references point at the generic deployed core paths
      (`@.claude/context/contracts/anti-analysis.md`,
      `@.claude/context/contracts/reference-grounding.md`) — matching what
      `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md` already names. A
      cslib-namespaced H3 anchor would dangle: cslib owns no H2/H3 parity copies. *(completed:
      file references `@.claude/context/contracts/reference-grounding.md#source-coverage-minimums`;
      confirmed `cslib-research-hard-agent.md` lines 40-42 point at the same generic core paths)*
- [x] Measure the file with `wc -l` and compare against the `line_count` in the
      `contracts/adversarial-verification.md` entry of
      `agent-system/extensions/cslib/index-entries.json`. Correct `line_count` to the measured
      value on any mismatch (never adjust the file to fit the number). *(completed: `wc -l` = 117,
      declared `line_count` = 117, no correction needed)*
- [x] Confirm the entry's `load_when.agents` is exactly
      `["general-research-hard-agent", "cslib-research-hard-agent"]` — a union, not a single name.
      Restore both names if either is missing. *(completed: both names present)*
- [x] Confirm the entry shape follows lean's contract-mirror precedent: `path`
      `"contracts/adversarial-verification.md"` (bare, not the `project/cslib/...` prefix cslib's
      other entries use), `domain: "project"`, `subdomain: "cslib"`, `load_when.task_types:
      ["cslib"]`, and no `commands` key. *(completed: entry shape matches lean's precedent exactly)*
- [x] Validate the JSON parses: `jq -e . agent-system/extensions/cslib/index-entries.json`.
      *(completed: valid)*
- [x] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and
      confirm the summary table reports `cslib PASS`. Fix and re-run on any cslib failure.
      *(completed: summary table reports `cslib PASS`)*

**Timing**: 30 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly two paths are expected to change and no others —
`agent-system/extensions/cslib/context/contracts/adversarial-verification.md` (hypothesized
present at 117 lines) and `agent-system/extensions/cslib/index-entries.json` (hypothesized to
carry one new entry with `line_count: 117`). Confirm at implementation time via `git status
--short -- agent-system/extensions/cslib/` and `wc -l` on the contract file; if the measured line
count differs from 117, the measured value is authoritative and the index entry is corrected to
match. If any third path under `agent-system/` shows as changed by this task, stop and report
rather than claiming it.

**Files to modify**:
- `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` - verify present
  and structurally complete; re-author only if missing
- `agent-system/extensions/cslib/index-entries.json` - verify the mirror entry's `line_count`,
  union-valued `load_when.agents`, and entry shape; correct on drift

**Verification**:
- `git status --short -- agent-system/extensions/cslib/` shows both paths changed
- `wc -l` on the contract file equals the entry's declared `line_count`
- `jq -e '.entries[] | select(.path=="contracts/adversarial-verification.md") | .load_when.agents'`
  returns both agent names
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports
  `cslib PASS`

---

### Phase 2: Confirm the Verification Bar and Claim the Files [COMPLETED]

**Goal**: Re-establish the task's full stated verification bar (union survives the upsert; no new
budget violation) and claim both paths via `modified_files` so the postflight commit captures the
uncommitted work.

**Tasks**:
- [x] Re-run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      as the closing gate and confirm the overall exit status and `cslib PASS`. *(deviation:
      altered — `cslib PASS` confirmed; overall exit is 1 due to a pre-existing, unrelated FAIL
      ("deployed script content drift" on `agent-system/extensions/core/scripts/check-extension-docs.sh`)
      caused by another in-flight task's uncommitted edit to that file, not by this task's changes.
      This task's file scope is limited to `agent-system/extensions/cslib/**`; per the plan's own
      risk-mitigation row ("Doc-lint or budget script emits a pre-existing unrelated failure and is
      misread as caused by this change"), the cslib-scoped criterion is what governs this item)*
- [x] Prove the union survives the upsert rather than assuming it: with a headless-Neovim script
      calling `neotex.plugins.ai.shared.extensions.merge.append_index_entries` against a scratch
      index file, apply core's `contracts/adversarial-verification.md` entry first and cslib's
      second (realistic core-then-extension order), then inspect the merged JSON and confirm the
      single surviving entry retains BOTH `general-research-hard-agent` and
      `cslib-research-hard-agent`. Delete the scratch file afterwards. *(completed: single surviving
      entry retained both agent names; scratch file and script deleted)*
- [x] Run `bash .claude/scripts/validate-context-budgets.sh` (read-only invocation of a deployed
      script; not an edit under `.claude/**`) and confirm `cslib-research-hard-agent` appears
      nowhere in the output — the pre-existing violations belong to loaded extensions only, and
      cslib is not a loaded extension in this repository's `.claude-extensions.json`. *(completed:
      8 violations, matching the research report's recorded baseline exactly; `cslib-research-hard-agent`
      appears 0 times)*
- [x] Confirm no file under `.claude/**` was written by this task:
      `git status --short -- .claude/` shows nothing attributable to this work. *(completed: empty
      output)*
- [x] Report both paths in `modified_files` so the implement postflight stages and commits them:
      `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` and
      `agent-system/extensions/cslib/index-entries.json`. Under-report rather than over-report:
      do not add unrelated working-tree paths. *(completed: both already committed at Phase 1's
      green sub-step commit; reported in `.return-meta.json`'s `modified_files`)*
- [x] Confirm the summary artifact and any deliverable text cite durable anchors (file paths,
      section headings, script names) rather than task numbers outside `specs/**`. *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: `modified_files` is hypothesized to contain exactly the two
`agent-system/extensions/cslib/**` paths named above and nothing else. Confirm at implementation
time by diffing the reported list against `git status --short -- agent-system/extensions/cslib/`;
any divergence is reported, not silently absorbed into the claim.

**Files to modify**:
- None beyond Phase 1's two paths — this phase verifies and claims, it does not author.

**Verification**:
- `check-extension-docs.sh` exits zero with `cslib PASS`
- The headless merge simulation output shows one entry carrying both agent names
- `validate-context-budgets.sh` output contains no occurrence of `cslib-research-hard-agent`
- `git status --short -- .claude/` shows no writes from this task
- `modified_files` lists exactly the two cslib source-store paths

---

## Testing & Validation

- [x] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` — Rule R
      hard gate passes; summary reports `cslib PASS` *(completed: `cslib PASS` confirmed; see
      Phase 2 task 1's deviation note for the unrelated overall-exit-code caveat)*
- [x] `jq -e . agent-system/extensions/cslib/index-entries.json` — valid JSON *(completed)*
- [x] `wc -l agent-system/extensions/cslib/context/contracts/adversarial-verification.md` equals the
      entry's declared `line_count` *(completed: both 117)*
- [x] `load_when.agents` contains both `general-research-hard-agent` and
      `cslib-research-hard-agent` *(completed)*
- [x] Headless-Neovim `merge.append_index_entries` simulation retains both agent names after the
      core-then-cslib upsert *(completed)*
- [x] `bash .claude/scripts/validate-context-budgets.sh` shows no new violation naming
      `cslib-research-hard-agent` *(completed: 0 occurrences, 8 pre-existing violations matching
      research baseline)*
- [x] No file written under `.claude/**` *(completed: `git status --short -- .claude/` empty)*

## Artifacts & Outputs

- `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` (new source file,
  claimed for commit)
- `agent-system/extensions/cslib/index-entries.json` (one new entry, claimed for commit)
- `specs/1000_cslib_adversarial_verification_mirror/summaries/01_cslib-h4-contract-mirror-summary.md`

## Rollback/Contingency

Both changes are confined to two files in the source store and touch no deployed or runtime state.
To revert, delete `agent-system/extensions/cslib/context/contracts/adversarial-verification.md`
and remove the `contracts/adversarial-verification.md` entry from
`agent-system/extensions/cslib/index-entries.json` — in that order the pair is consistent at every
intermediate point except one: an index entry with no source file fails Rule R, so remove the
entry FIRST, then the file, when reverting (the mirror of the load-bearing add ordering). If a
revert is needed after committing, `git revert` the implementation commit; no redeploy is required
because cslib is not a loaded extension in this repository.

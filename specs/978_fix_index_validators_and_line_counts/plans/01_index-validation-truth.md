# Implementation Plan: Task #978

- **Task**: 978 - fix_index_validators_and_line_counts
- **Status**: [NOT STARTED]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/978_fix_index_validators_and_line_counts/reports/01_context-index-validation-truth.md
- **Artifacts**: plans/01_index-validation-truth.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The context-index validation layer currently reports success while silently swallowing every
finding it makes: `validate-context-index.sh` pipes `jq` into `while read` in four separate check
blocks, so all `ERRORS`/`WARNINGS` increments happen in a subshell and are discarded. This plan
makes that layer tell the truth end to end: fix the counter-discarding structure, build a
`line_count` regenerator that operates on the source store across all extensions, correct the
~320 stale/null counts it finds, index the 14 currently-unindexed deployed context files, stamp
the generated index with `version`/`generated`, and add two new gates to `check-extension-docs.sh`
(already `verify-deploy.sh` gate 3) so both classes of drift fail loudly in future. Definition of
done is the three-part verification bar in Testing & Validation, plus a clean full
`verify-deploy.sh` run.

### Research Integration

The research report confirmed all four claimed defects empirically and changed the scope in five
ways that this plan is built around:

1. The subshell defect affects **four** check blocks, not one — the path-existence,
   domain-validity, and deprecated-replacement blocks have the identical structure and are
   dormant only because no violations exist today. One process-substitution pattern fixes all
   four (Phase 1).
2. `line_count` is a real budget input consumed by `validate-context-budgets.sh`
   (`line_count * 8` against per-agent hard caps), not decorative metadata (Phases 2-3).
3. True scope is source-level and much larger than the deployed 164-entry view: 444 entries
   across all extensions' `agent-system/extensions/*/index-entries.json`, of which 226 mismatch
   and 94 are `line_count: null`. The regenerator must target the source store, never only the
   deployed copy — a deployed-only fix is wiped by the next redeploy (Phases 2-3).
4. `check-extension-docs.sh` is the recommended home for both new gates: it already has the
   lettered-rule / `orphan_report()` / `ORPHAN_GATE_MODE` framework, already enumerates via
   `_git_deployed_files`, and is already invoked by `verify-deploy.sh` gate 3, so no change to
   `verify-deploy.sh` itself is needed (Phase 7).
5. There is no `literature` orphan — that extension is not loaded. The live orphan set is exactly
   11 core files plus 3 extension strays (email, memory, nvim), all recommended for indexing,
   none for exclusion (Phase 5). Re-verified during planning: `comm -23` of deployed `*.md`
   against indexed paths returns exactly 14.

**Planning-time finding not in the research report** (verified during plan construction, and the
reason Phase 4 exists): `M.append_index_entries` in
`lua/neotex/plugins/ai/shared/extensions/merge.lua` is **append-only with dedupe-by-path** — it
skips any entry whose `path` already exists in the target and never updates it. `sync.lua` also
lists `index.json` in `CONTEXT_EXCLUDE_PATTERNS`, so the deployed index is never overwritten by
file copy either. Consequence: corrected `line_count` values written into the source
`index-entries.json` files would **never reach** `.claude/context/index.json` on redeploy, and the
task's own verification bar ("validate-context-index.sh ... zero after") would be unreachable.
Phase 4 converts that function to upsert semantics, which also gives Defect 5's
`version`/`generated` stamp a natural home in the same write path.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap flag is set; this plan
neither reads nor writes ROADMAP.md.

## Goals & Non-Goals

**Goals**:

- `validate-context-index.sh` reports the true error and warning counts from all six check blocks,
  with no counter increments lost to a subshell.
- A regenerator script computes `line_count` from `wc -l` for every entry in every extension's
  source `index-entries.json`, with a non-mutating check mode and a write mode.
- Every `line_count` in `agent-system/extensions/*/index-entries.json` matches `wc -l` exactly.
- The 14 deployed context files with no index entry get real source-level entries with
  `load_when` metadata grounded in their existing `@`-references.
- Corrected and newly added source entries actually propagate to the deployed
  `.claude/context/index.json` on redeploy.
- The deployed index carries `version` and `generated` top-level fields the schema already
  declares.
- Two new lettered gates in `check-extension-docs.sh` catch both classes of drift on every
  `verify-deploy.sh` run, with the baseline left clean.

**Non-Goals**:

- Wiring `validate-context-budgets.sh` into `verify-deploy.sh`, or fixing its pre-existing
  failures (missing `tier` fields, dead entries, 11 over-budget agents). Its failure count is
  expected to *change* as `line_count` accuracy improves; that is a correct side effect, not a
  regression introduced here.
- Deleting, merging, or rewriting any context file. Every orphan is indexed, none excluded.
- Loading additional extensions, or changing which extensions are active.
- Changing `verify-deploy.sh`'s gate list or gate semantics.
- Re-tiering or restructuring the context index schema beyond adding the two stamp fields it
  already declares.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new gate promoted straight to hard mode breaks the currently-clean `check-extension-docs.sh` baseline | H | H | Sequencing: remediation (Phases 3, 5, 6) lands strictly before the gate (Phase 7). Phase 7 verifies a clean run immediately after adding the rules; the sibling severity variable exists as an escape hatch, not as the landing state. |
| Upsert semantics in `append_index_entries` silently clobber a deployed entry a second extension legitimately declares (first-writer-wins becomes last-writer-wins) | M | L | Phase 4 detects and reports same-path collisions across extensions before changing behavior; if any exist, they are resolved at the source rather than absorbed by the merge. Deployed `index.json` is a generated artifact, so overwriting it from source is the intended direction. |
| Regenerating counts across 19 extensions produces a very broad, hard-to-review diff | M | H | Phase 3 is a standalone commit containing only mechanical `line_count` value changes produced by one generator invocation, with no other edits; every value is independently verifiable by `wc -l`. |
| The 94 `line_count: null` entries belong to unloaded extensions never validated before, and may expose further schema violations once populated | M | M | The generator treats `null` and numeric-mismatch identically (recompute from `wc -l`); Phase 3 runs `validate-extension-index.sh` afterwards to surface any additional source-level problems as findings rather than silent breakage. |
| The extension-loader change that landed on master immediately before this task interacts with the Phase 4 merge.lua edit | M | M | Phase 4 reads the current `merge.lua` and `sync.lua` state before editing rather than assuming the researched shape, and Phase 6 redeploys via the sanctioned `deploy-headless.sh` path and re-verifies rather than trusting the edit in isolation. |
| Corrected `line_count` values make `validate-context-budgets.sh` report more violations | L | H | Explicitly a Non-Goal above; Phase 9 records the before/after count as an observation, and does not treat an increase as a failure. |
| A new script file added under `core/scripts/` without a `provides.scripts` declaration trips the existing Rule Q undeclared-scripts check | M | M | Phase 2 adds the manifest declaration in the same phase as the script file, and runs `check-extension-docs.sh` before closing. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 4 | -- |
| 2 | 3, 5 | 2 |
| 3 | 6 | 1, 3, 4, 5 |
| 4 | 7 | 6 |
| 5 | 8 | 2, 7 |
| 6 | 9 | 7, 8 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Make validate-context-index.sh report true counts [NOT STARTED]

**Goal**: Every check block's `ERRORS`/`WARNINGS` increment reaches the parent shell, and the
summary text is honest about warnings.

**Tasks**:
- [ ] Convert all four `jq ... | while IFS=... read` pipelines to `while ... read ... < <(jq ...)`
      process substitution: the path-existence block, the line-count block, the domain-validity
      block, and the deprecated-entries block.
- [ ] Leave the already-correct C-style "Checking entry fields" loop untouched.
- [ ] Change the summary so a run with `WARNINGS > 0` says so explicitly rather than printing a
      bare `Validation PASSED`; keep the exit code driven by `ERRORS` only, so existing callers
      see no behavior change in verdict.
- [ ] Add an opt-in `--strict` flag that makes a nonzero warning count exit nonzero, documented in
      the script header alongside the existing `--fix` note. Do not make it the default.
- [ ] Update the script's header comment block to describe the corrected behavior and the new
      flag.
- [ ] Confirm the existing `--fix` stub is left as a documented no-op (real regeneration is
      Phase 2's job, and it targets the source store, not this deployed-index script).

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research names four defective pipelines in
`agent-system/extensions/core/scripts/validate-context-index.sh` and one correct C-style loop.
Confirm at implementation time by grepping the file for `| while` and counting matches before
editing; if the count differs from four, reconcile against the actual file rather than the plan,
and note the discrepancy.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-context-index.sh` - process-substitution
  conversion of four blocks, honest summary wording, `--strict` flag, header comment update.

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/validate-context-index.sh` run
  against the current deployed index now reports a **nonzero** warning count matching the number
  of `[WARN]` lines it prints (`... 2>&1 | grep -c '^\[WARN\]'` equals the summary's
  `Warnings:` figure).
- Errors remain 0 and the exit code remains 0 in default mode.
- `bash -n` on the edited script passes.

---

### Phase 2: Build the source-store line_count regenerator [NOT STARTED]

**Goal**: A new, declared, POSIX-shell-styled script computes correct `line_count` values for
every entry in every extension's source `index-entries.json`, with a non-mutating check mode.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/generate-context-line-counts.sh` following the
      surrounding style in that directory: `set -uo pipefail`, the
      `[[ -n "${REPO_ROOT:-}" ]] || . deploy-root-guard.sh` / `EXT_DIR="${EXT_DIR:-...}"` preamble
      used by `check-extension-docs.sh`, `info`/`fail`-style output helpers, and `jq` for all JSON
      reads and writes.
- [ ] Iterate `$EXT_DIR/*/index-entries.json`; for each entry resolve the source file as
      `$EXT_DIR/<ext>/context/<entry.path>` and compute `wc -l`.
- [ ] Treat `line_count: null` and a numeric mismatch identically — both recompute from `wc -l`.
- [ ] Handle a missing source file as a reported problem, never a silent skip and never a written
      `null`.
- [ ] Implement two modes: default/`--check` (report only, exit nonzero when any entry is wrong,
      write nothing) and `--write` (rewrite each `index-entries.json` in place with corrected
      values, preserving key order and formatting as closely as `jq` allows, and reporting a
      per-extension changed-entry count).
- [ ] Preserve every other field on each entry untouched; only `line_count` may change.
- [ ] Add the script to `provides.scripts` in `agent-system/extensions/core/manifest.json` so the
      existing Rule Q undeclared-scripts check stays clean.
- [ ] Write the script header comment explaining why it targets the source store and not the
      deployed `.claude/context/index.json`, citing the source-store/deploy boundary rule by name.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research reports 444 source entries across 19 extensions, of which 226
mismatch numerically and 94 are `null` (124 exact). Confirm at implementation time by running the
new script's `--check` mode and comparing its census to these figures; report the actual numbers
in the phase record rather than restating the plan's. A material divergence means the tree moved
and the numbers here are stale, not that the generator is wrong.

**Files to modify**:
- `agent-system/extensions/core/scripts/generate-context-line-counts.sh` - new file.
- `agent-system/extensions/core/manifest.json` - add the script to `provides.scripts`.

**Verification**:
- `bash -n` on the new script passes.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
  runs to completion, prints a per-extension census, and exits nonzero (there are known
  mismatches at this point).
- `git status --short` confirms `--check` mode wrote nothing.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`
  still passes (Rule Q sees the new script as declared).

---

### Phase 3: Regenerate every source line_count [NOT STARTED]

**Goal**: All `line_count` values across `agent-system/extensions/*/index-entries.json` match
`wc -l` exactly.

**Tasks**:
- [ ] Run the Phase 2 generator in `--write` mode across all extensions.
- [ ] Re-run it in `--check` mode and confirm a clean, exit-0 result.
- [ ] Run `validate-extension-index.sh` over the rewritten sources and record any *other*
      source-level problems it surfaces (structure, path prefixes, resolution) as findings; fix
      only those directly caused by this rewrite, and report the rest without absorbing them into
      this phase.
- [ ] Spot-check at least three entries by hand across three different extensions (including one
      previously-`null` extension) with `wc -l` to confirm the written value is exact, not
      off-by-one.
- [ ] Review the diff to confirm that **only** `line_count` values changed — no reordering, no
      dropped fields, no whitespace-only churn on unrelated entries.

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase is expected to touch roughly 320 entries across up to 19
`index-entries.json` files. The authoritative figure is whatever the Phase 2 `--check` census
reported; confirm the post-write diff's changed-line count is consistent with it, and record both.

**Files to modify**:
- `agent-system/extensions/*/index-entries.json` - mechanical `line_count` corrections only.

**Verification**:
- `--check` mode exits 0 with zero reported mismatches and zero nulls.
- `git diff --stat` shows changes confined to `index-entries.json` files.
- `git diff` inspection confirms every changed line is a `line_count` value.

---

### Phase 4: Upsert semantics and version/generated stamp in the index merge [NOT STARTED]

**Goal**: Regenerated and newly added source entries actually reach the deployed index on
redeploy, and the deployed index carries the `version` and `generated` fields its schema already
declares.

**Tasks**:
- [ ] Re-read `M.append_index_entries` in
      `lua/neotex/plugins/ai/shared/extensions/merge.lua` and its two call sites
      (`shared/extensions/init.lua` load path, `claude/commands/picker/operations/sync.lua`
      re-injection path) in their current state — a loader change landed on master immediately
      before this task, so verify rather than assume the researched shape.
- [ ] Before changing behavior, detect whether any `path` is declared by more than one extension's
      `index-entries.json`; report any collisions found. Under current append-only semantics the
      first declarer wins; under upsert the last would. If collisions exist, resolve them at the
      source and record the resolution.
- [ ] Change the dedupe-by-path branch from skip-if-exists to replace-in-place, preserving the
      entry's position in the array so redeploys produce a stable, diffable ordering.
- [ ] Keep the `tracked.paths` return contract intact so `remove_index_entries_tracked` continues
      to work on unload.
- [ ] Stamp `generated` with an ISO8601 timestamp on every write, and set `version` per the
      schema's semver pattern.
- [ ] Confirm `index.schema.json` needs no change (it already declares both fields as optional
      top-level properties) and that `additionalProperties: false` is not violated.
- [ ] Update the note in `validate-context-index.sh`'s required-fields block that currently states
      the loader does not write `version`/`generated`, since that will no longer be true.
- [ ] Follow the Lua standards in the repo's CLAUDE.md and `neovim-lua.md` rule: 2-space
      indentation, local functions, LuaDoc comments on the changed function.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The plan asserts exactly two call sites for `append_index_entries`
(`init.lua` and `sync.lua`) and one consumer of its `tracked` return
(`remove_index_entries_tracked`). Confirm at implementation time with
`grep -rn "append_index_entries\|remove_index_entries_tracked" lua/` before editing; enumerate and
account for any additional site found.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - upsert semantics plus
  `version`/`generated` stamp in `append_index_entries`.
- `agent-system/extensions/core/scripts/validate-context-index.sh` - correct the stale comment
  about the loader not writing the stamp fields.

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"` loads the
  module without error.
- The changed function's behavior is exercised in Phase 6 against the real deploy; this phase's
  own gate is module load plus a read-through of both call sites confirming neither depends on
  skip-if-exists semantics.

---

### Phase 5: Index the 14 unindexed context files [NOT STARTED]

**Goal**: Every deployed context markdown file has a source-level index entry, with `load_when`
metadata grounded in how each file is actually referenced today.

**Tasks**:
- [ ] Re-derive the live orphan set rather than trusting the list below: diff `*.md` files under
      `.claude/context/` against `.entries[].path` in `.claude/context/index.json`.
- [ ] For the 11 core orphans, add entries to `agent-system/extensions/core/index-entries.json`:
      `guides/hard-mode-routing.md`, `patterns/batch-drain-loop.md`,
      `patterns/checkpoint-before-overflow.md`, `patterns/context-exhaustion-detection.md`,
      `patterns/context-protective-lead.md`, `patterns/lit-stage4a-flow.md`,
      `patterns/subagent-continuation-loop.md`, `patterns/task-lock.md`,
      `patterns/topic-assignment-pattern.md`, `standards/git-staging-scope.md`,
      `standards/orchestrator-runtime-files.md`.
- [ ] Add the three extension strays to their owning extensions:
      `project/email/design/email-to-memory-preferences.md` to
      `agent-system/extensions/email/index-entries.json`, `project/memory/README.md` to
      `agent-system/extensions/memory/index-entries.json`, and
      `project/neovim/domain/extension-deploy-modes.md` to
      `agent-system/extensions/nvim/index-entries.json`.
- [ ] Populate each entry's required fields (`path`, `domain`, `summary`, `line_count`) plus
      `topics`, `keywords`, and `load_when`, matching the field shape used by existing entries in
      the same file. `domain` must be one of `core`, `project`, `system`.
- [ ] Derive `load_when.agents` / `load_when.skills` / `load_when.commands` from each file's
      existing `@`-referencing agents, skills, commands, and rules — the research report's
      reference table is the starting point; re-derive with a grep per file to catch drift.
- [ ] For the five files with zero existing references, choose `load_when` from the file's own
      content and subject matter; do not leave a `load_when` that matches nothing (empty arrays
      mean "never match" per the documented semantics).
- [ ] Run the Phase 2 generator in `--write` mode again so the new entries' `line_count` values are
      exact rather than hand-typed.
- [ ] Do not use task-number citations in any summary or keyword text (deliverable rule); anchor
      descriptions to file paths and concepts.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The orphan set is asserted to be exactly 14 files — 11 core plus 3 extension
strays, with no `literature` orphan (that extension is not loaded). Confirm at implementation time
by re-running the deployed-files-vs-indexed-paths diff before adding anything; if the count is not
14, reconcile against the live result and report the difference.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - 11 new entries.
- `agent-system/extensions/email/index-entries.json` - 1 new entry.
- `agent-system/extensions/memory/index-entries.json` - 1 new entry.
- `agent-system/extensions/nvim/index-entries.json` - 1 new entry.

**Verification**:
- All four files remain valid JSON (`jq empty`).
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/validate-extension-index.sh --check-resolution`
  passes for the added entries.
- The Phase 2 generator's `--check` mode exits 0 (new entries have exact counts).
- Each new entry has a non-empty `load_when` that would match at least one agent, skill, command,
  or task type, or sets `always: true`.

---

### Phase 6: Redeploy and confirm the deployed index tells the truth [NOT STARTED]

**Goal**: The corrected and newly added source entries reach `.claude/context/index.json`, and the
Phase 1 validator reports zero errors and zero warnings against it.

**Tasks**:
- [ ] Confirm the working tree is committed up to this point so the redeploy's overwrite of
      `.claude/` is recoverable.
- [ ] Regenerate the deploy tree with `bash .claude/scripts/deploy-headless.sh` (the sanctioned
      headless equivalent of the interactive full sync).
- [ ] Confirm `.claude/context/index.json` now has top-level `version` and `generated` keys
      (`jq keys`).
- [ ] Confirm the 14 previously-orphaned paths now appear in `.entries[].path`.
- [ ] Confirm previously-stale `line_count` values in the deployed index now match their source
      entries — this is the concrete proof that the Phase 4 upsert change works and that the old
      append-only behavior would have failed here.
- [ ] Run the Phase 1 validator and record the summary.
- [ ] If any warnings remain, trace each to its source entry and fix at the source, then redeploy
      — never by editing `.claude/` directly.

**Timing**: 1 hour

**Depends on**: 1, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None by hand. `.claude/` is regenerated by `deploy-headless.sh`; no file under `.claude/` may be
  hand-authored in this phase or any other.

**Verification**:
- `bash .claude/scripts/validate-context-index.sh` reports `Errors: 0` and `Warnings: 0` and exits
  0 — the second half of the task's first verification-bar criterion.
- `bash .claude/scripts/validate-context-index.sh --strict` also exits 0.
- `jq -r 'keys' .claude/context/index.json` includes `generated` and `version`.
- The deployed-vs-indexed orphan diff returns 0 files.

---

### Phase 7: Add the two new gates to check-extension-docs.sh [NOT STARTED]

**Goal**: Both classes of drift fail loudly on every `verify-deploy.sh` run, with the baseline
left clean.

**Tasks**:
- [ ] Add a per-extension source `line_count` accuracy rule (next unused letter after Q) invoked
      from the per-extension loop alongside `check_undeclared_scripts`: for each entry in that
      extension's `index-entries.json`, compare `line_count` against `wc -l` of
      `$EXT_DIR/<ext>/context/<path>`, failing on mismatch, on `null`, and on a missing source
      file. This catches the 94-null class in unloaded extensions, which the deployed-index
      validator can never see.
- [ ] Add a project-wide deployed-index-orphan rule (the following letter) invoked from the
      project-wide block after `check_context_orphans`: enumerate `.claude/context/**/*.md` via
      the existing `_git_deployed_files "context"` helper and fail on any file absent from
      `.claude/context/index.json`'s `.entries[].path`.
- [ ] Scope the orphan rule to markdown only, so schema and template files that legitimately have
      no index entry are not flagged; document that scope decision in the rule's comment.
- [ ] Give the new rules their own severity variable (sibling to `ORPHAN_GATE_MODE`, defaulting to
      hard) rather than overloading the existing one — these are materially different checks with
      their own remediation timeline. Document the sibling relationship in the comment.
- [ ] Update the script's header comment bullet list and the "Rule letter index" block with both
      new letters, matching the existing entry style.
- [ ] Make no change to `verify-deploy.sh` — gate 3 already invokes this script in full.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: The plan assumes Q is the highest lettered rule currently in use and that
the project-wide block is where the orphan rule belongs. Confirm at implementation time by reading
the current "Rule letter index" header block and the project-wide invocation list before choosing
letters; do not reuse an existing letter.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - two new rule functions, their
  invocations, the sibling severity variable, and the header/rule-index documentation.

**Verification**:
- `bash -n` passes.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`
  exits 0 with `PASS: all extensions OK` — the clean baseline is preserved.
- **Negative test (verification-bar criterion 2)**: create a scratch context markdown file with no
  index entry, redeploy or place it so the gate sees it, confirm the run now FAILs naming that
  file, then remove it and confirm the run passes again. Leave no scratch file behind.
- **Negative test for the line-count rule**: temporarily perturb one `line_count` value in one
  extension's `index-entries.json`, confirm a FAIL naming that entry, then restore it and confirm
  a pass. Restore via a targeted edit, never a destructive git operation on a dirty tree.

---

### Phase 8: Documentation sync [NOT STARTED]

**Goal**: The new script and the `line_count`-to-budget relationship are discoverable from the
documentation the system actually generates and reads.

**Tasks**:
- [ ] Add the regenerator to the "Utility Scripts" list in
      `agent-system/extensions/core/merge-sources/claudemd.md` alongside the existing
      `check-extension-docs.sh` entry, with a one-line description.
- [ ] Add a short note to `agent-system/extensions/core/context/patterns/context-discovery.md`
      recording that the documented "Get line counts for budget calculation" query has a real
      consumer in `validate-context-budgets.sh` (`line_count * 8` against per-agent caps), that
      the counts are kept exact by the regenerator, and that the budget script is not currently
      wired into any automated gate.
- [ ] Update `agent-system/extensions/core/README.md` and/or `EXTENSION.md` if either enumerates
      core scripts, so the new script is not left undocumented.
- [ ] Re-run the generator's `--check` after touching `context-discovery.md`, since editing an
      indexed context file changes its line count.
- [ ] Use durable anchors only — script names, function names, file paths. No task-number
      references in any of these files.

**Timing**: 45 minutes

**Depends on**: 2, 7

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - Utility Scripts entry.
- `agent-system/extensions/core/context/patterns/context-discovery.md` - budget-consumer note.
- `agent-system/extensions/core/README.md` / `EXTENSION.md` - script listing, if applicable.

**Verification**:
- Diff read-through confirms every changed hunk is prose or a list entry, with no executable or
  JSON surface touched.
- `REPO_ROOT=$(pwd) bash .claude/scripts/check-task-references.sh` (the deliverable-rule lint
  gate) passes on the changed files.
- The generator's `--check` mode still exits 0 after the `context-discovery.md` edit.

---

### Phase 9: Final gate and baseline comparison [NOT STARTED]

**Goal**: The full gate set passes and all three verification-bar criteria are demonstrated
together on a freshly deployed tree.

**Tasks**:
- [ ] Redeploy once more via `bash .claude/scripts/deploy-headless.sh` so every source change in
      this task is reflected in `.claude/`.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` in full and confirm every gate passes, including
      gate 3 (`check-extension-docs.sh`) and gate 4 (`check-task-references.sh`).
- [ ] Demonstrate verification-bar criterion 1 by showing the validator's summary both before this
      task's changes (from the research report's recorded baseline) and now.
- [ ] Re-run the Phase 7 negative test once on the deployed copy of the gate script, confirming
      the deployed script — not just the source — carries the new rules.
- [ ] Record `validate-context-budgets.sh`'s violation count as an observation only, noting that
      any change relative to its pre-task output is the expected consequence of accurate
      `line_count` values and is explicitly out of scope.
- [ ] Confirm no file under `.claude/` was hand-authored at any point: every `.claude/` change in
      the final diff must be attributable to `deploy-headless.sh`.

**Timing**: 45 minutes

**Depends on**: 7, 8

**Verification Tier**: full

**Files to modify**:
- None. Verification and reporting only; `.claude/` changes come from the redeploy.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/validate-context-index.sh --strict` exits 0 with zero errors and zero
  warnings.
- The source `line_count` census is clean across all extensions.
- The scratch-orphan negative test fails and then passes on removal, run against the deployed
  script.

---

## Testing & Validation

The task's three verification-bar criteria, each mapped to the phase that proves it:

- [ ] **Criterion 1 (truthful counts)**: `validate-context-index.sh` against the deployed index
      reports a nonzero warning count before the regeneration (Phase 1 verification) and zero
      errors and zero warnings after (Phase 6 and Phase 9 verification).
- [ ] **Criterion 2 (orphan gate bites)**: a deliberately orphaned scratch context file makes
      `check-extension-docs.sh` fail; removing it makes it pass (Phase 7 negative test, re-run
      against the deployed script in Phase 9).
- [ ] **Criterion 3 (exact source counts)**: every `line_count` in
      `agent-system/extensions/*/index-entries.json` equals `wc -l` of its source file (Phase 3,
      re-confirmed in Phases 5, 8, and 9).

Supporting checks:

- [ ] `bash -n` passes on every modified shell script.
- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"` loads
      cleanly.
- [ ] `verify-deploy.sh` exits 0 in full.
- [ ] `check-task-references.sh` passes — no task-number citations outside `specs/`.
- [ ] `validate-extension-index.sh --check-resolution` passes.
- [ ] No file under `.claude/` appears in the diff except as output of `deploy-headless.sh`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/generate-context-line-counts.sh` (new)
- `agent-system/extensions/core/scripts/validate-context-index.sh` (corrected)
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (two new lettered rules)
- `agent-system/extensions/core/manifest.json` (new `provides.scripts` entry)
- `agent-system/extensions/*/index-entries.json` (regenerated `line_count`; 14 new entries across
  core, email, memory, nvim)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (upsert semantics, `version`/`generated`
  stamp)
- `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/context/patterns/context-discovery.md`, core README/EXTENSION.md
  (documentation)
- `.claude/` deploy tree regenerated by `deploy-headless.sh` (generated artifact, never
  hand-authored)
- `specs/978_fix_index_validators_and_line_counts/summaries/01_index-validation-truth-summary.md`

## Rollback/Contingency

Every phase is an independently revertable commit, and the phase ordering is designed so that a
revert at any point leaves a consistent tree:

- **Phases 1, 2, 7, 8** are additive or self-contained to one script; `git revert` of the phase
  commit restores prior behavior with no cross-file coupling.
- **Phase 3** is a single mechanical commit touching only `line_count` values; reverting it
  restores the stale values without affecting any other phase.
- **Phase 4** is the highest-risk revert because it changes shared merge semantics. If the upsert
  change causes deploy problems, revert that commit and redeploy; the source-store corrections from
  Phases 3 and 5 remain valid and simply stop propagating to the deployed index (the pre-task
  status quo), so nothing is left in a broken intermediate state.
- **Phase 5** entry additions are revertable independently; the new gate from Phase 7 would then
  fail, so Phases 5 and 7 must be reverted together if either is rolled back.
- **`.claude/` recovery** is never a git-revert concern: it is a disposable deploy artifact.
  Re-run `bash .claude/scripts/deploy-headless.sh` after any source revert to bring it back into
  agreement with the source store.
- If a destructive git operation is ever needed on a dirty tree during recovery, take a snapshot
  first via `bash .claude/scripts/git-snapshot.sh 978` per the git-workflow rule.

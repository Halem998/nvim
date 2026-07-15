# Implementation Plan: Enforce Every Deployed File Has a Source (Hard Drift Gate)

- **Task**: 864 - Enforce the invariant "every deployed file has a source" by extending the deployed-vs-source drift check into a hard gate, backfilling every deployed-only orphan into its correct owning extension, and repairing the broken symlink-deploy regression.
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 863 (extension store relocation — landed)
- **Research Inputs**: specs/864_enforce_every_deployed_file_has_a_source/reports/01_enforce-every-deployed-file-source.md
- **Artifacts**: plans/01_deployed-file-source-hard-gate.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The invariant "every deployed file under `.claude/` traces to a manifest-declared source" is
currently unenforced for four `provides` categories (agents, commands, context, scripts) and is
violated by 23 deployed-only orphan files spanning three extensions (core, literature, nvim). A
separate but adjacent regression — 19 broken symlinks under `.claude/{agents,commands,skills}/`
created by `install-extension.sh`, whose hardcoded relative target `../extensions/$EXT_NAME/...`
no longer resolves after the source store moved to `agent-system/extensions/` — currently leaves
`/literature`, its research agent, and the cslib/pr-review families unable to resolve their
deployed files at all. This plan repairs the symlinks first (so the gate's first clean run is
green for the right reason), backfills every orphan into its **correct owning extension** (not
uniformly core), extends `check-extension-docs.sh` with one orphan check per category plus a
distinct broken-symlink health check, and only then flips the new checks to hard/blocking.
Definition of done: `check-extension-docs.sh` exits non-zero on any unsourced deployed file or
broken deployed symlink, and exits 0 on the current tree after remediation.

### Research Integration

The research report supplies the authoritative orphan enumeration (per-file proposed source
homes), the per-category comparison-logic design (agents_subdir divergence, context recursive
comparison, scripts subdir-entry convention, `index.json`/`merge_targets` exclusion,
`git ls-files` enumeration), and the fully-evidenced root cause of the symlink regression. Two
facts confirmed during planning extend the report: (1) `install-extension.sh` is **itself a
dual-write file** (byte-identical copies at `.claude/scripts/install-extension.sh` and
`agent-system/extensions/core/scripts/install-extension.sh`, declared in core `provides.scripts`),
so its fix must land byte-identical in both, exactly like `check-extension-docs.sh`; (2)
`install-extension.sh` only *warns* when a command/skill symlink exists pointing elsewhere and does
**not** validate agent symlink targets at all — so re-running it will **not** repair the existing
broken symlinks. They must be deleted first, then recreated. The correct relative target is
`../../agent-system/extensions/$EXT_NAME/...` (verified via `os.path.relpath` from
`.claude/commands/`).

### Prior Plan Reference

No prior plan. This is the first plan for task 864.

### Roadmap Alignment

No `roadmap_flag` in delegation context and no ROADMAP.md consulted — no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Repair all broken `install-extension.sh`-created symlinks under `.claude/{agents,commands,skills}/`
  and fix the hardcoded relative path in both copies of `install-extension.sh` (byte-identical).
- Give every deployed-only orphan (23 files) a real manifest-declared source in its correct owning
  extension (core, literature, or nvim), plus resolve the three flagged ambiguous cases.
- Extend `check-extension-docs.sh` with a per-category orphan check (agents, commands, context,
  scripts) and a distinct broken-deployed-symlink health check.
- Flip the new checks to hard/blocking (contribute to `FAILURES`, non-zero exit) after remediation
  lands, and confirm a clean (exit 0) run on the current tree.

**Non-Goals**:
- Modifying the `.opencode/` deploy tree or its same-named `check-extension-docs.sh` (a materially
  different, out-of-scope tool for a separate deploy tree).
- Touching `loader.lua`'s copy-deploy logic (already symlink-safe; unchanged).
- Adding a `tests` provides category or sourcing `.claude/tests/` (out of scope — not a
  copy-deploy category).
- Fabricating sources for dead, superseded artifacts (`zotero.md`, `skill-zotero`) — these are
  deletion targets, not sourcing targets.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Naive `find`-based orphan scan enumerates gitignored `literature-pyenv/venv/` and `__pycache__/`, producing hundreds of false FAILs | H | M | Use `git ls-files .claude/<category>` for all enumerations (matches research method; naturally excludes gitignored runtime artifacts) |
| New orphan scan treats a dangling symlink as a regular file, crashing `cmp` or silently masking the 19-symlink regression | H | M | Explicit `[[ -L ]]` branch routed to the dedicated broken-symlink check; orphan checks operate only on regular files |
| Fixing `install-extension.sh` rel_path but not deleting existing broken symlinks leaves them broken (script is warning-only / does not validate agent targets) | H | M | Phase 1 deletes broken symlinks first, then re-runs `install-extension.sh` to recreate against the corrected path |
| `install-extension.sh` edit drifts the two byte-identical copies, tripping Rule F (script drift) | M | M | Dual-write byte-identical (source copy first, then `diff` both copies to confirm empty) — same discipline as check-extension-docs.sh |
| Flipping the gate to hard before backfill + symlink repair land makes the script permanently red, training agents to bypass it | H | L | Strict sequencing: all remediation (Phases 1-4) lands and is verified clean in advisory mode (Phase 5) before promotion to blocking (Phase 6) |
| `context/patterns/fork-patterns.md` is a stale duplicate of `docs/fork-patterns.md`; blindly sourcing it entrenches a duplicate | M | M | Phase 4 diffs the two before deciding source-vs-delete |
| `literature-organization.md` owning extension (core vs literature) guessed wrong | L | M | Phase 3 makes the decision explicitly (recommend literature) rather than defaulting to core |
| `commands/README.md` relocated verbatim carries forward its stale "legacy mirror" claim | M | M | Phase 2 rewrites its content to reflect `.claude/` as the primary tree, not just relocates it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |
| 3 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 1-4 touch disjoint file territories
(Phase 1: `install-extension.sh` + symlink tree; Phase 2: core manifest + core sources; Phase 3:
literature manifest + literature sources; Phase 4: nvim manifest + context files + fork-patterns
decision), so they carry no write conflicts.

### Phase 1: Repair broken symlink-deploy regression [COMPLETED]

**Goal**: Restore all broken `install-extension.sh`-created symlinks so `/literature`, its research
agent, and the cslib/pr-review families resolve again, and fix the root-cause relative path in both
copies of `install-extension.sh` so future deploys are correct.

**Tasks**:
- [x] Run a live broken-symlink audit to get the authoritative current list:
      `find .claude/agents .claude/commands .claude/skills -type l ! -exec test -e {} \; -print`
      (excludes the internal gitignored `literature-pyenv/venv/` symlinks, which live under
      `scripts/` and resolve fine). *(completed: confirmed 21 broken symlinks matching the
      research report's enumeration)*
- [x] Fix the hardcoded relative target in **both** copies of `install-extension.sh` — edit
      `agent-system/extensions/core/scripts/install-extension.sh` (source) first, then apply the
      identical edit to `.claude/scripts/install-extension.sh` (deployed). Change `../extensions/`
      to `../../agent-system/extensions/` at all five sites: the `expected_target` and `rel_path`
      in `install_commands` (~lines 93, 103), the `expected_target` and `rel_path` in
      `install_skills` (~lines 129, 139), and the `rel_path` in `install_agents` (~line 168).
      *(completed: all 5 sites fixed in both copies)*
- [x] Confirm the two copies are byte-identical: `diff .claude/scripts/install-extension.sh
      agent-system/extensions/core/scripts/install-extension.sh` must produce no output.
      *(completed: empty diff confirmed)*
- [x] Delete the broken cslib/literature/pr-review symlinks identified by the audit (they block
      recreation because the script only warns on a mismatched existing symlink and does not
      validate existing agent symlink targets at all). *(completed: 19 broken cslib/literature/
      pr-review symlinks deleted)*
- [x] Re-run `install-extension.sh` for the symlink-deploy extensions to recreate the symlinks
      against the corrected path: `bash .claude/scripts/install-extension.sh
      agent-system/extensions/cslib` and `bash .claude/scripts/install-extension.sh
      agent-system/extensions/literature`. *(completed: all symlinks recreated and resolve;
      deviation — see progress file: `merge_index_entries` (an unrelated side effect of running
      install-extension.sh) transiently dropped one pre-existing `context/index.json` entry
      unrelated to cslib/literature; detected via before/after path diff and restored manually,
      no data lost)*
- [x] Delete the dead zotero artifacts without recreating them (no `zotero` extension exists — it
      was absorbed into `literature`): `.claude/commands/zotero.md` and `.claude/skills/skill-zotero`.
      *(completed)*
- [x] Verify every remaining deployed symlink resolves: re-run the audit and confirm empty output;
      explicitly spot-check that `.claude/agents/literature-agent.md` and `.claude/commands/literature.md`
      resolve (`test -e`). *(completed: audit empty, both spot-checks pass)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/install-extension.sh` - fix relative target at 5 sites
- `.claude/scripts/install-extension.sh` - identical fix (byte-identical dual-write)
- `.claude/{agents,commands,skills}/*` - delete broken symlinks, recreate correct ones, delete dead zotero symlinks

**Verification**:
- `find .claude/agents .claude/commands .claude/skills -type l ! -exec test -e {} \; -print` returns nothing
- `test -e .claude/agents/literature-agent.md && test -e .claude/commands/literature.md` succeeds
- `diff` of the two `install-extension.sh` copies is empty

---

### Phase 2: Backfill core-owned orphans [COMPLETED]

**Goal**: Give the four genuinely core-owned orphans a source under `agent-system/extensions/core/`
and declare them in core's manifest.

**Tasks**:
- [x] `rules/no-task-references-in-deliverables.md`: copy the deployed file to
      `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`; add
      `"no-task-references-in-deliverables.md"` to core's `provides.rules`. *(completed)*
- [x] `commands/README.md`: create `agent-system/extensions/core/commands/README.md` and add
      `"README.md"` to core's `provides.commands`. **Rewrite** the content — the deployed copy
      stales-claims `.claude/commands/` is a "Legacy Mirror Directory" superseded by
      `.opencode/commands/`, which is backwards; `.claude/` is the primary Claude Code deploy tree.
      Then overwrite the deployed `.claude/commands/README.md` from the new source so both match.
      *(completed: rewritten to state .claude/ is the primary/active tree, .opencode/ a secondary
      mirror with its own extension-source layer)*
- [x] `scripts/lint/lint-contract-compliance.sh`: copy to
      `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` (sibling of the
      already-sourced `lint/lint-postflight-boundary.sh`); add
      `"lint/lint-contract-compliance.sh"` to core's `provides.scripts`. *(completed)*
- [x] `scripts/validate-handoff.sh`: copy to
      `agent-system/extensions/core/scripts/validate-handoff.sh`; add `"validate-handoff.sh"` to
      core's `provides.scripts`. *(completed)*
- [x] Confirm each new source file is byte-identical to its deployed counterpart (except
      `commands/README.md`, which is deliberately rewritten in both places). *(completed: diff
      empty for all 4)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add rules/commands/scripts entries
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - new source
- `agent-system/extensions/core/commands/README.md` - new source (rewritten content)
- `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` - new source
- `agent-system/extensions/core/scripts/validate-handoff.sh` - new source
- `.claude/commands/README.md` - rewrite deployed copy to match new source

**Verification**:
- `jq -r '.provides.rules[], .provides.commands[], .provides.scripts[]' agent-system/extensions/core/manifest.json` lists all four new entries
- `diff` of each new source vs its deployed copy is empty (README.md matches after rewrite)

---

### Phase 3: Backfill literature-owned orphans [COMPLETED]

**Goal**: Give the eight literature-owned orphans (6 scripts + 2 context patterns) a source under
`agent-system/extensions/literature/`, declare them, and resolve the `literature-organization.md`
guides ownership decision.

**Tasks**:
- [x] Backfill the 6 script orphans to `agent-system/extensions/literature/scripts/` and add each
      to literature's `provides.scripts`: `literature-audit.sh`, `literature-pyenv-provision.sh`,
      `zotero-resolve-pdf.sh`, `.zotero-title-sim.py`, `tests/generate-test-fixtures.py`,
      `tests/test-literature-convert.sh` (ship the `.zotero-title-sim.py` helper alongside its
      caller `zotero-resolve-pdf.sh`). *(completed)*
- [x] Backfill the 2 context patterns to
      `agent-system/extensions/literature/context/project/literature/patterns/` (already covered by
      literature's `"project/literature"` context entry — recursive, no manifest change needed):
      `chunk-file-conventions.md`, `zotero-pdf-resolution.md`. *(completed)*
- [x] Resolve `context/guides/literature-organization.md`: move it under literature's context tree
      at `agent-system/extensions/literature/context/guides/literature-organization.md` and add
      `"guides"` to literature's `provides.context` (research recommendation (a)). Confirm the
      deployed file at `.claude/context/guides/literature-organization.md` still traces to a source
      after the move (it is deployed under `.claude/context/guides/` by whichever extension declares
      the `guides` entry — verify the new literature `guides` entry produces it). *(completed:
      literature now declares "guides" alongside core's pre-existing "guides" entry; no filename
      collision between the two extensions' guides/ trees)*
- [x] Confirm each new source file is byte-identical to its deployed counterpart. *(completed:
      diff empty for all 9 new source files)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/literature/manifest.json` - add scripts entries + `"guides"` context entry
- `agent-system/extensions/literature/scripts/*` - 6 new source files
- `agent-system/extensions/literature/context/project/literature/patterns/*` - 2 new source files
- `agent-system/extensions/literature/context/guides/literature-organization.md` - new source

**Verification**:
- `jq -r '.provides.scripts[], .provides.context[]' agent-system/extensions/literature/manifest.json` lists the 6 scripts and `"guides"`
- `diff` of each new source vs its deployed copy is empty

---

### Phase 4: Backfill nvim orphan and resolve ambiguous cases [COMPLETED]

**Goal**: Backfill the nvim-owned context orphan and resolve the `fork-patterns.md` duplicate
question with a content diff.

**Tasks**:
- [x] `context/project/neovim/domain/extension-deploy-modes.md`: copy the deployed file to
      `agent-system/extensions/nvim/context/project/neovim/domain/extension-deploy-modes.md`
      (already covered by nvim's `"project/neovim"` recursive context entry — no manifest change
      needed). Optionally extend its content to document the `install-extension.sh` relative-path
      fragility repaired in Phase 1 (research Context Extension recommendation). *(completed:
      extended with a new "Relative-path fragility (regression precedent)" section documenting
      the Phase 1 repair; also corrected the two stale `../extensions/...` example symlink
      targets in the existing table to the corrected `../../agent-system/extensions/...` form)*
- [x] `context/patterns/fork-patterns.md`: diff the deployed
      `.claude/context/patterns/fork-patterns.md` against the existing
      `agent-system/extensions/core/docs/fork-patterns.md`. If identical, treat `docs/fork-patterns.md`
      as canonical and `git rm .claude/context/patterns/fork-patterns.md` (no new source). If
      diverged, add `context/patterns/fork-patterns.md` as a core source under
      `agent-system/extensions/core/context/patterns/` (covered by core's `"patterns"` entry).
      Record the decision in the implementation summary. *(completed: byte-identical (confirmed
      via diff, empty output) — `git rm .claude/context/patterns/fork-patterns.md`; also removed
      its now-dangling `context/index.json` metadata entry (path `patterns/fork-patterns.md`,
      domain `core`) since it did not trace to any current index-entries.json fragment and would
      otherwise point agents at a deleted file — see progress file deviation)*
- [x] Backfill the four remaining core `context/patterns` orphans to
      `agent-system/extensions/core/context/patterns/` (covered by core's `"patterns"` entry, no
      manifest change): `batch-drain-loop.md`, `context-protective-lead.md`,
      `topic-assignment-pattern.md`, and `hard-mode-routing.md` (the last under
      `agent-system/extensions/core/context/guides/`, covered by core's existing `"guides"` entry).
      *(completed)*
- [x] Confirm each new source file is byte-identical to its deployed counterpart. *(completed:
      diff empty for all 5 new/backfilled source files)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/nvim/context/project/neovim/domain/extension-deploy-modes.md` - new source
- `agent-system/extensions/core/context/patterns/{batch-drain-loop,context-protective-lead,topic-assignment-pattern}.md` - new sources
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` - new source
- `agent-system/extensions/core/context/patterns/fork-patterns.md` OR `.claude/context/patterns/fork-patterns.md` (deletion) - per diff decision

**Verification**:
- Every deployed `.claude/context/` file (excluding `index.json` and other `merge_targets`-produced files) traces to a source
- `diff` of each new source vs its deployed copy is empty
- fork-patterns decision recorded

---

### Phase 5: Extend check-extension-docs.sh with orphan + symlink checks (advisory) [IN PROGRESS]

**Goal**: Add one deployed-orphan check per category (agents, commands, context, scripts) plus a
distinct broken-deployed-symlink check, landing byte-identical in both copies, initially at
**info/advisory** level, and confirm the checks report zero issues on the now-remediated tree.

**Tasks**:
- [ ] Add per-category orphan checks that, for each category, build the set of
      `git ls-files .claude/<category>` (regular files only) and diff against the union of every
      extension's `provides.<category>` entries resolved against every extension's own source tree.
      Honor the per-category divergences from research: `agents` uses the `agents_subdir` override
      (Claude Code `"agents"`); `context` compares recursively (directory entries expand to their
      file trees; bare-filename entries match themselves); `scripts` entries may contain `/`
      (source_dir/scripts/<entry> → target_dir/scripts/<entry>).
- [ ] Exclude from the context check any `merge_targets`-produced file: `context/index.json` and
      any other merge-target output — do not flag them (they are not produced by `provides.context`).
- [ ] Add a distinct `check_broken_deployed_symlinks` function: for every symlink under
      `.claude/{agents,commands,skills}/`, test `[[ -e "$f" ]]`; report each broken one with a
      message that names `install-extension.sh`'s relative-path math as the likely cause (so a
      future reader does not mistake it for a missing manifest source). Route symlinks to this check
      via an explicit `[[ -L ]]` branch so the orphan checks never `cmp` a dangling symlink.
- [ ] Keep the new checks at info/advisory level for this phase (they must not yet contribute to
      the blocking `FAILURES` count).
- [ ] Land the edits byte-identical in both `agent-system/extensions/core/scripts/check-extension-docs.sh`
      (source, edit first) and `.claude/scripts/check-extension-docs.sh` (deployed). Confirm with
      `diff` (empty output). The script lints itself, so the new source files and manifest entries
      added in Phases 2-4 must already satisfy `check_manifest_entries`.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm the new checks report **zero**
      orphans and **zero** broken symlinks (proving Phases 1-4 are complete), and that the script's
      overall exit code is unchanged (still exits per pre-existing FAILURES only).
- [ ] Do any destructive testing of the comparison logic (e.g. simulating orphans/broken symlinks)
      in the scratchpad against fake project directories, never against the real `.claude/` tree.

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - add 5 new checks (advisory)
- `.claude/scripts/check-extension-docs.sh` - identical edit (byte-identical dual-write)

**Verification**:
- New checks print 0 orphans (all 4 categories) and 0 broken symlinks
- `diff` of the two `check-extension-docs.sh` copies is empty
- Full script run still exits per pre-existing behavior (no new blocking failures yet)

---

### Phase 6: Promote checks to hard gate and verify green [NOT STARTED]

**Goal**: Flip the new orphan and broken-symlink checks from advisory to blocking so any unsourced
deployed file or broken deployed symlink contributes to `FAILURES` and forces non-zero exit; then
confirm a clean (exit 0) run on the remediated tree and wire the gate into CI/precommit if not
already present.

**Tasks**:
- [ ] Promote the five new checks so their findings increment `FAILURES` (the existing non-zero
      exit at `FAILURES>0` then makes them blocking). Land byte-identical in both copies; confirm
      with `diff`.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and confirm it exits 0 (all orphans
      backfilled, all symlinks repaired, both dual-write pairs in sync).
- [ ] Confirm the gate is wired to run automatically (CI workflow and/or precommit hook). If a
      wiring point already invokes `check-extension-docs.sh`, no change is needed; otherwise add the
      minimal wiring. Do not create PRs or push.
- [ ] Optionally add a short rule-letter index comment block to the script header mapping the now
      10+ rules (including the new ones) to one-line descriptions (research recommendation).
- [ ] Write the implementation summary recording: orphans backfilled per extension, symlink repair
      outcome, the `fork-patterns.md` decision, and the `literature-organization.md` ownership
      decision.

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - promote checks to blocking
- `.claude/scripts/check-extension-docs.sh` - identical edit
- CI/precommit wiring file - only if not already invoking the script

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh; echo $?` prints 0 on the clean tree
- Introducing a temporary fake orphan (in scratchpad-simulated fixture, or a throwaway deployed
  file reverted immediately) causes a non-zero exit — confirming the gate is hard
- `diff` of the two `check-extension-docs.sh` copies is empty

---

## Testing & Validation

- [ ] `find .claude/agents .claude/commands .claude/skills -type l ! -exec test -e {} \; -print` returns no broken symlinks
- [ ] `.claude/agents/literature-agent.md` and `.claude/commands/literature.md` resolve
- [ ] Every deployed file under `.claude/{agents,commands,context,scripts,rules}` (excluding `merge_targets` output and intentional symlinks) traces to a manifest-declared source
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 on the remediated tree
- [ ] A simulated unsourced orphan or broken symlink causes non-zero exit (hard gate confirmed)
- [ ] Both `install-extension.sh` copies are byte-identical; both `check-extension-docs.sh` copies are byte-identical
- [ ] No task-number references introduced in any file outside `specs/**`

## Artifacts & Outputs

- plans/01_deployed-file-source-hard-gate.md (this file)
- summaries/01_deployed-file-source-hard-gate-summary.md (on completion)
- ~15 new source files under `agent-system/extensions/{core,literature,nvim}/`
- Updated `agent-system/extensions/{core,literature}/manifest.json`
- Repaired symlinks under `.claude/{agents,commands,skills}/`
- Extended, hard-gated `check-extension-docs.sh` (both copies) and fixed `install-extension.sh` (both copies)

## Rollback/Contingency

- All work is local (no PR/push per pr-prohibition). Revert with `git restore` / `git checkout` of
  the touched paths if the gate turns out over-strict.
- If a backfilled source home turns out wrong (e.g. `literature-organization.md` should have stayed
  core), the fix is a one-line manifest edit plus moving the source file — the gate itself is
  unaffected.
- The symlink repair is idempotent: if recreation misfires, delete the offending symlinks and
  re-run `install-extension.sh` for the affected extension.
- Promotion to hard gate (Phase 6) is the only irreversible-feeling step; keep it last so the tree
  is already clean, and revert the promotion edit alone (leaving backfill intact) if CI needs a
  grace period.

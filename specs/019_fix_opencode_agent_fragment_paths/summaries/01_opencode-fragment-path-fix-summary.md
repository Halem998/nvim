# Implementation Summary: Fix opencode agent-fragment path resolution and validator fail-fast

- **Task**: 19 - Fix opencode agent-fragment path resolution and validator fail-fast
- **Status**: [COMPLETED]
- **Started**: 2026-08-11T00:00:00Z
- **Completed**: 2026-08-11T02:10:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_opencode-fragment-path-fix.md, reports/01_opencode-fragment-path-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

All 12 `agent-system/extensions/*/opencode-agents.json` fragments referenced `{file:...}`
directories that no deploy path ever populates, causing `validate_opencode_fragment` to fail and
`generate_opencode_json` to discard entire extension agent sets on the first miss. This
implementation repointed every fragment at `.claude/agents/<agent>.md`, corrected `lean`'s bogus
directory and `present`'s stale `slides` basename/key, and converted the validator/generator pair
from fail-fast/per-fragment to report-all/per-agent-key degradation. All six plan phases completed
with zero deviations from the plan's intended approach.

## What Changed

- `agent-system/extensions/{epidemiology,filetypes,formal,latex,nix,nvim,present,python,typst,web,z3}/opencode-agents.json` -
  repointed 32 `{file:.opencode/agent/subagents/<name>.md}` references to
  `{file:.claude/agents/<name>.md}` (directory-prefix swap only; basenames unchanged)
- `agent-system/extensions/lean/opencode-agents.json` - repointed 2 references from the bogus
  `{file:.claude/extensions/lean/agents/<name>.md}` to `{file:.claude/agents/<name>.md}`
- `agent-system/extensions/present/opencode-agents.json` - corrected the `slides` entry's
  `{file:...}` basename from `slides-agent.md` to `slides-research-agent.md`, and renamed the
  agent key from `slides` to `slides-research` to match its manifest-derived name
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` -
  `M.validate_opencode_fragment` now accumulates every unreadable `{file:...}` reference in a
  fragment (sorted by agent name for determinism) instead of returning on the first miss, and
  additionally returns a `missing_by_key` map (agent_name -> file_path) as a third return value
  for direct consumption by the generator; `M.generate_opencode_json`'s merge loop now degrades
  per-agent-key (merging every agent whose own reference resolves and skipping only the
  individual offending key(s)) instead of discarding an entire fragment, with a rewritten `WARN`
  message naming every skipped key and its missing path and stating that the rest of the
  fragment was merged

## Decisions

- Adopted Option (a) in full, per the research and plan: repoint at `.claude/agents/`, zero new
  deploy machinery. Options (b) (new `.opencode/agent/subagents/` deploy step) and (c) (gate
  opencode processing off) were not revisited — both remain explicitly rejected.
- Added a third Lua return value (`missing_by_key`) to `validate_opencode_fragment` rather than
  having the generator re-derive the miss set from the error message string. This is additive
  (Lua multi-return) and does not change the type of the first two return values, so the plan's
  "keep the two-value shape unchanged in type" constraint holds.
- Phase 3's literal plan-stated verification grep (`grep -rn '.claude/extensions/lean'
  agent-system/extensions/`) is broader than the actual bug: it also matches many legitimate,
  unrelated `@.claude/extensions/lean/context/...` documentation self-references elsewhere in the
  `lean` and `cslib` extensions. The narrower, bug-scoped check
  (`grep -rn '.claude/extensions/lean/agents' agent-system/extensions/*/opencode-agents.json`)
  was used instead and returns zero matches, confirming the actual fix without a false-positive
  trap from the broader pattern.

## Plan Deviations

- None (implementation followed plan; the Phase 3 verification-grep note above is a measurement
  precision clarification, not a deviation from any task or edit the plan specified).

## Impacts

- Any project loading `nix` or `nvim` (the two fragment-owning extensions currently active in
  this repo) and opted into managed `opencode.json` generation now gets both extensions' agents
  merged with zero validation warnings, where previously both fragments were silently discarded
  whole.
- Any future stale rename or typo in a fragment's `{file:...}` value now degrades to a single
  named, skipped agent key with the rest of the fragment intact, rather than amplifying into a
  whole-extension silent drop.
- No `.claude/**` or `.opencode/**` files were touched; the fix took effect purely through the
  source-store edit path, confirmed by `git status` scope checks in Phase 6.

## Follow-ups

- None from this task's scope. See **Scope Boundaries and Sibling Interactions** below for the
  two out-of-scope facts recorded for sibling tasks.

## Noise Measurement

All four measurement arms were run before (Phase 1) and after (Phase 6) the fix, using identical
commands. Each arm is reported with its scope explicit; a structural number is never reported as
if it were a live one.

### Structural arm A: basename-vs-manifest mismatch (all 12 fragments, deploy-independent)

| | Before | After |
|---|---|---|
| Total `{file:...}` references (all 12 fragments) | 34 | 34 |
| Basename-vs-manifest mismatches | 1 (`present`'s `slides-agent.md`) | 0 |

Measured reference count (34) corrects the research's ~30 estimate.

### Structural arm B: resolvability from repo root today

| | Before | After |
|---|---|---|
| Resolvable | 0 / 34 | 4 / 34 |
| Unresolvable | 34 / 34 | 30 / 34 |

This arm is bounded by which extensions are currently deployed to `.claude/agents/` in *this*
repo (only `nix` and `nvim` of the 12 fragment-owning extensions are loaded here today), so its
after-value (4) is deploy-state-dependent, not a measure of the fix's structural completeness —
Structural arm A (0 mismatches across all 12, independent of what's loaded) is the
deploy-independent confirmation that every reference *would* resolve for any project where its
extension is loaded, per the plan's stated Goal.

### Key-parity arm (all 12, deploy-independent; mirrors `verify.lua`'s `verify_opencode_json_merge`)

| Extension | Before: missing_from_fragment | Before: missing_from_manifest | After: missing_from_fragment | After: missing_from_manifest |
|---|---|---|---|---|
| epidemiology | 2 | 2 | 2 | 2 |
| lean | 2 | 0 | 2 | 0 |
| present | 5 | 1 | 4 | 0 |

The `slides` -> `slides-research` rename cleared present's one `missing_from_manifest` entry and
its own corresponding `missing_from_fragment` entry, dropping present from 5+1 to 4+0.
epidemiology's and lean's entries persist entirely unchanged — see **Residual Noise Inventory**
below.

### Live arm (loaded extensions only, end-to-end through the real generator)

Extensions loaded in this repo with `opencode-agents.json` fragments: `nix`, `nvim` (of the 5
loaded extensions total — `core`, `email`, `memory` carry no such fragment).

| | Before | After |
|---|---|---|
| `WARN` lines emitted | 2 (one per fragment, first-miss only) | 0 |
| `jq '.agent \| keys \| length'` on generated `opencode.json` | 9 (base template + core only; zero nix/nvim agents merged) | 13 (+4: `nix-research`, `nix-implementation`, `neovim-research`, `neovim-implementation`) |

Method: headless `nvim --headless -u NONE -c "luafile ..."` driving
`merge.generate_opencode_json(project_dir, config.claude())` directly, with a temporary
`opencode.json.managed` marker created and deleted within the measurement, and `vim.schedule`
patched to run synchronously so scheduled `WARN` notifications are captured. `git status
--porcelain` confirmed clean of new root-level files after each run.

### Measured reduction

Live-arm `WARN` count fell from 2 to 0 for the extensions loaded in this repo: **100% of the live,
end-to-end validation-warning noise this task's `{file:...}` path bugs caused was eliminated.**
This matches the research's "essentially 100%" hypothesis for the path-noise class specifically.
It is not the residual noise measured by the independent key-parity arm below, which this fix
never targeted.

### Residual Noise Inventory (enumerated by source and extension, not a percentage)

`verify.lua`'s `verify_opencode_json_merge` key-parity check (a separate code path from
`validate_opencode_fragment`/`generate_opencode_json`, reached from `verify_extension` on the
reload path) still reports the following after this fix:

- **epidemiology**: `missing_from_fragment` = `epi-implement`, `epi-research` (2);
  `missing_from_manifest` = `epidemiology-implementation`, `epidemiology-research` (2). The
  fragment's agent keys (`epi-research`, `epi-implement`) do not match the manifest-derived names
  (`epidemiology-research`, `epidemiology-implementation`) — a naming-convention mismatch between
  the fragment's short keys and the manifest's `provides.agents` filenames, not a `{file:...}`
  path problem.
- **lean**: `missing_from_fragment` = `lean-implementation-hard`, `lean-research-hard` (2);
  `missing_from_manifest` = none (0). `lean`'s manifest declares 2 additional hard-mode agents
  that this fragment intentionally does not cover — the fragment covers fewer agents than the
  manifest declares, by design.
- **present**: `missing_from_fragment` = `pptx-assembly`, `slide-critic`, `slide-planner`,
  `slidev-assembly` (4); `missing_from_manifest` = none (0, cleared by this fix's `slides` ->
  `slides-research` rename). The fragment intentionally covers 5 of `present`'s larger agent set.

All three residuals share the same root cause: each fragment intentionally covers fewer agents
than its extension's manifest declares. This is categorically distinct from the `{file:...}`
path/stale-basename noise this task fixed, and this task does not attempt to close it — see the
plan's Non-Goals and the research's key-parity finding. A sibling task inherits this exact list
rather than a percentage.

## Scope Boundaries and Sibling Interactions

Two out-of-scope facts, recorded verbatim enough that a sibling task reader needs no further
archaeology:

1. **OpenCode content-flavor gap (unchanged by this fix).** The `.claude/agents/*.md` files this
   fix now resolves are Claude-Code-flavored: they carry `model:` YAML frontmatter and internal
   `@.claude/context/...` self-references, and no OpenCode-flavored agent body exists anywhere in
   the source store for these 12 extensions. This fix makes every `{file:...}` reference
   *resolve* and restores all 18 previously-dropped agents to the generated `opencode.json`; it
   does **not** make those agents semantically correct OpenCode prompts. That gap is pre-existing,
   neither introduced nor worsened here, and remains open.
2. **`.opencode/extensions/` mirror interaction (not touched by this fix, by design).** That
   mirror tree has already independently diverged from and self-corrected `agent-system/
   extensions/` for `nix` and `present` (and `lean`): the mirror's `present` fragment already used
   the key `slides-research`, and the mirror's `nix` fragment already used a self-contained
   `{file:.opencode/extensions/nix/agents/<name>.md}` convention instead of the shared
   `.opencode/agent/subagents/` path. A naive one-way canonical-to-mirror sync would regress both
   already-fixed spots. Separately, and independent of that: **the OpenCode config preset reads
   its fragments from `.opencode/extensions/`, not from the source store this task edited**, so
   this fix changes nothing about the mirror's own live behavior — nothing done here overwrites or
   interacts with `.opencode/extensions/` in any way.

## Verification

- Build: N/A (no build step for Lua/JSON fragment edits)
- Tests: Passed — `jq empty` on all 12 fragments; repo-wide grep confirms zero
  `opencode/agent/subagents` or bogus `.claude/extensions/lean/agents` references remain in any
  fragment; `merge.lua` loads clean under `nvim --headless`; headless harnesses confirmed
  deterministic multi-miss reporting (Phase 4) and per-agent-key degradation (Phase 5); live
  end-to-end generation for loaded extensions (`nix`, `nvim`) emits zero warnings and contains all
  4 expected restored agent keys
- Files verified: Yes
- `git status --porcelain` after Phase 6 cleanup shows no `.claude/**`, no `.opencode/**`, and no
  stray root-level files from this task's work
- `check-task-references.sh` confirms zero task-number citations in any edited deliverable

## References

- `specs/019_fix_opencode_agent_fragment_paths/reports/01_opencode-fragment-path-fix.md`
- `specs/019_fix_opencode_agent_fragment_paths/plans/01_opencode-fragment-path-fix.md`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`M.validate_opencode_fragment`,
  `M.generate_opencode_json`)
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` (`verify_opencode_json_merge`) — source of
  the residual key-parity noise inventoried above

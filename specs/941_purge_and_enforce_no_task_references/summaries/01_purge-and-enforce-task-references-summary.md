# Implementation Summary: Task #941

- **Task**: 941 - Purge ephemeral task-management references from deliverables and enforce the rule going forward
- **Status**: [IN PROGRESS]
- **Started**: 2026-07-28
- **Completed**: (partial — Phases 1-6 of 15)
- **Effort**: ~9.5 hours of the estimated 18
- **Dependencies**: None
- **Artifacts**: plans/01_purge-and-enforce-task-references.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Completed the three-phase prevention foundation (Phases 1-3) plus three purge phases (4-6),
clearing `agent-system/extensions/core/**` entirely (context/, docs/, scripts/, skills/,
commands/, agents/, rules/, hooks/, merge-sources/ all report 0). Before starting the purge, a
small correction was applied to `check-task-references.sh`: it gained an optional path-scope
argument so per-subtree finding counts could be verified (required by Phase 4 onward's
verification steps), with the no-argument/`--quiet`-only behavior kept byte-for-byte unchanged.
One new exemption-taxonomy category (test fixtures for the reference-pattern detector itself)
was discovered and documented during Phase 5. Nine purge phases (7-14) and the blocking hook flip
(Phase 15) remain; all are unblocked. Live baseline dropped from 1,223 to 876 occurrences
(agent-system/extensions 216, .opencode 610, lua 32, .memory 18) across this dispatch.

## What Changed

- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` — new. Sole home of
  `TASK_SEP`/`TASK_PATTERN`/`PHASE_PATTERN` (copied byte-for-byte from the pre-existing hook),
  `is_exempt_path` (path-level `specs/**` exemption), and `strip_exempt_regions` (awk-based
  content-level exemption via the `task-ref-ok:begin/end` block marker and bare `task-ref-ok`
  inline marker).
- `agent-system/extensions/core/scripts/check-task-references.sh` — new. Repo-wide lint gate:
  sources the shared library (never defines patterns locally; exits 2 if the library cannot be
  found), enumerates `git ls-files` under `agent-system/extensions`, `.opencode`, `lua`, and
  `.memory`, skips `specs/**` via `is_exempt_path`, strips exempt regions, greps the remainder
  for `PHASE_PATTERN`/`TASK_PATTERN`, and reports `path:line:matched-text`. Exit 0 clean / 1
  findings / 2 environment error. `--quiet` suppresses per-finding lines. First live baseline:
  1,223 unexempted occurrences across the four trees (563 / 610 / 32 / 18) — exactly 5 below the
  research's pre-purge 1,228, matching the 5 occurrences this dispatch's own Phase 1 purged.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — added gate 4
  ("Task-reference lint (check-task-references.sh --quiet)"), mirroring gate 3's doc-lint
  structure exactly (source-store-only `[SKIP]` guard, not-deployed `fail`, quiet invocation).
- `agent-system/extensions/core/manifest.json` — declared `check-task-references.sh` and
  `lib/task-reference-patterns.sh` in `provides.scripts`, at their true alphabetical positions.
- `agent-system/extensions/core/root-files/settings.local.json` — three permission entries for
  `check-task-references.sh`, mirroring the existing `check-extension-docs.sh` trio.
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — added an
  `## Exemption Taxonomy` section (marker convention plus the five-category table: `specs/**`
  path exemption, commit-message convention examples, command-usage examples, quoted historical
  anti-patterns, placeholder-bearing prose); wrapped its own **Before** anti-pattern block in a
  marked exempt region; rewrote `## Enforcement` to three accurate, verified-true layers (lint
  gate, write-time gate stated as presently advisory, and the four agent-contract files that
  actually carry the bullet), stated the four-tree deliverable boundary unambiguously, and
  recorded the known extension-implementation-agent coverage gap as a named, out-of-scope
  follow-up.
- `agent-system/extensions/core/rules/git-workflow.md` — converted its own commit-message
  examples to the placeholder form its Standard Actions table already uses (Single-Task
  Operations example, and the first/third Examples-block entries), retaining exactly one
  concretely-rendered example (`task 259 phase 2: implement modal semantics evaluator`) wrapped
  in a `task-ref-ok:begin/end` region with reason `canonical rendered commit-message example` —
  this is the taxonomy's named self-trip test case.
- `agent-system/extensions/core/agents/general-implementation-agent.md` and
  `general-implementation-hard-agent.md` — each gained a MUST-NOT bullet against citing task
  numbers outside `specs/**`, reusing the pre-existing cslib wording verbatim.

## Decisions

- Category 2 (commit-message convention examples) converts to placeholders rather than granting
  `git-workflow.md` a blanket path exemption — a path allowlist would immunize real future
  violations elsewhere in the same file. This was explicitly considered and rejected, per the
  plan's own instruction.
- The exemption marker's required reason is carried on the begin marker (block form) or the
  inline marker line (inline form); the end marker may be bare. This keeps the convention
  implementable as a single small `awk` pass in `strip_exempt_regions` without needing a
  reason-matching contract on the closing token.
- `check-task-references.sh` looks for the shared library at the deployed path first, falling
  back to the source-store path, so a `REPO_ROOT=$(pwd)` source-store invocation works before any
  deploy has run (this task's own Phase 1-2 verification depended on this).

## Plan Deviations

- **Task 1.4** (git-workflow.md taxonomy application) altered: the plan's task text named
  `todo: archive 3 completed tasks (336, 337, 338)` as one of git-workflow.md's 3
  `TASK_PATTERN` occurrences, but that string does not actually match the pattern (a `(` follows
  the separator where a digit is required). The real 3rd match was `task 334: complete research`
  in the Single-Task Operations example — a different section than the named `Examples` block.
  Converted the actual matching occurrence to placeholder form; also genericized the
  named-but-non-matching archive line for consistency with the Standard Actions table above it.
  The asserted occurrence *count* (3) was correct; only the narrative description of which three
  strings matched was off, and this was reconciled against the live file per the Scope
  Hypothesis's own instruction.
- **Task 2 manifest-ordering note** altered: the plan's parenthetical claimed
  `check-task-references.sh` "sorts immediately before `check-extension-docs.sh`" — true
  alphabetical order in the already-sorted `provides.scripts` array instead places it between
  `check-runtime-file-tracking.sh` and `check-vault-threshold.sh`. Inserted at the correct
  position, consistent with the array's existing strict ordering; the "declare it, alphabetical"
  intent was preserved even though the plan's own example position was wrong.

## Verification

- Build: N/A (bash scripts + markdown only)
- Tests: `bash -n` passed on all three new/modified `.sh` files
  (`check-task-references.sh`, `verify-deploy.sh`, `lib/task-reference-patterns.sh`).
  `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
  runs correctly end-to-end (exit 1, expected — the tree is still dirty pending Phases 4-14);
  unknown-flag and missing-library cases both correctly exit 2.
  `jq -e '.provides.scripts | index(...)'` confirms both manifest entries;
  `grep -c` confirms the 3 `settings.local.json` permission entries.
  Phase 1's shared-library `TASK_SEP`/`TASK_PATTERN`/`PHASE_PATTERN` assignments diff
  byte-for-byte against the pre-existing hook's copies. `strip_exempt_regions` verified 0
  residual matches on both edited rule files and both edited agent files.
- Files verified: Yes — all new/modified files read back and content-checked after each edit.

## What Changed (this continuation: Correction 1 + Phases 4-6)

- `agent-system/extensions/core/scripts/check-task-references.sh` — amended to accept an
  optional trailing `PATH_SCOPE` positional argument (after `--quiet` if present), validated to
  fall under one of the four `TREE_ROOTS` (exit 2 otherwise). The no-argument and `--quiet`-only
  forms are unchanged byte-for-byte (confirmed: same 4-tree scan, same totals, same exit codes
  before/after). Header usage text updated; no manifest change needed.
- **Phase 4**: purged all 147 occurrences under `agent-system/extensions/core/context/` (31
  files) — README, contracts, formats, guides, meta, orchestration, patterns, reference,
  standards, templates, workflows.
- **Phase 5**: purged all 121 occurrences under `agent-system/extensions/core/{docs,scripts}/`
  (docs 70, scripts 51). Discovered and documented a 6th exemption-taxonomy category ("Test
  fixtures for the reference-pattern detector itself") for
  `scripts/tests/test-validate-no-task-references.sh` and `scripts/tests/test-census-count.sh`,
  which deliberately author literal `task N` strings as regex-assertion inputs — marked with
  `task-ref-ok:begin/end` rather than converted to placeholders (a placeholder never matches
  `[0-9]+` and would silently disable the positive-match assertions).
- **Phase 6**: purged all 79 occurrences (corrected from the plan's stated 84 — see Plan
  Deviations) under `agent-system/extensions/core/{skills,commands,agents,rules,hooks,merge-sources}/`,
  including both task-description-named sites (`commands/orchestrate.md`'s cross-batch passage,
  restated without a concrete example; `skills/skill-orchestrate/SKILL.md`'s init-marker
  comment, reduced to the mechanism name). Two recurring citation clusters were resolved with a
  single reused durable-anchor phrase each: 14 "task 796" (mandatory topic-assignment decision)
  citations across skills/commands/agents, and the "task 809"/"task 810" (cross-task
  `file_scope` overlap check / a gate-in refactor) cluster repeated identically across
  `plan.md`/`research.md`/`revise.md`.
- `agent-system/extensions/core/context/README.md` through `workflows/task-breakdown.md` (31
  files), `docs/architecture/*.md` (5 files) plus `docs/examples/`, `docs/fork-patterns.md`,
  `docs/guides/*.md`, `docs/reference/standards/multi-task-creation-standard.md` (7 files),
  `scripts/*.sh` (10 files) plus `scripts/tests/*.sh` (2 files), `skills/*/SKILL.md` (9 files),
  `commands/*.md` (6 files), `agents/*.md` (4 files), `rules/artifact-formats.md`,
  `rules/no-task-references-in-deliverables.md` (Category 6 addition),
  `hooks/{claude-stop-notify,wezterm-clear-task-number,wezterm-utils}.sh`,
  `merge-sources/claudemd.md`.

## Plan Deviations (this continuation)

- **Pre-Phase-4 correction** (not a plan task, applied per orchestrator dispatch instruction):
  extended `check-task-references.sh` with the `PATH_SCOPE` argument described above, committed
  separately before Phase 4 began.
- **Phase 6 Scope Hypothesis** corrected from 84 to 79 occurrences: the plan's arithmetic
  under-credited Phase 1's `git-workflow.md` purge by 2 occurrences (Phase 1 actually cleared 5,
  not 3). Live count at Phase 6 start matched 79 exactly by subdirectory (skills 25, commands 28,
  agents 20, rules 1, hooks 3, merge-sources 2).
- No triage-bucket deviations: every site in Phases 4-6 was converted per the PROVENANCE /
  ILLUSTRATIVE / SANCTIONED buckets; no parenthetical carrying real explanatory weight was
  silently deleted (each PROVENANCE conversion either named the durable mechanism/file already
  present in the surrounding prose, or introduced one, e.g. "the 427 failure", "the
  phantom-artifact incident", "the cross-task file_scope overlap check").

## Verification (this continuation)

- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet
  agent-system/extensions/core` reports 0 — the entire core extension tree is clean.
- Per-phase scoped verification (via the new `PATH_SCOPE` argument) confirmed each phase's
  expected delta to 0 before moving to the next: Phase 4 147→0, Phase 5 121→0 (70+51), Phase 6
  79→0.
- `bash -n` passed on every edited `.sh` file (task-lock.sh, check-extension-docs.sh, the six
  command-gate/skill-base/parse-command-args/memory-retrieve/literature-retrieve/
  lifecycle-notify/generate-task-order scripts, the two test files, the three hooks).
  `check-extension-docs.sh` shows only expected pre-deploy source-vs-deployed drift FAILs on
  files this dispatch edited (normal until a deploy runs) plus 2 that predate this session — no
  new structural failures introduced.
- Repo-wide total dropped from 1,223 to 876 occurrences (agent-system/extensions 216 — all now in
  `literature/` (94, Phase 7) and the other 10 extensions (122, Phase 8) — `.opencode` 610, `lua`
  32, `.memory` 18, unchanged since those trees are untouched by Phases 4-6).

## What Changed (this continuation: Phases 7-10)

- **Phase 7**: purged all 94 occurrences under `agent-system/extensions/literature/` (25 files) —
  README.md's Deployment Status section rewritten around a "zotero/cite deployment-status audit"
  durable anchor; two `context/patterns/` docs; `scripts/deprecated/` (README + both quarantined
  scripts); 20 `scripts/*.sh|.py|.sql` files with trailing/embedded `(task #NNN[ Phase P])`
  parentheticals dropped where the surrounding comment already named the mechanism; both
  `skills/*/SKILL.md` files.
- **Phase 8**: purged all 122 occurrences across the ten remaining extensions (cslib, email,
  formal, founder, lean, memory, nix, nvim, present, web). Small extensions were almost entirely
  illustrative `"Research/implementation completed for task NNN:"` return-text examples,
  converted to `task {N}:` placeholder form. cslib's `lint-fix-wave-assignment.md` case study
  (built around real task numbers 210/211) was renamed throughout to "the rename
  task"/"the keyword-change task" plus matching worktree/patch names, following the same
  case-naming convention Phase 4 used for the BimodalLogic task-273 baseline. memory's
  usage-guide `/learn --task 142`-style command-usage examples were wrapped in
  `task-ref-ok:begin/end` blocks (Category 3) rather than converted. email had the largest and
  highest-judgment cluster (38 occurrences / 9 files) — the `tasks 823-824-827` index-freshness
  citations were replaced with mechanism cross-references exactly as the rule's own worked
  example prescribes; `.dotfiles task 80`/`.dotfiles task 72` cross-repo citations were
  generalized per the same principle applied to the BimodalLogic case; email-preferences.md's
  "Task 72" (a real citation of this repo's own task, reused 4 times as the anchor for the
  aerc-tagged/JSONL-manifest unsubscribe-review model) was given that descriptive name.
- **Phase 9**: purged all 32 occurrences under `lua/**` (13 files) — comment-only edits, all
  modules verified to still load via `nvim --headless`. `merge.lua`'s two generic "Task 1.2"/
  "Task 1.3" WBS labels renamed to "Step 1.2"/"Step 1.3". `cli.lua`'s single occurrence sat
  inside a pre-existing uncommitted user diagnostic-instrumentation hunk (unrelated WIP); only
  the flagged comment text was edited.
- **Phase 10**: purged all 18 occurrences under `.memory/**` (17 files). Discovered that 17 of
  18 occurrences were in frontmatter `topic`/`source` fields (machine-written by
  `memory-harvest.sh`/`/learn`, not prose), directly conflicting with a naive purge. Resolved by
  documenting a new Exemption Taxonomy **Category 7** ("Memory vault frontmatter provenance
  fields") in `rules/no-task-references-in-deliverables.md` and marking those lines in place with
  an inline `# task-ref-ok ... category 7` YAML comment — field values verified byte-for-byte
  unchanged via `yaml.safe_load` round-trip. Two `source:` fields with a redundant `"Task 547: "`
  prose prefix had the prefix dropped instead (the harvest template's real shape is a bare path).
  The sole body-prose occurrence (`MEM-plan-delegation-required.md`) was converted normally.

## Plan Deviations (Phases 7-10)

- **Phase 10, new taxonomy category**: discovered mid-phase that the "convert body, never
  frontmatter" instruction and the "scan must report 0" requirement directly conflict for
  `.memory/**`'s `topic`/`source` fields. Resolved per the plan's own directive to document newly
  discovered categories rather than handle them ad hoc — see Category 7 above.
- No other triage-bucket deviations in Phases 7-9: every site converted per the PROVENANCE /
  ILLUSTRATIVE / SANCTIONED buckets.

## Verification (Phases 7-10)

- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
  scoped to each tree confirmed the expected delta to 0 before moving to the next phase:
  literature 94→0, the ten remaining extensions 122→0 (so `agent-system/extensions` as a whole
  now reports 0), `lua` 32→0, `.memory` 18→0.
- `bash -n` passed on every edited `.sh` file; `python3 -m py_compile` passed on every edited
  `.py` file; `python3 -c "import json; json.load(...)"` passed on the edited `index-entries.json`.
- All 13 edited Lua modules verified to still load via
  `nvim --headless -c "lua require('<module>')" -c "q"`.
- `yaml.safe_load` round-trip on 4 sample `.memory/**` files confirmed frontmatter `topic`/
  `source` values are byte-for-byte unchanged by the inline `#`-comment marker.
- Repo-wide total dropped from 876 to 610 occurrences (`agent-system/extensions` now 0,
  `.opencode` 610 unchanged, `lua` 0, `.memory` 0).

## Notes

- Phase 15 (the blocking PreToolUse flip) was NOT touched, per the binding constraint that it
  must land strictly last, gated on `check-task-references.sh` exiting 0 across all four trees —
  which it does not yet do (610 occurrences remain, entirely within `.opencode/**`, Phases
  11-14's territory).
- Phases 11-14 (`.opencode/**`, 610 occurrences total: `extensions/core/` 199,
  `extensions/{formal,founder,lean,memory,nix,nvim,present,web}` 76, `context/{core,formats}`
  104, and the remaining `.opencode/**` tree 231) are territory-disjoint and may run in any
  order. `.opencode/**` is a git-tracked, hand-maintained port — edited directly in place, never
  routed through `agent-system/`; many sites will mirror durable anchors already established in
  Phases 4-8 above (e.g. "the cross-task file_scope overlap check", "the phantom-artifact
  incident") but the port has drifted, so each site still needs its own re-triage rather than a
  blind mirror. Phase 15 must run last. See the orchestrator handoff at
  `.orchestrator-handoff.json` for the precise resume instructions and accumulated decisions.

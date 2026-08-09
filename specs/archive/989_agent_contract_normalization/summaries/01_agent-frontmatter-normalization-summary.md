# Implementation Summary: Task #989

- **Task**: 989 - Agent contract normalization: frontmatter standard + no-task-references rollout
- **Status**: [COMPLETED]
- **Started**: 2026-08-05T21:11:24Z
- **Completed**: 2026-08-05T21:40:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: 948, 963, 971, 972, 974, 982 (all landed)
- **Artifacts**: plans/01_agent-frontmatter-normalization.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Delivered items 1, 2, and 3 of the task description: rewrote the agent frontmatter standard to
document the real subagent field set, fixed the seven silently-broken `allowed-tools:`/
`mcp-servers:` frontmatter declarations, added `model: sonnet` to the 15 agents missing it, rolled
out the no-task-references MUST-NOT bullet to 27 in-scope agents from a new canonical fragment,
and shipped `lint-agent-contracts.sh` (with fixture tests, manifest registration, and a new
`verify-deploy.sh` gate) to enforce all three going forward. Items 4 and 5 (body-skeleton drift and
terminal-metadata audit) are deferred per the research report's recommendation, reproduced below as
ready-to-run follow-up task descriptions.

## What Changed

- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` — added a
  complete supported-fields table, `tools:`/`disallowedTools:`/`mcpServers:` semantics, an
  "Invalid on Agent Files" subsection for `allowed-tools:`/`mcp-servers:`, extended Validation
  Rules (4, 5), and a note on `@`-references being inert pointer text.
- `agent-system/extensions/core/context/templates/agent-template.md` — corrected the stale
  `tools:`-not-supported claim (the plan named `docs/templates/agent-template.md`; the actual
  claim lived in `context/templates/agent-template.md` — see Plan Deviations).
- 7 frontmatter key migrations: `core/agents/synthesis-agent.md`,
  `literature/agents/literature-agent.md` (`allowed-tools:` → `tools:`, tool-scope audited, no
  widening needed); `founder/agents/{market,analyze,founder-spreadsheet,financial-analysis}-agent.md`,
  `present/agents/budget-agent.md` (`mcp-servers:` → `mcpServers:`, values preserved verbatim);
  `core/agents/spawn-agent.md` (`tools:` YAML list → comma-separated string form).
- 15 agent files — added `model: sonnet` (8 founder + 7 filetypes agents).
- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` (new) — canonical
  fragment holding the exact bullet text, the generated-copy-not-`@`-import rationale, and the
  in-scope classification rule.
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` — Enforcement section
  rewritten to describe the real coverage rule and point to the lint, replacing the stale
  3-agent "Known gap" paragraph.
- 27 agent files — added the no-task-references bullet (see confirmed enumeration below).
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (new) — frontmatter-gated
  dispatchable-agent detector, Check A (frontmatter key validity), Check B (`model:` presence),
  Check C (no-task-references bullet presence), Check D/E insertion point for follow-up work.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` (new) — 9 fixture
  assertions (positive + negative + fragment-missing + `--help`/unknown-argument).
- `agent-system/extensions/core/manifest.json` — registered both new scripts under
  `provides.scripts`.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — new `gate6` (agent contracts lint),
  appended after the existing `gate5` rather than renumbering.
- `agent-system/extensions/core/merge-sources/claudemd.md` — added `lint-agent-contracts.sh` to
  the Utility Scripts list.
- `agent-system/extensions/core/index-entries.json` — corrected `templates/agent-template.md`'s
  `line_count` (114 → 118) after Phase 1's edit changed it (unplanned fixup, see Plan Deviations).

## Decisions

- Phase 2's tool-scope audit for `synthesis-agent`/`literature-agent` found the declared
  `allowed-tools:` values already cover actual usage in both bodies — no widening needed. Both
  agents were previously running with **unrestricted inherited tool access** (the invalid key was
  a silent no-op) and now have the declared restriction actually enforced; this is a real behavior
  change, not a cosmetic rename.
- Phase 5's document-authoring-agent call (filetypes/, founder/, present/): 10 of 30 candidate
  agents included (write outside `specs/**`), 20 excluded (all outputs verified to land under
  `specs/{NNN}_{SLUG}/`, or — for `filetypes-router-agent` — no `Write` tool at all). Full
  per-agent reasoning recorded in `progress/phase-5-progress.json`.
- The no-task-references in-scope set for Check C in the lint is a curated, path-relative
  allowlist (not mechanically derivable from a file's own content, since "authors deliverable
  files outside `specs/**`" is a judgment call) — documented inline in the script.
- `lint-agent-contracts.sh` resolves its repo root via `git rev-parse --show-toplevel` rather than
  the `scripts/*.sh`-depth-specific `deploy-root-guard.sh` convention, because that guard was
  empirically verified (via a throwaway `/tmp` reproduction) to misresolve for a `scripts/lint/`
  caller — see `progress/phase-6-progress.json` for the reproduction. This lets the lint run
  identically from the deployed `.claude/scripts/lint/` copy or directly from the
  `agent-system/extensions/core/scripts/lint/` source-store copy, which Phase 8's verification
  requires.
- The new `verify-deploy.sh` gate was appended as `gate6` (after the existing `gate5`) rather than
  inserted mid-sequence, since gate numbers are consumed by an automated caller
  (`skill-orchestrate`'s redeploy checkpoint) and renumbering would have silently relabeled every
  downstream gate.

## Plan Deviations

- **Phase 1** (`agent-template.md` file path): the plan named
  `agent-system/extensions/core/docs/templates/agent-template.md` as the file carrying the stale
  `tools:`-not-supported claim; that claim actually lives in
  `agent-system/extensions/core/context/templates/agent-template.md` (verified via `grep` against
  both files before editing — the docs/templates file never made the claim). Fixed the real
  location.
- **Phase 4** (manifest.json registration): no `manifest.json` edit was made for the new fragment
  file. `provides.context` already lists `contracts` as a whole-directory entry that the deploy
  loader (`lua/neotex/plugins/ai/shared/extensions/loader.lua`, `file_or_dir` entry kind) copies
  recursively — a new file placed inside `context/contracts/` deploys automatically, matching the
  precedent of the two pre-existing files in that directory (`phase-closure.md`, `pre-edit-gate.md`),
  neither of which has its own manifest entry.
- **Phase 6/8** (`lint-contract-compliance.sh` source-store invocation): Phase 8's task list names
  the source-store path `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh`
  for the regression check; that pre-existing script (not modified by this task) has no
  `REPO_ROOT` override and resolves its root relative to its own location, so invoking it via the
  source-store path fails (`index.json not found`) regardless of this task's changes. Verified
  instead via the deployed path (`.claude/scripts/lint/lint-contract-compliance.sh`), which passed
  cleanly (24 passed, 0 failed, 0 warnings) — see progress file for both runs' output.
- **Phase 7** (unplanned fixup, not a plan task): fixed `index-entries.json`'s `templates/agent-template.md`
  `line_count` entry (114 → 118) after Phase 1's edit changed the file's actual line count,
  discovered via `check-extension-docs.sh` while verifying the deploy-gate wiring. Scoped to only
  this one entry, not a global `generate-context-line-counts.sh --write` run, to avoid also
  touching an unrelated, pre-existing drifted entry (`project/literature/patterns/agent-exploration.md`)
  this task never touched.

## Confirmed In-Scope Agent Enumeration (Phase 5)

21-agent baseline (matching the Scope Hypothesis exactly): 17 dispatchable implementation agents
(4 already compliant: `general-implementation-agent`, `general-implementation-hard-agent`,
`cslib-implementation-agent`, `cslib-implementation-hard-agent`; 13 newly edited:
`pr-review-implementation`, `email-implementation`, `epi-implement`, `founder-implement`,
`latex-implementation`, `lean-implementation`, `lean-implementation-hard`, `nix-implementation`,
`neovim-implementation`, `python-implementation`, `typst-implementation`, `web-implementation`,
`z3-implementation`) + 4 core planning/meta agents (`planner-agent`, `planner-hard-agent`,
`reviser-agent`, `meta-builder-agent`).

Plus 10 document-authoring agents (filetypes/founder/present call, see Decisions above):
`filetypes/{document,docx-edit,filetypes-spreadsheet,presentation,scrape,sheet}-agent`,
`founder/{deck-builder,meeting}-agent`, `present/{pptx-assembly,slidev-assembly}-agent`.

Total: 31 agents carry the bullet (4 pre-existing + 27 newly edited this task) — no count
diverged materially from its Scope Hypothesis.

## Verification

- Build: N/A (documentation/config task)
- Tests: Passed — `test-lint-agent-contracts.sh` 9/9 assertions pass
- Files verified: Yes
- `lint-agent-contracts.sh --verbose`: 33 passed, 0 warnings, 0 failed
- `check-task-references.sh`: PASS, 0 unexempted occurrences across all 4 tree roots
- `check-extension-docs.sh`: 3 pre-existing, unrelated findings only (two `.claude/` deploy-tree
  staleness findings from this task's own source-store-only edits — expected, since redeploying is
  a user-triggered action out of scope here; one pre-existing `literature` extension line_count
  drift this task never touched)
- `lint-contract-compliance.sh` (deployed path): 24 passed, 0 warnings, 0 failed — no regression
- `verify-deploy.sh` gate6: confirmed PASS against the source-store repo, and confirmed `[SKIP]`
  (not fail) against a synthetic deploy-consumer target with no `agent-system/extensions`
  directory

## Impacts

- `synthesis-agent` and `literature-agent` now actually enforce their declared tool restrictions
  (previously silent no-ops) — a live behavior change, audited and confirmed safe in Phase 2.
- 5 founder/present agents' MCP server declarations now actually take effect (previously silent
  no-ops under the misspelled `mcp-servers:` key).
- Future agent-contract drift (invalid frontmatter keys, missing `model:`, missing
  no-task-references bullet) fails loudly via `lint-agent-contracts.sh`, wired into
  `verify-deploy.sh`.

## Follow-ups

Two deferred items, reproduced verbatim below per Phase 8's task, ready to create with `/task`:

### Follow-up A: Agent body-skeleton drift and section lint

> Normalize agent body-section skeletons across all dispatchable agents and add lint enforcement.
> Depends on the agent-frontmatter-normalization work, which already ships
> `lint-agent-contracts.sh` with a frontmatter-gated dispatchable-agent detector and a commented
> Check D insertion point — extend that script rather than writing a new one or bolting onto
> `check-extension-docs.sh`.
>
> Measured drift (re-verify before editing; these are hypotheses):
> - 9 of 11 core agents lack `## Agent Metadata` and `## Allowed Tools`. `code-reviewer-agent.md`
>   and `meta-builder-agent.md` already have both and are in-repo worked examples.
> - 13 agents lack `## Error Handling`: `core/agents/code-reviewer-agent.md`,
>   `cslib/agents/cslib-vet-agent.md`, `email/agents/email-implementation-agent.md`,
>   `founder/agents/financial-analysis-agent.md`, `latex/agents/latex-{implementation,research}-agent.md`,
>   `literature/agents/literature-agent.md`, `python/agents/python-{implementation,research}-agent.md`,
>   `typst/agents/typst-{implementation,research}-agent.md`,
>   `z3/agents/z3-{implementation,research}-agent.md`.
> - `latex-implementation-agent.md` is a near-miss: it has `## Common Errors and Fixes` covering
>   the same ground. Decide whether to canonicalize on `## Error Handling` and rename it, or allow
>   a documented list of equivalent headings. Canonicalizing keeps the lint a single literal check.
>
> Design decision required first: reconcile `context/templates/agent-template.md` (the
> machine-consumed template `meta-builder-agent` generates from) against the actual stage skeleton
> used by the two most-hardened live agents, `general-research-agent.md` and
> `cslib-research-agent.md`. Do NOT merge the two template files — they are deliberately split by
> audience (tutorial vs. machine-consumed) and each already cross-references the other.
>
> Optional cleanup, not required: move `lean/context/project/lean4/agents/lean-{research,implementation}-flow.md`
> out of an `agents/`-named directory and update their two `@`-reference call sites. The
> frontmatter-gated detector already handles them correctly, so this is ambiguity reduction only.
>
> Source-store rule binding: edit `agent-system/extensions/**`, never `.claude/**`. No task-number
> citations in deliverables outside `specs/**`.

### Follow-up B: Terminal-metadata contract audit across all dispatchable agents

> Audit and normalize the terminal-metadata (`.return-meta.json`) contract across every
> dispatchable agent, and add a section-presence check as Check E of `lint-agent-contracts.sh`
> (the script already carries a commented insertion point and a frontmatter-gated
> dispatchable-agent detector).
>
> Reference shape to copy — the shape, not the literal text, since per-agent specifics differ
> (status value, `delegation_path` entry, artifact type): `cslib-research-agent.md`'s
> `## Stage 7: Write Final Metadata` and `general-research-agent.md`'s
> `### Stage 7: Write Metadata File`. Both carry the bare-string-array warning and the normative
> status vocabulary.
>
> Measured segmentation of the 77 agent-path files by presence of the literal `return-meta.json`
> (re-verify; these are hypotheses):
> - 8 already carry the hardened Stage-7 pattern and are the reference set: `general-research-agent`,
>   `general-research-hard-agent`, `planner-agent`, `planner-hard-agent`,
>   `general-implementation-hard-agent`, `cslib-research-agent`, `cslib-implementation-agent`,
>   `cslib-implementation-hard-agent`.
> - 62 mention it in some form. These need a shape and vocabulary audit against the 8 references
>   (correct terminal status value, `artifacts` as an array of `{type, path, summary}` objects
>   rather than bare path strings), not a from-scratch section add. This is the largest single
>   piece of work and may warrant being its own task again.
> - 13 have zero mention: `code-reviewer-agent`, `meta-builder-agent`, `synthesis-agent`,
>   `cslib-vet-agent`, `document-agent`, `docx-edit-agent`, `filetypes-router-agent`,
>   `filetypes-spreadsheet-agent`, `presentation-agent`, `scrape-agent`, `sheet-agent`,
>   `literature-agent`, `slide-planner-agent`.
>
> Required before editing any of the 13: an explicit, written, one-line classification per agent —
> genuinely missing versus legitimately different return contract. At least three plausibly have a
> different contract by design and must not be forced into the task-lifecycle shape:
> `code-reviewer-agent` has its own `## Return Format` (`/review` is outside the
> research/plan/implement lifecycle whose postflight reads `.return-meta.json`), `synthesis-agent`
> has its own `## Output Contract` (internal team-synthesis helper, not independently dispatched
> by a skill postflight), and `meta-builder-agent` is interactive task creation. A blanket sweep
> over all 13 is the wrong shape.
>
> Source-store rule binding: edit `agent-system/extensions/**`, never `.claude/**`. No task-number
> citations in deliverables outside `specs/**`.

## References

- `specs/989_agent_contract_normalization/plans/01_agent-frontmatter-normalization.md`
- `specs/989_agent_contract_normalization/reports/01_agent-contract-normalization-research.md`
- `specs/989_agent_contract_normalization/progress/phase-{1..7}-progress.json`

# Implementation Plan: Task #989

- **Task**: 989 - Agent contract normalization: frontmatter standard + no-task-references rollout
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: 948, 963, 971, 972, 974, 982 (all landed; this plan rebases on their agent-file edits)
- **Research Inputs**: specs/989_agent_contract_normalization/reports/01_agent-contract-normalization-research.md
- **Artifacts**: plans/01_agent-frontmatter-normalization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 989's description bundles five items. The research report established that two of them
(body-skeleton drift + lint; terminal-metadata audit + lint) are each independently large and
design-heavy, and recommended splitting. This plan honors that split: it delivers items 2, 3, and
1 — the frontmatter field-set standard and its bug fixes, the missing `model:` field, and the
no-task-references MUST-NOT rollout — plus the new lint script that enforces them, structured so
the two deferred items can bolt their checks onto the same script without redesign. Items 4 and 5
are recorded below as ready-to-run follow-up task descriptions, not phases.

The frontmatter work is not cosmetic. `allowed-tools:` (2 agents) and `mcp-servers:` (5 agents)
are not valid subagent frontmatter fields at all — those seven agents' tool restrictions and MCP
server declarations are silent no-ops today. Fixing them changes real runtime behavior and is
treated as a bug fix with a behavior-change sanity check, not a rename.

### Research Integration

Four findings from the report drive this plan's shape:

1. **`@`-imports in agent body text do NOT auto-resolve at subagent spawn** (proven empirically
   and against the official sub-agents docs). The task description's "shared @-imported include"
   strategy for items 1 and 5 is unfounded. Phase 4 therefore adopts
   canonical-fragment-plus-literal-copy-plus-lint, following this repo's own precedent of
   `.claude/CLAUDE.md` being generated from `merge-sources/`.
2. **The real subagent frontmatter fields are `tools:`, `disallowedTools:`, `mcpServers:`.**
   `allowed-tools:` belongs to SKILL.md/slash-command frontmatter; `mcp-servers:` (hyphenated) is
   a misspelling of `mcpServers:`. Both are silently ignored on agent files. Verified live on
   disk: `synthesis-agent.md` and `literature-agent.md` carry `allowed-tools:`;
   `market-agent.md`, `analyze-agent.md`, `founder-spreadsheet-agent.md`,
   `financial-analysis-agent.md`, and `budget-agent.md` carry `mcp-servers:`.
3. **Two files under a directory literally named `agents/` are not dispatchable agents** —
   `lean/context/project/lean4/agents/lean-{research,implementation}-flow.md` have no frontmatter
   block. A third, `core/agents/README.md`, is likewise not an agent. Any lint built on a bare
   `**/agents/*.md` glob misfires on all three, so the new lint's dispatchable-agent detector is
   frontmatter-gated (Phase 6), not path-gated. Re-verified on disk: 78 files match the glob, 75
   carry frontmatter.
4. **Recommended split.** Items 4 and 5 are deferred per the report's Recommended Phasing
   section and the delegating orchestrator's explicit instruction.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap consultation was
requested; `roadmap_flag` is absent. No ROADMAP.md phases are included.

## Goals & Non-Goals

**Goals**:

- `agent-frontmatter-standard.md` documents the real, complete subagent frontmatter field set and
  explicitly names `allowed-tools:` / `mcp-servers:` as invalid on agent files.
- All seven silently-broken frontmatter declarations are migrated to the correct field names, with
  their intended tool/MCP scope preserved and the behavior change acknowledged.
- The 15 agents currently omitting `model:` carry `model: sonnet` per the standard's tier table.
- The no-task-references MUST-NOT bullet exists in every agent that authors deliverable files
  outside `specs/**`, sourced from one canonical fragment and kept in sync by lint.
- A new `lint-agent-contracts.sh` enforces frontmatter-key validity, `model:` presence, and
  no-task-references-bullet presence, with a frontmatter-gated dispatchable-agent detector,
  fixture tests, manifest registration, and `verify-deploy.sh` wiring.
- The rule file's Enforcement section no longer names a stale 3-agent gap.

**Non-Goals**:

- Body-skeleton drift (`## Agent Metadata` / `## Allowed Tools` / `## Error Handling`) and its
  lint checks — deferred, see Deferred Follow-Up Tasks.
- Terminal-metadata contract audit across the 13 zero-mention and 62 partial-mention agents —
  deferred, see Deferred Follow-Up Tasks.
- Merging the two agent-template files. The report found them deliberately split by audience;
  only the one factually-stale `tools:`-not-supported claim is corrected here (Phase 1), because
  leaving it would directly contradict the standard doc this plan rewrites.
- Renaming or relocating the two lean4 flow files. The frontmatter-gated lint detector (Phase 6)
  is the required fix; the rename is optional cleanup and is not attempted.
- Any edit under `.claude/**`. That tree is a gitignored, disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Migrating `allowed-tools:` -> `tools:` actually restricts agents that currently enjoy unrestricted inherited access, breaking their live usage | H | M | Phase 2 requires reading each of the 7 agents' bodies and their dispatching skill to confirm the declared tool set covers what the agent actually does before the key is corrected; any agent whose declared set is too narrow gets a widened, documented value rather than a mechanical rename |
| The no-task-references in-scope agent set is guessed rather than derived, producing either an under-rollout or 75 pointless edits | M | H | Phase 4 fixes an explicit written classification rule ("authors deliverable files outside `specs/**`") before any rollout; Phase 5 carries a Scope Hypothesis requiring the implementer to enumerate and confirm the set against that rule, and to record the enumeration in the summary |
| The new lint's dispatchable-agent detector misfires on the 3 non-agent files in `agents/`-named paths | M | M | Phase 6 gates on frontmatter presence plus a `name:` key, and Phase 7 asserts all three known non-agent files are excluded as an explicit negative fixture |
| A canonical fragment file is created but drifts from the 21-odd literal copies with no enforcement, recreating the exact problem this task exists to fix | H | M | The lint check for bullet presence (Phase 6) compares against the canonical fragment's text, not a hardcoded string, so the fragment is load-bearing rather than decorative |
| Phase 2 and Phase 3 both edit `market-agent.md`, `analyze-agent.md`, `founder-spreadsheet-agent.md`, `financial-analysis-agent.md` | L | H | Phases 2 and 3 are sequenced, never parallel; the wave table below reflects this |
| Counts asserted here (7, 15, ~21) drift as other in-flight tasks land agent edits | M | M | Every count-bearing phase carries a Scope Hypothesis with the exact re-derivation command; counts are hypotheses to confirm, never facts to trust |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5 | 2 (for 3), 4 (for 5) |
| 4 | 6 | 3, 5 |
| 5 | 7 | 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel. Wave 2 and wave 3 pair a frontmatter-editing
phase with a prose/rollout phase whose file territories do not overlap; Phase 3 must not run
before Phase 2 because four founder agents appear in both edit sets.

---

### Phase 1: Rewrite the frontmatter standard to the real field set [COMPLETED]

- **Goal**: `agent-frontmatter-standard.md` becomes an accurate, complete reference for subagent
  frontmatter, so the migrations in Phases 2-3 have a standard to cite.

- **Tasks**:
  - [x] Add a complete supported-fields table to
    `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`:
    `name`, `description` (required); `tools`, `disallowedTools`, `model`, `permissionMode`,
    `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `effort`, `isolation`,
    `color`, `initialPrompt` (optional). *(completed)*
  - [x] Document `tools:` semantics (allowlist; the documented form is a comma-separated string,
    e.g. `tools: Read, Glob, Grep`), `disallowedTools:` (denylist, camelCase), and `mcpServers:`
    (camelCase). *(completed)*
  - [x] Add an explicit **Invalid on agent files** subsection naming `allowed-tools:` (valid only
    in SKILL.md / slash-command frontmatter) and `mcp-servers:` (hyphenated misspelling of
    `mcpServers:`), each with a one-line statement that the key is silently ignored rather than
    rejected — this is why the drift went unnoticed. *(completed)*
  - [x] Extend the Validation Rules section so rule 4 forbids the two invalid keys and rule 5
    requires `model:` on every dispatchable agent per the tier table. *(completed)*
  - [x] Correct the single stale claim in
    `agent-system/extensions/core/docs/templates/agent-template.md` that a `tools:` block is not
    supported. Change only that claim; do not touch the template's section skeleton (deferred).
    *(deviation: altered — the stale claim actually lives in
    `agent-system/extensions/core/context/templates/agent-template.md`, not
    `docs/templates/agent-template.md`; fixed the real location, see progress file)*
  - [x] Add a short note recording that `@`-references in an agent body are inert pointer text the
    agent must `Read` itself, not framework-level auto-expansion — the report identified this as a
    repo-wide documentation gap that keeps getting re-litigated. *(completed)*

- **Timing**: 1 hour

- **Depends on**: none

- **Verification Tier**: prose

- **Files to modify**:
  - `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` -
    complete field table, invalid-key subsection, extended validation rules
  - `agent-system/extensions/core/docs/templates/agent-template.md` - correct the
    `tools:`-not-supported claim only

- **Verification**:
  - `grep -n "mcpServers\|disallowedTools\|allowed-tools" agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` shows all three documented, with `allowed-tools` under the invalid heading.
  - `grep -n "not supported\|Do NOT include" agent-system/extensions/core/docs/templates/agent-template.md` no longer returns a claim about `tools:`.
  - Diff read-through confirms every changed hunk is prose/table text in a docs file.

---

### Phase 2: Fix the seven invalid frontmatter declarations [COMPLETED]

- **Goal**: The seven agents whose tool/MCP restrictions are silent no-ops today declare them
  under the correct field names, with their intended scope preserved and verified.

- **Tasks**:
  - [x] For `core/agents/synthesis-agent.md` and `literature/agents/literature-agent.md`: read the
    agent body and its dispatching skill (`skill-team-research` / `skill-literature`), confirm the
    declared value covers every tool the agent actually invokes, then change `allowed-tools:` to
    `tools:`. Widen the value where the audit shows it is too narrow, and record the widening in
    the phase notes rather than silently keeping the old value. *(completed: audit found declared
    values already cover actual usage for both agents, no widening needed — see progress file)*
  - [x] For `founder/agents/market-agent.md`, `founder/agents/analyze-agent.md`,
    `founder/agents/founder-spreadsheet-agent.md`,
    `founder/agents/financial-analysis-agent.md`, and `present/agents/budget-agent.md`: change
    `mcp-servers:` to `mcpServers:`, preserving the existing value verbatim (three carry `[]`; two
    carry a one-entry list — `sec-edgar` and `firecrawl` respectively). *(completed)*
  - [x] For `core/agents/spawn-agent.md`: normalize the YAML block-list `tools:` value to the
    documented comma-separated string form. The list form's parsing is unconfirmed by the docs;
    the string form is the verified-working shape. *(completed)*
  - [x] Leave `web/agents/web-{research,implementation}-agent.md` unchanged — `disallowedTools:`
    is already correct and is the field to standardize on. *(completed: verified unchanged)*
  - [x] Record, in the phase notes, that the two `allowed-tools:` agents were previously running
    with unrestricted inherited tool access and now are not. This is a behavior change, not a lint
    fix. *(completed: recorded in specs/989_agent_contract_normalization/progress/phase-2-progress.json)*

- **Timing**: 1 hour

- **Depends on**: 1

- **Verification Tier**: interface

- **Scope Hypothesis**: Exactly 8 agent files need a frontmatter key edit (2 `allowed-tools:`,
  5 `mcp-servers:`, 1 `tools:` normalization). Confirm at implementation time by re-running, from
  `agent-system/extensions`:
  `grep -rn "^allowed-tools:\|^mcp-servers:\|^tools:" */agents/*.md */context/project/*/agents/*.md`
  If the count differs, reconcile against the report's Findings section 2 table before editing and
  note the delta.

- **Files to modify**:
  - `agent-system/extensions/core/agents/synthesis-agent.md` - `allowed-tools:` -> `tools:`
  - `agent-system/extensions/literature/agents/literature-agent.md` - `allowed-tools:` -> `tools:`
  - `agent-system/extensions/founder/agents/market-agent.md` - `mcp-servers:` -> `mcpServers:`
  - `agent-system/extensions/founder/agents/analyze-agent.md` - `mcp-servers:` -> `mcpServers:`
  - `agent-system/extensions/founder/agents/founder-spreadsheet-agent.md` - `mcp-servers:` -> `mcpServers:`
  - `agent-system/extensions/founder/agents/financial-analysis-agent.md` - `mcp-servers:` -> `mcpServers:`
  - `agent-system/extensions/present/agents/budget-agent.md` - `mcp-servers:` -> `mcpServers:`
  - `agent-system/extensions/core/agents/spawn-agent.md` - `tools:` list -> comma-string form

- **Verification**:
  - `grep -rn "^allowed-tools:\|^mcp-servers:" agent-system/extensions/*/agents/*.md` returns
    nothing (SKILL.md and command files legitimately keep `allowed-tools:` and are out of scope).
  - Every edited file still parses as valid YAML frontmatter: first line `---`, closing `---`
    present, `name:` and `description:` intact.
  - The tool-scope audit for the two `allowed-tools:` agents is written down, naming for each the
    tools its body actually invokes versus the declared set.

---

### Phase 3: Add `model: sonnet` to the 15 agents missing it [COMPLETED]

- **Goal**: Every dispatchable agent declares a model, resolving the tier table's assignment
  rather than silently inheriting.

- **Tasks**:
  - [x] Add `model: sonnet` to the 8 founder agents: `project-agent.md`, `meeting-agent.md`,
    `market-agent.md`, `founder-spreadsheet-agent.md`, `finance-agent.md`,
    `financial-analysis-agent.md`, `strategy-agent.md`, `analyze-agent.md`. *(completed)*
  - [x] Add `model: sonnet` to the 7 filetypes agents: `presentation-agent.md`, `sheet-agent.md`,
    `docx-edit-agent.md`, `filetypes-router-agent.md`, `filetypes-spreadsheet-agent.md`,
    `scrape-agent.md`, `document-agent.md`. *(completed)*
  - [x] Do NOT add `model:` to `lean/context/project/lean4/agents/lean-{research,implementation}-flow.md`
    or `core/agents/README.md` — none is a dispatchable agent (no frontmatter block at all).
    *(completed: verified untouched)*
  - [x] Place `model:` consistently after `description:` in each frontmatter block, matching the
    standard's examples. *(completed)*

- **Timing**: 45 minutes

- **Depends on**: 2

- **Verification Tier**: local

- **Scope Hypothesis**: Exactly 15 dispatchable agents lack `model:` (8 founder + 7 filetypes).
  Confirm at implementation time by running, from `agent-system/extensions`:
  `for f in $(find . -path "*/agents/*.md"); do head -1 "$f" | grep -q '^---$' && { grep -q "^model:" "$f" || echo "$f"; }; done`
  This must return exactly the 15 named above, and must not return any of the three
  frontmatter-less files.

- **Files to modify**:
  - `agent-system/extensions/founder/agents/{project,meeting,market,founder-spreadsheet,finance,financial-analysis,strategy,analyze}-agent.md` - add `model: sonnet`
  - `agent-system/extensions/filetypes/agents/{presentation,sheet,docx-edit,filetypes-router,filetypes-spreadsheet,scrape,document}-agent.md` - add `model: sonnet`

- **Verification**:
  - The confirmation loop above returns zero files.
  - `grep -c "^model: sonnet" ` across the 15 files returns 1 each.
  - No frontmatter block gained a duplicate `model:` key.

---

### Phase 4: Establish the canonical no-task-references fragment and classification rule [NOT STARTED]

- **Goal**: One authoritative source for the MUST-NOT bullet text plus a written rule for which
  agents must carry it — the design work that makes Phase 5 mechanical.

- **Tasks**:
  - [ ] Create a canonical fragment file under
    `agent-system/extensions/core/context/contracts/` (or the nearest existing shared-fragment
    location the implementer confirms) holding the exact bullet text currently live in the four
    compliant agents:
    ``Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead``
  - [ ] Document in that fragment's header that it is a **generated-copy source, not an
    `@`-import**: agent bodies carry a literal copy of the bullet, kept in sync by lint, because
    `@`-references in an agent body do not auto-resolve at spawn. Cite the CLAUDE.md-from-
    merge-sources generation precedent as the model.
  - [ ] Write the in-scope classification rule into the fragment header: an agent must carry the
    bullet if and only if it **authors deliverable files outside `specs/**`**. This covers every
    implementation agent, the planning agents (`planner-agent`, `planner-hard-agent`,
    `reviser-agent`), and `meta-builder-agent`. Research agents whose only outputs are reports
    under `specs/**` are out of scope, and the fragment must say so explicitly so the exclusion
    reads as a decision rather than an omission.
  - [ ] Update the Enforcement section of
    `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`: replace the
    "Known gap" paragraph naming `neovim-implementation-agent`, `nix-implementation-agent`, and
    `email-implementation-agent` with a statement of the real coverage rule and a pointer to the
    lint that enforces it. Do not delete the paragraph before Phase 5 lands the coverage it
    describes — write the replacement text in this phase and confirm accuracy in Phase 8.

- **Timing**: 1.5 hours

- **Depends on**: 1

- **Verification Tier**: prose

- **Files to modify**:
  - `agent-system/extensions/core/context/contracts/` - new canonical fragment file
  - `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - Enforcement
    section rewrite
  - `agent-system/extensions/core/manifest.json` - register the new fragment under the appropriate
    `provides` array so it deploys

- **Verification**:
  - The fragment's bullet text is byte-identical to the bullet in
    `core/agents/general-implementation-agent.md` (verify with `grep -F` against both).
  - The fragment states the classification rule and the not-an-`@`-import caveat.
  - `jq '.provides' agent-system/extensions/core/manifest.json` lists the new fragment.
  - The rule file's Enforcement section no longer names a three-agent known gap.

---

### Phase 5: Roll the bullet out to the in-scope agents [NOT STARTED]

- **Goal**: Every agent matching Phase 4's classification rule carries the canonical bullet in its
  MUST NOT / Critical Requirements list.

- **Tasks**:
  - [ ] Enumerate the in-scope set by applying Phase 4's rule. Starting point: the 17 dispatchable
    implementation agents (`general-implementation`, `general-implementation-hard`,
    `cslib-implementation`, `cslib-implementation-hard`, `pr-review-implementation`,
    `email-implementation`, `epi-implement`, `founder-implement`, `latex-implementation`,
    `lean-implementation`, `lean-implementation-hard`, `nix-implementation`,
    `neovim-implementation`, `python-implementation`, `typst-implementation`,
    `web-implementation`, `z3-implementation`) plus `planner-agent`, `planner-hard-agent`,
    `reviser-agent`, `meta-builder-agent`.
  - [ ] Make and record an explicit include/exclude call for the document-authoring agents in
    `filetypes/`, `present/`, and `founder/` — they write files outside `specs/**` but of a
    non-prose kind. One line per agent; the call must be written down either way, not left
    implicit.
  - [ ] Skip the 4 agents already compliant (`general-implementation-agent`,
    `general-implementation-hard-agent`, `cslib-implementation-agent`,
    `cslib-implementation-hard-agent`) unless their bullet text has drifted from the fragment, in
    which case correct it to match.
  - [ ] Insert the bullet as the last numbered item of each target agent's existing MUST NOT list,
    matching the placement used in the four compliant agents. Where an agent has no MUST NOT list,
    add it to `## Critical Requirements` under a `**MUST NOT**:` heading rather than inventing a
    new section shape.
  - [ ] Do not renumber or reword any surrounding bullet.

- **Timing**: 1.5 hours

- **Depends on**: 4

- **Verification Tier**: local

- **Scope Hypothesis**: The in-scope set is approximately 21 agents (17 implementation + 4
  planning/meta), of which 4 are already compliant, leaving roughly 17 to edit — plus whatever the
  document-authoring-agent call adds, which could raise the total toward 35. This is a hypothesis,
  not a count. Confirm at implementation time by enumerating against Phase 4's written rule and
  recording the resulting list in the implementation summary before making any edit. If the
  confirmed set differs materially from ~21, say so explicitly rather than silently editing a
  different number of files.

- **Files to modify**:
  - `agent-system/extensions/*/agents/*implementation*.md` and `*implement*.md` - add the bullet
  - `agent-system/extensions/core/agents/{planner-agent,planner-hard-agent,reviser-agent,meta-builder-agent}.md` - add the bullet
  - Additional `filetypes/`, `present/`, `founder/` agents as determined by the recorded call

- **Verification**:
  - `grep -rlF 'Reference task numbers ("task N", "tasks N-M") in files outside specs/**' agent-system/extensions/*/agents/*.md`
    returns exactly the confirmed in-scope set.
  - Every match is byte-identical to the Phase 4 fragment.
  - Each edited file's MUST NOT list numbering is contiguous.
  - `bash .claude/scripts/check-task-references.sh` still passes — the bullet text itself contains
    the literal placeholder forms `"task N"` / `"tasks N-M"` without digits, so it must not trip
    the repo-wide gate. If it does, the fragment needs an exemption marker with a stated category,
    and that finding must be reported, not worked around silently.

---

### Phase 6: New `lint-agent-contracts.sh` with frontmatter-gated detection [NOT STARTED]

- **Goal**: A narrowly-scoped lint that fails loudly on frontmatter-key drift, missing `model:`,
  and missing no-task-references bullets — with a dispatchable-agent detector the deferred
  follow-up tasks can reuse.

- **Tasks**:
  - [ ] Create `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`, modeled on
    `lint-contract-compliance.sh`'s existing structure: `set -euo pipefail`, color constants,
    `--verbose`/`--help` parsing, `log_pass`/`log_fail`/`log_warn` helpers, PASSED/FAILED/WARNINGS
    counters, lettered check functions, and the same summary block and exit-code contract
    (0 = pass, 1 = failures).
  - [ ] Implement the **dispatchable-agent detector** as a shared function: a file under an
    `agents/`-named path qualifies only if its first line is `---` and its frontmatter contains a
    `name:` key. This must exclude `core/agents/README.md` and both
    `lean/context/project/lean4/agents/lean-*-flow.md`. Write it as a reusable function with a
    header comment stating that the deferred section-presence and terminal-metadata checks are
    expected to call it.
  - [ ] **Check A - frontmatter key validity**: fail on `allowed-tools:` or `mcp-servers:` in any
    dispatchable agent; warn on any frontmatter key outside the documented set from Phase 1.
  - [ ] **Check B - model presence**: fail on any dispatchable agent lacking `model:`; fail on a
    `model:` value outside `opus|sonnet|haiku`.
  - [ ] **Check C - no-task-references bullet presence**: for every agent matching Phase 4's
    classification rule, fail if the canonical bullet is absent. Read the expected text **from the
    Phase 4 fragment file**, never from a string hardcoded in the lint — that is what makes the
    fragment load-bearing. Fail loudly if the fragment file itself is missing.
  - [ ] Leave a commented placeholder block naming Check D (required body sections) and Check E
    (terminal-metadata section presence) as the deferred follow-up tasks' insertion point, so the
    seam is explicit rather than rediscovered.

- **Timing**: 2 hours

- **Depends on**: 3, 5

- **Verification Tier**: local

- **Files to modify**:
  - `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - new file

- **Verification**:
  - `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 against the
    post-Phase-5 tree.
  - `--help` prints the check list and exits 0; an unknown argument exits 2.
  - The detector, run in isolation, enumerates exactly 75 dispatchable agents and excludes the
    three known non-agent files by name.
  - Check C fails with a named error when the fragment file is temporarily renamed.

---

### Phase 7: Fixture tests, manifest registration, and deploy-gate wiring [NOT STARTED]

- **Goal**: The new lint is independently tested and actually runs as part of deploy verification.

- **Tasks**:
  - [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`, modeled
    on the existing test scripts in that directory (e.g. `test-validate-no-task-references.sh`'s
    assert-helper shape).
  - [ ] Positive fixtures: a rogue-key agent (`allowed-tools:`) fails Check A; an agent without
    `model:` fails Check B; an implementation agent without the bullet fails Check C.
  - [ ] Negative fixtures: a frontmatter-less file placed in an `agents/`-named fixture directory
    is not treated as an agent and produces no finding; a compliant agent passes all three checks.
  - [ ] Register both new scripts in `agent-system/extensions/core/manifest.json` under
    `provides.scripts` as `lint/lint-agent-contracts.sh` and
    `tests/test-lint-agent-contracts.sh`, matching the existing subdirectory-path entry style
    (`lint/lint-contract-compliance.sh`, `tests/test-handoff-reader-parity.sh`).
  - [ ] Wire the lint into `agent-system/extensions/core/scripts/verify-deploy.sh` as a new gate
    following the `check-task-references.sh` gate-4 pattern: a `CURRENT_GATE` label, the
    source-store-only skip for deploy consumers, and finding-line emission on failure.
  - [ ] Update the utility-scripts list in
    `agent-system/extensions/core/merge-sources/` (the CLAUDE.md generation source) to mention
    `lint-agent-contracts.sh`, so the generated index stays truthful.

- **Timing**: 1.5 hours

- **Depends on**: 6

- **Verification Tier**: interface

- **Files to modify**:
  - `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - new file
  - `agent-system/extensions/core/manifest.json` - two `provides.scripts` entries
  - `agent-system/extensions/core/scripts/verify-deploy.sh` - new gate
  - `agent-system/extensions/core/merge-sources/` - utility-scripts list entry

- **Verification**:
  - `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0 with
    every fixture assertion reported.
  - `jq -r '.provides.scripts[]' agent-system/extensions/core/manifest.json | grep agent-contracts`
    returns both entries.
  - `bash agent-system/extensions/core/scripts/verify-deploy.sh` runs the new gate and reports it
    by label.
  - The gate correctly skips (not fails) when run against a deploy consumer with no
    `agent-system/extensions` directory.

---

### Phase 8: Full verification sweep and follow-up handoff [NOT STARTED]

- **Goal**: Every item in the task's verification bar is demonstrated green, and the two deferred
  items are handed off in ready-to-run form.

- **Tasks**:
  - [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` and
    confirm zero frontmatter-key violations, zero missing `model:`, zero missing bullets.
  - [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm it still passes across the
    repo after the ~17-plus bullet insertions.
  - [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm the
    new fragment, lint, and test files did not introduce dangling-reference or orphan findings.
  - [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` and
    confirm no regression from the frontmatter edits.
  - [ ] Confirm the rule file's Enforcement section text written in Phase 4 is now factually
    accurate against the shipped coverage; correct it if Phase 5's confirmed set differed from the
    hypothesis.
  - [ ] Reproduce the two Deferred Follow-Up Task descriptions below verbatim in the
    implementation summary so they can be created directly with `/task`. Do not create the tasks
    from within implementation.
  - [ ] Record in the summary: the confirmed in-scope agent enumeration from Phase 5, the
    tool-scope audit results from Phase 2, and any count that differed from its Scope Hypothesis.

- **Timing**: 1 hour

- **Depends on**: 7

- **Verification Tier**: full

- **Files to modify**:
  - `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - Enforcement
    accuracy correction, only if Phase 5's confirmed set differed
  - `specs/989_agent_contract_normalization/summaries/01_*-summary.md` - the summary artifact

- **Verification**:
  - All four lint/check scripts above exit 0.
  - The task's three verification-bar clauses are each demonstrated with quoted command output:
    zero frontmatter-key violations; the bullet grep matches every implementation/planning/meta
    agent; all `model:` values valid and the previously-bare 15 resolved.
  - The summary contains both follow-up task descriptions verbatim.

---

## Deferred Follow-Up Tasks

Per the research report's Recommended Phasing section and the delegating orchestrator's explicit
instruction, items 4 and 5 of the original task description are not phases in this plan. They are
recorded here in ready-to-run form.

### Follow-up A: Agent body-skeleton drift and section lint

Create with `/task` using this description:

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

Create with `/task` using this description:

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

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0
- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0 with
      all positive and negative fixtures asserted
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` exits 0
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` runs and reports the new gate
- [ ] Every edited agent file's frontmatter still parses: opening `---`, closing `---`, `name:` and
      `description:` present
- [ ] No file under `.claude/**` was modified (`git status --short .claude/` is empty, or shows
      only deploy-regeneration output the user initiated)

## Artifacts & Outputs

- `specs/989_agent_contract_normalization/plans/01_agent-frontmatter-normalization.md` (this file)
- `specs/989_agent_contract_normalization/summaries/01_agent-frontmatter-normalization-summary.md`
- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` (rewritten
  field set)
- `agent-system/extensions/core/context/contracts/` canonical no-task-references fragment (new)
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` (new)
- 8 agent files with corrected frontmatter keys; 15 agent files with `model: sonnet` added;
  ~17-plus agent files with the no-task-references bullet added
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` (Enforcement section)
- `agent-system/extensions/core/manifest.json` (three new `provides` entries)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (new gate)

## Rollback/Contingency

Every change is a text edit under `agent-system/extensions/**` plus two new files; no data
migration and no state mutation. Per-phase commits make `git revert` of any single phase clean.

- **Phase 2 is the only behavior-changing phase.** If correcting `allowed-tools:` to `tools:`
  breaks `synthesis-agent` in a live `--team` run, or `literature-agent` under `/literature`, the
  fix is to widen the declared tool value — not to revert to the invalid key, which would restore
  the silent no-op. If widening is not obviously correct, revert that one file and report it as a
  blocker rather than guessing at a tool set.
- If Phase 5's bullet text trips `check-task-references.sh`, stop and report. Do not add an
  exemption marker without a stated category from that rule's Exemption Taxonomy.
- If the new deploy gate proves flaky against deploy consumers, revert the `verify-deploy.sh` hunk
  only; the lint and its tests remain independently runnable and the rest of the task stands.

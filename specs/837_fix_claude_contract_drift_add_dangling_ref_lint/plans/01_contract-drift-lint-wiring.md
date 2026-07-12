# Implementation Plan: Fix Contract Drift and Add Dangling-Reference Lint

- **Task**: 837 - fix_claude_contract_drift_add_dangling_ref_lint
- **Status**: [NOT STARTED]
- **Effort**: 5 hours
- **Dependencies**: None (independent of #831-#836)
- **Research Inputs**: specs/837_fix_claude_contract_drift_add_dangling_ref_lint/reports/01_contract-drift-dangling-ref-lint.md
- **Artifacts**: plans/01_contract-drift-lint-wiring.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/state-management.md
  - .claude/rules/artifact-formats.md
- **Type**: meta

## Overview

Nvim's 8 core contract files in `.claude/context/contracts/` are architecturally invisible to
the extension sync pipeline: `core/manifest.json`'s `provides.context` array omits `"contracts"`,
and no `.claude/extensions/core/context/contracts/` source directory exists. Consequently core's
contracts never propagate to child projects via "Load Core," producing dangling
`.claude/context/contracts/*.md` references in downstream copies of `skill-orchestrate-hard`.
This plan fixes the root cause in THIS repo (the source of truth, which is otherwise healthy):
register `contracts` as a core-owned context category and migrate the 8 files into the core
extension source; extend `check-extension-docs.sh` with a `provides.context` disk-existence check
and a deployed-file dangling-contract-reference scan; and wire the validator into the sync path so
drift fails LOUDLY at load time. Downstream child-project reconciliation is treated as a
propagation/deployment step (out of this repo's editable scope), not a set of direct edits to
other repos. Definition of done: core contracts flow through the same `copy_context_dirs()` /
allow-list pipeline as every other core artifact, and a missing contract reference produces a
visible failure during "Load Core."

### Research Integration

Integrates report `01_contract-drift-dangling-ref-lint.md`:
- Root cause confirmed live: `core/manifest.json` `provides.context` omits `"contracts"`;
  `.claude/extensions/core/context/contracts/` is absent; deployed `.claude/context/contracts/`
  holds 8 files added directly to the deployed layer.
- Recommendation AGAINST promoting `context-hygiene.md` to core (it is explicitly Lean4/CSLib-
  scoped and belongs in the `lean` extension) — honored in Phase 1.
- Two `check-extension-docs.sh` gaps: no `provides.context` disk-existence branch in
  `check_manifest_entries()`; no scan of deployed `.claude/skills|agents|rules` for dangling
  `.claude/context/contracts/*.md` references (Phases 2-3).
- The script is never invoked automatically; wiring must produce LOUD, non-silent failure output
  (Phase 4).
- `core/index-entries.json` currently has no `contracts` entries — reconciliation flagged (Phase 1).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no roadmap context provided).

## Goals & Non-Goals

**Goals**:
- Register `"contracts"` in `core/manifest.json` `provides.context` and migrate nvim's 8 deployed
  contract files into `.claude/extensions/core/context/contracts/` as the canonical source so they
  propagate through `copy_context_dirs()` / the "Load Core" allow-list.
- Reconcile `core/index-entries.json` so `contracts` entries exist and are consistent with the new
  source location.
- Add `provides.context` disk-existence validation to `check-extension-docs.sh`.
- Add a project-wide deployed-file scan for dangling `.claude/context/contracts/*.md` references
  that FAILs loudly when the referenced path is absent.
- Wire the validator into the sync path so contract drift surfaces a visible failure at load time.
- Document the `provides.context` sync contract and the downstream reconciliation procedure.

**Non-Goals**:
- Do NOT promote `context-hygiene.md` (or any Lean-scoped file) into core.
- Do NOT edit other child repos directly (BimodalLogic, cslib, Logos/Hardware, etc.). Their
  reconciliation is a propagation/deployment step run FROM those repos (documented, not executed).
- Do NOT build a general `@.claude/...` dangling-path linter for all reference forms; scope the new
  check to `.claude/context/contracts/*.md` references specifically (generic scan is a stretch goal
  flagged separately to avoid false positives on extension-conditional references).
- Do NOT change `.syncprotect` schema (orthogonal to referential-integrity validation).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Migrating contracts to the core extension source changes the source-of-truth path; `index.json`/`index-entries.json` `contracts` entries could become inconsistent | M | M | Phase 1 explicitly reconciles `core/index-entries.json` and verifies deployed `.claude/context/contracts/` content is byte-identical to the new source before/after |
| Blanket dangling `@.claude/...` scan produces false positives on legitimately extension-conditional references | M | M | Scope the new check to `.claude/context/contracts/*.md` references only; generic scan deferred as flagged stretch goal (Non-Goal) |
| Wiring a hard-FAIL validator into sync could block legitimate partial syncs (project not loading `lean`, correctly lacking `context-hygiene.md`) | H | L | Validator is reference-driven (validates only what deployed content actually cites in THIS project), never presence-driven; a project that references nothing missing passes |
| Migration accidentally removes the deployed `.claude/context/contracts/` files that healthy nvim skills depend on at runtime | H | L | Keep deployed files in place; add the extension source as the propagation origin. Verify all 6 `skill-orchestrate-hard` references still resolve in nvim after Phase 1 |
| Editing `check-extension-docs.sh` in two phases (2 and 3) on the same file risks merge churn | L | M | Territory: Phase 3 depends on Phase 2 (sequential same-file edits); both must keep the canonical `.claude/extensions/core/scripts/` copy and deployed `.claude/scripts/` copy identical |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 1, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Register contracts as a core-owned context category [COMPLETED]

- **Goal:** Make core's 8 contracts flow through the extension sync pipeline by declaring
  `contracts` in the core manifest and creating the canonical extension source directory.
- **Tasks:**
  - [x] Add `"contracts"` to `.claude/extensions/core/manifest.json` `provides.context` array. *(completed)*
  - [x] Create `.claude/extensions/core/context/contracts/` and copy the 8 deployed files into it
        (`adversarial-verification.md`, `anti-analysis.md`, `convergence.md`,
        `orchestrator-discipline.md`, `recovery.md`, `reference-grounding.md`, `territory.md`,
        `wrap-up.md`) so the extension source is byte-identical to the deployed layer. *(completed:
        diff -rq confirms byte-identical)*
  - [x] Leave the deployed `.claude/context/contracts/` files in place (runtime skills depend on
        them); do NOT delete. *(completed)*
  - [x] Confirm `context-hygiene.md` is NOT added to core (stays lean-extension-scoped). *(completed:
        remains only in `.claude/extensions/lean/context/contracts/`)*
  - [x] Reconcile `.claude/extensions/core/index-entries.json`: add `contracts` index entries (with
        `subdomain: "contracts"`) consistent with the new source location if the merge into
        `index.json` requires them; verify no duplicate/stale entries result. *(completed: 8 entries
        added matching the already-deployed `.claude/context/index.json` contracts entries verbatim,
        no duplicates)*
- **Timing:** 1 hour
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/core/manifest.json` - add `"contracts"` to `provides.context`
  - `.claude/extensions/core/context/contracts/*.md` - new canonical source (8 files)
  - `.claude/extensions/core/index-entries.json` - add/reconcile `contracts` entries
- **Verification:**
  - `jq '.provides.context | index("contracts")' .claude/extensions/core/manifest.json` is non-null.
  - `diff -rq .claude/context/contracts/ .claude/extensions/core/context/contracts/` shows no
    differences (except any Lean-scoped file, which must NOT appear in either).
  - All 6 `contracts/` references in `.claude/skills/skill-orchestrate-hard/SKILL.md` still resolve
    to existing deployed files.

### Phase 2: Add provides.context disk-existence validation to check-extension-docs.sh [COMPLETED]

- **Goal:** Close the gap where a manifest can claim a `provides.context` subdir that does not exist
  on disk (confirmed live in cslib's stale `lean` extension copy).
- **Tasks:**
  - [x] Extend `check_manifest_entries()` (or add a sibling `check_context_entries()`) to iterate
        `provides.context` and verify each entry exists as a file OR directory under
        `<ext_path>/context/<entry>`, mirroring the existing agents/skills/commands/rules/scripts
        pattern. *(completed: added inline to check_manifest_entries(), not a sibling function)*
  - [x] Emit a FAIL (non-zero contribution) with a clear message when a declared context entry is
        missing on disk. *(completed)*
  - [x] Apply the edit to the canonical source `.claude/extensions/core/scripts/check-extension-docs.sh`
        and re-sync the deployed copy `.claude/scripts/check-extension-docs.sh` so both remain identical.
        *(completed: diff confirms identical)*
- **Timing:** 0.75 hour
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/core/scripts/check-extension-docs.sh` - canonical source
  - `.claude/scripts/check-extension-docs.sh` - deployed copy (kept identical)
- **Verification:**
  - Running the script in this repo passes for `core` (now that Phase 1 created the source dir) and
    for `lean` (which has its `context/contracts/`).
  - A deliberate temporary test (declare a bogus context entry) triggers a FAIL, then is reverted.
  - `diff .claude/extensions/core/scripts/check-extension-docs.sh .claude/scripts/check-extension-docs.sh`
    shows no differences.

### Phase 3: Add deployed dangling-contract-reference scan [NOT STARTED]

- **Goal:** Add a project-wide check that catches dangling `.claude/context/contracts/*.md`
  references in deployed skills/agents/rules — the exact BimodalLogic/cslib defect.
- **Tasks:**
  - [ ] Add a new project-wide (not per-extension) check that scans `.claude/skills/*/SKILL.md`,
        `.claude/agents/*.md`, `.claude/rules/*.md` (and optionally `.claude/commands/*.md`) for
        `.claude/context/contracts/[a-z-]+\.md`-shaped references.
  - [ ] For each referenced path, verify it exists under the current project's `.claude/` root;
        FAIL loudly (visible message listing file + missing reference) when absent.
  - [ ] Scope strictly to `contracts/*.md` references (per Non-Goals); leave a clearly-commented
        extension point for a future generic `@.claude/...` scan without enabling it.
  - [ ] Re-sync the deployed copy so both script copies remain identical.
- **Timing:** 1.5 hours
- **Depends on:** 2
- **Files to modify:**
  - `.claude/extensions/core/scripts/check-extension-docs.sh` - canonical source
  - `.claude/scripts/check-extension-docs.sh` - deployed copy (kept identical)
- **Verification:**
  - Running the script in THIS repo passes (all 6 nvim `skill-orchestrate-hard` references resolve).
  - A temporary test reference to a nonexistent contract triggers a loud FAIL, then is reverted.
  - Script exits non-zero when any dangling contract reference is present.

### Phase 4: Wire the validator into the sync path with loud failure [NOT STARTED]

- **Goal:** Ensure `check-extension-docs.sh` runs automatically after a full sync / "Load Core" and
  surfaces FAIL output prominently, satisfying the LOUD-FAILURE requirement.
- **Tasks:**
  - [ ] In `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, invoke
        `check-extension-docs.sh` after `execute_sync` / the "Load Core" full-sync completes.
  - [ ] Surface FAIL output prominently (notify/echo the failing lines, not just a swallowed exit
        code); a missing contract must produce a visible message at load time, not a silent no-op.
  - [ ] Ensure a non-zero exit does not corrupt or half-apply the sync, but is clearly reported to
        the user (distinct from the existing `audit_synced_content()` grep-pattern audit, which
        stays unchanged).
  - [ ] Confirm the validator is reference-driven so a legitimate partial sync (project not loading
        `lean`) does not spuriously fail.
- **Timing:** 1 hour
- **Depends on:** 2, 3
- **Files to modify:**
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - invoke validator post-sync,
    surface failures loudly
- **Verification:**
  - Trigger a "Load Core" sync in this repo; validator runs and reports PASS visibly.
  - Introduce a temporary dangling reference; the sync path surfaces a LOUD, visible failure; revert.
  - `nvim --headless` smoke check that `sync.lua` loads without error after the edit.

### Phase 5: Document the provides.context contract and downstream reconciliation [NOT STARTED]

- **Goal:** Document why `provides.context` registration is mandatory for cross-project distribution,
  and give a reproducible procedure for reconciling downstream child-project drift (as a
  propagation step, not direct edits).
- **Tasks:**
  - [ ] Add a short section to `.claude/docs/guides/creating-extensions.md` documenting the
        `provides.context` contract and its role in `copy_context_dirs()` / the allow-list sync,
        using `contracts/` as the worked cautionary example.
  - [ ] Document the downstream reconciliation procedure (out of this repo's editable scope): from
        each affected child repo (BimodalLogic, cslib, Logos/Hardware, and the un-inspected set —
        ModelChecker, Logos/{ModelChecker,Website,Vision,Theory}, protocol, ModelBuilder,
        theorem_proving_in_lean4, ProofChecker.bak, Repos/provability-fabric), run the new validator
        to detect drift, then re-run "Load Core" to pull the now-registered core contracts.
  - [ ] Note that the new validator is the systematic sweep tool (replacing manual enumeration).
- **Timing:** 0.75 hour
- **Depends on:** 1, 4
- **Files to modify:**
  - `.claude/docs/guides/creating-extensions.md` - `provides.context` sync-contract section
  - (Optional) a short reconciliation note under the task's own docs or the guide — no edits to other repos
- **Verification:**
  - The guide section renders and cross-references `copy_context_dirs()` and the allow-list logic.
  - The reconciliation procedure is self-contained and runnable from any child repo without edits to
    this repo required.

## Testing & Validation

- [ ] `jq '.provides.context' .claude/extensions/core/manifest.json` includes `"contracts"`.
- [ ] `.claude/extensions/core/context/contracts/` contains the 8 core contract files, byte-identical
      to the deployed `.claude/context/contracts/`.
- [ ] `context-hygiene.md` is absent from core (present only in the `lean` extension).
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 in this repo (healthy source of truth).
- [ ] Temporary injected bogus `provides.context` entry -> script FAILs; reverted.
- [ ] Temporary injected dangling `.claude/context/contracts/*.md` reference -> script FAILs loudly;
      reverted.
- [ ] Both script copies (`.claude/extensions/core/scripts/` and `.claude/scripts/`) are identical.
- [ ] "Load Core" sync runs the validator and surfaces PASS/FAIL visibly.
- [ ] `nvim --headless -c "luafile <sync.lua path>" -c "q"` (or module require) loads without error.

## Artifacts & Outputs

- `.claude/extensions/core/manifest.json` (updated `provides.context`)
- `.claude/extensions/core/context/contracts/*.md` (8 new canonical source files)
- `.claude/extensions/core/index-entries.json` (reconciled `contracts` entries)
- `.claude/extensions/core/scripts/check-extension-docs.sh` and `.claude/scripts/check-extension-docs.sh`
  (two new checks; kept identical)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (validator wired into sync path)
- `.claude/docs/guides/creating-extensions.md` (provides.context contract + reconciliation procedure)
- `specs/837_fix_claude_contract_drift_add_dangling_ref_lint/summaries/01_contract-drift-lint-wiring-summary.md`

## Rollback/Contingency

- Each phase is an isolated, revertible edit. If Phase 1 migration causes runtime issues, revert the
  manifest `provides.context` change and delete the new `.claude/extensions/core/context/contracts/`
  directory; the deployed `.claude/context/contracts/` files are untouched, so nvim's healthy state
  is preserved.
- If the validator wiring (Phase 4) blocks legitimate syncs, gate the invocation behind a report-only
  mode (warn but do not abort) until the reference-driven scope is confirmed, then re-enable loud
  failure.
- Script changes (Phases 2-3) are additive checks; revert via git to restore the prior
  `check-extension-docs.sh` if a false-positive pattern emerges.

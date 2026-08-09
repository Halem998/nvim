# Implementation Summary: Task #991

- **Task**: 991 - meta_catchall_decomposition
- **Status**: [COMPLETED]
- **Started**: 2026-08-09T21:10:00Z
- **Completed**: 2026-08-09T21:52:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_meta-catchall-decomposition.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Broke the `task_types: ["meta"]` catch-all in the context index and converted
`validate-context-budgets.sh` from reading a never-populated authored `tier` field to deriving
tier algorithmically from `load_when` shape. All 25 meta-only entries now carry a real hook or an
explicit `on_demand` marker, `"meta"` no longer appears in any `load_when.task_types` array
repo-wide, and the two checks whose meaning changed under derivation were restated rather than
left as tautologies. Every edit targets the source store at `agent-system/extensions/**`; nothing
under `.claude/**` was written.

## What Changed

- `agent-system/extensions/core/scripts/validate-context-budgets.sh` — added a single
  `derived_tier` jq function with a documented rule table; converted all four former `.tier` read
  sites (verbose per-agent listing, Tier Classification Check, Dead Entry Check ×2, Double-Loading
  Check); re-keyed the Dead Entry Check on an explicit `on_demand` marker; restated the
  Double-Loading Check on `load_when` shape alone and downgraded it to a warning; split the
  `WARNINGS` counter so a double-loading warning is no longer narrated as a documented budget
  exception.
- `agent-system/extensions/core/index-entries.json` — 25 entries rehooked (G1–G7), 6 marked
  `on_demand: true`, 61 trimmed of `"meta"`, 1 entry's two broken agent names removed, 1
  `line_count` corrected.
- `agent-system/extensions/core/context/index.schema.json` — declared the optional `on_demand`
  boolean property; extended the entry `$comment` to record why it exists.
- `agent-system/extensions/nvim/index-entries.json` — trimmed `"meta"` from its one meta-tagged
  entry.
- `specs/991_meta_catchall_decomposition/shadow-validate.sh` — new redeploy-free verification
  harness (task artifact).
- `specs/991_meta_catchall_decomposition/baseline-validator.txt`,
  `final-validator.txt` — before/after records.

## Decisions

- **Tier derivation rule table**: `always` → 1; non-empty `agents` → 2; non-empty `commands` or
  `task_types` → 3; all hooks empty → 4. Verified total over the corpus (no entry is reachable
  only via `skills`/`languages`, so no entry falls through miscategorized).
- **The `grep -c '.tier'` gate stays a pure read-site detector.** Two explanatory comments
  quoting the old predicates initially tripped it. Rather than deviate from the plan's gate, the
  comments were reworded to describe the old predicates without the literal dotted token, keeping
  both the explanation and a zero-false-positive check.
- **Double-Loading downgraded to a warning, not folded in silently.** The restatement surfaces 49
  pre-existing matches at once; counting them as violations would fail every run from day one and
  the signal would be switched off rather than acted on.
- **Class 2 trim (12 entries): `"meta"` dropped, `/meta` added to none.** Each already carries a
  command hook reaching its real consumer. The two closest calls
  (`repo/self-healing-implementation-details.md`, `reference/orchestrator-critical-paths.json`)
  are already hooked to `/errors,/fix-it` and `/orchestrate` respectively.
- **`CAPS`/`EXCEPTIONS` left untouched**, per the plan's rejection of option (a): raising caps to
  measured usage would retire the per-agent budget check as a live instrument.

## Plan Deviations

- **Phase 3 — cslib mirror entry skipped** (phase closed `[COMPLETED WITH EXCLUSIONS]` with a
  full `#### Reasoned Exclusions` record). `check-extension-docs.sh` Rule R is a hard gate
  requiring every index entry to resolve to a source file at `<ext>/context/<path>`; cslib ships
  no copy of the contract, so the mirror entry is structurally illegal regardless of its
  `load_when` shape. The plan cited `lean/index-entries.json` as shape precedent without
  accounting for lean also owning its own 93-line copy of the file. Making the cslib entry legal
  would mean authoring a cslib-specialized ~103-line copy of a core-owned contract — a new file
  outside the declared Scope Expansion and precisely the "guessing at a shape" the phase's own
  contingency forbids. Took the documented contingency: kept the core removal (correct on its
  own), recorded the mirror as unfinished. **Known consequence**: in a cslib-loaded deploy the
  contract was previously reachable for `cslib-research-hard-agent` via core's entry and now is
  not.
- **Phase 4 — `meta-builder-agent` moved +40 tokens** (130,360 → 130,400) where the phase
  predicted a byte-identical per-agent block. Fully traced: `index.schema.json` is itself an
  indexed entry whose `load_when.agents` names `meta-builder-agent`; the plan-mandated `$comment`
  extension plus the new property grew it 128 → 133 lines, and Rule R's hard `line_count` gate
  required correcting the declared count. 5 lines × 8 = 40 tokens exactly. Shrinking the comment
  to restore 128 lines was rejected as tuning the artifact to flatter the number. The bar's
  `meta-builder-agent` row is restated as 130,400 with this justification.
- **Phase 2 — `EXCEPTIONS_APPLIED` counter added** (not in the plan). Routing the Double-Loading
  warning through the shared `WARNINGS` counter would have made the summary print
  "Documented exceptions: 1" for a finding that is not a budget exception. Splitting the counters
  keeps both reports honest.

## Verification

- Build: N/A. `bash -n` on the validator: PASS.
- Tests: harness run at every phase boundary, diffed against the prior phase.
- `grep -c '.tier'` on the validator: **0** read sites.
- `jq empty` on all edited JSON: PASS. Entry counts unchanged: core 136, nvim 24, cslib 16.
- Dead Entry Check **negative test**: unmarking `contracts/convergence.md` reproduced exactly 1
  violation naming it; restored byte-identical. The check retains real signal.
- `check-extension-docs.sh`: only the expected deployed-vs-source drift on the edited validator
  (resolves on the operator's redeploy). No Rule R or Rule T findings.
- `check-task-references.sh`: PASS, 0 unexempted occurrences across 4 deliverable trees.
- `CAPS`/`EXCEPTIONS`: unchanged; no hunk adds or removes a table row.
- Harness path-set identity vs the deployed index: empty diff, 187 entries, 0 duplicate paths.

### Final state vs the chosen bar

| Row | Required | Measured |
|-----|----------|----------|
| Tier Classification | OK via derivation | OK — Tier 1:3 / 2:144 / 3:34 / 4:6 |
| Dead Entry (explicit-intent) | OK, 0 violations | OK — all 6 all-empty entries carry `on_demand` |
| Double-Loading | warning naming 49 | warning naming 49, 0 violations |
| Tier 1 Check | unchanged | OK, 3 entries / 334 lines |
| Per-agent budget | exactly 8 violations | exactly 8, same agents, no ninth |
| `general-implementation-agent` | 68,560 | **68,560** |
| `planner-agent` | 31,848 | **31,848** |
| Every other capped agent | byte-identical | byte-identical (except the recorded +40) |
| Total / exit | 8 / exit 1 | **8 / exit 1** |

### Remaining violations (all 8 pre-existing per-agent budget overruns)

| Agent | Baseline | Final | Note |
|-------|----------|-------|------|
| `meta-builder-agent` | 130,360 | 130,400 | +40, recorded deviation above |
| `general-implementation-agent` | 56,800 | 68,560 | +11,760, predicted (G1+G5 hooks) |
| `neovim-implementation-agent` | 40,104 | 40,104 | untouched |
| `planner-agent` | 29,200 | 31,848 | +2,648, predicted (G1 hooks) |
| `general-research-agent` | 28,744 | 28,744 | untouched |
| `neovim-research-agent` | 22,872 | 22,872 | untouched |
| `nix-implementation-agent` | 22,520 | 22,520 | untouched |
| `nix-research-agent` | 19,896 | 19,896 | untouched |

Exit 1 is the accepted terminal state. Two agents increased by predicted, documented amounts
because correct hooks outrank the cap; the other six are untouched by this work.

## Impacts

- **Work item 1**: meta-only entries 25 → 0.
- **Work item 2**: `"meta"` in `load_when.task_types` repo-wide (all 19 extensions) 87 → 0.
  `meta-builder-agent`'s resolved context under the documented adaptive query drops from
  93 entries / 26,987 lines to **54 / 16,634** — a **38.4%** reduction.
- **Work item 3**: the authored `tier` field is read at zero call sites.
- **Work item 4**: no `load_when.agents` array in the reconstructed index names an agent absent
  from this deploy.
- Phase 7 empirically confirmed the research's central prediction: the per-agent block was
  byte-identical across the trim, proving the budget check reads only `load_when.agents` and
  never `task_types`.

## Follow-ups

- **Operator step (required, not done by the implementer)**: redeploy the `.claude/` tree
  (`<leader>al` → `[Reload All]`, or `deploy-headless.sh` invoked deliberately), then run
  `bash .claude/scripts/validate-context-budgets.sh` and confirm it matches `final-validator.txt`
  apart from the `Index:` line. Also spot-check `--verbose` prints real derived tiers instead of
  `Tier ?`. The implementer did not redeploy: `regeneration-is-manual-only.md` sanctions exactly
  one automated caller and this was not it.
- **Triage the 49 Double-Loading warnings.** Surfaced by the restatement, deliberately not folded
  in.
- **cslib hook for `contracts/adversarial-verification.md`.** Requires cslib to first own a copy
  at `cslib/context/contracts/adversarial-verification.md` (mirroring how lean does it); the
  index entry is the second step, not the first.
- **Author a tier-semantics context file.** The derivation's authority is currently the
  `derived_tier` function and its header comment.
- **Observed, not acted on**: `lean/index-entries.json`'s mirror entry names only
  `lean-research-hard-agent`. Under the loader's upsert-by-path (last extension processed wins the
  whole entry), a lean-loaded deploy that processes lean after core would drop
  `general-research-hard-agent`'s hook on that path. This is the dormant load-order issue the
  plan put out of scope; recorded here so it is not lost.

## References

- `specs/991_meta_catchall_decomposition/plans/01_meta-catchall-decomposition.md`
- `specs/991_meta_catchall_decomposition/reports/01_meta-catchall-decomposition.md`
- `specs/991_meta_catchall_decomposition/baseline-validator.txt`
- `specs/991_meta_catchall_decomposition/final-validator.txt`
- `specs/991_meta_catchall_decomposition/shadow-validate.sh`

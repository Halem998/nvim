# Implementation Plan: Fix opencode agent-fragment path resolution and validator fail-fast

- **Task**: 19 - Fix opencode agent-fragment path resolution and validator fail-fast
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/019_fix_opencode_agent_fragment_paths/reports/01_opencode-fragment-path-fix.md`
- **Artifacts**: plans/01_opencode-fragment-path-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

All 12 extension `opencode-agents.json` fragments carry `{file:...}` references to directories
that no deploy path ever populates, so `validate_opencode_fragment` fails, and because that
validator is fail-fast *and* its caller degrades per-fragment, one unreadable path silently
discards an entire extension's agent set — 18 agents vanish from the generated `opencode.json`.
This plan repoints every fragment at `.claude/agents/<agent>.md` (the research's recommended
Option (a), requiring zero new deploy code), corrects the two fragments whose problem goes beyond
a directory swap, and converts the validator from fail-fast/per-fragment to report-all/per-agent-key
so the next stale rename degrades gracefully instead of amplifying. A before/after noise
measurement is an explicit deliverable, produced so the sibling noise-silencing task can narrow
its scope against evidence rather than re-diagnosing.

### Research Integration

The research report's recommendation is adopted in full and was independently re-verified during
planning:

- **Option (a) confirmed airtight.** Every fragment's `{file:...}` basename was cross-checked
  against its own extension's `manifest.json` `provides.agents` and against the real files in
  `agent-system/extensions/<ext>/agents/`. Exactly one basename is stale across all 12 fragments:
  `present`'s `slides-agent.md` (real file: `slides-research-agent.md`). Every other basename
  matches its manifest exactly, including `epidemiology`'s `epi-research-agent.md` /
  `epi-implement-agent.md`.
- **Count correction confirmed.** 11 of 12 fragments use `.opencode/agent/subagents/`; only `lean`
  differs, using the nonexistent `.claude/extensions/lean/agents/`.
- **No redeploy is required for this fix (new, planning-time finding).** `config.claude()` sets
  `global_extensions_dir = ~/.config/nvim/agent-system/extensions`, and
  `generate_opencode_json` reads each fragment from `extension.path .. "/opencode-agents.json"`
  — i.e. directly from the source store. `merge.lua` is live code under `lua/`, not a deployed
  artifact. Both edit targets therefore take effect without touching `.claude/` at all, which
  removes the largest execution risk this task could have carried.
- **Validator/caller contract is contained (new, planning-time finding).** A repo-wide grep shows
  `validate_opencode_fragment` has no caller outside `merge.lua`, so its return-shape change has
  an empty external dependent set. `generate_opencode_json` has four external call sites but its
  signature is unchanged by this work.
- **A second, independent noise source will survive this fix (new, planning-time finding).**
  `verify.lua`'s `verify_opencode_json_merge` compares fragment *keys* against
  manifest-derived names and is reached from `verify_extension` on the reload path. Measured
  today: `epidemiology` reports 2 missing-from-fragment + 2 missing-from-manifest, `lean` 2, and
  `present` 5 + 1. Renaming `present`'s `slides` key clears its missing-from-manifest entry but
  leaves 4 missing-from-fragment; `epidemiology`'s and `lean`'s persist entirely. This is
  key-parity noise, categorically distinct from the `{file:...}` path noise this task fixes, and
  it is precisely the kind of residual the sibling task must be told about rather than left to
  rediscover.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Every `{file:...}` reference in all 12 `agent-system/extensions/*/opencode-agents.json`
  fragments resolves to a real file for any project where that extension is loaded.
- `present`'s stale `slides` entry is corrected to `slides-research`, both in its `{file:...}`
  basename and its agent key.
- `validate_opencode_fragment` reports every missing reference in a fragment, deterministically,
  in one message — not a nondeterministic first-miss.
- `generate_opencode_json` degrades per-agent-key: a fragment with one bad reference contributes
  all its other agents instead of contributing none.
- A measured, evidenced before/after noise record is produced and handed to the sibling
  noise-silencing task, including the residual noise this fix does **not** eliminate.

**Non-Goals**:
- **Producing functionally correct OpenCode prompt bodies.** `.claude/agents/*.md` are
  Claude-Code-flavored: they carry `model:` YAML frontmatter and `@.claude/context/...`
  self-references, and no OpenCode-flavored agent body exists anywhere in the source store for
  these extensions. This fix makes the references *resolve* and restores all 18 dropped agents to
  the generated `opencode.json`; it does not make those agents semantically correct under
  OpenCode. That is a pre-existing authoring gap, neither introduced nor worsened here, and it
  must be stated plainly in the handoff record so a later reader cannot mistake this fix for
  end-to-end OpenCode correctness.
- Adding a deploy step that populates `.opencode/agent/subagents/` (research Option (b) —
  explicitly rejected: premature investment in a dormant path that would not fix the content
  mismatch anyway).
- Gating opencode fragment processing off (research Option (c) — explicitly rejected: defers
  rather than fixes the latent agent-drop).
- Any edit to `.opencode/extensions/**`. That mirror has already independently diverged and
  self-corrected for `nix`, `present`, and `lean`; reconciling it is the sibling sync/drift task's
  decision, not this task's.
- Any edit to any deployed `.claude/**` file.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edits land in the deployed `.claude/` tree instead of the source store and are wiped by the next reload | H | L | Every phase names `agent-system/extensions/**` or `lua/**` explicitly; Phase 6 verifies `git status` shows no `.claude/**` modification. `.claude/` is gitignored here, so a stray write would also be invisible to review — treat the path check as mandatory, not advisory |
| Renaming `present`'s `slides` key breaks an external `--agent slides` invocation | M | L | `.opencode/` is dormant: no `opencode.json` or `opencode.json.managed` exists in this repo, and the research confirms no current reliance. Safe to rename now, before real usage resumes |
| The measurement is taken against a repo where only 2 of the 12 fragment-owning extensions are loaded, overstating coverage | M | H | Phase 1 and Phase 6 split measurement into a *live* arm (loaded extensions only, end-to-end through the real generator) and a *structural* arm (all 12 fragments, basename-vs-manifest, deploy-independent). Neither arm is reported as if it were the other |
| The temporary `opencode.json.managed` marker needed for live measurement is left behind or committed | M | M | Phases 1 and 6 create and delete the marker within the same phase and assert `git status --porcelain` shows no new untracked root files before closing |
| Per-agent-key degradation subtly changes merge behavior for the four external `generate_opencode_json` call sites without changing its signature | M | L | Phase 5 is declared `local` precisely because its blind spot is behavior-through-unchanged-signature; Phase 6's live end-to-end measurement is the covering check for exactly that blind spot |
| A task number leaks into a fragment JSON or into `merge.lua` | M | L | Both edit targets are deliverables outside `specs/**`; the write-time guard blocks it, and Phase 6 re-checks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 4 |
| 4 | 6 | 2, 3, 5 |

Phases within the same wave can execute in parallel. Wave 2 is genuinely parallel-safe by
territory: Phase 2 owns the 11 uniform fragment files, Phase 3 owns `lean` + `present`, Phase 4
owns `merge.lua`. No two wave-2 phases touch the same file.

### Phase 1: Baseline noise census and measurement harness [COMPLETED]

**Goal**: Capture the before-state noise numbers, by both measurement arms, before any edit. This
is the baseline half of the measurement deliverable the sibling task depends on.

**Tasks**:
- [x] Census every `{file:...}` reference across all 12 fragments; record the total count and the
      per-fragment breakdown (`grep -o '{file:[^}]*}' agent-system/extensions/*/opencode-agents.json`).
      *(completed: measured 34 total references, correcting the research's ~30 estimate)*
- [x] **Structural arm (all 12 fragments, deploy-independent)**: for each fragment, check whether
      each `{file:...}` basename appears in that extension's `manifest.json` `provides.agents`.
      Record the count of mismatches. Expected baseline: 1 (`present`'s `slides-agent.md`).
      *(completed: measured 1 mismatch, matches expectation)*
- [x] **Structural arm, resolvability**: record how many of the referenced paths are readable from
      the repo root today. Expected baseline: 0. *(completed: measured 0/34 resolvable)*
- [x] **Key-parity arm (all 12, deploy-independent)**: run the fragment-keys-vs-manifest symmetric
      difference that `verify.lua`'s `verify_opencode_json_merge` performs, and record per-extension
      `missing_from_fragment` / `missing_from_manifest`. This is the separate noise source that
      will partially survive the fix. *(completed: epidemiology 2+2, lean 2+0, present 5+1 --
      matches research's measured numbers)*
- [x] **Live arm (loaded extensions only)**: create a temporary `opencode.json.managed` marker at
      the repo root, drive `generate_opencode_json` headlessly, and capture (a) the number of
      `WARN` lines it emits and (b) `jq '.agent | keys | length'` of the produced `opencode.json`.
      Note in the record which extensions were loaded at measurement time. *(completed: extensions
      loaded today with fragments are nix and nvim only; 2 WARN lines, 9 agent keys in generated
      opencode.json -- zero nix/nvim agents merged)*
- [x] Delete `opencode.json` and `opencode.json.managed`; confirm `git status --porcelain` shows
      no new untracked root files. *(completed)*
- [x] Write the raw command outputs to the scratchpad and keep them for Phase 6's diff.
      *(completed: scratchpad/phase1-*.txt and phase1-baseline-record.md)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research asserts ~30 agent-key file references across 12 fragments and
~60 warning lines. Both are hypotheses. Confirm the true reference count from the census command
above and the true live warning count from the live arm; report the measured numbers, and if they
differ from the research's estimates, say so explicitly rather than restating the estimate.

**Files to modify**:
- None (read-only phase; scratchpad outputs only)

**Verification**:
- All four measurement arms produced numbers, each labelled with its scope (all-12 structural vs.
  loaded-only live).
- `git status --porcelain` clean of new root-level files after the live arm.

---

### Phase 2: Repoint the 11 uniform fragments to `.claude/agents/` [COMPLETED]

**Goal**: Replace the `.opencode/agent/subagents/` directory prefix with `.claude/agents/` in
every fragment that uses it, leaving basenames untouched.

**Tasks**:
- [x] For each of `epidemiology`, `filetypes`, `formal`, `latex`, `nix`, `nvim`, `present`,
      `python`, `typst`, `web`, `z3`: rewrite each `{file:.opencode/agent/subagents/<name>.md}`
      to `{file:.claude/agents/<name>.md}`. *(completed: 32 substitutions across 11 files, matching
      the Phase 1 census for these fragments)*
- [x] Do not alter any basename in this phase. `present`'s stale `slides-agent.md` basename is
      Phase 3's territory — this phase only moves its directory prefix. *(completed: confirmed
      present's basename mismatch persists exactly as before, deferred to Phase 3)*
- [x] Confirm each edited file still parses (`jq empty <file>`). *(completed: all 11 pass)*
- [x] Confirm no `.opencode/agent/subagents/` reference remains in any of the 11. *(completed:
      repo-wide grep confirms zero matches)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly 11 fragments and the per-fragment reference
counts censused in Phase 1. Confirm at implementation time that the number of substitutions made
equals the Phase 1 census count for those 11 files, and that a repo-wide
`grep -rn '.opencode/agent/subagents/' agent-system/extensions/` returns nothing afterward.

**Files to modify**:
- `agent-system/extensions/epidemiology/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/filetypes/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/formal/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/latex/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/nix/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/nvim/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/present/opencode-agents.json` - directory prefix swap only
- `agent-system/extensions/python/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/typst/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/web/opencode-agents.json` - directory prefix swap
- `agent-system/extensions/z3/opencode-agents.json` - directory prefix swap

**Verification**:
- `jq empty` passes on all 11 files.
- `grep -rn 'opencode/agent/subagents' agent-system/extensions/` returns no matches.
- Every resulting basename still appears in its extension's `manifest.json` `provides.agents`.

---

### Phase 3: Correct the two non-uniform fragments [COMPLETED]

**Goal**: Fix `lean`'s wrong directory and `present`'s stale basename plus its mismatched agent
key — the two problems a uniform directory swap cannot reach.

**Tasks**:
- [x] `lean`: rewrite both `{file:.claude/extensions/lean/agents/<name>.md}` references to
      `{file:.claude/agents/<name>.md}`, preserving the `lean-research-agent.md` and
      `lean-implementation-agent.md` basenames (both confirmed present in `lean`'s manifest and
      in `agent-system/extensions/lean/agents/`). *(completed)*
- [x] `present`: change the `slides` entry's `{file:...}` basename from `slides-agent.md` to
      `slides-research-agent.md`. *(completed)*
- [x] `present`: rename the agent key `slides` to `slides-research`, so the key matches its
      manifest-derived name and `verify.lua`'s key-parity check stops reporting it as
      missing-from-manifest. *(completed)*
- [x] Confirm both files parse (`jq empty`). *(completed: both pass)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that exactly two fragments need correction beyond the
directory swap, and that `present`'s `slides-agent.md` is the only stale basename across all 12
fragments. Confirm both by re-running Phase 1's structural basename-vs-manifest check after this
phase: it must report zero mismatches across all 12.

**Files to modify**:
- `agent-system/extensions/lean/opencode-agents.json` - directory prefix correction on 2 references
- `agent-system/extensions/present/opencode-agents.json` - `slides` key rename plus basename correction

**Verification**:
- `jq empty` passes on both files.
- `grep -rn '.claude/extensions/lean' agent-system/extensions/` returns no matches.
- `present`'s fragment contains key `slides-research` pointing at
  `{file:.claude/agents/slides-research-agent.md}`, and no key `slides`.
- The structural basename-vs-manifest check reports zero mismatches across all 12 fragments.

---

### Phase 4: Validator report-all in `validate_opencode_fragment` [COMPLETED]

**Goal**: Make the validator collect every missing reference in a fragment and return them all in
one deterministic message, instead of returning on the first miss under nondeterministic
`pairs()` order.

**Tasks**:
- [x] In `M.validate_opencode_fragment`, accumulate every `(agent_name, file_path)` whose
      resolved path is unreadable rather than returning on the first one. *(completed)*
- [x] Sort the accumulated misses by agent name so repeated runs produce identical output — the
      nondeterministic-ordering complaint in the research is as much a defect as the truncation.
      *(completed: agent_names collected then table.sort()'d before iteration)*
- [x] Return `false` plus a single message enumerating all misses when any exist; return
      `true, nil` when none do. Keep the two-value `(boolean, string|nil)` shape so the caller's
      contract is unchanged in type. *(completed: first two return values unchanged in type; see
      deviation note below on the added third value)*
- [x] Additionally return, or otherwise make available to the caller, the per-agent miss set that
      Phase 5 needs for per-key degradation. Do not force Phase 5 to re-derive it by re-parsing
      the message string. *(completed: added a third return value, `missing_by_key` (agent_name ->
      file_path map), consumed directly by Phase 5 -- a Lua multi-return addition, not a change to
      the first two values' type, consistent with "unchanged in type")*
- [x] Keep the existing LuaDoc annotation block accurate for the new return contract. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The dependent set for this signature change is asserted to be empty outside
`merge.lua` (planning-time grep found no other caller of `validate_opencode_fragment` anywhere in
`lua/`). Re-confirm with a repo-wide grep at implementation time before relying on it; if any
external caller has appeared, enumerate and build it as this tier requires.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - `M.validate_opencode_fragment`

**Verification**:
- Repo-wide grep re-confirms the enumerated dependent set (expected: `merge.lua` only).
- `merge.lua` loads clean headlessly
  (`nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"`).
- A headless harness feeding a synthetic fragment with two bad references gets both named in one
  message, and gets byte-identical output across repeated runs.

---

### Phase 5: Per-agent-key degradation in `generate_opencode_json` [COMPLETED]

**Goal**: Stop one bad reference from discarding an entire extension's agent set. Merge every
agent whose own `{file:...}` resolves; skip only the individual offending keys.

**Tasks**:
- [x] Replace the all-or-nothing `if valid then ... else skip fragment` branch with a per-key
      merge that consults the per-agent miss set from Phase 4. *(completed)*
- [x] Preserve the existing first-writer-wins semantics (`if base.agent[key] == nil then`) for
      keys that do merge. *(completed: preserved via `elseif base.agent[key] == nil then`)*
- [x] Emit one `WARN` per fragment naming every skipped key and its missing path, stating clearly
      that the named keys were skipped and the rest of the fragment was merged — the current
      message says "Skipping fragment", which will be actively wrong after this change.
      *(completed: new message names each skipped key with its missing path and states the rest
      of the fragment was merged)*
- [x] Leave `generate_opencode_json`'s `(boolean, string|nil)` signature unchanged. *(completed:
      unchanged)*

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that `generate_opencode_json`'s four external call sites
(`opencode/core/init.lua`, `opencode.lua`, and two in `shared/extensions/init.lua`) need no change
because the signature is unchanged. Re-confirm the call-site list by grep at implementation time
and confirm none inspects merge granularity.

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - `M.generate_opencode_json` merge loop and
  warning message

**Verification**:
- `merge.lua` loads clean headlessly.
- A headless harness with a synthetic fragment holding one resolvable and one unresolvable agent
  produces an `opencode.json` containing the resolvable agent and a warning naming only the
  unresolvable one.
- Declared blind spot for this tier — behavior change visible to the four callers through an
  unchanged signature — is covered by Phase 6's live end-to-end run, not deferred past it.

---

### Phase 6: After-measurement, residual-noise report, and sibling handoff record [NOT STARTED]

**Goal**: Produce the measured after-state, quantify what noise remains and why, and record the
two out-of-scope facts the sibling tasks need. This phase is the deliverable the coordination
depends on; it is not a formality.

**Tasks**:
- [ ] Re-run all four Phase 1 measurement arms unchanged, with the same commands, and diff against
      the baseline.
- [ ] Confirm the live arm now emits zero `{file:...}` validation warnings and that
      `jq '.agent | keys | length'` on the generated `opencode.json` has risen by the expected
      number of restored keys for the loaded extensions.
- [ ] Confirm the structural arm now reports zero unresolvable-by-construction references and zero
      basename-vs-manifest mismatches across all 12 fragments.
- [ ] Delete `opencode.json` and `opencode.json.managed`; confirm `git status --porcelain` shows
      no new untracked root files.
- [ ] Confirm `git status` shows modifications only under `agent-system/extensions/` and
      `lua/neotex/plugins/ai/shared/extensions/merge.lua` — no `.claude/**` writes, no
      `.opencode/extensions/**` writes.
- [ ] Confirm no task-number citation was introduced into any edited fragment or into `merge.lua`.
- [ ] Write the **Noise Measurement** section of the implementation summary, containing: the
      before/after table for all four arms; the explicit statement of what percentage of the
      original warning noise this fix eliminated, measured rather than estimated; and the
      **residual noise inventory** — specifically that `verify.lua`'s key-parity check still
      reports missing-from-fragment entries for `epidemiology`, `lean`, and `present` (whose
      fragments intentionally cover fewer agents than their manifests declare), which is a
      distinct noise source this task does not address.
- [ ] Write the **Scope Boundaries and Sibling Interactions** section of the summary, recording:
      (a) the OpenCode content-flavor gap — references now resolve, but the resolved bodies are
      Claude-flavored and are not functionally correct OpenCode prompts, a pre-existing gap left
      deliberately open; and (b) the mirror interaction — `present` and `lean` were edited here in
      ways where `.opencode/extensions/`'s copies were *already* independently more correct, so a
      naive one-way canonical-to-mirror sync would now be closer to harmless for those two but
      `nix`'s mirror still carries a self-contained per-extension path convention that a one-way
      sync would regress. Note also that the OpenCode config preset reads its fragments from
      `.opencode/extensions/`, not from the source store this task edited, so nothing done here
      changes mirror behavior.

**Timing**: 1.25 hours

**Depends on**: 2, 3, 5

**Verification Tier**: local

**Scope Hypothesis**: The research estimates this fix removes "essentially 100%" of the reported
warning noise. Treat that as a hypothesis to be measured, not restated. Report the measured
reduction, and if the residual is above zero, enumerate each remaining warning by source and
extension so the sibling task inherits a list rather than a percentage.

**Files to modify**:
- `specs/019_fix_opencode_agent_fragment_paths/summaries/01_opencode-fragment-path-fix-summary.md` -
  add the Noise Measurement and Scope Boundaries and Sibling Interactions sections

**Verification**:
- Before/after numbers present for all four arms, each labelled with its scope.
- Residual noise enumerated by source and extension, not summarized as a percentage alone.
- Both out-of-scope facts recorded verbatim enough that a sibling task reader needs no further
  archaeology.
- `git status --porcelain` shows no `.claude/**`, no `.opencode/**`, and no stray root-level files.

---

## Testing & Validation

- [ ] `jq empty` passes on all 12 `agent-system/extensions/*/opencode-agents.json`.
- [ ] `grep -rn 'opencode/agent/subagents\|\.claude/extensions/lean' agent-system/extensions/`
      returns no matches.
- [ ] Every `{file:...}` basename across all 12 fragments appears in its extension's
      `manifest.json` `provides.agents`.
- [ ] `merge.lua` loads clean under `nvim --headless`.
- [ ] Headless harness: a fragment with two bad references names both, deterministically, in one
      message.
- [ ] Headless harness: a fragment with one good and one bad reference merges the good key and
      skips only the bad one.
- [ ] Live end-to-end generation for the loaded extensions emits zero `{file:...}` warnings and
      contains every expected agent key.
- [ ] No modifications outside `agent-system/extensions/**`, `lua/.../merge.lua`, and `specs/**`.
- [ ] No task-number citations in any deliverable file outside `specs/**`.

## Artifacts & Outputs

- 11 repointed fragments under `agent-system/extensions/*/opencode-agents.json` (Phase 2)
- 2 corrected fragments: `lean` and `present` (Phase 3)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` with report-all validation and per-agent-key
  degradation (Phases 4-5)
- `specs/019_fix_opencode_agent_fragment_paths/summaries/01_opencode-fragment-path-fix-summary.md`
  containing the **Noise Measurement** and **Scope Boundaries and Sibling Interactions** sections
  (Phase 6) — the handoff deliverable for both sibling tasks

## Rollback/Contingency

Every edit is a small, self-contained change to a git-tracked file, committed per green sub-step,
so `git revert` of the relevant commits restores the prior state exactly. No deployed artifact is
written and no migration is performed, so there is no out-of-band state to unwind.

If Phase 5's per-agent-key degradation proves harder to land cleanly than estimated, Phases 2-4
stand alone and are independently valuable: the path fix eliminates the actual observed noise, and
the report-all validator improves diagnosis, without Phase 5. In that case, close Phase 5 as
`[PARTIAL]`, keep Phases 2-4 committed, and record the deferral in the Phase 6 handoff record so
the sibling noise task can pick up the degradation change with full context — the research already
identifies it as work that task could legitimately own.

If the live measurement arm cannot be driven headlessly within its time box, fall back to the
structural and key-parity arms alone, which are deploy-independent and cover all 12 fragments, and
say explicitly in the handoff record that the live arm was not taken. Do not report a structural
result as if it were a live one.

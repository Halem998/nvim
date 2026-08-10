# Research Report: CSLib Adversarial-Verification Mirror

**Task**: Give the cslib extension its own copy of the adversarial-verification contract and a
union-valued index entry for it, closing a recorded regression.
**Started**: 2026-08-10T00:38:23Z
**Completed**: 2026-08-10T00:50:00Z
**Effort**: Small (2 files, ~150 lines total)
**Dependencies**: Two prior meta tasks that decomposed a catch-all task and recorded this gap
as a follow-on (see their summaries under `specs/991_meta_catchall_decomposition/` and
`specs/992_extension_md_slim_down/`)
**Sources/Inputs**: Codebase (core/lean/cslib context trees, `merge.lua`, `check-extension-docs.sh`,
`validate-context-budgets.sh`), prior-task summaries/plans/reports, a headless-Neovim upsert
simulation
**Artifacts**:
- `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` (new file, 117 lines)
- `agent-system/extensions/cslib/index-entries.json` (new entry appended)
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Authored `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` (117
  lines) and added a matching `contracts/adversarial-verification.md` entry to
  `agent-system/extensions/cslib/index-entries.json`, in that order (source file first, satisfying
  Rule R before the index entry references it).
- Chose **near-verbatim mirror content** (option "a" of the three the task posed), not a
  cslib-specialized rewrite like lean's. Rationale: the deployed path
  `.claude/context/contracts/adversarial-verification.md` is shared with core, and the loader's
  upsert-by-path merge means whichever extension is processed last for a given deploy fully
  replaces the file content at that path — so `general-research-hard-agent` may transparently end
  up reading cslib's copy. Keeping the body identical to core's avoids silently narrowing or
  drifting the contract for agents that never asked for cslib-specific instructions.
- The index entry's `load_when.agents` is `["general-research-hard-agent",
  "cslib-research-hard-agent"]` — a union, not cslib's agent alone — following the task's explicit
  instruction and the same pattern lean's own entry should carry (out of this task's file scope).
- Verified with a headless-Neovim simulation of `merge.append_index_entries` (core's entry applied
  first, cslib's entry applied second, matching realistic processing order) that the merged result
  retains **both** agent names in a single entry — the union survives the upsert; it was not
  assumed.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` now reports
  `cslib PASS` (previously would have failed Rule R had the index entry been added without the
  source file, as the prior task's phase-contingency probe confirmed).
- `bash .claude/scripts/validate-context-budgets.sh` shows 8 pre-existing violations, all against
  agents from extensions already loaded in this repo's live deploy (`core`, `nix`, `nvim`, etc.);
  cslib is not currently a loaded extension here (`.claude-extensions.json` lists only `core`,
  `email`, `memory`, `nix`, `nvim`), so this change cannot have introduced a new violation — it
  never reaches the deployed index in this repo's current configuration. No new failing agent name
  appears in the report.

## Context & Scope

**What was researched**: How to close a specific, previously-documented regression where
`cslib-research-hard-agent` lost reach to the H4 adversarial-verification contract after a prior
task correctly narrowed core's `contracts/adversarial-verification.md` index entry to list only
core-shipped agents (removing `cslib-research-hard-agent` and `lean-research-hard-agent`, both of
which name agents belonging to extensions that were unloaded in that deploy). The prior task
explicitly declined to author the cslib-side fix because it required a new ~103-line file outside
its declared scope, and recorded the gap as this follow-on task instead.

**Constraints established by the prior task and re-verified here, not re-discovered**:
- `check-extension-docs.sh` Rule R (`check_line_count_accuracy`, a hard gate —
  `INDEX_TRUTH_GATE_MODE` defaults to `hard`) requires every `index-entries.json` entry to resolve
  to an actual source file at `<ext>/context/<path>` with a matching `line_count`. An index entry
  alone, with no source file, fails this gate — reproduced by the prior task and re-confirmed here
  by construction (the file was authored before the entry was added).
- The lean extension's existing `contracts/adversarial-verification.md` mirror entry works only
  because lean owns its own 93-line specialized copy of the file; it is not evidence that a bare
  index entry suffices.
- The extension loader's `merge.lua` (`M.append_index_entries`) performs an **upsert by path**:
  if an entry's `path` already exists in the target deployed index, the whole object (content and
  `load_when`, not just changed fields) is replaced in place. Whichever extension is processed
  last for a given load/sync run wins the entry entirely. This is documented in `merge.lua` as a
  "known dormant risk" for the `contracts/*.md` paths core and lean already share, and is not
  something this task is scoped to redesign — only to work correctly within.

## Findings

### Codebase Patterns

**Core's file** (`agent-system/extensions/core/context/contracts/adversarial-verification.md`,
103 lines) is a domain-agnostic H4 contract (Claim Verification Bar, Confidence Level Taxonomy,
Contradiction Resolution Protocol, Forbidden Verification Outputs) with a single shared "Domain
Specialization" section that already names both `cslib` (BibKey verification against
`references.bib`, reuse-completeness, zero-debt compliance) and `lean4`
(`lean_hover_info`/`lean_local_search`-backed verification) as valid "Verification Method" plug-in
values, without forking the file per domain.

**Lean's file** (`agent-system/extensions/lean/context/contracts/adversarial-verification.md`,
93 lines) takes the opposite approach: a full domain-specific rewrite. Its header states it is
"the lean-extension parity copy... so lean-only deployments (no core extension loaded) still have
the contract available," every generic example is replaced with a lean4-specific one (e.g., the
Confidence Taxonomy's "High" bullet cites `lean_local_search` + `lean_hover_info` instead of "2+
independent sources agree" alone), and the H3 composition line points at a lean-namespaced
anchor (`@.claude/extensions/lean/context/contracts/reference-grounding.md#source-coverage-minimums-lean4`)
that only resolves because lean also owns its own H3 contract copy.

**Why the lean pattern does not transfer directly to cslib**: cslib owns no parity copies of the
sibling H2 (`anti-analysis.md`) or H3 (`reference-grounding.md`) contracts at all —
`cslib-research-hard-agent.md`'s own Context References section points those two bullets straight
at core's generic deployed paths (`@.claude/context/contracts/anti-analysis.md` and
`@.claude/context/contracts/reference-grounding.md`), not at cslib-namespaced equivalents. A
lean-style rewrite of only the H4 file, cross-referencing a cslib-namespaced H3 anchor that does
not exist, would create a dangling reference. The safer, more consistent choice — confirmed by
checking `cslib-research-hard-agent.md` line 42, which already points at the **generic** deployed
path `@.claude/context/contracts/adversarial-verification.md` (not an extension-namespaced one,
unlike lean's agent) — is to keep the new cslib file's cross-references pointing at the same
generic core paths cslib already uses everywhere else, and to keep the body content aligned with
core's rather than diverging into lean's cslib-agnostic phrasing.

**The collision consequence this creates, deliberately accepted**: because cslib's new entry
declares the identical relative path `contracts/adversarial-verification.md` as core's, and the
deploy tree copies context files into one shared merged location
(confirmed: `.claude/extensions/<ext>/` in the live deploy holds only `manifest.json`, not a
namespaced content tree — there is no separate `.claude/extensions/cslib/context/` mirror), the
two extensions' index entries and file content genuinely collide at
`.claude/context/contracts/adversarial-verification.md`. Whichever of `core`/`cslib` is processed
last for a given load/sync run supplies both the deployed file's content and the deployed index
entry. This is why the report above chose near-verbatim content: `general-research-hard-agent`
(which has no cslib-specific instructions) may receive cslib's file transparently, and a
lean-style full rewrite would have silently changed that agent's contract content as a side
effect of an unrelated extension being loaded.

**`cslib/index-entries.json` structure**: all 17 pre-existing entries use `domain: "project"`,
`subdomain: "cslib"`, and path prefix `project/cslib/...` (mirroring the
`cslib/context/project/cslib/` directory layout used for cslib's own domain docs). The new entry
departs from that path-prefix convention (using bare `contracts/adversarial-verification.md`, a
new top-level `cslib/context/contracts/` directory) because it is following the lean precedent for
a *contract mirror*, not a cslib-domain doc — matching lean's own entry shape exactly
(`domain: "project"`, `subdomain: "lean"`, path `contracts/adversarial-verification.md`, no
`commands` key, only `agents` + `task_types`).

### External Resources

None consulted — this is a self-contained internal-tooling task; the schema
(`context/index.schema.json`), the gate script (`check-extension-docs.sh`), and the merge engine
(`merge.lua`) are the complete and only relevant references.

### Recommendations

Implemented directly (see Decisions below), consistent with the delegation's explicit instruction
to edit `agent-system/extensions/**` as part of this dispatch:

1. `agent-system/extensions/cslib/context/contracts/adversarial-verification.md` — 117 lines.
   Structure: a new 3-paragraph header explaining (a) what this file is and why it exists, (b)
   why it deliberately does **not** specialize into cslib-only content (the shared-path collision
   argument above), (c) a pointer to where genuinely cslib-only H4 behavior should go if ever
   needed (a new additive section, not a rewrite of the shared baseline) — followed by the
   Claim Verification Bar, Confidence Level Taxonomy, Contradiction Resolution Protocol, and
   Forbidden Verification Outputs sections copied verbatim from core, and the same Domain
   Specialization section (both cslib and lean4 bullets, unchanged) with one appended closing
   line naming the canonical core file.
2. `agent-system/extensions/cslib/index-entries.json` — new entry appended at end of `entries[]`:
   `path: "contracts/adversarial-verification.md"`, `line_count: 117`, `domain: "project"`,
   `subdomain: "cslib"`, `load_when.agents: ["general-research-hard-agent",
   "cslib-research-hard-agent"]`, `load_when.task_types: ["cslib"]`.

## Decisions

- **Content strategy: near-verbatim mirror, not a cslib-specialized rewrite, and not a
  redirect/stub.** All three options the task posed were weighed:
  - *(a) Verbatim copy* — chosen, for the collision-safety reason above.
  - *(b) cslib-specialized variant* (lean-style rewrite) — rejected: cslib has no parity H2/H3
    copies to cross-reference from a rewritten H4 file, and a rewrite would silently alter
    `general-research-hard-agent`'s contract content whenever cslib wins the shared-path
    collision, which is an unrelated and unwanted side effect.
  - *(c) a mechanism avoiding a third divergent copy entirely* — investigated and ruled out
    structurally, not merely rejected on style grounds: Rule R requires a real source file at
    `<ext>/context/<path>` with an accurate `line_count`, so a zero-content redirect is not legal
    regardless of phrasing. A previously-harvested project memory
    (`.memory/10-Memories/MEM-insight-context-loading-by-at-reference.md`) further confirms
    `@`-references inside an agent's own body do not auto-resolve at subagent spawn — each
    consuming agent needs a literal, readable file at the path its own Context References bullet
    names, which is exactly what `cslib-research-hard-agent.md` line 42 already names (the
    generic core path). A stub file would technically satisfy Rule R's line-count check but would
    not avoid the "third copy" problem in any way that reduces maintenance burden, since Rule R's
    accuracy check is per-file regardless of how much content that file holds.
- **`load_when.agents` union, not cslib-only.** Set to
  `["general-research-hard-agent", "cslib-research-hard-agent"]`, per the task's explicit
  instruction and the headless-Neovim upsert proof (Adversarial Self-Verification below) that this
  union — not a cslib-only list — is what prevents `general-research-hard-agent`'s hook from
  being silently dropped when cslib's entry wins the collision.
- **Did not add `lean-research-hard-agent` to the union.** The task's file scope is limited to
  `agent-system/extensions/cslib/**`; extending the union to include an agent lean's own sibling
  task is separately responsible for is out of scope here (`lean` is also not currently a loaded
  extension in this repository, so no three-way collision is live to test against). The task
  description itself frames this task as "establishing the union-valued pattern that [the sibling
  lean task] applies" — i.e., this task's job is to demonstrate the pattern correctly for cslib,
  not to pre-emptively patch lean's entry.
- **Path convention**: followed lean's precedent exactly (`contracts/adversarial-verification.md`,
  `domain: "project"`, `subdomain: "cslib"`, no `commands` key) rather than cslib's own
  `project/cslib/...` convention used by its 17 pre-existing entries, because this is a contract
  mirror at the same conceptual tier as core's and lean's `contracts/` trees, not a cslib-domain
  doc.

## Risks & Mitigations

- **Risk**: the shared-path collision (documented as a "known dormant risk" in `merge.lua`) means
  a future cslib-only content edit to this file could silently become the deployed content for
  `general-research-hard-agent` too, and vice versa for edits to core's file.
  **Mitigation**: the file's own header now states this explicitly, and instructs that genuinely
  cslib-only H4 behavior belongs in an additive new section rather than a rewrite of the shared
  body — reducing (not eliminating) the chance of an unreviewed divergence.
- **Risk**: `bash .claude/scripts/validate-context-budgets.sh` could not be run against a live
  cslib-loaded deploy (cslib is not currently a loaded extension in this repository's
  `.claude-extensions.json`), so the "no new budget violation" bar was verified only at the
  source-file level (`check-extension-docs.sh` Rule R passes) and via a targeted headless
  simulation of the merge step, not a full end-to-end deploy-and-validate cycle.
  **Mitigation**: none needed beyond noting the limitation — cslib not being loaded here means
  this change structurally cannot have changed the currently-deployed budget numbers (verified:
  `cslib-research-hard-agent` does not appear anywhere in the current
  `validate-context-budgets.sh` output).

## Context Extension Recommendations

None — this is a meta task operating entirely within already-documented conventions (Rule R,
`merge.lua`'s upsert-by-path behavior, lean's mirror-entry precedent). No new context-file gap
was surfaced.

## Appendix

### Adversarial Self-Verification

| # | Claim | Verification Method | Confidence |
|---|-------|---------------------|------------|
| 1 | Core's `adversarial-verification.md` is 103 lines | `wc -l` on the file | High |
| 2 | Lean's `adversarial-verification.md` is 93 lines | `wc -l` on the file | High |
| 3 | The new cslib file is 117 lines, matching the declared `line_count` | `wc -l` on the new file, cross-checked against the `index-entries.json` value written | High |
| 4 | `check-extension-docs.sh` Rule R requires a real source file per index entry, and fails without one | Direct read of `check_line_count_accuracy()` (lines 611-644) plus the prior task's own reproduction, quoted verbatim in `specs/991_meta_catchall_decomposition/plans/01_meta-catchall-decomposition.md` ("`[cslib] FAIL: Rule R: index-entries.json entry 'contracts/adversarial-verification.md' has no source file...`") | High |
| 5 | `merge.append_index_entries` replaces the whole entry object on a path match (upsert, not field-merge) | Direct read of `merge.lua` lines 545-563 plus its own doc comment at lines 496-522 | High |
| 6 | After core's entry is applied and then cslib's entry is applied (matching realistic core-then-extension processing order), the merged result is a single entry equal to cslib's, retaining both `general-research-hard-agent` and `cslib-research-hard-agent` | Ran a headless-Neovim script calling `merge.append_index_entries` twice against a scratch index file with the actual entry shapes used here; inspected the resulting JSON | High |
| 7 | `cslib-research-hard-agent.md` references the contract via the generic core path `@.claude/context/contracts/adversarial-verification.md`, not an extension-namespaced path | `Grep` of `agent-system/extensions/cslib/agents/cslib-research-hard-agent.md` lines 42 and 251 | High |
| 8 | `lean-research-hard-agent.md` references its contract primarily via an extension-namespaced path (`@.claude/extensions/lean/context/contracts/adversarial-verification.md`), with the generic core path listed separately as "fallback" | `Grep` of `agent-system/extensions/lean/agents/lean-research-hard-agent.md` lines 32-36 | High |
| 9 | cslib has no existing `context/contracts/` directory or parity copies of the H2/H3 contracts | `find agent-system/extensions/cslib/context -iname "*.md"` returned only `project/cslib/**` paths before this task's file was added | High |
| 10 | `check-extension-docs.sh` now reports `cslib PASS` with both the new file and index entry present | Ran `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`; summary table shows `cslib PASS` | High |
| 11 | The `.claude-extensions.json` in this repository currently loads only `core`, `email`, `memory`, `nix`, `nvim` (not `cslib` or `lean`) | `jq -r '.extensions \| keys'` on `.claude-extensions.json` | High |
| 12 | `validate-context-budgets.sh`'s 8 reported violations are pre-existing and unrelated to this change | The violation list names only agents from currently-loaded extensions (`nix-research-agent`, `general-research-agent`, `general-implementation-agent`, `nix-implementation-agent`, `planner-agent`, `neovim-research-agent`, `neovim-implementation-agent`, `meta-builder-agent`); `cslib-research-hard-agent` does not appear anywhere in the output, and this task made no edits under `.claude/**` | High |

No unresolved contradictions were encountered.

### Search Queries / Commands Used

- `jq` queries against `core/index-entries.json`, `lean/index-entries.json`, `cslib/index-entries.json`
- `grep -n "Rule R" -A 30 agent-system/extensions/core/scripts/check-extension-docs.sh`
- `grep -rn "adversarial-verification" agent-system/extensions/{core,lean,cslib}/agents/*.md`
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
- `bash .claude/scripts/validate-context-budgets.sh`
- A headless-Neovim Lua script exercising `neotex.plugins.ai.shared.extensions.merge.append_index_entries` directly (scratch file, deleted after use)

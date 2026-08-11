# Implementation Plan: Task #36

- **Task**: 36 - Audit context loading efficiency
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None (soft coordination: task 29 for manifest-schema changes is deferred to follow-up tasks; task 32 is the redeploy delivery vehicle; task 31 governs the .opencode/ mirror boundary)
- **Research Inputs**: specs/036_audit_context_loading_efficiency/reports/01_team-research.md
- **Artifacts**: plans/01_context-loading-optimization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The team research measured the session-start eager context surface at ~69.9 KB (~17.5k tokens) and found that its composition is an accident of `@`-reference path style: refs written `@context/...` resolve (relative to `.claude/`) and inline whole files eagerly, while refs written `@.claude/...` resolve to a nonexistent `.claude/.claude/...` path and silently load nothing — including five email safety-invariant pointers. This plan executes the audit's cheap wins in the source store (`agent-system/extensions/**`, never `.claude/**`): normalize every `@`-reference in generated-CLAUDE.md sources downward to plain backticked paths, apply the rules-frontmatter triage, re-site mis-sited literature rows, document the resolution semantics, and create follow-up optimization tasks for the durable deliverables (measurement harness, deploy budget gates, email dead-safety-import defect, command-body slimming). Definition of done: source store contains no resolving or broken-looking `@`-refs in CLAUDE.md merge sources per the audit's inventory, the rules triage is applied, semantics are documented, follow-up tasks exist in state.json, and all repo lint gates pass. Expected effect at next redeploy: session-start surface drops from ~17.5k to ~9.5k tokens (-46%) with zero behavior loss.

### Research Integration

Key findings integrated from `reports/01_team-research.md`:
- **F2 (master finding)**: `@`-refs resolve relative to the containing file's directory; `@context/...` loads eagerly, `@.claude/...` is silently inert. Phases 1-2 normalize both classes downward.
- **F3**: Broken refs are accidentally protective — repairing upward would add ~16k tokens/session and admit volatile files (`specs/TODO.md`, `state.json`, `errors.json`) into the cached prompt prefix. Every phase carries the **no-volatile-files-in-eager-prefix** constraint; no ref is ever converted to a resolving form.
- **F4 triage (critic's dissent upheld)**: gate `neovim-lua.md` with `paths:`; split `no-task-references-in-deliverables.md` (eager principle + lazy taxonomy); leave `source-store-deploy-boundary.md` eager because its enforcement hook is PostToolUse/non-blocking.
- **F5**: no index.json work — no runtime consumer loads from `load_when`; explicitly out of scope.
- **F6 (reframing)**: justification is correctness and relevance hygiene, not raw token savings.
- **F7**: growth is structural (unconditional per-extension append, no budget gate) — addressed via follow-up tasks (P3/P4), not in this plan's direct edits.
- **F8**: literature command rows are mis-sited in core's merge source.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap_path was provided in the delegation context (roadmap consultation skipped). The research report independently notes alignment: `specs/ROADMAP.md` Phase 2 "Context discovery caching" and the "<60 seconds to first artifact" success metric are both advanced by this work; the follow-up budget-gate task extends the Phase 1 CI-enforcement philosophy.

## Goals & Non-Goals

**Goals**:
- Eliminate the accidental eager/inert split: every `@`-reference in generated-CLAUDE.md sources becomes a plain backticked path (both the resolving `@context/...` forms and the broken `@.claude/...` / `@specs/...` / `@README.md` forms).
- Apply the F4 rules triage: `paths:` frontmatter for `neovim-lua.md`; split of `no-task-references-in-deliverables.md` into a short eager principle plus a lazily-loaded exemption taxonomy; explicit recorded decision to leave `source-store-deploy-boundary.md` eager and `pr-prohibition.md`'s `**/*` glob as-is.
- Re-site `/literature` and `/cite` command rows and the `skill-literature` mapping row from core's merge source to the literature extension's merge source.
- Document `@`-resolution semantics and the eager-channel inventory (with the volatility constraint) in core context files.
- Create follow-up optimization tasks for: the eager-context measurement harness (P3), verify-deploy broken-`@`-ref lint + context-budget gate (P4), the email dead-safety-import defect (P5), and `commands/task.md` body slimming (P7).

**Non-Goals**:
- No index.json entry changes (F5: no runtime consumer; savings ~zero).
- No "repair" of broken `@`-refs to resolving form — this direction is explicitly forbidden.
- No unloading of extensions; no memory-injection or skills/agents-roster trims (measured cheap or already budgeted).
- No redeploy of `.claude/` in this task — delivery happens at the next deploy (task 32 is the natural vehicle); no `.claude/**` file is hand-edited.
- No manifest schema changes (`merge_targets.claudemd.max_bytes` etc.) — deferred to the follow-up gate task to avoid schema churn against the in-flight manifest work.
- No `.opencode/**` edits — fixes land in the shared source store; mirror propagation is the sync task's concern.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A normalization edit accidentally leaves (or creates) a resolving `@`-ref, silently inlining a file eagerly | H | M | Phase 7 runs the audit's census grep (`grep -oE '@[A-Za-z0-9._/-]+' ...`) over all merge sources and EXTENSION.md files; acceptance is zero `@path` tokens outside code fences/exempt contexts |
| Splitting `no-task-references-in-deliverables.md` breaks its consumers (lint scripts, hook, agent-contract fragment references) | H | M | Pattern/exemption logic lives in `scripts/lib/task-reference-patterns.sh`, not the markdown — verify by running `check-task-references.sh`, `lint-agent-contracts.sh`, and `scripts/tests/test-validate-no-task-references.sh` after the split; update all cross-references that name the rule file |
| Removing eager email/nvim "Context Pointers" text degrades agent behavior | L | L | Those imports are already inert (load nothing today); converting to plain paths is a zero-delta change. The email safety-eagerness question is escalated as its own follow-up task, not silently decided here |
| Volatile files (`specs/TODO.md`, `state.json`, `errors.json`) enter the cached prefix via a well-meaning future edit | H | M | Phase 5 documents the constraint in core context; Phase 2 converts those refs to plain paths so no broken-looking ref remains to "fix"; follow-up P4 task adds the durable lint |
| Edits drift between source store and deployed `.claude/` (stale-deploy confusion during verification) | M | M | All edits target `agent-system/extensions/**` only; Phase 7 verification greps the source store, never the live `.claude/` tree |
| Follow-up task creation desyncs state.json/TODO.md | M | L | Use existing task-creation conventions: update `state.json` via jq (append, never wholesale array replacement), then run `generate-todo.sh`; validate with `jq empty` |
| Literature-row re-site loses rows for deploys where literature IS loaded | M | L | Move (not delete) the rows verbatim into `agent-system/extensions/literature/merge-sources/claudemd.md`; diff both files to confirm net-zero content loss |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 5 | -- |
| 2 | 4 | 2 |
| 3 | 6 | 1, 2, 3, 4, 5 |
| 4 | 7 | 6 |

Phases within the same wave can execute in parallel (disjoint file sets: Phase 1 = nix/present/literature extension sources; Phase 2 = email/nvim/formal/lean sources + core merge source; Phase 3 = rules sources; Phase 5 = core context docs + memory file).

### Phase 1: De-`@` the resolving extension context references [COMPLETED]

**Goal**: Stop the unconditional eager inlining of extension domain context (~4.5k tokens/session from nix alone; ~5.7k more wherever literature is loaded) by converting resolving `@context/...` bullets to plain backticked paths.

**Tasks**:
- [x] In `agent-system/extensions/nix/EXTENSION.md`: convert the 5 `@context/project/nix/...` Context bullets to plain backticked paths (keep the one-line descriptions). *(completed)*
- [x] In `agent-system/extensions/present/EXTENSION.md`: convert its resolving `@context/...` refs the same way. *(completed: 5 bullets)*
- [x] In `agent-system/extensions/literature/merge-sources/claudemd.md`: convert its resolving `@context/...` refs the same way. Note: this file has uncommitted local modifications — read current content first and preserve unrelated in-flight changes. *(completed: 5 bullets, in-flight changes preserved)*
- [x] Sweep the remaining extensions the research census flagged as using the resolving form (`web`, `cslib`) and apply the same conversion. *(completed: web 4, cslib 4)*
- [x] Confirm each converted file's path targets still exist in the source store (pointer integrity — the paths must be real, just not `@`-prefixed). *(completed: all 23 paths exist)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research asserts nix has exactly 5 resolving bullets and names {nix, present, literature, web, cslib} as the resolving-form users. Confirm at implementation time with `grep -n '@context/' agent-system/extensions/*/EXTENSION.md agent-system/extensions/*/merge-sources/claudemd.md` before editing; treat the census as a hypothesis and convert whatever the grep actually finds.

**Files to modify**:
- `agent-system/extensions/nix/EXTENSION.md` - 5 Context bullets to plain paths
- `agent-system/extensions/present/EXTENSION.md` - resolving refs to plain paths
- `agent-system/extensions/literature/merge-sources/claudemd.md` - resolving refs to plain paths
- `agent-system/extensions/web/EXTENSION.md`, `agent-system/extensions/cslib/EXTENSION.md` - same defect class (confirm via grep first)

**Verification**:
- `grep -c '@context/' <each edited file>` returns 0.
- Every plain path written exists on disk under the corresponding extension's source tree.
- `bash .claude/scripts/check-extension-docs.sh` passes for the touched extensions.

---

### Phase 2: Normalize the inert `@.claude/...` and volatile refs to plain paths [COMPLETED]

**Goal**: Disarm the trap where a future "path fix" repairs broken refs upward (+~16k tokens/session, volatile files in the cached prefix) by converting every inert `@`-form to the same plain-path convention. Zero token delta today; removes the hazard.

**Tasks**:
- [x] In `agent-system/extensions/core/merge-sources/claudemd.md`: convert to plain backticked paths — the Quick Reference rows (`@specs/TODO.md`, `@specs/state.json`, `@specs/errors.json`, `@.claude/docs/docs-README.md`), the docs-README reference in the preamble, the 8-entry Rules References list (`@.claude/rules/*.md`), the Context Imports list (`@.claude/context/repo/project-overview.md`, `@README.md`), and the jq-workarounds ref (`@.claude/context/patterns/jq-escaping-workarounds.md`). *(completed: all 16 refs converted)*
- [x] In `agent-system/extensions/email/EXTENSION.md`: convert the 5 `@.claude/context/project/email/domain/*` Context Pointers to plain paths. Do NOT make them resolve — the eager-safety question is escalated in Phase 6 as its own task. *(completed)*
- [x] In `agent-system/extensions/nvim/EXTENSION.md`: convert the 3 `@.claude/context/project/neovim/*` Context Imports to plain paths. *(completed)*
- [x] In `agent-system/extensions/formal/EXTENSION.md` and `agent-system/extensions/lean/EXTENSION.md` (research census: same broken form): convert the same way. *(completed: formal 6 fenced refs, lean 5 bullets)*
- [x] Prose fix: update the "All skills use lazy context loading via @-references" bullet in core's merge source (Important Notes) if it survives — after this phase, the honest phrasing is plain-path references resolved on demand. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research asserts the broken-form users are {email, nvim, formal, lean} plus core's merge source, and that core's Rules References list has exactly 8 entries. Confirm with `grep -n '@\.claude/\|@specs/\|@README' agent-system/extensions/*/EXTENSION.md agent-system/extensions/core/merge-sources/claudemd.md` before editing; convert whatever is actually present.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - all inert/volatile `@`-refs to plain paths
- `agent-system/extensions/email/EXTENSION.md` - 5 safety pointers to plain paths
- `agent-system/extensions/nvim/EXTENSION.md` - 3 context imports to plain paths
- `agent-system/extensions/formal/EXTENSION.md`, `agent-system/extensions/lean/EXTENSION.md` - same conversion (confirm via grep first)

**Verification**:
- The Phase-1 + Phase-2 census grep over all merge sources and EXTENSION.md files finds no remaining `@`-prefixed file references outside code fences.
- No ref was converted to a resolving `@` form (the diff contains no added `@` characters).
- `bash .claude/scripts/check-extension-docs.sh` passes.

---

### Phase 3: Rules frontmatter triage [COMPLETED]

**Goal**: Apply the F4 verdicts so that eager rule injection is a decision, not an omission: gate the neovim rule by path, split the largest rule into eager-principle + lazy-taxonomy, and record the deliberate keep-eager decisions.

**Tasks**:
- [x] Add YAML `paths:` frontmatter to `agent-system/extensions/nvim/rules/neovim-lua.md` matching its own declared scope: `lua/**/*.lua`, `after/**/*.lua`, `*.lua`. *(completed)*
- [x] Split `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`: keep a short always-eager rule file (~15 lines: principle, exceptions summary, pointer to the taxonomy and to `scripts/lib/task-reference-patterns.sh` as the mechanical source of truth) and move the 7-category Exemption Taxonomy table plus the detailed Enforcement narrative to a lazily-loaded companion (e.g. `agent-system/extensions/core/context/standards/task-reference-exemptions.md` — confirm the natural home against the existing context tree at implementation time). *(completed: companion created at the hypothesized path; all 7 categories preserved verbatim)*
- [x] Update every cross-reference to the moved taxonomy content: the enforcement-history decision record pointer, `check-task-references.sh` / `validate-no-task-references.sh` header comments if they cite the rule's sections, and any docs naming the taxonomy's location. *(completed: 5 files updated — hook, lint script, shared lib, bullet fragment, hook test)*
- [x] Do NOT add `paths:` to `agent-system/extensions/core/rules/source-store-deploy-boundary.md` — add a brief comment in that file recording the decision (its hook is PostToolUse/non-blocking; deferral risks learning the rule after the violating write) so a future optimizer does not re-litigate silently. Do not cite this task's number in the comment. *(completed)*
- [x] Leave `pr-prohibition.md`'s `paths: "**/*"` glob unchanged (deliberate: universal-scope deferred-tier rule); no edit needed beyond confirming it has frontmatter. *(completed: frontmatter confirmed)* *(deviation: altered — also gated web-astro.md with paths: frontmatter, a 4th frontmatter-less rule surfaced by the Scope Hypothesis check and triaged per its instruction)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The research asserts exactly 3 source-store rules lack `paths:` frontmatter (`no-task-references-in-deliverables.md`, `neovim-lua.md`, `source-store-deploy-boundary.md`). Confirm with the audit's check: `for f in agent-system/extensions/*/rules/*.md; do head -8 "$f" | grep -q '^paths:' || echo "$f"; done` before editing; if additional frontmatter-less rules surface, triage them by the same eager-safety test (is enforcement pre-write or post-write?) rather than gating blindly.

**Files to modify**:
- `agent-system/extensions/nvim/rules/neovim-lua.md` - add `paths:` frontmatter
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` - shrink to eager principle
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` (new, or the confirmed natural home) - taxonomy + enforcement detail
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` - decision note only
- Cross-referencing docs/scripts headers as found by `grep -rn 'no-task-references-in-deliverables' agent-system/`

**Verification**:
- `bash .claude/scripts/check-task-references.sh` exits 0 (taxonomy still mechanically honored via the shared library).
- `bash .claude/scripts/lint/lint-agent-contracts.sh` passes (agent-contract fragment coverage unaffected).
- `bash .claude/scripts/tests/test-validate-no-task-references.sh` passes (hook behavior unchanged; test fixtures reference the shared library, not the rule prose).
- The split rule file plus companion together preserve all 7 taxonomy categories (diff audit: no category dropped).

---

### Phase 4: Re-site literature rows from core to the literature extension [NOT STARTED]

**Goal**: Stop `/literature` and `/cite` documentation from rendering in every deploy regardless of whether the literature extension is loaded (F8 mis-siting).

**Tasks**:
- [ ] Move the `/literature` command rows (7 rows), the `/cite` rows (2 rows), and the `skill-literature` Skill-to-Agent mapping row from `agent-system/extensions/core/merge-sources/claudemd.md` into `agent-system/extensions/literature/merge-sources/claudemd.md`, verbatim.
- [ ] Confirm the literature merge source's existing structure accommodates command-table and skill-table rows (it already carries the `--lit` section); place moved rows under appropriate headings.
- [ ] Diff both files to confirm the move is net-zero: every moved row appears exactly once, in the literature source.

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: The research asserts the mis-sited content is exactly the `/literature` + `/cite` command rows and one skill-mapping row. Confirm with `grep -n 'literature\|/cite' agent-system/extensions/core/merge-sources/claudemd.md` before moving; move whatever core-resident literature-specific content the grep reveals.

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - remove literature-specific rows
- `agent-system/extensions/literature/merge-sources/claudemd.md` - receive them

**Verification**:
- `grep -c '/literature\|/cite\|skill-literature' agent-system/extensions/core/merge-sources/claudemd.md` returns 0.
- The same grep against the literature merge source finds all moved rows.
- `bash .claude/scripts/check-extension-docs.sh` passes.

---

### Phase 5: Document resolution semantics, channel inventory, and the volatility constraint [NOT STARTED]

**Goal**: Make the audit's master finding durable knowledge so the next author cannot re-introduce the accident: record `@`-resolution semantics, the eager-channel inventory, and the no-volatile-files-in-eager-prefix constraint in core context.

**Tasks**:
- [ ] In `agent-system/extensions/core/context/architecture/context-layers.md`: add a section on eager-vs-lazy channels — the native CLAUDE.md chain, `@`-import resolution (relative to the containing file's directory; `@.claude/...` from within `.claude/CLAUDE.md` is silently inert), rules `paths:` globs (absence = eager; presence = deferred to first path touch), and preflight injection (memory/`--lit`). State the volatility constraint explicitly: files that change per task operation must never be `@`-imported into the eager prefix.
- [ ] In `agent-system/extensions/core/context/patterns/context-discovery.md`: add a short cross-reference to the new channel-inventory section (do not duplicate content).
- [ ] Extend the existing memory `.memory/10-Memories/MEM-insight-context-loading-by-at-reference.md` with the generated-CLAUDE.md-side facts (directory-relative resolution, the two path-style classes, the downward-normalization decision) rather than creating a new memory. No task numbers in the memory body outside frontmatter provenance conventions.
- [ ] Record the open question from the audit as a stated unknown in the channel-inventory section: whether a `paths:`-gated rule fires before or only after the matching write — flagged as requiring an empirical test before anyone gates an enforcement rule.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/architecture/context-layers.md` - channel inventory + volatility constraint
- `agent-system/extensions/core/context/patterns/context-discovery.md` - cross-reference
- `.memory/10-Memories/MEM-insight-context-loading-by-at-reference.md` - extend with CLAUDE.md-side facts

**Verification**:
- Diff read-through: all changed hunks are prose/markdown; no task-number citations outside `specs/**` (the write-time hook will also enforce this); cross-references point at real files/sections.

---

### Phase 6: Create follow-up optimization tasks [NOT STARTED]

**Goal**: Discharge the task description's "create optimization tasks" requirement for the durable deliverables that exceed this task's safe scope.

**Tasks**:
- [ ] Create task: **Eager-context measurement harness** (`measure-eager-context.sh`, type `meta`) — predicts the eager set from source store + fresh regenerate (parent CLAUDE.md chain, generated CLAUDE.md, resolving `@`-imports, rules lacking `paths:` or with `**/*`), emits bytes/est-tokens per contributing source, `--check`/`--write` split like `generate-context-line-counts.sh`. Note in the description: must never measure the live `.claude/` tree (stale-deploy concern).
- [ ] Create task: **verify-deploy context gates** (type `meta`) — (a) broken-`@`-ref lint: every `@path` in generated CLAUDE.md must resolve or be explicitly citation-only; (b) warning-first context-budget gate; consider per-extension `merge_targets.claudemd.max_bytes`. Note the sequencing dependency on the in-flight manifest-schema work in the description.
- [ ] Create task: **Email safety-context loading decision** (type `email` or `meta`) — the five "non-negotiable" safety pointers load nothing; decide deliberately whether they should be eager (accepting ~13k tokens) or whether wrapper contracts + agent definitions already carry enforcement. Frame as a live defect, not an efficiency item.
- [ ] Create task: **Slim `commands/task.md`** (type `meta`, lower priority) — 37,465 B (~9.4k tokens) per `/task` invocation plus its ~2.8k-token import; largest single per-invocation contributor.
- [ ] For each: allocate numbers from `next_project_number`, append entries to `specs/state.json` `active_projects` via jq (append `+=`, never wholesale array replacement), create `specs/{NNN}_{SLUG}/` directories, then run `bash .claude/scripts/generate-todo.sh`.

**Timing**: 45 minutes

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: local

**Scope Hypothesis**: Four follow-up tasks are hypothesized (P3, P4, P5, P7). Confirm at implementation time that none is already covered by an existing open task (scan `specs/TODO.md` for harness/gate/email-safety items) before creating; skip any that would duplicate.

**Files to modify**:
- `specs/state.json` - four new task entries
- `specs/TODO.md` - regenerated via `generate-todo.sh` (never hand-edited)
- `specs/{NNN}_{SLUG}/` directories for the new tasks

**Verification**:
- `jq empty specs/state.json` passes; `jq '.active_projects | length'` increased by the number of tasks created.
- TODO.md regenerated and shows the new tasks with `[NOT STARTED]`.
- Each new task's description names its source-store targets and carries the no-volatile-files / source-store-only constraints where applicable.

---

### Phase 7: Full verification sweep [NOT STARTED]

**Goal**: Close the task with the complete gate set over the source store, confirming the normalization is total and nothing regressed.

**Tasks**:
- [ ] Census grep: `grep -rnoE '@[A-Za-z0-9._/-]+\.md|@specs/[A-Za-z0-9._/-]+|@README\.md' agent-system/extensions/*/EXTENSION.md agent-system/extensions/*/merge-sources/*.md` — expect zero hits outside code fences/illustrative contexts; justify any survivor inline.
- [ ] Frontmatter check: every rule under `agent-system/extensions/*/rules/*.md` either has `paths:` frontmatter or is one of the two recorded deliberate-eager files (`source-store-deploy-boundary.md`, plus the slimmed `no-task-references-in-deliverables.md` which remains eager by design).
- [ ] Run the full lint set: `check-extension-docs.sh`, `check-task-references.sh`, `lint-agent-contracts.sh`, `lint-routing-wiring.sh`, and `bash -n` over any touched `.sh` files.
- [ ] Predicted-surface estimate: sum `wc -c` of the post-edit eager set (parent chain + core merge source + loaded extensions' EXTENSION.md + the two deliberate-eager rules) and record the before/after numbers in the implementation summary — expected ~9.5k tokens against the audited ~17.5k baseline. This is a source-store prediction, not a live-tree measurement.
- [ ] Confirm zero writes landed under `.claude/**` (git status shows only `agent-system/**`, `specs/**`, and `.memory/**` changes).

**Timing**: 30 minutes

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- None (verification only; summary content feeds `summaries/01_context-loading-optimization-summary.md` at implementation close)

**Verification**:
- All listed lint gates exit 0; census greps clean; before/after byte accounting recorded.

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 after Phases 1, 2, 4.
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0 after Phase 3 (taxonomy split preserves lint behavior).
- [ ] `bash .claude/scripts/tests/test-validate-no-task-references.sh` passes after Phase 3.
- [ ] `bash .claude/scripts/lint/lint-agent-contracts.sh` and `lint-routing-wiring.sh` exit 0 in Phase 7.
- [ ] `jq empty specs/state.json` passes after Phase 6; TODO.md regenerated via script only.
- [ ] Census grep for `@`-refs over all merge sources and EXTENSION.md files returns zero unexempted hits.
- [ ] No file under `.claude/**` was hand-edited (source-store-deploy-boundary rule).

## Artifacts & Outputs

- `specs/036_audit_context_loading_efficiency/plans/01_context-loading-optimization.md` (this plan)
- Source-store edits across `agent-system/extensions/{core,nix,nvim,email,present,literature,formal,lean,web,cslib}/**` per phases 1-5
- New context file: taxonomy companion to the slimmed task-references rule (Phase 3)
- Four new follow-up task entries in `specs/state.json` + directories (Phase 6)
- `specs/036_audit_context_loading_efficiency/summaries/01_context-loading-optimization-summary.md` (at implementation close, with before/after byte accounting)

## Rollback/Contingency

All edits are markdown/frontmatter changes in a git-tracked source store with per-phase commits (`task {N} phase {P}: {name}` convention): revert any phase with `git revert` of its commit(s). The deployed `.claude/` tree is untouched by this task, so the live system cannot be broken mid-task — changes only take effect at the next deliberate redeploy, which is itself gated by `verify-deploy.sh`. If the Phase 3 split breaks a lint consumer that cannot be quickly fixed forward, revert only the Phase 3 commit and re-scope the split into its own follow-up task; Phases 1-2 and 4-6 are independent and remain deliverable. Follow-up task creation (Phase 6) is additive to state.json and reversible by removing the appended entries and regenerating TODO.md.

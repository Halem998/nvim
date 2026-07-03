# Research Report: Task #806

**Task**: 806 - Align lean/cslib hard-mode contracts with 778 strategic-sorry policy
**Started**: 2026-07-03T16:33:31Z
**Completed**: 2026-07-03T17:22:45Z
**Effort**: 2-4 hours (per task metadata)
**Dependencies**: task 778 (COMPLETED — landed the core policy this task must be aligned to)
**Sources/Inputs**: Codebase read (core contracts, extension overrides, agent files), task 778 plan/summary artifacts, cross-repo inspection of `~/Projects/cslib/.claude/`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 778 already anticipated and explicitly named this exact follow-up in its Downstream
  Notes, including the precise fix (reconcile lean/cslib overrides + rename `next_dispatch`
  field to `follow_up_task`). This report confirms and expands that scope with exact anchors.
- The contradiction is NOT confined to the single override file named in the task description.
  It exists in **three separate anchor points per file** (6 total across the two agent files),
  because each hard-mode agent file independently restates a categorical "no main-target sorry"
  rule in its own Zero-Debt Policy / Final Verification / MUST NOT sections — restating,
  not just @-referencing, the anti-analysis.md contract.
- Beyond the categorical ban, the lean/cslib `sorry_inventory` schema differs from core's
  778-landed canonical schema in three ways: missing `strategic` boolean, field named
  `next_dispatch` instead of `follow_up_task`, and no `skeleton` field in the
  `.orchestrator-handoff.json` example JSON in either agent file.
- cslib has no separate `anti-analysis.md` override (confirmed: `find` for
  `*anti-analysis*` under `.claude/extensions/cslib/` returns nothing) and its manifest lists
  `"dependencies": ["core", "lean", "literature"]` — it inherits the lean override transitively.
  `cslib-implementation-hard-agent.md`'s own Context References list still points at
  `@.claude/context/contracts/anti-analysis.md` (the CORE file, not the lean override) — this
  is worth flagging to the planner as a possible existing gap (see Findings, Context Reference
  Gap) independent of task 806's main fix.
- Cross-repo: `~/Projects/cslib/.claude/` is a **full flattened copy**, not symlinks, for
  context/contract files — and it is currently STALE at exactly this contradiction: its
  `.claude/context/contracts/anti-analysis.md` already contains the *lean-override* text (not
  the core generic text), confirming a previous manual copy/merge, and it has none of task 778's
  `skeleton`/`strategic`/`follow_up_task` additions. `install-extension.sh` (present in both
  repos, identical) does **not** copy context/contract file contents — it only symlinks
  skills/commands/agents and merges `index-entries.json` metadata. There is no discovered
  automated mechanism that produced the flattened copy in `~/Projects/cslib`; the sync there is
  effectively manual/undocumented. Do not edit that repo — flag for manual re-sync after 806
  lands.

## Context & Scope

Task 778 (COMPLETED) relaxed the CORE zero-debt policy under `--hard` in
`.claude/context/contracts/anti-analysis.md` and `.claude/context/contracts/wrap-up.md` to
permit documented **strategic sorries** forming a skeleton, gated by a domain-agnostic
5-condition acceptance test, and added a `skeleton` boolean + 7-field `sorry_inventory` schema.
Task 778 explicitly declared the lean/cslib extension overrides **out of scope** (Non-Goal) and
recorded a Downstream Note naming this exact reconciliation as follow-up work, to be surfaced via
task 772. Task 806 is that follow-up.

Scope per task 806 description: hard-mode lean/cslib only; standard mode unchanged. Three files
named as the primary edit targets:
1. `.claude/extensions/lean/context/contracts/anti-analysis.md` (override; cslib inherits it,
   no separate cslib anti-analysis.md exists)
2. `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`
3. `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`

This research additionally surfaces that the categorical ban is restated (not just inherited via
@-reference) inside both agent .md files themselves, in multiple sections, so a complete fix
touches more than the one override file's "Sub-Sorry Policy" section.

## Findings

### 1. Canonical core wording to align against (778-landed, read verbatim)

**`.claude/context/contracts/anti-analysis.md`** (core, 102 lines) — the 5-condition test lives
under `## Sub-Sorry Policy` → `### Strategic sorries (skeleton division points)` (lines 59-83):

> A main-target-level placeholder is acceptable as a **strategic sorry** — a deliberate division
> point in a skeleton, not an abandoned or stuck proof — ONLY when ALL five conditions hold:
>
> 1. **Deliberate division boundary**: ... planned as part of a skeleton ... not a proof the
>    agent got stuck on and gave up.
> 2. **Tightly scoped**: scoped to exactly one theorem, function, or definition — not an entire
>    module, file, or multi-part goal.
> 3. **Documented**: comment states (a) the assumption, (b) why deferred, (c) the owning
>    follow-up task or sub-phase.
> 4. **Tracked**: recorded in the handoff `sorry_inventory` with `strategic: true` and a
>    non-null `follow_up_task`. Untracked = never strategic; forces `partial`/`blocked`.
> 5. **Build-green**: the placeholder is a syntactically/type-valid token in the target language
>    (`sorry` in Lean4; domain equivalents such as `admit`, `raise NotImplementedError`, or an
>    explicit `-- STUB:` marker) — the build/typecheck must still pass.
>
> A dispatch meeting all five conditions ... reports `status: "implemented"` with
> `skeleton: true` ... Non-strategic main-target sorries ... remain forbidden.

Line 99 of this file already states the domain-specialization contract that task 806 must honor:
> - **lean4**: H2 applies with a formal proof line bar (first sorry-free lemma within 20 tool
>   calls)
> - Extension overrides live in `.claude/extensions/{domain}/context/contracts/anti-analysis.md`

This is explicit license/expectation that the lean override adds a *stricter proof-line-bar*,
not a *categorically stricter sorry ban* that contradicts the base policy.

**`.claude/context/contracts/wrap-up.md`** (core, 129 lines) — canonical schema (lines 42-51):

```
sorry_inventory entry: {file, line, statement, strategic, assumption, why_deferred, follow_up_task}
```
- `strategic`: boolean — true if the sorry qualifies under anti-analysis.md's 5-condition test.
- `follow_up_task`: REQUIRED (non-null) when `strategic: true`.

status/skeleton interaction table (lines 57-63):
| `status` | `skeleton` | Meaning |
|---|---|---|
| `implemented` | `false`/absent | Fully complete, no outstanding sorries |
| `implemented` | `true` | Build-green with only tracked strategic sorries |
| `partial`/`blocked` | `true` | **Invalid** |

Domain Specialization for lean4 (lines 121-127, already present, no separate override file
needed for wrap-up.md — confirmed `.claude/extensions/lean/context/contracts/` has no
`wrap-up.md` file, only `adversarial-verification.md`, `anti-analysis.md`, `context-hygiene.md`,
`reference-grounding.md`):
> - **lean4**: sorry_inventory is mandatory and must be populated. ... Under `--hard`, a sorry
>   additionally counted as a strategic skeleton division point requires `strategic: true` and a
>   non-null `follow_up_task` in its `sorry_inventory` entry (see the canonical entry schema
>   above and the five-condition test in `anti-analysis.md`).

**Field name to use everywhere in the lean/cslib files: `follow_up_task`** (not `next_dispatch`).
Task 778's own downstream note explicitly names this rename as part of the fix.

### 2. Exact current contradiction text, file by file

#### File 1: `.claude/extensions/lean/context/contracts/anti-analysis.md` (85 lines)

Section `## Sub-Sorry Policy for Leaf Sorries` (lines 60-74) is the direct analog of core's
`### Strategic sorries` subsection but with the opposite conclusion. Exact text to replace:

```
**A sorry is a leaf sorry if and only if ALL of the following hold**:
1. It appears inside a `have` step or auxiliary `lemma` that is itself the argument
   to a larger theorem, NOT as the body of a top-level theorem
2. It has a comment: `-- sorry: assumes X; deferred because Y; next dispatch: Z`
3. It does NOT appear in the sorry_inventory of the final handoff as "main target"
   (it may appear as a leaf entry with `why_deferred` populated)

**Non-leaf sorries (i.e., main-target sorries) are NEVER acceptable as final output.**

If the main theorem body is `by sorry`, the dispatch has failed to make progress.
The escalation protocol (from lean-implementation-agent) applies.
```

The **exact anchor line to remove/replace** is line 71:
`**Non-leaf sorries (i.e., main-target sorries) are NEVER acceptable as final output.**`
and lines 73-74 (the "dispatch has failed" / escalation-protocol-applies sentence).

Section `## Interaction with H9 Sorry Inventory` (lines 76-84) — current text:
```
Lean4 hard dispatches use the sorry_inventory field in `.orchestrator-handoff.json`
to track leaf sorries across dispatch boundaries. At the end of each dispatch:

1. All remaining sorries (leaf or otherwise) MUST be enumerated in `sorry_inventory`
2. Each entry requires: `{file, line, statement, assumption, why_deferred, next_dispatch}`
3. The orchestrator uses sorry_inventory to dispatch targeted follow-ups
4. A dispatch with sorries but an empty sorry_inventory is NON-CONFORMING
```
Item 2's field list is missing `strategic` and uses `next_dispatch` instead of `follow_up_task`
— must be updated to mirror core wrap-up.md's canonical 7-field schema.

**Recommended replacement wording** (for the planner to adapt), preserving the file's own
leaf-sorry criteria (1-3, which remain valid and are NOT in conflict with core policy — core's
test is only about main-target-level placeholders) and adding a new subsection mirroring core's
five conditions, specialized for Lean4:

```
### Strategic main-target sorries (Lean4 skeleton division points)

A main-target-level `sorry` (i.e., the body of a top-level theorem/lemma is `by sorry` or a
bare `sorry` term) is acceptable ONLY when it meets the core `anti-analysis.md` five-condition
strategic-sorry test, specialized here for Lean4:

1. **Deliberate division boundary**: planned as part of a skeleton from a hard-mode plan's
   phase/part breakdown — not a proof the agent got stuck on and abandoned.
2. **Tightly scoped**: exactly one theorem/lemma/definition, not an entire file or module.
3. **Documented**: a comment immediately above/on the sorry states (a) the assumption,
   (b) why deferred, (c) the owning follow-up task.
4. **Tracked**: recorded in `sorry_inventory` with `strategic: true` and non-null
   `follow_up_task`.
5. **Build-green**: `sorry` is Lean4's canonical placeholder token — `lake build` (or the
   scoped module build) must still succeed. Track via `#print axioms <decl>` showing
   `sorryAx`, and/or `declaration uses 'sorry'` compiler warnings, to confirm the sorry is
   real and located where documented (not silently absorbed by an unrelated proof).

Non-strategic main-target sorries — any that fail one or more conditions — remain forbidden;
the Escalation Protocol (from lean-implementation-agent / the hard agent's own Escalation
Protocol section) applies instead.
```

And update the H9 interaction section's field list to:
`{file, line, statement, strategic, assumption, why_deferred, follow_up_task}` — matching core.

#### File 2: `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` (463 lines)

Three separate anchor points restate the categorical ban (this file is "self-contained" per its
own header note at line 22: "Do NOT @-reference lean-implementation-agent... All lean-specific
sections are included inline below" — meaning it does NOT simply inherit anti-analysis.md's
wording by reference either; it duplicates policy prose that must be independently corrected):

**(a) Stage 5 handoff JSON example** (lines 258-280) — the example JSON has no `skeleton` field
and the `sorry_inventory` entry uses `assumption`, `why_deferred`, `next_dispatch` (missing
`strategic`, wrong field name for the follow-up field). Needs `"skeleton": false` added to the
schema (with note it may be `true`) and the entry fields renamed/extended to match core.

**(b) Lines 293-297, "Leaf sub-sorry vs. main-target sorry"** — exact current text:
```
**Leaf sub-sorry vs. main-target sorry**:
- Leaf sub-sorries (inside `have` steps, not top-level): include in sorry_inventory with
  prefix notation in statement: "have (leaf): {statement}"
- Main-target sorries (top-level theorem body is `by sorry`): include in `blockers`, not
  just sorry_inventory; set `status: "partial"` if any main-target sorries remain
```
This is the sharpest contradiction: it hard-codes "set `status: partial` if any main-target
sorries remain" with NO exception. Must add an explicit strategic-sorry branch: when all five
core conditions hold, the main-target sorry goes in `sorry_inventory` with `strategic: true`
and `follow_up_task` populated, NOT in `blockers`, and `status` may be `"implemented"` with
`skeleton: true`.

**(c) Stage 6 Final Verification, item 1** (lines 310-316):
```
1. **Check for sorries**:
   ...
   Record: `sorry_count` (must be 0 for implemented status). `--cross-check` runs its own
   `lake build` and reports both the stripper and compiler counts, feeding the reported
   inventory into `sorry_inventory`.
```
"`sorry_count` (must be 0 for implemented status)" is an absolute, unconditional gate. Must be
revised to: `sorry_count` must be 0 OR every remaining sorry is present in `sorry_inventory`
with `strategic: true` (and the five-condition test satisfied) — otherwise `status` cannot be
`"implemented"`.

**(d) "Zero-Debt Policy" section** (lines 394-402), full current text:
```
## Zero-Debt Policy

**NO sorry in implemented status**. This applies to both main-target theorems AND
any sorry introduced during this dispatch that was not present at dispatch start.

Exceptions ONLY for leaf sub-sorries that:
1. Were pre-existing in sorry_inventory from prior dispatches
2. Are being tracked for a future targeted dispatch
3. Are documented in sorry_inventory with next_dispatch populated
```
This section's heading itself ("Zero-Debt Policy") is the exact core-778 phrase this task
relaxes; core's own contract file section is literally titled with the same "zero-debt" framing
before 778 introduced the strategic-sorry exception (see core anti-analysis.md's `Sub-Sorry
Policy` intro at line 47-50 of that file, which explicitly scopes "STANDARD mode ... zero-debt
bar is unaffected"). This lean-agent section must gain a new exception item for strategic
main-target sorries, parallel to the existing "leaf sub-sorries" exceptions, and rename
`next_dispatch` → `follow_up_task`.

**(e) "MUST NOT" list, item 4** (line 456):
```
4. Return `status: "implemented"` if any sorry remains (leaf sorries must be in inventory)
```
Needs the parenthetical extended: "(leaf sorries must be in inventory; main-target sorries only
permitted as tracked strategic sorries meeting the five-condition test, with `skeleton: true`)".

#### File 3: `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` (357 lines)

This file's Context References (line 40) point at the CORE
`@.claude/context/contracts/anti-analysis.md`, not the lean override — so cslib dispatches
already load the CORRECT (778-landed) core policy text for the anti-analysis contract itself.
The contradiction here lives entirely in the agent file's own restated prose (same pattern as
lean's file 2), not in a loaded override:

**(a) Stage 5 handoff JSON example** (lines 260-271) — no `skeleton` field; `sorry_inventory: []`
example shows no per-entry schema at all (less detailed than lean's file, but the surrounding
prose at lines 273-275 is the operative constraint):
```
`sorry_inventory` MUST be populated: list any remaining sorries with file and line number.
On clean implementation: `sorry_inventory: []`.
On `partial` or `blocked`: populate `blockers` with verbatim goal text from plan checklist.
```
No mention of `strategic`/`follow_up_task`/main-target sorries being permissible at all — must
be extended to reference the core five-condition test and the `skeleton` field, matching what
file 2's corrected version will say (for consistency across lean and cslib agents).

**(b) "MUST NOT" list, item 5** (line 351):
```
5. Return implemented status if any sorry remains
```
Same fix pattern as lean file 2 item (e): add the strategic-sorry/skeleton exception.

Note: cslib's Escalation Protocol section (lines 321-329) is for `[BLOCKED]` phases (missing
Mathlib lemmas, unsolvable goals) — this is orthogonal to strategic sorries (a deliberate
skeleton division point is not a blocked phase) and should NOT be touched.

### 3. cslib -> lean inheritance mechanism (confirmed)

- `.claude/extensions/cslib/manifest.json`: `"dependencies": ["core", "lean", "literature"]`
  (confirmed via `jq '.dependencies'`).
- `find .claude/extensions/cslib -iname "*anti-analysis*"` returns **no results** — cslib has
  no anti-analysis.md override of its own; per the project's extension-dependency auto-load
  mechanism (documented in CLAUDE.md: "Extensions can declare dependencies... Dependencies are
  auto-loaded silently... with circular detection and a depth limit of 5"), cslib tasks pick up
  the lean override transitively when lean is loaded as a dependency.
- However — as noted above — `cslib-implementation-hard-agent.md`'s own Context References list
  (line 40) explicitly cites `@.claude/context/contracts/anti-analysis.md` (CORE path), not
  `@.claude/extensions/lean/context/contracts/anti-analysis.md`. This is a **pre-existing
  possible gap** independent of task 806: it's ambiguous whether cslib hard-mode dispatches are
  actually supposed to load the lean override's stricter proof-line-bar / lean-specific
  forbidden-conclusions text, or only the core file. Flagging for the planner to decide whether
  task 806 should also add the lean override to cslib's Context References list, or leave as
  documented (since this ambiguity predates 806 and isn't part of its stated scope). Recommend:
  note it as an open question in the plan, do not silently fix without a plan decision, since
  changing Context References changes cslib's H2 proof-line-bar behavior beyond just the sorry
  policy this task targets.

### 4. Cross-repo sync mechanism (confirmed via direct inspection)

- `~/Projects/cslib/.claude/` exists as a full separate `.claude/` tree (own `CLAUDE.md`,
  `extensions/`, `agents/`, `context/`, `settings.json`, etc.) — a real consuming repo, git
  history present (`git log` on `.claude/context/contracts/anti-analysis.md` shows commits
  `ae8bbdca update`, `ae152d6a task 281: complete orchestration`).
- **`install-extension.sh`** (byte-identical script exists at both
  `.claude/scripts/install-extension.sh` in this repo and presumably deployed the same way in
  cslib) only performs: (1) symlink commands, (2) symlink skills, (3) symlink agents, (4) merge
  `index-entries.json` into `context/index.json`, (5) validate. **It does NOT copy or symlink
  `context/contracts/*.md` file content at all** — confirmed by reading the full script; there is
  no `install_context()` function, only `merge_index_entries()` which merges *index metadata*,
  not file bodies.
- Despite this, `~/Projects/cslib/.claude/context/contracts/anti-analysis.md` currently contains
  the **lean-override text** (formal proof line bar, lean-specific forbidden conclusions,
  leaf-sorry-only policy) sitting at the CORE path, not the core generic text — i.e. at some
  prior point a flattened/merged copy was manually produced that overwrote the core path with
  the lean specialization. `~/Projects/cslib/.claude/extensions/lean/` exists but contains only
  `manifest.json` — no `context/contracts/` subdirectory at all in that repo.
  `~/Projects/cslib/.claude/context/contracts/wrap-up.md` has **no** `skeleton`/`strategic`
  content (`grep -n "skeleton\|strategic"` returns nothing) — confirming it predates task 778
  entirely and is stale on both axes (the lean/cslib contradiction AND the 778 schema).
  `~/Projects/cslib/.claude/agents/lean-implementation-hard-agent.md` and
  `cslib-implementation-hard-agent.md` both exist as real files (not symlinks) and both still
  contain the "main-target sorry" / "Non-leaf sorries ... NEVER acceptable" prose, confirming
  they are stale copies of the pre-806 state of files 2 and 3.
- **No automated re-sync script was found** anywhere in either repo for context/contract or
  agent file *content* (as opposed to symlink structure). The mechanism that produced the
  cslib-repo's copies is not captured in any script in this repo. Recommendation for the
  planner: task 806's plan should include an explicit, clearly-labeled **NOTE/flag** (not an
  automated step, since editing `~/Projects/cslib` is out of scope) instructing the user to
  manually re-copy the three corrected files (plus core `wrap-up.md` and `anti-analysis.md`,
  which are apparently already flattened/copied into that repo too and should be checked for
  staleness at the same time) into `~/Projects/cslib/.claude/` after 806 lands. This matches the
  task description's explicit instruction: "FLAG the change for re-install sync (do not edit
  that repo)."

### 5. Verification of consistency scope (per task 806 instructions: "Verify consistency with
core anti-analysis.md and wrap-up.md (778 schema)")

- Core `anti-analysis.md`'s Domain Specialization section (line 99) explicitly sanctions lean
  overriding the proof-line-bar bound (20 -> 30% of tool calls) — this part of the lean override
  is fine and should NOT be changed.
- Core `wrap-up.md`'s lean4 Domain Specialization (lines 123-127) already states the
  `strategic`/`follow_up_task` requirement generically for lean4 — the lean/cslib agent files
  need to be brought into line with THIS text, which already exists and was written with the
  lean/cslib case in mind (task 778's own summary confirms: "the lean extension override
  matched" when grepping for contract references, i.e. 778's authors were aware of the lean
  override's existence when writing wrap-up.md's lean4 section, but explicitly deferred editing
  the override itself).

## Decisions

- Scope of edits is confirmed as: 1 override file (lean anti-analysis.md) + restated-prose
  fixes in 2 agent files (lean-implementation-hard-agent.md, cslib-implementation-hard-agent.md)
  — six total anchor points, not one.
- Field rename `next_dispatch` -> `follow_up_task` applies everywhere in all three files (README
  confirms this was pre-planned by task 778's own downstream note).
- The `cslib-implementation-hard-agent.md` Context References ambiguity (core vs. lean override
  anti-analysis.md path) is flagged as an open question, not silently resolved — recommend the
  plan explicitly decide and document this rather than treating it as in-scope-by-default.
- Cross-repo `~/Projects/cslib` sync: flag only, do not edit. Recommend the plan's final phase
  or wrap-up include a visible NOTE (in the implementation summary, matching task 778's own
  precedent of a `> **NOTE (downstream...)**` block) rather than a script or automated action,
  since no automated sync mechanism exists to hook into.

## Risks & Mitigations

- **Risk**: Editing only the override file's "Sub-Sorry Policy" section without touching the two
  agent files' Zero-Debt Policy / Final Verification / MUST NOT restatements would leave the
  contradiction intact in practice (agents read their own file's prose, and the lean agent is
  explicitly self-contained/non-@-referencing). **Mitigation**: plan must include all six anchor
  points identified in Findings §2, not just the override file.
- **Risk**: Renaming `next_dispatch` to `follow_up_task` could silently break any script that
  parses the old field name. **Mitigation**: `grep -rn "next_dispatch"` across `.claude/` before
  finalizing the plan to confirm no script (e.g., `validate-handoff.sh`) depends on the old name;
  task 778's summary notes `validate-handoff.sh` doesn't yet enforce field-level schema checks at
  all (a separately flagged gap, task 807 per commit history), so this rename is likely safe but
  should be spot-checked.
- **Risk**: Scope creep into standard-mode lean/cslib agents (`lean-implementation-agent.md`,
  `cslib-implementation-agent.md` — the non-hard versions). Task 806 explicitly states "standard
  mode unchanged" — confirmed these files were not read/altered in this research; the planner
  should explicitly exclude them.

## Context Extension Recommendations

- **Topic**: Cross-repo extension content sync (`~/Projects/cslib`)
- **Gap**: No documented or scripted mechanism syncs `.claude/context/contracts/*.md` or
  `.claude/agents/*.md` file *content* (as opposed to index metadata) from this repo to
  `~/Projects/cslib/.claude/`. `install-extension.sh` only handles symlinks + index-entries
  merge.
- **Recommendation**: a future meta task could formalize this as a documented manual checklist
  or a new `sync-to-repo.sh` script (out of scope for 806, but worth flagging as its own
  follow-up task alongside the 806 fix, similar to how 778 spawned 806 and the `validate-handoff.sh`
  gap spawned task 807 — see commit `6909c5ee7 task: spawn follow-ups 806..., 807...`).

## Appendix

Grep/search queries used:
- `find .claude/extensions/cslib -iname "*anti-analysis*"` (confirms no cslib override)
- `jq '.dependencies' .claude/extensions/cslib/manifest.json`
- `diff .claude/context/contracts/anti-analysis.md ~/Projects/cslib/.claude/context/contracts/anti-analysis.md`
- `grep -n "skeleton\|strategic" ~/Projects/cslib/.claude/context/contracts/wrap-up.md`
- `grep -rn "downstream\|out-of-scope\|next_dispatch.*follow_up_task" specs/778_*/`

Files read in full: `.claude/context/contracts/anti-analysis.md` (core, 102 lines),
`.claude/context/contracts/wrap-up.md` (core, 129 lines),
`.claude/extensions/lean/context/contracts/anti-analysis.md` (85 lines),
`.claude/extensions/lean/agents/lean-implementation-hard-agent.md` (463 lines),
`.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` (357 lines),
`specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/summaries/01_strategic-sorry-skeleton-policy-summary.md`
(partial, downstream notes section), `.claude/scripts/install-extension.sh` (full, 298 lines).

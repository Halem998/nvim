# Research Report: Task #778

**Task**: 778 - Hard-mode: relax zero-debt for strategic-sorry skeletons (division mechanism)
**Started**: 2026-07-03T00:00:00Z
**Completed**: 2026-07-03T00:00:00Z
**Effort**: 3-6 hours
**Dependencies**: None (foundational — tasks 772 and 774 depend on this task)
**Sources/Inputs**:
- Codebase: `.claude/context/contracts/wrap-up.md`, `.claude/context/contracts/anti-analysis.md`,
  `.claude/skills/skill-implementer-hard/SKILL.md`, `.claude/agents/general-implementation-hard-agent.md`,
  `.claude/extensions/lean/context/contracts/anti-analysis.md`,
  `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`,
  `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`,
  `.claude/scripts/validate-handoff.sh`, `.claude/scripts/lint/lint-contract-compliance.sh`
- Task descriptions for 772, 774 (`specs/state.json`)
**Artifacts**:
- This report: `specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/reports/01_strategic-sorry-skeleton-policy.md`
- Handoff: `specs/778_hardmode_relax_zerodebt_strategic_sorry_skeleton/.orchestrator-handoff.json`
**Standards**: report-format.md, subagent-return.md, wrap-up.md (H9), anti-analysis.md (H2)

## Executive Summary

- The core hard-mode contracts (`wrap-up.md`, `anti-analysis.md`) are loaded **exclusively**
  by hard-mode skills/agents (`skill-implementer-hard`, `skill-orchestrate-hard`,
  `skill-researcher-hard`, `general-implementation-hard-agent`, `general-research-hard-agent`,
  and the cslib/lean hard extension variants). Standard-mode `skill-implementer` /
  `general-implementation-agent` never reference either file (confirmed by repo-wide grep).
  This means editing these two files is **structurally scoped to `--hard`** — no code change
  is needed to "gate" the relaxation by mode; the gate already exists because standard mode
  never loads the file. The report recommends making this gate **explicit** (a one-line note)
  rather than relying on the accidental/implicit structural fact, since the implicit form is
  fragile against future refactors.
- The existing "No leftover scaffolding" clause in `wrap-up.md` already carries a narrow,
  informal exception ("except explicitly noted sorry-placeholders in lean4 domains") and the
  existing `anti-analysis.md` Sub-Sorry Policy already permits **leaf** sub-sorries but
  explicitly forbids **main-target** sorry-stubs as final output. Task 778's core change is to
  formalize and *broaden* this: define a **strategic sorry** category that legitimizes
  main-target-level placeholders when they are deliberate, documented, scoped, and — critically
  — **tracked** to a follow-up task/sub-phase.
- Recommend keeping the handoff JSON `status` enum unchanged (`implemented | partial | blocked`)
  and adding a new boolean `skeleton` field plus an extended `sorry_inventory` entry schema
  (`strategic`, `assumption`, `why_deferred`, `follow_up_task`) rather than inventing a fourth
  status value — this is lower blast-radius for `validate-handoff.sh` and downstream consumers
  that already gate on `status == "implemented"`.
- **Critical gap found**: the lean extension's own contract override
  (`.claude/extensions/lean/context/contracts/anti-analysis.md`) and
  `lean-implementation-hard-agent.md` currently state flatly that "Non-leaf sorries (i.e.,
  main-target sorries) are NEVER acceptable as final output" and set `status: "partial"` if any
  main-target sorry remains. The cslib hard agent is even stricter ("Prohibited workarounds: no
  sorry ... NO sorry in implemented status"). Task 778's explicit scope is core-files-only
  (`wrap-up.md`, `anti-analysis.md`, `skill-implementer-hard/SKILL.md`,
  `general-implementation-hard-agent.md`), so this report does **not** propose editing the lean
  or cslib extension files — but flags that task 772/774 (which are motivated by a Lean4
  incident, task 305) will hit a **direct contradiction** with the lean override until a
  follow-up task aligns it. This is the single most important risk for the planner to account for.

## Context & Scope

Task 778 is the foundational leg of a three-part hard-mode revision (research=777,
planning=774, implementation=772), all gated on this task. The goal is to relax the hard-mode
zero-debt/build-green completeness bar so that a documented "strategic sorry" — a deliberate,
scoped, tracked placeholder marking a division point in a skeleton — is an acceptable dispatch
outcome under `--hard`, while build-green (compiles/typechecks) and STANDARD-mode zero-debt
remain untouched. This report investigates the four named artifacts plus their consumers and
downstream dependents (lean/cslib extension overrides, `validate-handoff.sh`,
`lint-contract-compliance.sh`) to produce an exact, minimal-blast-radius change plan.

**Explicit scope boundary** (per task description, "hard-mode ONLY"):
1. `.claude/context/contracts/wrap-up.md` — "No leftover scaffolding" clause + handoff schema
2. `.claude/context/contracts/anti-analysis.md` — Sub-Sorry Policy section
3. `.claude/skills/skill-implementer-hard/SKILL.md` — Stage verification/parsing
4. `.claude/agents/general-implementation-hard-agent.md` — Wrap-up contract execution (Stage 5)

Extension override files (lean, cslib) and `validate-handoff.sh` / `lint-contract-compliance.sh`
are investigated for impact analysis only; changes to them are **out of scope** for 778 and are
called out as Context Extension Recommendations for a follow-up task (likely surfaced by 772,
since that leg's motivating incident — task 305 — was a Lean4 task).

## Findings

### Codebase Patterns

**Contract loading topology** (repo-wide grep for `contracts/wrap-up.md` and
`contracts/anti-analysis.md` references):

| File | References `anti-analysis.md`? | References `wrap-up.md`? |
|---|---|---|
| `skill-implementer` (standard) | No | No |
| `general-implementation-agent` (standard) | No | No |
| `skill-implementer-hard` | Yes | Yes |
| `general-implementation-hard-agent` | Yes | Yes |
| `skill-researcher-hard` / `general-research-hard-agent` | Yes (H2 only, no H9) | No |
| `skill-orchestrate-hard` | Yes | Yes |
| `skill-cslib-implementation-hard` / `cslib-implementation-hard-agent` | Yes | Yes |
| `lean-implementation-hard-agent` | Yes (+ own override file) | Yes |

This confirms the gating is real and total: no standard-mode file loads either contract. The
relaxation is therefore automatically `--hard`-only by construction.

**Existing informal precedent** — `wrap-up.md` Build-Green Invariant (lines 77-88), bullet 3:
```
3. **No leftover scaffolding**: No TODO-stubs, placeholder functions, or half-written code
   blocks (except explicitly noted sorry-placeholders in lean4 domains)
```
and `wrap-up.md` field semantics (line 33):
```
- `sorry_inventory`: Array of {file, line, statement} for each sorry introduced (lean4 domains)
```
Both already gesture at "documented sorry is OK" but (a) are lean4-scoped in wording despite the
task's explicit domain-agnostic intent ("same idea applies to other domains"), (b) carry no
`strategic` vs. ordinary distinction, (c) carry no follow-up-task tracking requirement, and
(d) provide no reporting mechanism distinct from plain `"implemented"`.

**Existing informal precedent** — `anti-analysis.md` Sub-Sorry Policy (lines 45-51):
```
## Sub-Sorry Policy (for formal verification domains)

- Tightly scoped, documented leaf sub-sorrys are acceptable progress markers
- Main target theorems as sorry-stubs are not acceptable as final dispatch output
- Each sorry must include a comment stating: (a) what it assumes, (b) why it was deferred,
  (c) which next dispatch should address it
```
This is the direct ancestor of the strategic-sorry policy: it already has the 3-part
documentation requirement (assumes / why deferred / next dispatch) that task 778 point (2)
asks for — it just needs its scope widened from "leaf sub-sorries only" to "leaf sub-sorries
OR a documented strategic (main-target/division-boundary) sorry", widened from "formal
verification domains" to all domains, and the tracking requirement upgraded from "next dispatch"
(informal) to "follow-up task/sub-phase" (a machine-checkable reference into `sorry_inventory`).

**Lean extension override is a hard blocker for downstream tasks 772/774** —
`.claude/extensions/lean/context/contracts/anti-analysis.md` "Sub-Sorry Policy for Leaf
Sorries" section states: *"Non-leaf sorries (i.e., main-target sorries) are NEVER acceptable as
final output. If the main theorem body is `by sorry`, the dispatch has failed to make
progress."* `lean-implementation-hard-agent.md` (lines ~274-278) reinforces this: main-target
sorries go into `blockers` (not just `sorry_inventory`) and force `status: "partial"`.
`cslib-implementation-hard-agent.md` is stricter still ("Prohibited workarounds: no sorry ...
NO sorry in implemented status"). Since extension override files take precedence over core
contracts for their domain (per the project's extension-override pattern), the core-only change
proposed here will have **zero effect** on lean4/cslib task types until these override files are
separately updated — yet task 305 (the motivating incident for 772/774/778) was a lean4/
BimodalLogic task. This is flagged as a Context Extension Recommendation below, not
implemented here.

**`validate-handoff.sh`** currently validates `status ∈ {implemented, partial, blocked}`,
warns (does not fail) if `sorry_inventory` is absent, and does not inspect entry-level
structure. Adding a `skeleton` field and richer `sorry_inventory` entries requires no change to
existing checks (they will simply pass); a follow-up implementation task should extend it to
validate that every `strategic: true` entry has a non-null `follow_up_task`, `assumption`, and
`why_deferred` — flagged as a recommendation, not performed here.

**`lint-contract-compliance.sh`** only checks that agent files carry the `@`-reference to
`anti-analysis.md` / `wrap-up.md` by string match — it does not assert on file content shape,
so no lint changes are required by this task.

### External Resources

Not applicable — this is a closed, internal agent-system contract change with no external
dependency or library surface.

### Recommendations

#### 1. Standard-vs-hard gating mechanism

Two layers, both to be documented (the first already exists structurally; the second makes it
explicit and durable):

- **Structural** (no code change needed): `anti-analysis.md` and `wrap-up.md` are loaded only
  by `-hard` skills/agents. Standard-mode dispatch paths never read these files, so standard
  mode is unaffected by construction.
- **Explicit** (add a one-line self-documenting note): open the new/modified sections in both
  files with a sentence stating the relaxation applies only under `--hard`, and that this
  contract file is loaded exclusively by hard-mode dispatch paths. This converts an accidental
  invariant into a stated one, protecting against a future refactor that might cause a
  standard-mode skill to start loading these files without re-deriving the gating rationale.

#### 2. `anti-analysis.md` — replace/extend the Sub-Sorry Policy section

Broaden title and scope from "for formal verification domains" to all domains; keep the
existing leaf-sorry bullets verbatim (unchanged behavior); add a new "Strategic sorries
(skeleton division points)" subsection defining the five acceptance conditions: (1) deliberate
division boundary from a skeleton plan (not an abandoned/stuck proof), (2) tightly scoped to one
theorem/function/definition, (3) documented with assumption + why-deferred + follow-up
task/sub-phase, (4) tracked in `sorry_inventory` with `strategic: true` and non-null
`follow_up_task` — an undocumented/untracked sorry is never strategic and forces
`partial`/`blocked`, (5) build-green: the placeholder is a syntactically/type-valid token in the
target language (`sorry` in Lean4; domain equivalents elsewhere: `admit`, `raise
NotImplementedError`, an explicit `-- STUB:` marker). A dispatch satisfying all five reports
`status: "implemented"` + `skeleton: true` (see #3), not `partial`/`blocked`. Non-strategic
main-target sorries remain forbidden, per the existing Forbidden Conclusions section.

#### 3. `wrap-up.md` — handoff schema and Build-Green Invariant

- Add `"skeleton": false` to the handoff JSON schema example, adjacent to `status`. Semantics:
  boolean, default `false`; `true` only when `status == "implemented"` and the dispatch's
  completeness rests on one or more strategic sorries (an "implemented (skeleton)" outcome, per
  task wording). MUST be `false`/absent when `status` is `partial` or `blocked` — an incomplete
  skeleton with untracked gaps is a `partial`/`blocked` outcome, not a skeleton success.
- Extend the `sorry_inventory` field semantics from `{file, line, statement}` to
  `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`. Mirrors the
  per-entry shape the lean extension already independently converged on
  (`file, line, statement, assumption, why_deferred, next_dispatch`), so the core schema and the
  lean extension's schema become directly reconcilable when a follow-up task aligns them —
  rename `next_dispatch` -> `follow_up_task` on the lean side at that time, since a task/
  sub-phase reference is more precise than "next dispatch" for cross-dispatch tracking.
- Amend Build-Green Invariant bullet 3 ("No leftover scaffolding") to state the `--hard`-only
  exception for documented strategic sorries meeting the anti-analysis.md policy, cross-
  referencing that file rather than duplicating the five conditions. Standard mode: explicitly
  state the invariant is unchanged and absolute (no exception).
- Extend the Domain Specialization > lean4 bullet to note that, under `--hard`, strategic
  sorries additionally require `strategic: true` and `follow_up_task` — but do not touch the
  lean extension's own override file (out of scope; see Risks).

#### 4. `skill-implementer-hard/SKILL.md` — Stage verification/parsing

Stage 6 ("Parse Subagent Return") currently reads `status`, `artifact_path`/type/summary,
`memory_candidates`, `completion_summary`, `phases_completed`, `phases_total` from
`.return-meta.json`. Add parsing of `skeleton` and `sorry_inventory` (both optional, default
`false`/`[]`) so skeleton dispatches are visible to the skill layer, and add a log line (mirroring
the existing Stage 1.5 hard-mode cost note pattern) such as: `[hard-mode] Skeleton dispatch: N
strategic sorries -> follow-up tasks {...}` when `skeleton == true`. Stage 7's existing gate
(`if status == "implemented"` -> run postflight status update) requires **no change** — a
skeleton dispatch already reports `status: "implemented"` under the schema proposed in #3, so it
already flows through the existing "implemented" postflight path correctly.

#### 5. `general-implementation-hard-agent.md` — Stage 5 (H9 Wrap-Up)

Add a third worked example to the existing two (`implemented` / `partial or blocked`) branches
in "Step 1: Write `.orchestrator-handoff.json`": *"On `implemented` with strategic sorries
(skeleton)"* — set `status: "implemented"`, `skeleton: true`, empty `blockers`, null
`continuation_path`, and populate `sorry_inventory` with the full per-entry schema from #3 for
every strategic sorry. Add a short new subsection near the existing "Anti-Analysis Contract
(Mandatory)" section, e.g. "Strategic-Sorry Skeleton (Hard Mode)", pointing at
`anti-analysis.md`'s new policy and stating the agent MAY leave a strategic placeholder meeting
the five conditions instead of being forced toward `partial`/`blocked` or toward
analysis-paralysis. Add one line to the "MUST DO" list: populate `follow_up_task` for every
strategic sorry — an untracked sorry is a defect, not a skeleton success. No change needed to
the "MUST NOT" list; strategic sorries still require actual file operations, so they don't
conflict with the existing anti-analysis-only prohibition.

### Exact `sorry_inventory` Entry Schema (proposed)

```json
{
  "file": "path/to/file",
  "line": 42,
  "statement": "verbatim placeholder text or theorem/function signature",
  "strategic": true,
  "assumption": "what this placeholder assumes / what remains to be proved or implemented",
  "why_deferred": "one-sentence justification for deferring to a follow-up part",
  "follow_up_task": "774"
}
```
- `strategic` (bool, default `false`): `true` marks a documented, policy-conforming division
  point; `false`/absent marks an ordinary (non-strategic) sorry, which is never acceptable in an
  `"implemented"` dispatch (forces `partial`/`blocked`, unchanged from current behavior).
- `follow_up_task` (string, required when `strategic: true`): either a `state.json` task number
  (created by planner-hard, task 774) or a named sub-phase id in the current plan (e.g.
  `"phase-4"`) — task 778 point (3) explicitly allows either form.
- `assumption` / `why_deferred` (string, required when `strategic: true`): mirrors the existing
  3-part documentation bullet already present in `anti-analysis.md`'s leaf-sorry policy.

### Handoff JSON `status`/`skeleton` Interaction (proposed)

| `status` | `skeleton` | Meaning |
|---|---|---|
| `implemented` | `false` (default) | Fully complete phase, no debt, unchanged from today |
| `implemented` | `true` | Skeleton complete: build-green, only strategic (tracked) sorries remain, reported as "implemented (skeleton)" |
| `partial` | `false` | Existing partial semantics, unchanged |
| `blocked` | `false` | Existing blocked semantics, unchanged |
| `partial`/`blocked` | `true` | Invalid combination — a dispatch with untracked/non-strategic gaps is never a "skeleton success" |

Keeping `status` a 3-value enum (rather than adding `implemented_skeleton` as a 4th value) means
`validate-handoff.sh`'s existing `valid_statuses=("implemented" "partial" "blocked")` check and
every consumer that gates on `status == "implemented"` (e.g. `skill-implementer-hard` Stage 7)
continue to work unmodified — this is the lowest-blast-radius encoding for the "implemented
(skeleton)" reporting requirement in task point (4).

## Decisions

- **Do not add a 4th `status` enum value.** Use `status: "implemented"` + `skeleton: true`
  instead of `status: "implemented_skeleton"`. Rationale: minimizes changes to
  `validate-handoff.sh` and every Stage-7-style consumer that currently branches only on
  `status == "implemented"`.
- **Do not modify the lean or cslib extension override files in this task.** They directly
  contradict the new core policy ("non-leaf/main-target sorries never acceptable"), but task
  778's scope is explicitly core-files-only. This is surfaced as the top risk for 772/774.
- **Keep the field name `sorry_inventory`** (not renamed to something domain-neutral like
  `placeholder_inventory`) since task 778 explicitly names it and Lean4 `sorry` is called the
  "canonical" placeholder; the per-entry `statement` field already accommodates non-Lean
  placeholder text (stub function signatures, `NotImplementedError` call sites, etc.).
- **Policy definition lives in `anti-analysis.md`; schema/reporting mechanics live in
  `wrap-up.md`**, cross-referenced rather than duplicated — matches the existing H2/H9
  contract-file division of responsibility in this repo.

## Risks & Mitigations

- **Risk**: Lean/cslib extension overrides directly contradict the relaxed core policy, so
  772/774 (both motivated by a Lean4 incident) cannot benefit from this change until a follow-up
  task aligns `.claude/extensions/lean/context/contracts/anti-analysis.md` and
  `lean-implementation-hard-agent.md` (and, if desired, cslib's stricter "no sorry" rule).
  **Mitigation**: flag explicitly in this report (done); recommend the planner for 772 or 774
  spawn a dedicated follow-up task to reconcile the lean/cslib overrides with the new core
  schema (rename `next_dispatch` -> `follow_up_task`, add `strategic` field, relax the "never
  acceptable" main-target rule under the five strategic-sorry conditions).
- **Risk**: A dispatch could mislabel an abandoned/stuck sorry as "strategic" to avoid an
  honest `partial`/`blocked` report, since the policy is self-attested by the agent that writes
  the handoff. **Mitigation**: the tracking requirement (non-null `follow_up_task` referencing a
  real task number or sub-phase) is the load-bearing check — a follow-up implementation task
  should extend `validate-handoff.sh` to verify `follow_up_task` values resolve to an existing
  `state.json` task number or a named sub-phase in the plan file, rejecting free-text
  hand-waving.
- **Risk**: Scope creep into research-grade "strategic" theorems disguised as division points
  (the exact failure mode task 305 hit). **Mitigation**: condition (2) "tightly scoped to one
  theorem/function/definition" plus H8 phase sizing (task 774's remit) together bound this;
  778 defines the acceptance test, 774 is responsible for actually placing sorries at
  correctly-sized boundaries.

## Context Extension Recommendations

- **Topic**: Lean/cslib extension contract alignment with core strategic-sorry policy
  **Gap**: `.claude/extensions/lean/context/contracts/anti-analysis.md` and
  `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` are not covered by this
  task's scope but directly conflict with the new core policy for the exact domain (Lean4) that
  motivated it.
  **Recommendation**: create a follow-up task (owned by, or spawned from, task 772) to update
  the lean extension's Sub-Sorry Policy and `lean-implementation-hard-agent.md`'s handoff logic
  to recognize `strategic: true` main-target sorries per the core policy, and to rename
  `next_dispatch` -> `follow_up_task` in its `sorry_inventory` entries for schema consistency.

- **Topic**: `validate-handoff.sh` strategic-sorry structural validation
  **Gap**: the validator currently only warns if `sorry_inventory` is absent; it does not check
  per-entry structure or that `follow_up_task` resolves to a real task/sub-phase.
  **Recommendation**: extend `validate-handoff.sh` (in the 772 implementation task or a
  dedicated follow-up) to fail when a `strategic: true` entry lacks `follow_up_task`,
  `assumption`, or `why_deferred`, and to warn if `follow_up_task` does not match a
  `state.json` task number or a `### Phase N` heading in the associated plan.

## Appendix

**Search/investigation performed**:
- Read `specs/778_.../` directory structure and `state.json` entry for task 778 (description,
  scope, dependencies)
- Read `.claude/context/contracts/wrap-up.md` in full
- Read `.claude/context/contracts/anti-analysis.md` in full
- Read `.claude/skills/skill-implementer-hard/SKILL.md` in full
- Read `.claude/agents/general-implementation-hard-agent.md` in full
- Read `state.json` entries for tasks 772 and 774 (dependent tasks, for cross-task consistency)
- Repo-wide grep for `sorry_inventory` across `.claude/` (13 files) to map every consumer
- Diffed `.claude/agents/general-implementation-hard-agent.md` against
  `.claude/extensions/core/agents/general-implementation-hard-agent.md` — confirmed identical
  (the extension-core copy is a mirror, not a divergent override)
- Read `.claude/extensions/lean/context/contracts/anti-analysis.md` in full (override file)
- Grepped `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` and
  `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` for sorry-related policy
- Read `.claude/scripts/validate-handoff.sh` in full
- Grepped `.claude/scripts/lint/lint-contract-compliance.sh` for wrap-up/anti-analysis/sorry
  references
- Grepped `.claude/skills/skill-planner-hard/SKILL.md` and `.claude/agents/planner-hard-agent.md`
  for existing skeleton/follow-up references (none found — confirms task 774 has not yet
  implemented the skeleton-plus-follow-up mechanism this task's policy will support)

**References**:
- `.claude/context/contracts/wrap-up.md` (H9 contract)
- `.claude/context/contracts/anti-analysis.md` (H2 contract)
- `.claude/skills/skill-implementer-hard/SKILL.md`
- `.claude/agents/general-implementation-hard-agent.md`
- `.claude/extensions/lean/context/contracts/anti-analysis.md`
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- `.claude/scripts/validate-handoff.sh`
- `specs/state.json` (tasks 772, 774, 778)

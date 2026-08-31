# Research Report: Build hard_contracts manifest key and contract-text injection

- **Task**: 118 - Build hard_contracts manifest key and contract-text injection at dispatch-prep time
- **Started**: 2026-08-31T00:00:00Z
- **Completed**: 2026-08-31T00:00:00Z
- **Effort**: ~3 hours (codebase investigation, no code changes — this is a design/spec report)
- **Dependencies**: Task 117 (Stage 3.5 Dispatch Prep — confirmed landed, see Findings)
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 1, Stage MT-1, Stage 3.5, dispatch sites)
  - `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  - `agent-system/extensions/core/skills/skill-researcher-hard/SKILL.md`, `skill-planner-hard/SKILL.md`, `skill-implementer-hard/SKILL.md`
  - `agent-system/extensions/core/agents/general-research-hard-agent.md`, `planner-hard-agent.md`, `general-implementation-hard-agent.md`
  - `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`, `command-route-skill.sh`, `command-route-agent.sh`
  - `agent-system/extensions/core/scripts/verify-deploy.sh`
  - `agent-system/extensions/core/context/guides/manifest-routing-schema.md`, `hard-mode-routing.md`
  - `agent-system/extensions/core/context/contracts/*.md`
  - `agent-system/extensions/core/commands/orchestrate.md`, `scripts/parse-command-args.sh`
  - `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` (A4-i, A4-ii, A4-iii)
  - `specs/TODO.md` (tasks 118, 119, 120, 121, 122)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- `context/contracts/*.md` already exists as the shared contract-text store; this task is a
  **consumer-count reduction**, not content authoring. No contract file needs new prose.
- `skill-orchestrate/SKILL.md`'s Stage 3.5 (Dispatch Prep, built by task 117) is confirmed landed
  and has the exact shape task 118 needs to extend: an `Inputs` table, several named procedures,
  and an `Outputs and injection contract` paragraph consumed by exactly **10 dispatch-site
  pointer lines** (7 single-task, 3 multi-task loops) that all share near-identical fixed wording.
- `/orchestrate --hard` **always** dispatches through `skill-orchestrate` (never
  `skill-orchestrate-hard` — confirmed: `commands/orchestrate.md` hardcodes
  `skill: "skill-orchestrate"` and nowhere names `skill-orchestrate-hard` as a Skill-tool target;
  `skill-orchestrate-hard/SKILL.md` is unreachable dead code today, referenced only by its own
  manifest listing). `effort_flag` (which can be `"hard"`) already flows into
  `skill-orchestrate`'s Stage 1/MT-1 and is used today only for **agent** routing
  (`command-route-agent.sh` against `routing_agents_hard`), never for contract-text injection.
- The per-phase contract lists this task must centralize are fully recoverable from the 7
  soon-to-be-deleted `-hard` files' own reference order (documented below); no invention needed.
- Recommend a new `hard_mode` boolean, derived once at Stage 1/MT-1 from `effort_flag`, shared by
  this task's contract injection AND task 119's stateful `if $hard_mode` branches (task 119
  explicitly expects this shape).
- Recommend a new `routing_lookup_flat()` function in `manifest-routing-lib.sh` — a one-level-block
  sibling of the existing `routing_lookup()` — because `hard_contracts: {task_type: [...]}` has no
  per-operation axis, unlike `routing`/`routing_hard`/`routing_agents`/`routing_agents_hard`'s
  `{op: {task_type: value}}` shape. Reusing `routing_lookup()` unchanged would force a fake `op`
  key into a manifest shape that does not have one.
- The design report's suggested `verify-deploy.sh` warning text ("no longer consulted") is
  **factually premature** if added by this task alone: `routing_hard`/`routing_agents_hard` remain
  genuinely consulted (by `/research`/`/plan`/`/implement`'s `command-route-skill.sh`, and by
  `command-route-agent.sh`) until task 119 (state-machine migration) and task 121 (file deletion)
  land later in the same dependency chain. Recommend accurate present-tense wording instead (see
  Decisions).

## Context & Scope

Task 118 sits between task 117 (Stage 3.5 Dispatch Prep — landed) and task 119 (state-machine
migration — not started) in a 4-task chain (118 → 119 → 120/121) collapsing
`skill-orchestrate-hard` and the 6 other `-hard` files into `hard_mode`-gated branches of
`skill-orchestrate/SKILL.md`. This task's WORK items, verbatim from `specs/TODO.md`:

1. Extend Stage 3.5 Dispatch Prep so that, when `hard_mode` is set, it builds and appends the
   ordered `context/contracts/*.md` reference block to the dispatch prompt.
2. Add an optional `hard_contracts` manifest key (`{task_type: [path, ...]}`) letting an extension
   add or override a contract for its own task types, resolved by the existing manifest-routing
   ladder's compound-key (`ext:subtype`) matching; a `"replace:core-file.md:override-file.md"`
   entry substitutes rather than adds.
3. Add a deploy-time warning (not a hard error, not silent ignore) in `verify-deploy.sh` for any
   extension still declaring `routing_hard`/`routing_agents_hard`, naming the extension and
   pointing at `hard_contracts` as the migration path.

**Explicitly out of scope** (per the task description and confirmed independently against the
design report): the stateful hard-mode logic — churn/three-strikes counters (H5/H6), the burnout
circuit breaker, and the single-blocking-phase-per-cycle implement-dispatch limiter (H1). These
are conditional **state-machine** branches, not prompt-injectable text, and are task 119's scope.
This report does not design that logic; it only defines the `hard_mode` boolean task 119 is
expected to consume (per task 119's own description: "Port this residue into
`skill-orchestrate/SKILL.md` as `if $hard_mode` conditional branches").

Also out of scope, confirmed by reading `commands/orchestrate.md` and `manifest-routing-schema.md`
directly: any change to `/research`/`/plan`/`/implement`'s own `command-route-skill.sh` routing.
Those commands are a **separate**, larger consolidation effort (A1 "Single Entry Point" in the
task 116 design report — those commands are slated for deletion once `/orchestrate` becomes the
sole entry point) and are not touched by this task or its dependents.

## Findings

### 1. Stage 3.5 Dispatch Prep — current shape (task 117, confirmed landed)

`skill-orchestrate/SKILL.md` Stage 3.5 (~lines 340-432) is a single canonical procedure referenced
by pointer from every dispatch site. Its current `Inputs` table has: `phase`, `description`,
`task_type`, `focus_prompt`, `clean_flag`, `effort_flag`, `lit_flag`, `orchestrator_mode`. **No
`hard_mode` input exists yet** — this must be added.

Its current `Outputs and injection contract`: produces `memory_context`, `lit_context`,
`effort_note`; every dispatch site appends them in that order, skipping empties, never adding them
to the `context` JSON object.

**Dispatch-site call count** (grep-verified): exactly **7 single-task** pointer lines (2 for
research, 2 for plan, 3 for implement — the extra implement sites are resume-with-continuation and
resume-without-continuation variants) and **3 multi-task loop** pointer lines (research, plan,
implement loops in Stage MT-4), for **10 total**. Every one of the 7 single-task rows shares this
literal trailing substring verbatim:
```
then append `memory_context`, then `lit_context`, then `effort_note` from Stage 3.5, each skipped when empty
```
and every one of the 3 multi-task rows shares:
```
with `memory_context`, then `lit_context`, then `effort_note` from Stage 3.5 appended, each skipped when empty
```
Both patterns are `grep -c` confirmed unique-and-exact across the file (7 and 3 hits
respectively, no near-misses), and a third pattern — `` `memory_context`, `lit_context`, and
`effort_note`.`` — appears exactly 10 times (the "to produce X, Y, and Z" phrasing shared by all
10 sites' lead-in). This means adding a 4th output (`hard_contracts_block`) is a **3-pattern,
global find-and-replace** across the file, not 10 hand-edits — low risk, mechanically verifiable
before/after with the same grep counts.

### 2. `/orchestrate --hard` never invokes `skill-orchestrate-hard`

`commands/orchestrate.md`'s Anti-Bypass Constraint requires delegating "to `skill-orchestrate`"
(not `-hard`), and its single Skill-tool invocation site hardcodes `skill: "skill-orchestrate"`
for both single-task and multi-task dispatch. `EFFORT_FLAG` (which `parse-command-args.sh` sets to
`"hard"` on `--hard`) is threaded into the delegation context as `effort_flag` and consumed by
`skill-orchestrate` Stage 1b purely for **agent** selection
(`command-route-agent.sh ... "$effort_flag"` against `routing_agents_hard`). A repo-wide grep for
`skill: "skill-orchestrate-hard"` (or any string naming it as a Skill-tool target) returns **zero
hits** outside `skill-orchestrate-hard/SKILL.md`'s own file and the core manifest's file listing.

This confirms the design report's premise (skill-orchestrate-hard's Stage MT delegates to base MT
stages, and the whole file is dead weight ready for the collapse) and, more directly, tells this
task exactly where `hard_mode`-gated logic belongs: **inside `skill-orchestrate/SKILL.md`**, never
in the (already-unreachable) `-hard` file.

### 3. Per-phase contract lists, recovered from the 7 files being collapsed

Grepped every `context/contracts/*.md` reference across the 7 candidate files. Order matches each
file's own declared reference order (its own "Context References"/frontmatter list), which is the
order each phase's contract block should preserve:

| Phase | Contracts, in source order | Source evidence |
|-------|------------------------------|------------------|
| `research` | `anti-analysis.md` (H2), `reference-grounding.md` (H3), `adversarial-verification.md` (H4) | `general-research-hard-agent.md:25-27`, `skill-researcher-hard/SKILL.md:21-23` (same order) |
| `plan` | `reference-grounding.md` (H3), `wrap-up.md` (H9 — skeleton/sorry_inventory schema), `anti-analysis.md` (H2 — 5-condition strategic-sorry test) | `planner-hard-agent.md:28,29,33` |
| `implement` | `anti-analysis.md` (H2), `wrap-up.md` (H9), `territory.md` (H7, **conditional** — "when territory params present"), `recovery.md`, `phase-closure.md`, `pre-edit-gate.md` | `general-implementation-hard-agent.md:29-34`, `skill-implementer-hard/SKILL.md:24-29` (same order) |

Two contracts are correctly **excluded** from every list above:
- `convergence.md` (H6) — documents stateful churn/three-strikes counters, not prompt text; this
  is task 119's state-machine scope, not dispatch-prompt injection.
- `orchestrator-discipline.md` — governs the orchestrator's own behavior as read directly by
  `skill-orchestrate-hard` today (`Read .claude/context/contracts/orchestrator-discipline.md` at
  its own Stage, lines 205/548), never injected into a dispatched sub-agent's prompt. Not a
  per-dispatch injection candidate at all.

`territory.md`'s conditionality: `general-implementation-hard-agent.md:107,146` gate it on a
`territory` delegation-context key (owned_files/read_only_files) supplied only by
`skill-orchestrate-hard`'s own H7 parallel-dispatch machinery. Grepped
`skill-orchestrate/SKILL.md` for `territory` and found an explicit, already-recorded **Decision
record** (line ~2028, inside the Multi-Task Mode section): "base mode does NOT gain a `territory`
dispatch key." No current single-task or multi-task dispatch site in `skill-orchestrate/SKILL.md`
sets one. `territory.md` inclusion should therefore be gated on a Stage-3.5 `territory` input that
is defined but **currently always empty/absent** — forward-compatible for task 122 (team-mode
fan-out, a sibling task, dependencies Task 117 + Task 119, not 118) without redesigning contract
selection when that lands.

### 4. `hard_contracts` manifest key — shape mismatch with the existing ladder

`manifest-routing-lib.sh`'s `routing_lookup()` (the shared 5-step ladder used by `routing`,
`routing_hard`, `routing_agents`, `routing_agents_hard`) resolves **two-level** blocks:
`(.[$block] // {})[$op][$task_type]`. The design report specifies `hard_contracts` as
`{task_type: [path, ...]}` — a **one-level** block with no `$op` axis (a hard-mode contract list
is not naturally partitioned by research/plan/implement the way skill/agent routing is — an
extension's contract addition applies to whichever phase's dispatch-prep call resolves it).

Forcing `hard_contracts` through `routing_lookup()` unchanged would require inventing a fake `$op`
value (e.g. passing `task_type` as both `$op` and `$task_type`, or a constant sentinel), which
would misrepresent the manifest shape WORK item 2 actually specifies and complicate every
manifest author's `hard_contracts` block for no benefit. **Recommend a parallel function**,
`routing_lookup_flat(block, task_type)`, replicating the same four-step precedence
(non-core-exact → non-core-compound → core-exact → core-compound) against a one-level `jq` path
(`(.[$block] // {})[$task_type]`), using `jq -c` (not `-r`) since the resolved value is a JSON
array, not a scalar. This keeps `manifest-routing-lib.sh`'s stated role as "single source of truth
for the manifest routing ladder" — same precedence semantics, correct shape.

Verified: zero of the 19 extension manifests declare `hard_contracts` today (grepped
`agent-system/extensions/*/manifest.json` for the string — no hits), matching the design report's
own "no extension needs this on day one" observation. The mechanism is additive/speculative but
cheap.

**`replace:` prefix semantics** (design report A4-ii, example:
`"replace:anti-analysis.md:lean/contracts/lean-anti-analysis.md"`): both sides name a
**basename-relative** path — the left side matches an entry already present in the phase's core
list (by exact basename), the right side is the extension-relative override path substituted in
its place. A resolution procedure needs three passes over the resolved JSON array: (1) build the
phase's fixed core list, (2) apply every `replace:` entry as an in-place array-element
substitution, (3) append every remaining, non-`replace:`-prefixed entry as a plain addition.

### 5. `verify-deploy.sh` — gate structure and where a warning fits

`verify-deploy.sh` runs 16 numbered gates (`gate0`..`gate15`), each incrementing a shared `CHECKS`
counter via `pass()`/`fail()`; `fail()` also increments `FAILURES` (which flips the script's exit
code and final PASS/FAIL line) and appends to a `FINDINGS_LIST` consumed by `--findings` mode. The
file's own header comment states "(gate0 through gate15)" for the findings-mode gate range — this
needs updating if a `gate16` is added.

**No existing non-blocking "warning" helper exists** — every check today is binary pass/fail via
`pass()`/`fail()`. Since the task requires "not a hard error", a new gate needs a `warn()` helper
that increments `CHECKS` (for an accurate final count, mirroring `pass()`/`fail()`'s convention)
but **never** increments `FAILURES` and never flips the exit code. The natural insertion point is
immediately after gate 15's `fi`, before the final `say ""` / PASS-FAIL summary block (~line 719).

Extensions declaring `routing_hard` and/or `routing_agents_hard` today (grep-verified against
`*/manifest.json`, matching the design report's own count): exactly **3 of 19** — `core`, `cslib`,
`lean`.

### 6. `manifest-routing-schema.md` / `hard-mode-routing.md` — where `hard_contracts` needs documenting

`manifest-routing-schema.md`'s "## The Four Blocks" section (`routing`, `routing_hard`,
`routing_agents`, `routing_agents_hard`) is the canonical enumeration of manifest routing keys.
Adding a 5th key (`hard_contracts`) without updating this doc would leave the doc silently
incomplete, and this task's own `verify-deploy.sh` warning (Decision below) points readers at this
exact doc — a dead pointer if it says nothing about `hard_contracts`. `hard-mode-routing.md`'s own
"Related Files" section lists the schema doc as the fuller reference and would similarly benefit
from one cross-reference line, but does not need the full mechanism re-explained (it is scoped
specifically to the `--hard` skill/agent resolution path, a different mechanism from contract-text
injection).

## Decisions

1. **`hard_mode` derivation**: compute once, at Stage 1 (single-task) and Stage MT-1
   (multi-task), as `hard_mode="false"; [ "$effort_flag" = "hard" ] && hard_mode="true"`. Not
   computed inside Stage 3.5 itself, so task 119's state-machine branches (Stage 2 loop-guard
   init, Stage 3c burnout breaker, Stage 4b churn detection — all outside Stage 3.5) can read the
   same boolean without re-deriving it. This directly satisfies task 119's own stated expectation
   of `if $hard_mode` branches elsewhere in the file.

2. **Contract lists are fixed, per-phase, ordered arrays** (not re-derived per dispatch) —
   `research`/`plan`/`implement` cases exactly as tabulated in Findings §3, with `territory.md`
   conditional on a (currently always-empty) `territory` Stage-3.5 input.

3. **`hard_contracts` resolution uses a new `routing_lookup_flat()` sibling function**, not a
   forced reuse of `routing_lookup()` — see Findings §4 for the shape-mismatch rationale. This
   keeps `manifest-routing-lib.sh` as the single ladder implementation for BOTH block shapes
   without misrepresenting either.

4. **`verify-deploy.sh` warning wording — deviates from the design report's literal suggested
   text**, and this deviation is deliberate, not an oversight: the design report's proposed
   message ("...which is no longer consulted after the hard-mode collapse...") would be **false**
   at the moment this task's own gate starts running, because `routing_hard`/`routing_agents_hard`
   remain genuinely consulted (by `command-route-skill.sh` for `/research`/`/plan`/`/implement`,
   and by `command-route-agent.sh`) until task 119 and task 121 — both dependent on this task —
   land later in the same chain. Recommend accurate, collapse-stage-independent wording instead,
   e.g.:
   > `extension '{name}' declares routing_hard/routing_agents_hard — these are being replaced by
   > dispatch-prep contract injection; migrate to the hard_contracts manifest key (see
   > context/guides/manifest-routing-schema.md)`

   This phrasing is true both now (still consulted, migration in progress) and after task 121 (by
   which point task 121 itself removes these blocks from `core`/`cslib`/`lean`'s manifests, so the
   warning's remaining long-term audience — a 4th extension mistakenly adding `routing_hard` after
   the collapse — is exactly the case where "being replaced" reads naturally). The planner/
   implementer should feel free to adjust exact wording, but should preserve the "being replaced /
   migrate to" framing rather than the "no longer consulted" framing for the reason stated above.

5. **New gate (`gate16`) in `verify-deploy.sh`**, non-blocking via a new `warn()` helper (counts
   toward `CHECKS`, never `FAILURES`), iterating `$CLAUDE_DIR/extensions/*/manifest.json` and
   flagging any manifest with `has("routing_hard") or has("routing_agents_hard")`. Update the
   file's header comment's stated gate range (`gate0` through `gate15` → `gate0` through
   `gate16`).

6. **Documentation**: add a `hard_contracts` entry to `manifest-routing-schema.md`'s "Four Blocks"
   section (renaming/expanding it, since it becomes a 5th block with a genuinely different shape —
   one-level vs. two-level), briefly noting the `replace:` prefix and pointing at
   `routing_lookup_flat()`. Add one cross-reference line in `hard-mode-routing.md`'s own doc,
   without duplicating the mechanism.

## Recommendations

For the planner, in dependency order:

1. **`agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`**: add
   `routing_lookup_flat(block, task_type)` immediately after `routing_lookup()`'s closing `}`
   (before `routing_trace()`), implementing the same 4-step non-core/core × exact/compound
   precedence against the one-level `jq -c '(.[$b] // {})[$tt] // empty'` path, setting
   `$_ROUTE_LAST_VALUE`/`$_ROUTE_LAST_VIA` on the same terms as `routing_lookup()`. Add one usage
   line to the file's header `# Usage:` block.

2. **`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`**:
   - Stage 1: add a `hard_mode` bullet to the Inputs list (derived from `effort_flag`, per
     Decision 1).
   - Stage MT-1: add the identical `hard_mode` derivation to its own Inputs list.
   - Stage 3.5 Inputs table: add `hard_mode` row (source: Stage 1/MT-1) and a `territory` row
     (optional, currently unset by any call site — per Findings §3).
   - Stage 3.5 body: insert a new "Hard-mode contract injection, gated on `hard_mode == "true"`"
     subsection between the existing "Effort-depth note" and "Outputs and injection contract"
     paragraphs, containing: (a) the fixed per-phase `core_contracts` array construction (case
     statement over `$phase`, per the table in Findings §3, with the `territory.md` conditional
     append); (b) the `hard_contracts` extension-resolution step calling
     `routing_lookup_flat "hard_contracts" "$task_type"`, applying `replace:` substitutions first
     then additive appends; (c) the final `hard_contracts_block` string build
     (`<hard-mode-contracts>` tag wrapping one `- context/contracts/{file}` line per resolved
     entry).
   - Update the "Outputs and injection contract" paragraph to name `hard_contracts_block` as a 4th
     output, appended last (after `effort_note`), with the same empty-skip rule.
   - Update all 10 dispatch-site pointer lines via 3 global find/replace passes (verified safe by
     the exact/unique grep counts in Findings §1): the "to produce X, Y, and Z" 10-hit pattern, the
     7-hit single-task "then append ... each skipped when empty" pattern, and the 3-hit
     multi-task "with ... appended, each skipped when empty" pattern — each gaining
     `hard_contracts_block` as the final item.

3. **`agent-system/extensions/core/scripts/verify-deploy.sh`**: add a `warn()` helper next to
   `pass()`/`fail()` (increments `CHECKS`, never `FAILURES`, echoes to stderr unconditionally like
   `fail()` does). Add gate 16 (per Decision 5) immediately before the final PASS/FAIL summary.
   Update the header comment's "(gate0 through gate15)" range.

4. **`agent-system/extensions/core/context/guides/manifest-routing-schema.md`**: extend "The Four
   Blocks" section to document `hard_contracts` as a 5th, differently-shaped block (per Decision
   6). **`agent-system/extensions/core/context/guides/hard-mode-routing.md`**: add one
   cross-reference line, no mechanism duplication.

5. **Verification bar for the implementer**: (a) `hard_mode` is `"false"` unless `--hard` is
   passed, confirmed by tracing `EFFORT_FLAG` through `parse-command-args.sh` →
   `commands/orchestrate.md` → Stage 1/MT-1; (b) a `hard_mode=true` dispatch's prompt contains a
   `<hard-mode-contracts>` block naming exactly the phase's fixed contract list, in the documented
   order, for all three phases; (c) a `hard_mode=false` (default) dispatch's prompt is
   byte-identical to today's (no `<hard-mode-contracts>` tag at all — empty-skip, not an empty tag
   pair); (d) `manifest-routing-lib.sh`'s existing test/lint consumers
   (`lint-routing-wiring.sh`, `test-routing-resolution.sh`) still pass unmodified, since
   `routing_lookup_flat` is purely additive; (e) `verify-deploy.sh --findings` against the current
   tree emits exactly 3 `gate16` findings (`core`, `cslib`, `lean`), and the script's overall exit
   code is unaffected by their presence (still 0, since gate16 never fails).

## Risks & Mitigations

- **Risk**: a future editor "simplifies" `routing_lookup_flat()` into a call to `routing_lookup()`
  with a synthetic `$op`, silently changing `hard_contracts`'s manifest shape. **Mitigation**: the
  new function's own doc comment (drafted in this report's Findings §4) states the shape mismatch
  explicitly; the implementer should preserve that comment verbatim.
- **Risk**: the 3-pattern global replace across `skill-orchestrate/SKILL.md`'s 10 dispatch sites
  silently misses a site if a future edit rewords one row's fixed phrasing before this task lands.
  **Mitigation**: this report's exact `grep -c` counts (10/7/3) are captured as a pre-condition;
  the implementer should re-run the same three greps immediately before editing and abort/re-scope
  if counts differ from those recorded here.
- **Risk**: wording the `verify-deploy.sh` warning as "being replaced" (Decision 4) rather than
  the design report's literal suggested text could read as a report deviation needing sign-off.
  **Mitigation**: flagged explicitly above with full reasoning; the planner can restore the
  design report's exact wording if a human reviewer prefers literal fidelity over point-in-time
  accuracy, but should not do so silently.

## Appendix

- Grep commands used to derive counts in Findings §1 and §5 are reproduced verbatim in this
  report's own investigation (not restated here); re-running them against the current file state
  is the cheapest pre-implementation sanity check (see Risks above).
- `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md` sections A4-i,
  A4-ii, A4-iii are the originating design decisions this report operationalizes; A2/A6/A7 provide
  broader context on the full collapse (tasks 117-122) this task is one link in.

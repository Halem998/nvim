# Research Report: Task #925

**Task**: 925 - depth_first_phase_closure_and_pre_edit_gate
**Started**: 2026-07-27T17:40:00Z
**Completed**: 2026-07-27T17:57:00Z
**Effort**: research
**Dependencies**: None
**Sources/Inputs**: Codebase grep/read of `agent-system/extensions/core/` (the source store) and
  all `extensions/*/index-entries.json` files
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The "verified absent" claim is confirmed exactly: a repo-wide grep for
  `depth-first|breadth-first|one phase at a time` across all of `agent-system/` returns zero
  hits.
- Standard mode's phase loop (`agents/general-implementation-agent.md` Stage 4, "Execute File
  Operations Loop") is a single-dispatch `for each phase starting from resume point` loop with no
  ordering-by-cost and no stop-at-boundary condition — it advances to the next phase
  automatically once the current one closes ("Only then proceed to Stage 4D-iii and the next
  phase"). `skills/skill-implementer/SKILL.md` documents this explicitly: "delegates the entire
  phase loop to `general-implementation-agent` in a single Agent tool call."
- Hard mode's H1 phase selector (`skills/skill-implementer-hard/SKILL.md` Stage 3b) picks the
  **first** plan heading matching `NOT STARTED|PARTIAL|IN PROGRESS` scanning top-to-bottom — it
  does not preferentially finish an already-open `PARTIAL`/`IN PROGRESS` phase over starting a
  numerically-earlier `NOT STARTED` one; both statuses win on position alone.
- **Scope item D (highest value): the hard-mode-only claim for `context/contracts/` is
  exhaustively confirmed.** Every single `contracts/*.md` entry in every `index-entries.json`
  across the whole source store (core + all 15 extensions) has a `load_when.agents` list
  containing exclusively `*-hard` agent names (or is empty/orphaned). Zero exceptions, checked
  file-by-file. The directory's registration in the adaptive context-discovery mechanism is
  hard-mode-exclusive without exception.
- **No central injection point exists that extension implementers already inherit.** Only
  `agents/general-implementation-agent.md` (core, standard mode) is wired to run the adaptive
  `context-discovery.md` query at all. None of the 11 extension implementation agents, and no
  hard-mode implementation agent (core or extension), reference `context-discovery.md` or run
  the `index.json` adaptive query — each loads only what is hand-listed in its own "Context
  References" section. Propagating any core content (including this new contract) to the 13
  extension implementers is real, per-file work; there is no free hook. This has direct
  precedent: `cslib-implementation-hard-agent.md` already hand-lists `@.claude/context/contracts/
  anti-analysis.md`, `wrap-up.md`, `territory.md` as individual bullets, copied by hand from
  core's hard agent — exactly the propagation pattern a downstream task would have to repeat.
- The two composition partners are real and load-bearing: `plan-format.md`'s
  `**Scope Hypothesis:**` field explicitly states its implementation-side consumer is
  "out-of-scope for this document" — this task's per-item pre-edit gate is that missing
  consumer. `status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` / `#### Reasoned Exclusions`
  record is the shipped landing zone for a failed-probe item.
- Recommendation: author `context/contracts/phase-closure.md` (or a `pre-edit-gate.md` sibling,
  see Decisions) and wire it via **explicit `@`-references** added to all four files named in
  Scope A — not via directory placement or reliance on the adaptive query alone, since neither
  is sufficient in this codebase. Also add an `index-entries.json` entry breaking the contracts/
  hard-only precedent (for Context Gap Detection accuracy), but treat it as supplementary, not
  load-bearing.

## Context & Scope

Researched task 925's four scope items (A-D) for the core agent-system source store at
`agent-system/extensions/core/` (all edits target this tree per the SOURCE-STORE RULE; `.claude/`
is a disposable deploy artifact and was not read as the source of truth). Focus was scope item D
per the delegation's explicit weighting ("SPEND YOUR EFFORT HERE"). All claims below are grounded
in direct `grep`/`jq`/`Read` evidence, not inference from filenames.

## Findings

### 1. Depth-first / breadth-first grep verification

```
grep -rniE "depth-first|depth first|breadth-first|breadth first|one phase at a time" agent-system/
```
Zero matches. Confirmed absent exactly as the task description states.

### 2. Exact quotes: standard-mode sequencing vs. hard-mode phase selector

**Standard mode** — `skills/skill-implementer/SKILL.md`:
- Line 278 (Stage 5, describing what the subagent does): `Execute phases sequentially` — this is
  the entirety of the ordering language; it constrains order (ascending), not concurrency of
  opening.
- Lines 223-226: "this skill is a thin wrapper that delegates the entire phase loop to
  `general-implementation-agent` in a single Agent tool call — it has no per-phase-transition
  point of its own."

`agents/general-implementation-agent.md` Stage 4 ("Execute File Operations Loop"), line 112:
`For each phase starting from resume point:` — followed by sub-stages A (mark in progress),
B (execute steps), C (verify), D (mark complete + self-review), then (line 296) "Only then
proceed to Stage 4D-iii and the next phase (or Stage 5 if all phases are complete)." There is no
cost-ordering step and no "stop if the next phase cannot be finished" gate — the loop's only exit
conditions are "all phases complete" or a context-exhaustion handoff (Stage 4E/4C).

**Hard mode** — `skills/skill-implementer-hard/SKILL.md` Stage 3b (lines 146-153), verbatim:
```bash
next_phase=""
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  # Scan phase headings top-to-bottom; first NOT STARTED / PARTIAL / IN PROGRESS wins.
  # Heading form: "### Phase {N or N.1}: {name} [STATUS]"
  next_phase=$(grep -E '^### Phase [0-9]+(\.[0-9]+)?: .*\[(NOT STARTED|PARTIAL|IN PROGRESS)\]' "$plan_path" \
    | head -1 \
    | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?):.*/\1/')
fi
```
This is a strict "first matching heading, position order" scan. `PARTIAL` and `NOT STARTED` are
in the same alternation with no priority between them — if phase 2 is `NOT STARTED` and phase 3
is `PARTIAL` (e.g. because an earlier dispatch jumped ahead or was reordered), the scan picks
phase 2 first, opening a new phase before the already-open phase 3 is closed. This is the exact
mechanism by which hard mode "explicitly PERMITS returning to a previously-opened PARTIAL phase
later" rather than prioritizing it.

### 3. Scope item D — `context/contracts/` referrer census and injection-point finding

**(i) Every referrer of `context/contracts/` across the whole source store.**

A repo-wide `grep -rl "context/contracts/"` across `agent-system/` returns 29 files. Classified:

| Category | Count | Examples |
|---|---|---|
| `*-hard` agent/skill files (the actual load sites via explicit `@`-reference) | ~17 | `agents/general-implementation-hard-agent.md`, `skills/skill-implementer-hard/SKILL.md`, `skills/skill-planner-hard/SKILL.md`, `skills/skill-researcher-hard/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, `agents/planner-hard-agent.md`, `agents/general-research-hard-agent.md`, cslib/lean `*-hard` equivalents |
| `context/contracts/*.md` files themselves (self/sibling cross-references) | 4 | `context/contracts/{anti-analysis,adversarial-verification,reference-grounding,recovery}.md` |
| Scripts (lint/validation tooling, not runtime agent context) | 3 | `scripts/validate-handoff.sh`, `scripts/check-extension-docs.sh`, `scripts/lint/lint-contract-compliance.sh` |
| Mode-neutral standard/rule files citing a contract **by filename in prose only** | 4 | `rules/error-handling.md` (cites `recovery.md` for the fix-forward ladder), `context/standards/status-markers.md` (cites `anti-analysis.md`'s strategic-sorry family), `context/formats/plan-format.md` (cites `reference-grounding.md`'s Tier 1/2/3 numbering), `extensions/memory/skills/skill-memory/SKILL.md` (cites `convergence.md`'s three-strikes precedent) |
| Docs | 1 | `extensions/lean/EXTENSION.md` |

Critically, **the "mode-neutral" row is prose citation only — not a load path.** These four files
mention a `context/contracts/*.md` path by name as a conceptual cross-reference; none of them
`@`-import or programmatically load the cited file, and reading the citing file does not cause
the cited contract to enter the agent's context.

The load-bearing check is the `index-entries.json` `load_when` registration, queried
exhaustively across **every** `index-entries.json` in the source store (core + all 15
extensions):

```
core:  contracts/adversarial-verification.md | agents=[general-research-hard-agent, cslib-research-hard-agent, lean-research-hard-agent]
core:  contracts/anti-analysis.md            | agents=[general-implementation-hard-agent, general-research-hard-agent]
core:  contracts/convergence.md              | agents=[]   (orphaned — never adaptively loaded)
core:  contracts/orchestrator-discipline.md  | agents=[]   (orphaned — never adaptively loaded)
core:  contracts/recovery.md                 | agents=[general-implementation-hard-agent]
core:  contracts/reference-grounding.md      | agents=[general-research-hard-agent, planner-hard-agent]
core:  contracts/territory.md                | agents=[general-implementation-hard-agent]
core:  contracts/wrap-up.md                  | agents=[general-implementation-hard-agent]
lean:  contracts/reference-grounding.md      | agents=[lean-research-hard-agent, lean-implementation-hard-agent]
lean:  contracts/anti-analysis.md            | agents=[lean-research-hard-agent, lean-implementation-hard-agent]
lean:  contracts/adversarial-verification.md | agents=[lean-research-hard-agent]
lean:  contracts/context-hygiene.md          | agents=[lean-research-hard-agent, lean-implementation-hard-agent, cslib-research-hard-agent, cslib-implementation-hard-agent]
```
Every non-extension `index-entries.json` (python, web, cslib, founder, latex, formal, literature,
filetypes, typst, memory, epidemiology, email, z3, nvim, slidev, present, nix) has **zero**
`contracts/` entries at all.

**Conclusion: the hard-mode-only claim is confirmed exhaustively and without exception** for the
adaptive-query load path. Of 12 total `contracts/*.md` index registrations across the entire
source store, 100% list only `*-hard` agent names (or are empty). This is not a sampling
artifact — it is a complete census.

**(ii) Does a central injection point exist that extension implementers already inherit?**

No. Investigated three candidate hooks, all negative:

1. **The adaptive `context-discovery.md` query itself.** Only
   `agents/general-implementation-agent.md` (core, standard) carries the instruction
   `@.claude/context/patterns/context-discovery.md — Use with agent=general-implementation-agent,
   command=/implement` that tells the agent to run the jq adaptive query at runtime. A grep for
   `context-discovery|index.json|load_when|jq -r.*entries` across all 11 extension
   `*-implementation-agent.md` files (cslib, pr-review, email, latex, lean, nix, nvim, python,
   typst, web, z3) returns **zero** hits in every one. `general-implementation-hard-agent.md`
   also has zero hits for this pattern — hard mode never runs the adaptive query either; its
   loading is 100% explicit `@`-references and inline prose citations (e.g. `context/standards/
   status-markers.md` is cited twice in `general-implementation-hard-agent.md` by prose, not by a
   `Context References` bullet). So even a `commands: ["/implement"]`-scoped index entry — which
   *would* reach every dispatch of `/implement` in principle — is inert for every implementer
   except core's standard agent, because nothing else evaluates that index.

2. **`scripts/skill-base.sh`'s `skill_context_injection` lifecycle stage.** This hook exists but
   runs in the opposite direction from what would be needed: it calls
   `skill_run_extension_hook "context_injection" ...`, a **per-task-type extension hook** that
   lets *extensions* inject their own domain content (e.g. memory's `memory-context` block,
   literature's `<literature-briefing>` block) into the *core* skill's dispatch prompt. It is not
   a mechanism for core to broadcast a fixed behavioral contract outward into every extension
   implementer's context. There is no reverse "core injects into all extensions" lifecycle stage.

3. **A shared prompt-context builder script.** Searched for
   `*prompt*builder*|*build-dispatch*|*prompt-context*|*dispatch-prompt*` across the whole source
   store: zero files found. Each `skill-*/SKILL.md` (core and every extension) constructs its own
   Agent-tool dispatch prompt inline, by hand, in its own Stage 5 — there is no shared prompt
   template or builder function any implementer calls into.

**Existing precedent confirms propagation is genuinely manual, not free.**
`cslib/agents/cslib-implementation-hard-agent.md` (an extension hard-mode agent that already
needs core's H2/H7/H9 contracts) lists, as individually hand-copied bullets in its own "Context
References" section:
```
- `@.claude/context/contracts/anti-analysis.md` - H2 anti-analysis contract (MANDATORY)
- `@.claude/extensions/lean/context/contracts/context-hygiene.md` - ... (MANDATORY)
- `@.claude/context/contracts/wrap-up.md` - H9 wrap-up and handoff contract (MANDATORY)
- `@.claude/context/contracts/territory.md` - H7 territory contract (when territory params present)
```
This is the exact same three-contract set core's own `general-implementation-hard-agent.md`
lists, copied by hand into a sibling extension file. It is direct, in-repo evidence that when
this system previously needed a core contract to reach an extension implementer, the only
mechanism used was manual per-file `@`-reference — confirming that the downstream task of
propagating a new phase-closure/pre-edit-gate contract to the 13 extension implementers is real
work, with no shortcut this research could locate. **This finding should be stated unambiguously
in the plan phase: the downstream propagation task is NOT closable as "already free" — it
requires touching each extension implementer file, following the `cslib-implementation-hard-
agent.md` precedent as the template.**

### 4. Composition with the two shipped partners (must read before drafting Scope B)

Both partners are live in `context/formats/plan-format.md` and
`context/standards/status-markers.md`. Key details for compatibility:

- **`plan-format.md` line 197-200 (Counts-are-hypotheses obligation)**, verbatim: "Any count,
  file list, or scope estimate asserted in a plan is a hypothesis requiring implementation-time
  confirmation, never a fact. When a phase asserts one, it carries a **Scope Hypothesis:** line
  stating the hypothesis and how to confirm it at implementation time. **The implementation-side
  gate that consumes this obligation (i.e., that mechanically checks a confirmation happened) is
  a separate, out-of-scope concern for this document** — this section defines the planner-side
  carrier field only." This is an explicit, named gap this task's pre-edit gate is meant to
  close. The new contract should reference `**Scope Hypothesis:**` by name and state plainly that
  it is the consumer plan-format.md deferred.
- **Verification Tier vocabulary** (`prose < local < interface < full`, plan-format.md lines
  149-175) and **Commit Mode** (`per-substep`/`atomic-batch`, line 84) are orthogonal axes — the
  pre-edit gate is a third, separate axis (per-item evidence before an edit lands) and must not
  be folded into either; the contract should say so explicitly to avoid a future reader treating
  them as the same knob.
- **`[COMPLETED WITH EXCLUSIONS]`** (`status-markers.md` lines 160-200): a phase-heading-only
  marker, admission-tested on five conditions (decision not abandonment; tightly scoped;
  documented reason; evidenced; no residual work). Character-class constraint: the marker text
  must match `[A-Z][A-Z ]*` (uppercase + spaces only — no dash/digit/parenthesis) because
  `scripts/update-task-status.sh`'s `count_plan_phases()` TOTAL regex depends on it.
- **`#### Reasoned Exclusions` record** (`plan-format.md` lines 254-275), verbatim table:
  ```
  #### Reasoned Exclusions

  | Item | Reason | Evidence |
  |------|--------|----------|
  | {the excluded item} | {why it is not applicable} | {what confirms the reason -- command output, quoted match count, diff excerpt, or artifact reference} |
  ```
  `follow_up_task` is deliberately absent — an exclusion is closed by evidence, not tracked
  forward, distinguishing it from a strategic sorry. The new pre-edit gate should route a
  failed-probe item directly into this exact table/column set (`Item | Reason | Evidence`) rather
  than inventing a parallel schema.

### 5. Scope C — wave-table non-contradiction

Confirmed verbatim in `context/formats/plan-format.md` (two occurrences, lines 146 and 353):
`Phases within the same wave can execute in parallel.` `context/contracts/territory.md` opens by
stating it "governs file ownership and commit coordination **when multiple agents are dispatched
simultaneously** to work on different phases of the same plan" — i.e., cross-agent orchestrator
dispatch, a different axis from a single dispatch's own phase-opening order. The new contract
must state its scope explicitly as "a single dispatch's own phase-opening sequencing" to avoid
being read as contradicting the wave table or territory.md.

## Decisions

- **Placement recommendation**: `context/contracts/phase-closure.md`, matching the genre
  (mandatory behavioral contract, same family as anti-analysis/recovery/wrap-up/territory) and
  naming convention of its siblings. Directory choice is not itself load-bearing in this
  codebase (see Finding D-ii) — what matters is the wiring below.
- **Wiring**: add an explicit `@.claude/context/contracts/phase-closure.md` bullet to the
  "Context References" section of BOTH `agents/general-implementation-agent.md` (standard) and
  `agents/general-implementation-hard-agent.md` (hard) — this is the actual load-bearing act,
  independent of directory or index registration, matching how hard-mode agents already load
  anti-analysis.md/recovery.md/etc. For `skills/skill-implementer/SKILL.md` and
  `skills/skill-implementer-hard/SKILL.md`, add a documentation-only "Path:" bullet to their own
  Context References sections (per Scope A's instruction) — these skills do not load context
  themselves ("Context is loaded by the delegated agent," `skill-implementer/SKILL.md` line 25),
  so the bullet there is discoverability, not the load path.
- **Recommend (not required for correctness) an `index-entries.json` entry** for
  `contracts/phase-closure.md` with `load_when.agents: ["general-implementation-agent",
  "general-implementation-hard-agent"]` — the first non-hard-exclusive `contracts/` entry in the
  system. This keeps Stage-4.5-style Context Gap Detection accurate and documents the break from
  precedent explicitly (a one-line comment/decision note in the plan should flag this as an
  intentional exception), but is supplementary since the explicit `@`-reference above is what
  actually causes loading in this codebase.
- **Pre-edit gate (Scope B) must explicitly name and consume `**Scope Hypothesis:**`** from
  plan-format.md as the trigger condition (a phase with a Scope Hypothesis line implies its
  items require per-item confirmation before edit), and must route failed items into the
  existing `#### Reasoned Exclusions` `Item | Reason | Evidence` table verbatim, using the phase
  marker `[COMPLETED WITH EXCLUSIONS]` when all five admission-test conditions in
  status-markers.md hold. Do not invent a fourth verification-tier-like axis or a competing
  record format.

## Risks & Mitigations

- **Risk**: placing the new contract in `context/contracts/` without the explicit `@`-reference
  wiring would silently reproduce the exact defect this task fixes (the file would be
  "written" but invisible to standard-mode dispatches). **Mitigation**: Scope A's four explicit
  reference targets are non-negotiable; the plan phase should treat "add explicit `@`-reference
  bullet" as a literal, checkable phase step in both agent files, not "reference from" in the
  loose/aspirational sense.
- **Risk**: a future contributor reads `context/contracts/` and assumes (per the now-broken
  100%-hard-mode precedent) that anything placed there is automatically hard-mode-only and skips
  wiring it into standard mode. **Mitigation**: the new contract's own header should state
  plainly that it is loaded via explicit reference in both modes, not via directory convention.
- **Risk**: the downstream "propagate to 13 extension implementers" task gets closed as
  unnecessary based on a mistaken belief that some central hook covers it. **Mitigation**: this
  report's Finding D-ii is unambiguous — no such hook exists; state this finding directly in the
  plan artifact so the downstream task's scoping decision is evidence-backed either way (do it
  by hand, following the `cslib-implementation-hard-agent.md` precedent, or explicitly decide not
  to and say why).

## Context Extension Recommendations

- **Topic**: `context/contracts/` directory semantics are undocumented as hard-mode-exclusive
  anywhere in the architecture docs (checked `context/architecture/context-layers.md` and
  `docs/architecture/handoff-schema.md` — no such claim exists to correct). **Gap**: there is no
  single place that states "everything in `context/contracts/` is currently hard-mode-only by
  convention, verify before assuming inheritance." **Recommendation**: either add a short note to
  `context/architecture/context-layers.md`'s existing "Where to store new content" decision tree,
  or let the new phase-closure contract's own header serve as the first documented counter-
  example and pointer.

## Appendix

Search queries used (representative):
```bash
grep -rniE "depth-first|depth first|breadth-first|breadth first|one phase at a time" agent-system/
grep -n -i "sequential\|execute phases\|one phase" agent-system/extensions/core/skills/skill-implementer/SKILL.md
grep -n -i "phase\b" agent-system/extensions/core/agents/general-implementation-agent.md
grep -rln "context/contracts/" agent-system/ --include="*.md" --include="*.sh" --include="*.json"
find agent-system -name "index-entries.json" | while read f; do
  jq -r '.entries[]? | select(.path|test("contracts/")) | "\(.path) | agents=\(.load_when.agents)"' "$f"
done
for f in $(find agent-system -iname "*-implementation-agent.md"); do
  grep -n "context-discovery\|index.json\|load_when" "$f"
done
grep -n "Counts-are-hypotheses\|Scope Hypothesis\|Reasoned Exclusions\|COMPLETED WITH EXCLUSIONS" \
  agent-system/extensions/core/context/formats/plan-format.md \
  agent-system/extensions/core/context/standards/status-markers.md
```

References:
- `agent-system/extensions/core/skills/skill-implementer/SKILL.md`
- `agent-system/extensions/core/skills/skill-implementer-hard/SKILL.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- `agent-system/extensions/core/context/formats/plan-format.md`
- `agent-system/extensions/core/context/standards/status-markers.md`
- `agent-system/extensions/core/context/contracts/territory.md`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/index-entries.json`
- `agent-system/extensions/lean/index-entries.json`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- `agent-system/extensions/core/context/patterns/context-discovery.md`

# Research Report: Consolidate Routing to a Single Router

**Task**: 981 - consolidate_routing_to_single_router
**Started**: 2026-08-05
**Completed**: 2026-08-05
**Effort**: Medium-large (5 independent implementations, cross-cutting)
**Dependencies**: None
**Sources/Inputs**: Codebase read (`agent-system/extensions/**`), no web search needed
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- All five defects named in the review are confirmed live in the source store
  (`agent-system/extensions/**`), with exact line numbers below.
- A **sixth, undocumented bug** was found: `implement.md` — held up by the review as the one
  command that calls `command-route-skill.sh` correctly — omits the 4th positional argument
  (`effort_flag`) at its call site. `/implement N --hard` therefore never resolves
  `skill-implementer-hard` via the manifest `routing_hard` mechanism today. Any fix that makes
  `research.md`/`plan.md` "call `command-route-skill.sh` exactly as `implement.md` does" must
  first fix `implement.md`'s own call, or it will faithfully propagate the same defect to two
  more commands.
- The manifest data needed to fix agent-name derivation and directory-probing already exists on
  disk and requires no schema invention: every manifest carries a top-level `.task_type` string
  and a `.provides.agents` array of real, on-disk agent filenames — `epi-research-agent.md`,
  `filetypes-router-agent.md`, etc. The bug is that today's code *derives* agent names by string
  surgery (`sed 's/^skill-//' + '-agent'`) instead of reading `.provides.agents`, and *guesses*
  extension directories by assuming `directory == task_type` instead of scanning `.task_type`
  fields.
- `routing_exempt: true` is set on three manifests, not one: `core`, `literature`, `slidev`. The
  loop that identifies "the core manifest" breaks on the first glob hit; it resolves to `core`
  only because `core` sorts alphabetically before `literature` and `slidev`, not because of any
  uniqueness guarantee.
- `skill-orchestrate-hard`'s manifest loop has no `break` — it visits every manifest in glob
  order (core is included, un-excluded) and keeps overwriting `RESEARCH_AGENT`/`IMPLEMENT_AGENT`
  on every hit, so the **last** manifest (alphabetically) that declares a `routing_hard` entry
  for a given `task_type` wins. `command-route-skill.sh` is documented and implemented as
  first-match, non-core-before-core. These are genuinely opposite precedence rules, exactly as
  `context/guides/hard-mode-routing.md` already documents and disclaims.
- `skill-orchestrator` (vestigial 6th table) is byte-identical to its own `.archived` twin and has
  exactly one live consumer: `agent-system/extensions/epidemiology/commands/epi.md`, at two call
  sites. Its own routing table only lists `general|meta|markdown` — it does not actually implement
  extension-manifest routing in its Execution Flow despite epi.md relying on it to route `epi`-typed
  tasks. Two guides (`copy-claude-directory.md`, `adding-domains.md`) still instruct new-extension
  authors to edit it.

## Context & Scope

The task asks to collapse five independent routing implementations into one, per the review at
`specs/reviews/review-2026-07-29-agent-system.md`. This report verifies each named defect against
the current source store, quantifies it with real manifest data, and surfaces one additional
defect the review did not name. It does not produce the consolidated implementation — that is
the planner's job — but it identifies exactly what data is already available to build it and what
new data (an explicit agent-routing table, or a convention for reading `provides.agents`) will
need to be added to manifests.

All five extant implementations live under `agent-system/extensions/core/`:

| # | File | Role |
|---|------|------|
| 1 | `scripts/command-route-skill.sh` | Canonical router (skill-level), called by `implement.md` only |
| 2 | `commands/research.md` (Stage 2) | Inline hand-copy of routing Steps 1-3, no hard ladder |
| 3 | `commands/plan.md` (Stage 2) | Inline hand-copy of routing Steps 1-3, no hard ladder |
| 4 | `skills/skill-orchestrate/SKILL.md` (Stage 1b) | Agent-level router for `/orchestrate`, directory-name-guessing probe |
| 5 | `skills/skill-orchestrate-hard/SKILL.md` (Stage 1b) | Agent-level router for `/orchestrate --hard`, last-match-wins, no core exclusion |
| — | `skills/skill-orchestrator/SKILL.md` (+ `.archived` twin) | Vestigial 6th table, one live consumer (`epi.md`) |

## Findings

### Defect 1 — `research.md` / `plan.md` never call `command-route-skill.sh`

Confirmed. `agent-system/extensions/core/commands/research.md` lines 467-506 (STAGE 2) and
`agent-system/extensions/core/commands/plan.md` lines 467-506 (STAGE 2) each hand-roll their own
Step-1/Step-2/Step-3 manifest loop (`for manifest in .claude/extensions/*/manifest.json; do ...
.routing.research[$tt] ... done`), byte-for-byte parallel to `command-route-skill.sh`'s Steps
1-3, but with **no Step 4 hard-mode block at all**. `effort_flag`/`--hard` is parsed at Stage 1.5
in both files and passed to the *skill* as a prompt-context string (`effort_flag={effort_flag}`),
but never consulted for *skill selection*. Consequently `/research N --hard` and `/plan N --hard`
always resolve `skill-researcher`/`skill-planner` (or the extension's plain skill), never
`skill-researcher-hard`/`skill-planner-hard`, regardless of any `routing_hard` manifest entry.

`implement.md` line 263 is the sole call site of `command-route-skill.sh` in any command file:

```bash
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"
```

**This call is itself broken** — it passes only 3 arguments. `command-route-skill.sh`'s 4th
parameter is `effort_flag` (`"$4"`, documented in its own header as `"hard" | "fast" | "" |
unset`), and Step 4 of the script is gated on `[ "$_effort_flag" = "hard" ]`. Since `implement.md`
never passes `$EFFORT_FLAG` (exported at STAGE 0 by `parse-command-args.sh`, confirmed present:
`EFFORT_FLAG — "fast", "hard", or ""`), `_effort_flag` is always empty inside the sourced script,
Step 4 never runs, and `SKILL_NAME` never becomes `skill-implementer-hard` via the manifest
mechanism. Grepping the whole command/skill tree found no other invocation of
`skill-implementer-hard`, `skill-researcher-hard`, or `skill-planner-hard` outside
`lint-contract-compliance.sh`'s static mapping table — i.e. there is currently **no live path** by
which `/implement N --hard` reaches the hard-mode implementer skill through this mechanism either.
The fix for this task must correct `implement.md`'s call site (add `"$EFFORT_FLAG"` as the 4th
arg) in addition to wiring `research.md`/`plan.md` to call the script — otherwise "call it exactly
as implement.md does" reproduces a non-functional pattern in two more places.

### Defect 2 — `skill-orchestrate` / `skill-orchestrate-hard`: opposite precedence, sed-derived agent names

Confirmed both sub-claims.

**Opposite precedence** (`context/guides/hard-mode-routing.md` already documents and accepts this
as a known, intentional divergence — see "First-Match vs Last-Match Precedence" in that file):
- `command-route-skill.sh` Step 4a-4e: first-match-wins, non-core manifests scanned before the
  core manifest (identified by `routing_exempt: true`), with an explicit `break` on hit.
- `skill-orchestrate-hard/SKILL.md` lines 175-187: iterates `.claude/extensions/*/manifest.json`
  (core included, not excluded) with **no `break`**, unconditionally overwriting
  `RESEARCH_AGENT`/`IMPLEMENT_AGENT` on every subsequent hit. Given bash glob's alphabetical
  ordering, whichever manifest sorts *last* among those declaring a `routing_hard` entry for the
  task_type wins — the opposite of "first match, non-core before core."
- `skill-orchestrate/SKILL.md` (base, non-hard) has yet a *third* shape: a hardcoded `case`
  statement for `lean4|lean`/`neovim`/`nix` (default `*` → general agents), then a *single*
  extension-manifest lookup gated on `[ -f ".claude/extensions/${TASK_TYPE}/manifest.json" ]` — no
  loop over all manifests at all (see Defect 3).

**Sed-derived agent names produce non-existent agents.** Both `skill-orchestrate` (line 104, 107)
and `skill-orchestrate-hard` (lines 181, 184) derive the agent name from the routed skill name via
`sed 's/^skill-//' | sed 's/$/-agent/'`. Verified against real manifests:

| `task_type` | Manifest `routing.*` value | sed-derived agent | Real agent | Exists? |
|---|---|---|---|---|
| `email` (research) | `skill-researcher` | `researcher-agent` | `general-research-agent` | sed result does not exist |
| `memory` (research + implement) | `skill-learn` | `learn-agent` | *(none — `skill-learn` is direct-execution, no agent)* | sed result does not exist |
| `filetypes` (research + implement) | `skill-filetypes` | `filetypes-agent` | `filetypes-router-agent` | sed result does not exist |
| `present:slides` (implement) | `skill-slides:assemble` | `slides:assemble-agent` (contains a stray `:`) | *(no single agent — multi-stage skill)* | sed result is not even a valid identifier |
| `epi` / `epi:study` / `epidemiology` (research) | `skill-epi-research` | `epi-research-agent` | `epi-research-agent` | **matches**, but see Defect 3 — the manifest lookup that would produce this never fires |

So sed-derivation is wrong for at least 3 of the 5 spot-checked task types, and even where it
would *coincidentally* match (`epi`), the surrounding directory-probe bug (Defect 3) prevents that
manifest from ever being consulted for `skill-orchestrate` (base mode).

Every manifest already exposes exactly the data needed instead: `provides.agents` (an array of
real, on-disk agent filenames, e.g. `epidemiology/manifest.json`: `["epi-research-agent.md",
"epi-implement-agent.md"]`). No sed derivation is required if routing is changed to declare
agent names explicitly (a new `routing_agents` block, mirroring `routing`/`routing_hard`'s
`{op: {task_type: value}}` shape) or to cross-reference `routing.{op}[$tt]`'s skill name against
`provides.agents` by convention. `memory`'s `provides.agents` is `null` — confirming the task
description's point that `/orchestrate` on a memory task has no agent to dispatch to at all, and
this must be handled by explicit declaration (e.g. routing memory's `implement` op to
`general-implementation-agent` deliberately) rather than by an accidental sed string.

### Defect 3 — extension directory probe assumes `directory == task_type`

Confirmed, and confirmed asymmetric: this bug exists only in `skill-orchestrate` (base), not in
`skill-orchestrate-hard` (which instead globs all manifests — see Defect 2's precedence finding).

`skill-orchestrate/SKILL.md` lines 96-109:
```bash
manifest=".claude/extensions/${TASK_TYPE}/manifest.json"
if [ -f "$manifest" ]; then
  ext_research=$(jq -r ".routing.research[\"$TASK_TYPE\"] // empty" "$manifest")
  ...
```

Verified real extension directory names vs. their declared `task_type`:

| `task_type` value(s) declared in manifest routing | Actual extension directory | `directory == task_type`? |
|---|---|---|
| `neovim` | `nvim` | No — masked by the hardcoded `case "$TASK_TYPE" in neovim) ...` arm above it |
| `lean4` | `lean` | No — masked by the hardcoded `case ... lean4\|lean) ...` arm |
| `epi`, `epi:study`, `epidemiology` | `epidemiology` | **No, and NOT masked** — `epi` (the keyword most likely to be used; `epidemiology` extension's `keyword_overrides` presumably includes it) has no `case` arm and no directory named `.claude/extensions/epi/`, so the probe fails silently and falls through to the `*)` default (`general-research-agent`/`general-implementation-agent`) |
| `filetypes` | `filetypes` | Yes (coincidence) |
| `email`, `memory`, `present*`, `nix`, `python`, `latex`, `typst`, `web`, `z3`, `founder*` | matches their own directory 1:1 | Yes (all currently 1:1 by naming coincidence) |

Every manifest already carries the correct, authoritative mapping as its own top-level
`.task_type` field (a single string) plus its `.routing.{op}` keys (which may list *several*
aliases pointing at the same extension — e.g. epidemiology's routing keys are `epi`, `epi:study`,
*and* `epidemiology`, all resolving to the one `agent-system/extensions/epidemiology/` directory,
even though the manifest's singular `.task_type` field is just `"epi"`). A directory-resolution
fix should scan `.claude/extensions/*/manifest.json` for the manifest whose `.routing.{research,
plan, implement}` keys (exact or compound-base match) contain the given `task_type` — the exact
same data source `command-route-skill.sh`'s Step 1/1b already reads — rather than either the
single `.task_type` field alone (which would miss the `epidemiology` alias) or directory-name
guessing.

### Defect 4 — `routing_exempt: true` is not unique to core

Confirmed: three manifests set `routing_exempt: true`.

```
core         | name=core        | routing_exempt=true
literature   | name=literature  | routing_exempt=true
slidev       | name=slidev      | routing_exempt=true
```

`command-route-skill.sh`'s Step 4c core-identification loop (lines 123-142) does:
```bash
for _manifest in .claude/extensions/*/manifest.json; do
  ...
  if [ "$_is_core" = "true" ]; then
    _core_manifest="$_manifest"
    break
  fi
done
```
This resolves to `core` today purely because glob output is alphabetically sorted and `core` sorts
before `literature` and `slidev`. Every manifest already has a `.name` field that is unique and
matches the manifest's own self-declared identity (`"name": "core"`, `"name": "literature"`,
`"name": "slidev"`) — `.name == "core"` is a direct, unambiguous replacement. `routing_exempt`
should be kept (per the task's own instruction) for whatever exemption semantics it independently
serves (it is presumably used elsewhere to mean "don't apply routing precedence rules to this
extension's own entries," which is a legitimately different concern from "which manifest IS core")
— grep confirms `routing_exempt` is read only by the two `command-route-skill.sh`/
`skill-orchestrate-hard` core-identification loops in the files already covered above; no other
consumer was found, so re-purposing/narrowing it should be safe but should be grep-verified again
immediately before the edit lands (extension manifests could be added between now and
implementation).

### Defect 5 — `skill-orchestrator` is vestigial but still load-bearing for one caller

Confirmed. `diff` between `skill-orchestrator/SKILL.md` and its own `.archived` twin returns no
differences (byte-identical, 128 lines each). Its "Task-Type-Based Routing" table (lines 42-48)
only lists `general`/`meta`/`markdown`, with a one-line disclaimer that "additional languages ...
are available via extensions" — but its Execution Flow section (lines 79-90) is prose-only
("4. Determine target skill by task_type") with no code showing how, in practice, that includes
extension-manifest consultation the way `command-route-skill.sh` or the inline command copies do.

One live consumer: `agent-system/extensions/epidemiology/commands/epi.md`, two references:
- Line 249 (prose): "validate task_type starts with 'epi', then delegate to research via
  skill-orchestrator."
- Lines 358-366 (the actual dispatch): `skill: "skill-orchestrator"`, `args: "command=research
  task_number={N} session_id={session_id}"`.

Two guides still instruct developers to edit it when adding a new domain:
- `docs/guides/copy-claude-directory.md` lines 134, 142, 252 ("Update routing in
  `skill-orchestrator/SKILL.md`", "Add entry to routing table in `skill-orchestrator/SKILL.md`",
  "Verify `skill-orchestrator/SKILL.md` has correct routing for your language.")
- `docs/guides/adding-domains.md` lines 199, 363-368 (an ASCII architecture diagram showing
  `Orchestrator (skill-orchestrator)` as the routing entry point, plus a "Step 5: Update Routing
  / #### Update skill-orchestrator" section with an edit example).

A third, non-actionable reference was also found: `context/patterns/context-protective-lead.md`
line 250 lists `skill-orchestrator` in a historical postflight-compliance audit table
("Compliant | 0 | Refactored"). This is a point-in-time audit record, not a functional dependency
or a routing instruction — it does not need to change for this task's correctness bar, though the
planner may choose to annotate it as referring to a since-retired skill.

**Fix shape for the one live consumer**: `epi.md` already knows, at both call sites, that it is
requesting a `research` op for a task whose `task_type` starts with `epi`. Once `research.md`
itself is fixed to call `command-route-skill.sh` (Defect 1's fix), the cleanest replacement is for
`epi.md` to either (a) delegate through the now-fixed `/research` command path directly, or (b)
call `command-route-skill.sh "research" "$task_type" "skill-researcher"` itself and invoke the
resolved skill — mirroring the pattern `implement.md` already uses — rather than depending on
`skill-orchestrator`'s stub routing table, which does not actually contain an `epi` entry today.

## Decisions

- The consolidation should treat **agent-name resolution** as a new, explicit data need on
  manifests (either a `routing_agents` block paralleling `routing`/`routing_hard`, or a documented
  convention for cross-referencing `routing.{op}[$tt]`'s skill name against `provides.agents`) —
  not as a derivable string transform. `provides.agents` already lists the real filenames; no
  extension needs to invent new data, only a new (or corrected) consumer.
- Extension-directory resolution for `/orchestrate` should scan manifests' `.routing.{op}` keys
  (the same source `command-route-skill.sh` already reads), not the singular `.task_type` field
  alone and not directory-name guessing — the `epidemiology` extension's multiple aliases (`epi`,
  `epi:study`, `epidemiology`) demonstrate why the singular field is insufficient by itself.
- Core-manifest identification should key on `.name == "core"`, with `routing_exempt` retained
  only for its (separately-scoped) exemption semantics, per the task's own instruction. A grep for
  other `routing_exempt` consumers should be re-run immediately before this edit lands.
- `implement.md`'s existing `command-route-skill.sh` call site must be corrected (missing 4th
  `effort_flag` argument) as part of this task's scope — it is the "reference" call site the task
  description explicitly asks `research.md`/`plan.md` to mirror, and mirroring it as-is would ship
  three broken call sites instead of two.
- `skill-orchestrator`'s retirement should route its one consumer (`epi.md`) onto the same fixed
  mechanism `research.md` uses post-fix, not onto a bespoke third mechanism.

## Risks & Mitigations

- **Risk**: Changing `routing_exempt`'s core-identification role could silently break some other,
  not-yet-found consumer. **Mitigation**: a fresh repo-wide grep for `routing_exempt` immediately
  before implementing Defect 4's fix (this report's grep found only the two loops already
  documented, but manifests/extensions can be added between research and implementation).
- **Risk**: `present:slides` (and any other multi-stage/compound skill name like
  `skill-slides:assemble`) may not resolve to a single agent under a `routing_agents`-style
  explicit table, since the skill itself performs internal sub-routing to different agents
  depending on document type. **Mitigation**: the wiring-validation check (verification bar item
  2) should treat such skills as an explicitly-declared exception (e.g. skip agent-existence
  checking for skills whose name contains `:`, or require the manifest to declare a
  representative/primary agent), not silently pass or silently fail on them.
- **Risk**: `memory`'s `provides.agents` is `null` (no agent — `skill-learn` is direct-execution).
  A routing_agents-based orchestrate fix must explicitly decide (and document) what `/orchestrate`
  does for a `memory`-typed task rather than defaulting through a broken derivation.
- **Risk**: The "wiring validation check" the verification bar calls for does not exist yet.
  `agent-system/extensions/core/scripts/verify-deploy.sh` already has a numbered gate sequence
  (gate0-gate6, with gate5 doing a comparable "declared-vs-deployed" comparison and gate3/gate4
  already following a "SKIP if not source-store" precedent for source-store-only checks). A new
  gate7 in that same file, or a new script under `scripts/lint/` in the pattern of
  `lint-agent-contracts.sh`, are the two established homes; either is consistent with existing
  conventions and either would give the planner a concrete slot rather than inventing new
  validation infrastructure from scratch.
- **Risk**: No existing test file covers routing resolution specifically — `scripts/tests/`
  has no `test-*routing*.sh` today (only `test-orchestrate-triage-classify.sh`, which covers a
  different concern). The "table-driven test" the verification bar calls for (identical routing
  decisions from both orchestrate engines for an identical (op, task_type) matrix) will be new
  test infrastructure, not an extension of an existing routing test.

## Context Extension Recommendations

- **Topic**: Manifest schema documentation for `provides.agents` and the relationship between a
  manifest's `.task_type` field (singular) and its `.routing.{op}` keys (which may list several
  aliases for the same extension, as epidemiology does).
- **Gap**: No context file currently documents this relationship or that `provides.agents` is
  meant to be the authoritative agent-name source (as opposed to a derivable convention). This
  research had to reconstruct it by reading `epidemiology/manifest.json`, `nvim/manifest.json`,
  and others directly.
- **Recommendation**: Once this task lands, add a short section to
  `context/guides/hard-mode-routing.md` (or a new `context/guides/manifest-routing-schema.md`)
  documenting the final `routing`/`routing_hard`/`routing_agents` triple and the directory-
  resolution-via-routing-keys convention, so a future extension author does not reintroduce
  directory-name guessing by copying an old pattern.

## Appendix

### Files read in full or in relevant part
- `agent-system/extensions/core/scripts/command-route-skill.sh`
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
- `agent-system/extensions/core/commands/research.md`
- `agent-system/extensions/core/commands/plan.md`
- `agent-system/extensions/core/commands/implement.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 1b, lines 1-190)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 1b, lines 140-194)
- `agent-system/extensions/core/skills/skill-orchestrator/SKILL.md` + `.archived` twin (full, 128 lines each)
- `agent-system/extensions/core/docs/guides/copy-claude-directory.md`, `adding-domains.md` (grep context)
- `agent-system/extensions/epidemiology/commands/epi.md` (grep context)
- `agent-system/extensions/core/manifest.json`, `cslib/manifest.json` (`routing_hard` full contents)
- `agent-system/extensions/{nvim,lean,filetypes,email,memory,present,epidemiology}/manifest.json`
  (`task_type`, `provides.agents`, `routing.*` full contents)
- `agent-system/extensions/core/scripts/parse-command-args.sh` (EFFORT_FLAG export, header only)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate numbering/structure, grep only)
- `agent-system/extensions/core/scripts/lint/` directory listing (existing lint script inventory)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (confirms `.orchestrator-
  handoff.json` is hard-mode-implement-only; this research agent correctly wrote only
  `.return-meta.json`, not a handoff file, per that contract and per this agent's own Stage 3.6
  scoping decision)

### Search commands used
```bash
find agent-system/extensions -iname "command-route-skill.sh" -o -iname "hard-mode-routing.md"
grep -n "sed\|s/^skill-\|-agent\"\|task_type ==\|case.*task_type\|routing\[" \
  agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
grep -rl "filetypes-router-agent" agent-system/
for d in agent-system/extensions/*/; do jq -r '.name, .routing_exempt' "$d/manifest.json"; done
for ext in nvim lean filetypes email memory present; do
  jq '{task_type, provides_agents: .provides.agents}' "agent-system/extensions/$ext/manifest.json"
done
grep -rln "skill-orchestrator" agent-system/ --include="*.md"
```

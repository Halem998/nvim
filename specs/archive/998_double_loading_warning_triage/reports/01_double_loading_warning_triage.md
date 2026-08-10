# Research Report: Task #998

**Task**: 998 - Triage the 49 Double-Loading Check entries; decide whether the check is a defect
detector or a shape it should stop flagging
**Started**: 2026-08-09
**Completed**: 2026-08-09
**Effort**: Medium (enumeration + criterion design; ~36 mechanical entry edits + one script rewrite)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/*/index-entries.json`,
`agent-system/extensions/core/scripts/validate-context-budgets.sh`,
`agent-system/extensions/core/context/index.schema.json`, skill/agent/manifest files), no web
research needed (purely structural/internal)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The 49 "double-loaded" entries split cleanly into two shapes: **36 are genuinely redundant**
  (their `commands[]` hook names a command that resolves to exactly one agent, and that agent is
  already present in the same entry's `agents[]`), and **13 are legitimately dual-addressed**
  (at least one command in `commands[]` is a direct-execution command with no dispatched agent at
  all, or a command whose route is broader than the entry's own `agents[]`).
- **Root fact enabling the fix**: `load_when.commands` and `load_when.agents` have **no live
  runtime consumer today** that concatenates both query results without dedup — every script that
  reads `load_when` is a validator/linter (`validate-context-budgets.sh`,
  `validate-index.sh`, `validate-wiring.sh`, `check-extension-docs.sh`,
  `lint-contract-compliance.sh`, `install-extension.sh`). The "double-loading" the check catches
  is therefore a **structural/documentation redundancy** in the index's own cross-referencing
  scheme (the same audience reachable two ways), not an observed live duplicate-token bug — this
  matters for scoping the fix conservatively (see Decisions).
- **Criterion** (full form in Findings): an entry with non-empty `agents[]` and non-empty
  `commands[]` is REDUNDANT iff every command in `commands[]` is *agent-routed* (resolves, per
  the core manifest's `routing_agents` table or a skill's sole unconditional `subagent_type:`
  line, to exactly one canonical non-hard agent) **and** that agent is already a member of the
  entry's own `agents[]`. Any command that is *direct* (no dispatched agent — `/review`,
  `/errors`, `/task`, `/todo`, `/refresh`, `/fix-it`, `/learn`, `/distill`, `/literature`,
  `/project-overview`, `/tag`, `/merge`, `/cite`) or is `/orchestrate` (whose effective route is
  the *union* of research+plan+implement agents, broader than any single entry's `agents[]`)
  makes the entry non-redundant by construction.
- **Recommended action**: narrow the 36 redundant entries by dropping their `commands[]` array
  (source: `agent-system/extensions/core/index-entries.json`, all 36 attribute to core); leave the
  13 legitimate entries untouched (source: 11 core, 2 `agent-system/extensions/memory/index-entries.json`).
  Re-key `validate-context-budgets.sh`'s Double-Loading Check to compute the SAME redundancy
  predicate mechanically (derived live from the deployed `.claude/extensions/core/manifest.json`
  and the three singleton skills' `subagent_type:` lines, never a hardcoded path allowlist), report
  it as a **violation** (contributing to exit code) instead of a warning, and report the remaining
  legitimately-dual entries as informational-only (exempt by construction, not by a frozen list).
- A secondary, out-of-scope finding worth flagging separately: several entries' `agents[]` arrays
  look under-populated relative to actual usage (e.g. `patterns/context-discovery.md` is described,
  in `general-research-agent.md`'s own hand-authored Context References list, as used with
  `agent=general-research-agent`, yet the index entry only hooks `meta-builder-agent`/`/meta`) and
  hard-mode agents (`general-research-hard-agent`, `planner-hard-agent`,
  `general-implementation-hard-agent`) have no `agents[]` hooks at all on any of the 36 redundant
  entries even though they plausibly need the same format/pattern files their non-hard
  counterparts use. Both are coverage gaps, not double-loading, and are out of this task's scope.

## Context & Scope

Task 998 asks to (1) enumerate the 49 entries the Double-Loading Check names, (2) produce a
written criterion separating "legitimately dual-addressed" from "over-broad hook", (3) act on the
classification (fix the over-broad entries, decide on an exemption mechanism for the legitimate
ones), and (4) re-key the check so it either reaches 0 or retains a *mechanically enforced*
exemption set. This report is the research/triage deliverable; it does not itself edit
`agent-system/extensions/**` (a subsequent plan/implement phase should do the mechanical edits
using the exact list and design below).

The check under triage lives in
`agent-system/extensions/core/scripts/validate-context-budgets.sh` (deployed copy:
`.claude/scripts/validate-context-budgets.sh`), section `--- Double-Loading Check ---`. It
currently flags any `.claude/context/index.json` entry whose `load_when.agents` and
`load_when.commands` are both non-empty, reports the count as a WARNING (not a violation, does not
affect exit code), and was deliberately downgraded to warning status by the meta-catch-all
decomposition work when the check was restated on `load_when` shape (previously it required the
now-defunct authored `tier` field to equal 3, which was unsatisfiable under the current
algorithmic tier derivation).

## Findings

### How `load_when.commands` and `load_when.agents` are actually consumed

Grepped every script under `agent-system/extensions/*/scripts/`,
`agent-system/extensions/*/skills/*/SKILL.md`, and `agent-system/extensions/*/commands/*.md` for
`load_when`. Only six scripts reference it, and every one is a validator, linter, or the
extension installer (`install-extension.sh`, `validate-wiring.sh`, `validate-index.sh`,
`validate-context-budgets.sh`, `check-extension-docs.sh`,
`scripts/tests/test-index-entries-schema.sh`, `scripts/lint/lint-contract-compliance.sh`). No
`SKILL.md` anywhere queries `load_when.commands` (or `.agents`) to build a subagent's actual
context at dispatch time. `context/patterns/context-discovery.md`'s documented jq query patterns
(including the "adaptive OR query" combining `agents`/`task_types`/`commands`/`always`) are a
**documentation/discovery aid**, not a wired runtime injector — confirmed by grepping every
`skill-researcher`, `skill-planner`, `skill-implementer` `SKILL.md` for `context-discovery` or
`index.json`: none call it. Each dispatchable agent's own `.md` file (e.g.
`agent-system/extensions/core/agents/general-research-agent.md`, this report's own author) instead
carries a small, hand-authored "## Context References" list of `@`-paths — and per
`.claude/rules/source-store-deploy-boundary.md`'s prior note, `@`-references inside an agent body
do **not** auto-resolve at subagent spawn; they are instructions the agent itself follows via
explicit `Read` calls.

**Consequence for scoping the fix**: because nothing today unions an agents-query result with a
commands-query result without dedup, "double-loading" is not an observed live bug (no token is
actually read twice by a real pipeline today). It is a structural redundancy in the index's own
cross-referencing metadata — the same audience (one agent, reached through one command) asserted
via two different `load_when` keys on the same entry. The check's own restated comment already
says as much ("restated on load_when shape alone, which is what 'double-loaded' always meant") and
this finding corroborates it. The fix criterion below targets exactly that structural redundancy;
it does not attempt to model a hypothetical future live-injection pipeline more precisely than the
check's own stated intent requires.

### Enumeration and per-entry attribution (49 total)

All 49 attribute cleanly to two source files — 47 to
`agent-system/extensions/core/index-entries.json`, 2 to
`agent-system/extensions/memory/index-entries.json` (`project/memory/domain/memory-reference.md`,
`project/memory/distill-usage.md`). No other extension's `index-entries.json` contributes an
entry to this set. (Verified by looking up each of the 49 merged-index paths against every
`agent-system/extensions/*/index-entries.json`'s own `.entries[].path`.)

### The classification criterion

For an entry `E` with `A = load_when.agents` and `C = load_when.commands`, both non-empty:

1. Classify each command `c ∈ C` as either **agent-routed** or **direct**:
   - **Agent-routed, single canonical (non-hard) agent** — derivable mechanically, never
     hardcoded twice:
     - `/research` → `routing_agents.research.{general,meta,markdown}` in
       `.claude/extensions/core/manifest.json` (today: `general-research-agent`, uniformly across
       all three core task types)
     - `/plan` → `routing_agents.plan.{general,meta,markdown}` (today: `planner-agent`)
     - `/implement` → `routing_agents.implement.{general,meta,markdown}` (today:
       `general-implementation-agent`)
     - `/meta` → the sole `subagent_type: "..."` line in `.claude/skills/skill-meta/SKILL.md`
       (today: `meta-builder-agent`)
     - `/spawn` → the sole `subagent_type:` line in `.claude/skills/skill-spawn/SKILL.md` (today:
       `spawn-agent`)
     - `/revise` → the sole `subagent_type:` line in `.claude/skills/skill-reviser/SKILL.md`
       (today: `reviser-agent`)
   - **Direct** (no dispatched agent at all — verified by grepping every `commands/*.md` and
     `skills/*/SKILL.md` for `subagent_type`/`Agent(` and finding none for these): `/review`,
     `/errors`, `/task`, `/todo`, `/refresh`, `/fix-it`, `/learn`, `/distill`, `/literature`,
     `/project-overview`, `/tag`, `/merge`, `/cite`. (`/review`'s skill has no `Agent`/
     `subagent_type` call anywhere — `code-reviewer-agent` exists but is currently dormant, matching
     CLAUDE.md's own note that it is "available for future skill integration", not presently wired.)
   - **`/orchestrate`** is treated as its own case: it is a direct-execution state-machine skill
     that, across a full task lifecycle, dispatches through the *same* per-task-type resolution as
     `/research`+`/plan`+`/implement` combined — its effective agent reach is the *union* of all
     three, never a single agent, and never `meta-builder-agent`/`spawn-agent`/`reviser-agent`
     (those three skills are not part of the orchestrate lifecycle). Because that union is
     necessarily broader than any single entry's `agents[]`, `/orchestrate` in `commands[]` never
     makes an entry redundant.

2. **Entry is REDUNDANT** (over-broad hook — narrow it) iff **every** `c ∈ C` is agent-routed
   *and* its resolved agent is already a member of `A`.
3. **Entry is LEGITIMATE / dual-addressed** (keep both hooks) iff **at least one** `c ∈ C` is
   direct or is `/orchestrate` — i.e. reaches a consumer (a direct-execution skill's own inline
   logic, or the broader orchestrate union) that `A` cannot already cover.

This is a total, decidable partition — every one of the 49 entries falls into exactly one bucket,
and the totals below sum to 49.

**Deliberate scoping note**: route(`c`) above uses the *non-hard* canonical agent only.
Hard-mode agents (`general-research-hard-agent`, `planner-hard-agent`,
`general-implementation-hard-agent`) are a documented, deliberately separate audience with their
own agent files; whether they also need hooks to the same format/pattern files these 36 entries
cover is a *coverage* question for the hard agents' own entries, not a *redundancy* question for
these entries. Folding hard-mode reachability into the redundancy test would flip nearly every
entry in the dataset to "non-redundant" (since no entry in the 49 lists a hard-mode agent in
`agents[]`) and defeat the check's purpose entirely — recorded here so a future editor does not
"fix" this by widening route(c) and silently neutering the check again.

### Classification results (36 redundant / 13 legitimate)

**REDUNDANT (36) — all in `agent-system/extensions/core/index-entries.json`. Fix: drop
`load_when.commands` (set to `[]`), keep `load_when.agents` unchanged.**

| Path | agents[] | commands[] (to remove) |
|---|---|---|
| architecture/component-checklist.md | meta-builder-agent | /meta |
| architecture/generation-guidelines.md | meta-builder-agent | /meta |
| formats/command-output.md | meta-builder-agent | /meta |
| formats/command-structure.md | meta-builder-agent | /meta |
| formats/frontmatter.md | meta-builder-agent | /meta |
| formats/plan-format.md | planner-agent | /plan |
| formats/progress-file.md | general-implementation-agent | /implement |
| formats/report-format.md | general-research-agent | /research |
| formats/summary-format.md | general-implementation-agent | /implement |
| formats/task-order-format.md | meta-builder-agent, spawn-agent | /meta, /spawn |
| guides/extension-development.md | meta-builder-agent | /meta |
| meta/context-revision-guide.md | meta-builder-agent | /meta |
| meta/domain-patterns.md | meta-builder-agent | /meta |
| meta/meta-guide.md | meta-builder-agent | /meta |
| patterns/checkpoint-execution.md | general-implementation-agent | /implement |
| patterns/context-discovery.md | meta-builder-agent | /meta |
| patterns/inline-status-update.md | general-implementation-agent | /implement |
| patterns/thin-wrapper-skill.md | meta-builder-agent | /meta |
| processes/implementation-workflow.md | general-implementation-agent | /implement |
| processes/planning-workflow.md | planner-agent | /plan |
| processes/research-workflow.md | general-research-agent | /research |
| schemas/frontmatter-schema.json | meta-builder-agent | /meta |
| schemas/subagent-frontmatter.yaml | meta-builder-agent | /meta |
| standards/testing.md | general-implementation-agent | /implement |
| standards/xml-structure.md | meta-builder-agent | /meta |
| templates/agent-template.md | meta-builder-agent | /meta |
| templates/command-template.md | meta-builder-agent | /meta |
| templates/orchestrator-template.md | meta-builder-agent | /meta |
| templates/subagent-template.md | meta-builder-agent | /meta |
| templates/thin-wrapper-skill.md | meta-builder-agent | /meta |
| workflows/task-breakdown.md | planner-agent, spawn-agent | /plan, /spawn |
| index.schema.json | meta-builder-agent | /meta |
| patterns/regeneration-is-manual-only.md | meta-builder-agent | /meta |
| guides/hard-mode-routing.md | meta-builder-agent | /meta |
| contracts/no-task-references-bullet.md | meta-builder-agent | /meta |
| guides/manifest-routing-schema.md | meta-builder-agent | /meta |

**LEGITIMATE / dual-addressed (13) — keep both hooks, exempt by construction (the mechanical
redundancy predicate below evaluates false for each, with no separate allowlist needed).**

| Path | agents[] | commands[] | Why non-redundant |
|---|---|---|---|
| patterns/jq-escaping-workarounds.md | meta-builder-agent, general-implementation-agent, general-implementation-hard-agent | /errors, /meta | `/errors` is direct (no agent) |
| standards/analysis-framework.md | code-reviewer-agent | /review | `/review` is direct — `code-reviewer-agent` is not actually dispatched by any skill today |
| standards/code-patterns.md | code-reviewer-agent | /review | same |
| standards/interactive-selection.md | meta-builder-agent | /meta, /fix-it, /review | `/fix-it`, `/review` are direct |
| standards/status-markers.md | planner-agent, general-implementation-agent | /task, /plan, /implement | `/task` is direct |
| templates/state-template.json | meta-builder-agent | /task | `/task` is direct |
| workflows/review-process.md | code-reviewer-agent | /review | `/review` is direct |
| project/memory/domain/memory-reference.md (memory ext.) | general-research-agent | /learn, /distill | both direct |
| project/memory/distill-usage.md (memory ext.) | general-research-agent | /distill | direct |
| patterns/context-protective-lead.md | meta-builder-agent | /meta, /orchestrate | `/orchestrate`'s union reach exceeds `A` |
| patterns/task-lock.md | general-implementation-agent | /research, /refresh, /plan, /implement, /orchestrate | `/research` routes to a different agent; `/refresh` is direct |
| patterns/topic-assignment-pattern.md | meta-builder-agent | /task, /review | both direct |
| standards/git-staging-scope.md | general-implementation-agent, general-implementation-hard-agent, neovim-implementation-agent, nix-implementation-agent | /orchestrate, /research, /errors, /implement, /plan | `/research` routes elsewhere; `/errors` is direct |

36 + 13 = 49, confirmed against the check's own reported count.

### Mechanical enforcement design for `validate-context-budgets.sh`

Replace the current "any dual-hook entry is a warning" section with a routing table derived live
from the *deployed* artifacts (never a second hardcoded copy of agent names), then apply the same
redundancy predicate as a **violation** check:

```bash
# Derive route(c) for the 6 agent-routed commands from deployed artifacts only.
MANIFEST_FILE="${REPO_ROOT}/.claude/extensions/core/manifest.json"
route_research=$(jq -r '[.routing_agents.research.general,.routing_agents.research.meta,.routing_agents.research.markdown] | unique | join(" ")' "$MANIFEST_FILE")
route_plan=$(jq -r '[.routing_agents.plan.general,.routing_agents.plan.meta,.routing_agents.plan.markdown] | unique | join(" ")' "$MANIFEST_FILE")
route_implement=$(jq -r '[.routing_agents.implement.general,.routing_agents.implement.meta,.routing_agents.implement.markdown] | unique | join(" ")' "$MANIFEST_FILE")
route_meta=$(grep -oP 'subagent_type:\s*"\K[^"]+' "${REPO_ROOT}/.claude/skills/skill-meta/SKILL.md" | head -1)
route_spawn=$(grep -oP 'subagent_type:\s*"\K[^"]+' "${REPO_ROOT}/.claude/skills/skill-spawn/SKILL.md" | head -1)
route_revise=$(grep -oP 'subagent_type:\s*"\K[^"]+' "${REPO_ROOT}/.claude/skills/skill-reviser/SKILL.md" | head -1)

ROUTE_JSON=$(jq -n --arg r "$route_research" --arg p "$route_plan" --arg i "$route_implement" \
  --arg m "$route_meta" --arg s "$route_spawn" --arg v "$route_revise" '
  {"/research":($r|split(" ")),"/plan":($p|split(" ")),"/implement":($i|split(" ")),
   "/meta":($m|split(" ")),"/spawn":($s|split(" ")),"/revise":($v|split(" "))}')

# REDUNDANT iff every commands[] entry is a key in ROUTE_JSON (agent-routed, not direct/
# /orchestrate) AND its route is fully contained in this entry's own agents[].
REDUNDANT='
  (.load_when.agents // []) as $A | (.load_when.commands // []) as $C |
  ($A|length) > 0 and ($C|length) > 0 and
  ($C | all(. as $c | ($route[$c] // null) as $r | $r != null and (($r - $A) | length) == 0))
'

double_loaded_redundant=$(jq --argjson route "$ROUTE_JSON" "[.entries[] | select($REDUNDANT)] | length" "$INDEX_FILE")
double_loaded_dual=$(jq --argjson route "$ROUTE_JSON" \
  "[.entries[] | select((((.load_when.agents//[])|length)>0) and (((.load_when.commands//[])|length)>0) and (($REDUNDANT)|not))] | length" "$INDEX_FILE")

echo "--- Double-Loading Check ---"
if [[ $double_loaded_redundant -eq 0 ]]; then
  echo "Redundant dual-hook entries: 0 -- OK"
else
  echo "Redundant dual-hook entries: $double_loaded_redundant"
  VIOLATIONS=$((VIOLATIONS + double_loaded_redundant))
  jq -r --argjson route "$ROUTE_JSON" ".entries[] | select($REDUNDANT) | \"  \(.path)\"" "$INDEX_FILE"
fi
if [[ $double_loaded_dual -gt 0 ]]; then
  echo "Legitimately dual-addressed entries (exempt -- commands[] not subsumed by agents[]): $double_loaded_dual"
fi
```

After the 36 entries are narrowed, `double_loaded_redundant` should read **0**, and this check
should move from the WARNINGS counter into the VIOLATIONS counter (i.e. contribute to exit code
like the Tier 1 / Dead Entry / Tier Classification checks already do) — restoring it to a real
gate rather than a permanently-ignored warning. `double_loaded_dual` (13, expected to stay 13
unless new legitimate dual entries are added) prints as informational text only, never adds to
`WARNINGS` or `VIOLATIONS` — it is exempt *by construction* of the predicate, with no separate
allowlist file to keep in sync.

**Negative test** (the "still fires" proof the verification bar requires): add a fixture entry to
a scratch copy of index.json with `agents: ["meta-builder-agent"]`, `commands: ["/meta"]` (exactly
the most common redundant shape) and confirm `double_loaded_redundant` becomes 1 against that
fixture; then add a fixture entry with `agents: ["meta-builder-agent"]`, `commands: ["/review"]`
and confirm it does NOT increment `double_loaded_redundant` (falls into the dual/exempt bucket
instead), proving the predicate discriminates rather than trivially firing on any dual-hook shape.

## Decisions

- **Fix direction for the 36 redundant entries is "drop `commands[]`, keep `agents[]`"**, not the
  reverse. `agents[]` is the finer-grained, more precise hook (it is what every other entry in the
  ~187-entry index uses when it needs only one hook), and it is what the majority of non-flagged
  entries already rely on exclusively. Dropping `commands[]` is the minimal, lowest-risk edit.
- **route(c) is scoped to non-hard canonical agents only** (see scoping note above) — a deliberate
  choice to keep the check meaningful rather than accidentally neutering it by widening the
  redundancy test to cover hard-mode reachability that no entry in this dataset declares anyway.
- **`/orchestrate` is never treated as fully subsuming** an entry's `agents[]`, because its
  effective reach is a union across three different skills' agent resolution, never a single
  agent matching one entry's `agents[]` list.
- **No new schema field or allowlist file is introduced.** The exemption for the 13 legitimate
  entries is the redundancy predicate's own `false` result — mechanically re-derived every run
  from the deployed manifest/skill files, so it cannot silently drift stale the way a hand-maintained
  allowlist could, and it automatically classifies any future entry added in either bucket.

## Risks & Mitigations

- **Risk**: a future contributor adds a new dual-hook entry pairing a single-agent command (e.g.
  `/meta`) with that same agent already in `agents[]`, recreating the exact redundant shape.
  **Mitigation**: this is precisely what re-keying the check to a violation (rather than warning)
  prevents — `verify-deploy.sh`/CI-adjacent runs of `validate-context-budgets.sh` will fail closed
  on the new entry instead of silently accumulating another pending-triage warning. (Per
  `context-discovery.md`'s own note, `validate-context-budgets.sh` is not currently wired into
  `verify-deploy.sh` — wiring it in is called out there as a separate, not-yet-scheduled
  follow-up; this task does not change that wiring, only the check's own internal severity.)
- **Risk**: the routing derivation silently breaks if `skill-meta`/`skill-spawn`/`skill-reviser`'s
  `SKILL.md` ever gains a second, conditional `subagent_type:` line (making "the sole line" no
  longer well-defined). **Mitigation**: `head -1` degrades gracefully (takes the first match
  rather than erroring), and if manifest/skill files are ever missing the script should treat an
  empty `route_*` value as "no known route" (same as a direct command) rather than crashing —
  worth an explicit test in the implementation phase.
- **Risk**: hard-coding the six-command routing table inside the shell script duplicates knowledge
  that also lives in the manifest/skill files. **Mitigation**: already addressed by design — the
  agent values are read live from those files at check-run time, not copied as literals; only the
  *command names* (`/research`, `/plan`, `/implement`, `/meta`, `/spawn`, `/revise`) and the
  *direct-command roster* are literal, and both are small, low-churn, and already documented in
  CLAUDE.md's Skill-to-Agent Mapping table for a human to cross-check.

## Context Extension Recommendations

- **Topic**: hard-mode agent context coverage. **Gap**: none of the 36 redundant (or 13
  legitimate) entries hook any of `general-research-hard-agent`, `planner-hard-agent`,
  `general-implementation-hard-agent` in `agents[]`, even though these agents plausibly need the
  same format/pattern/template files their non-hard counterparts use (report-format.md,
  plan-format.md, progress-file.md, etc.). **Recommendation**: a follow-up task auditing whether
  hard-mode agents discover these files through some other mechanism (their own hardcoded Context
  References list) or have a genuine gap — out of scope here since it is a coverage question, not
  a double-loading one.
- **Topic**: `agents[]` under-population relative to documented usage. **Gap**:
  `patterns/context-discovery.md` is referenced by `general-research-agent.md`'s own Context
  References list ("Use with agent=`general-research-agent`, command=`/research`") but the index
  entry's `agents[]` only lists `meta-builder-agent`. **Recommendation**: worth a separate
  audit of whether index `agents[]` arrays accurately reflect which agents' own `.md` files
  actually reference each context file — a distinct, pre-existing drift issue from double-loading.

## Appendix

- Search/verification commands used: `bash .claude/scripts/validate-context-budgets.sh --verbose`
  (baseline + entry listing); `jq` queries over `.claude/context/index.json` and every
  `agent-system/extensions/*/index-entries.json` for enumeration/attribution; `grep -rln
  "load_when"` across `scripts/`, `skills/*/SKILL.md`, `commands/*.md` to establish the no-live-consumer
  finding; `grep -n "subagent_type"` across `skill-meta`, `skill-spawn`, `skill-reviser` SKILL.md
  files to confirm each has exactly one unconditional agent target; `jq '.routing_agents,
  .routing_agents_hard'` on `agent-system/extensions/core/manifest.json` for the research/plan/implement
  routing table.
- Files read: `agent-system/extensions/core/scripts/validate-context-budgets.sh`,
  `agent-system/extensions/core/context/index.schema.json`,
  `agent-system/extensions/core/context/patterns/context-discovery.md`,
  `agent-system/extensions/core/agents/general-research-agent.md`,
  `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md` (to confirm this task's
  correct handoff-writing behavior — see below).
- **Handoff-writing note**: per `handoff-schema.md`'s "Handoff Writers" table,
  `.orchestrator-handoff.json` is formally hard-mode-implement-only; "research agents never write
  a handoff at all, in any mode." This report's own agent file
  (`general-research-agent.md`, Stage 3.6 "Scoping Decision") states the same constraint
  explicitly. This research dispatch completed normally (no context-pressure partial), so per that
  documented contract no `.orchestrator-handoff.json` write was made for this cycle; the
  orchestrator recovers this cycle's outcome from `.return-meta.json` via
  `orchestrate-recover-outcome.sh`, exactly as designed for base-mode research dispatches.

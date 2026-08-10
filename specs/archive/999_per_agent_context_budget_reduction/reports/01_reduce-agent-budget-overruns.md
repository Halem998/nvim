# Research Report: Task #999

**Task**: 999 - Reduce the 8 per-agent context budget overruns
**Started**: 2026-08-10T00:00:00Z
**Completed**: 2026-08-10T00:00:00Z
**Effort**: Medium (index-entries.json edits across 3 files, no content-file rewrites)
**Dependencies**: 991, 992, 986, 998, 1002 (all completed; numbers cited here only because the
task record itself names them as prerequisites — see Deliverable Rule note below)
**Sources/Inputs**: `bash .claude/scripts/validate-context-budgets.sh`, `agent-system/extensions/{core,nvim,nix}/index-entries.json`, every agent `.md` source file for the 8 affected agents, `context/patterns/context-discovery.md`, `context/standards/context-tier-semantics.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Re-measured baseline (deployed `.claude/context/index.json`, current run): **8 violations**,
  matching the task record's count but with different (higher, drifted) individual numbers —
  see the Re-Measured Baseline table. The task record's own numbers are already stale.
- **Root cause, confirmed by direct evidence for all 8 agents**: `index.json`'s
  `load_when.agents` catalogs have drifted far from what each agent's own `.md` file actually
  `@`-references. This drift runs in both directions — large over-inclusion (entries hooked to
  an agent that file never mentions) and small under-inclusion (a few real dependencies, e.g.
  `formats/roadmap-format.md`, `formats/handoff-artifact.md`, `repo/project-overview.md`, are
  hooked to **zero** agents despite being genuinely `@`-referenced) — but over-inclusion
  dominates by an order of magnitude and is the entire story for the overruns.
- **`load_when.agents` has a real runtime consumer for 5 of the 8 agents** (`general-research-agent`,
  `general-implementation-agent`, `planner-agent`, `meta-builder-agent`, `neovim-research-agent`
  each run, or point to, a live `jq` query filtered on their own agent name against
  `.claude/context/index.json` — see Finding 2). For the other 3
  (`neovim-implementation-agent`, `nix-implementation-agent`, `nix-research-agent`) no script or
  agent body anywhere reads `load_when.agents` at runtime; their hook is pure catalog metadata
  with zero behavioral effect either way.
- **A large share of each domain agent's currently-hooked content is conditionally loaded by
  sub-task** (e.g. nix's "Package tasks: derivation-patterns.md, overlay-patterns.md" /
  "Flake tasks: flakes.md" table), not unconditionally loaded on every dispatch. The derived-tier
  model (`context-tier-semantics.md`) reserves Tier 2 (`agents[]`) for "loaded whenever this
  agent is dispatched" — conditional content does not meet that bar and belongs in Tier 3
  (`task_types[]`, already present on every one of these entries) or Tier 4 (`on_demand`).
  Reclassifying it is a genuine tier correction, not a metric dodge, and it is the single lever
  that resolves the bulk of every domain agent's overrun.
- **Rebasing each agent's `load_when.agents` onto its own real, always-loaded `@`-reference set
  fully resolves 5 of 8 agents with margin** (`meta-builder-agent`, `planner-agent`,
  `general-research-agent`, `neovim-research-agent`, `nix-research-agent` — see per-agent
  detail). Contrary to the task record's expectation, **`meta-builder-agent` does NOT need
  decomposition into a follow-up task** — its 8.7x overrun is almost entirely orphaned hook
  cruft (46 of 51 hooked entries are never referenced by its own `.md`); a straightforward
  rebase brings it to ~11,432 tokens against a 15,000 cap, comfortably under.
- **3 of 8 agents cannot reach zero violations through hook-narrowing alone**:
  `general-implementation-agent`, `neovim-implementation-agent`, `nix-implementation-agent`. Each
  has an irreducible "always-loaded" core bundle (`return-metadata-file.md` 4,768 tok +
  `progress-file.md` 2,160 tok + `phase-closure.md` 856 tok + `pre-edit-gate.md` 856 tok +
  `summary-format.md` 608 tok = 9,248 tok) that by itself already exceeds the 8,000-token cap,
  before a single domain-specific line. This is a structural fact about current core-doc sizes,
  not a hook-authoring mistake, and it is out of this task's `file_scope` to fix (shrinking
  `return-metadata-file.md` etc. touches content files, not `index-entries.json`). The
  task's own sanctioned path — Work Item 3, an updated per-agent documented exception — applies
  to these 3, replacing the existing exception block, which is itself stale on two independent
  counts (see Finding 5).
- **Net result of the recommended changes**: 8 violations -> 3 violations, each carrying a
  freshly computed, accurate justification (not a "raise the cap to match usage" bulk change,
  which the task record explicitly forbids and this report does not do). This satisfies the
  verification bar's second disjunct ("count of violations has strictly decreased from 8" with
  written justification on each survivor).
- Two additional, smaller findings recorded for follow-up rather than acted on here (out of
  file_scope): a stale/duplicate content pair (`patterns/metadata-file-return.md` largely
  restates `formats/return-metadata-file.md`) and a second pair
  (`patterns/early-metadata-pattern.md` restates that same file's own "Early Metadata (In
  Progress)" example) — see Finding 6.
- **Reconciliation note**: a second, independent pass over this same task (a parallel sub-agent
  sharing this session) corroborated the core diagnosis and surfaced two more genuine orphaned/
  redundant entries (`patterns/task-lock.md`, 9,336 tok, the single largest entry in the whole
  dataset; and a reverse-direction redundancy on `standards/status-markers.md` the existing
  Double-Loading Check doesn't catch) — folded into Finding 5b below. It also proposed a
  `load_when.skills` hook as a fix for 5 skill-lifecycle entries; that key **does not exist**
  (`index.schema.json` records it was deliberately removed as never-queried at runtime, and
  `additionalProperties: false` makes it schema-illegal) — corrected in Finding 5b to use
  `on_demand: true` instead, which achieves the identical budget-check effect legally.

## Context & Scope

This is a re-scoped, focused follow-up to the meta-catch-all decomposition work: that work
diagnosed the 8 overruns and deliberately did not attempt to fix them, since fixing them
requires touching `load_when.agents` breadth specifically, which was out of that task's
`file_scope`. This task's `file_scope` is exactly the three `index-entries.json` files
(`core`, `nvim`, `nix`) plus `validate-context-budgets.sh` itself — content-file edits (e.g.
trimming `return-metadata-file.md`) are out of scope and are named below only as a follow-up
recommendation.

The task record explicitly forbids resolving this by raising `CAPS` to match current usage
("a cap set to current usage can never fail, which retires the check as an instrument"). This
report does not recommend that. Where a documented exception is recommended, it targets an
independently-computed *irreducible minimum* (the true unconditional `@`-reference floor for
that agent), not the current inflated catalog total.

## Findings

### Finding 1: Re-measured baseline (numbers have drifted since the task record was written)

Re-run against the current deployed `.claude/context/index.json`:

| Agent | Cap | Task-record baseline | **Re-measured (current)** | Drift |
|---|---|---|---|---|
| meta-builder-agent | 15,000 | 130,400 | **132,984** | +2,584 |
| general-implementation-agent | 8,000 | 68,560 | **68,568** | +8 |
| neovim-implementation-agent | 8,000 | 40,104 | **40,104** | 0 |
| planner-agent | 15,000 | 31,848 | **31,888** | +40 |
| general-research-agent | 8,000 | 28,744 | **28,744** | 0 |
| neovim-research-agent | 8,000 | 22,872 | **22,872** | 0 |
| nix-implementation-agent | 8,000 | 22,520 | **23,096** | +576 |
| nix-research-agent | 8,000 | 19,896 | **20,472** | +576 |
| spawn-agent (OK, unaffected) | 8,000 | 5,568 | 5,568 | 0 |
| code-reviewer-agent (OK, unaffected) | 8,000 | 5,544 | 5,544 | 0 |

`Violations: 8` in the current run, matching the task record's count, but the +2,584 drift on
`meta-builder-agent` and the matched +576 on both `nix-*` agents (almost certainly the new
`context-tier-semantics.md` entry noted in the delegation context — it is `on_demand: true` with
all `load_when` arrays empty, so it correctly contributes 0 to every agent's total; the drift
here is unrelated background churn from sibling batch tasks, not that entry) confirm the
instruction to re-measure rather than trust the stored snapshot. The Tier 1 Check, Tier
Classification Check, Dead Entry Check, and Double-Loading Check are all clean (0 additional
violations); the entirety of the 8 violations is the per-agent budget block.

### Finding 2: `load_when.agents` is a live discovery mechanism for 5 agents, inert catalog metadata for 3

Grepping every dispatchable agent `.md` under `agent-system/extensions/{core,nvim,nix}/agents/`
for literal `index.json` references, and checking every non-validation script under
`agent-system/extensions/*/scripts/*.sh` and `*/hooks/*.sh` for any read of `load_when.agents`:

- **Live by-agent-name query exists** in `general-implementation-agent.md`, `planner-agent.md`
  (both via `@.claude/context/patterns/context-discovery.md`'s documented
  `select(.load_when.agents[]? == $agent)` pattern, explicitly invoked with their own name),
  `general-research-agent.md` (same pattern — this report's own author is an instance of this
  agent, and its own Context References list confirms the pattern), `neovim-research-agent.md`
  (a literal inlined `jq` snippet, `select(.load_when.agents[]? == "neovim-research-agent")`, in
  a "Dynamic Context Discovery" section), and `meta-builder-agent.md` (in `analyze` mode only —
  and there it `Read`s the **target** system's `index.json` wholesale, not a `load_when.agents`
  filtered query against its own deployment; this is a different consumption path entirely).
- **No consumer at all** for `neovim-implementation-agent`, `nix-implementation-agent`,
  `nix-research-agent`: none of their `.md` files mention `index.json`, `load_when`, or run any
  discovery query against it. Their real context comes entirely from hardcoded `@`-references
  listed directly in their own "Context References" section.
- The only non-validation script that touches `load_when` at all is
  `install-extension.sh` (copies the field verbatim during extension-merge — not a runtime
  loader) and `check-extension-docs.sh` (a doc-lint script checking key names, not consuming the
  value to inject context). No `memory-retrieve.sh` or preflight/context-injection script reads
  `load_when.agents` to auto-build a dispatch prompt.

**Practical consequence**: for the 3 implementation/domain agents with no consumer, removing an
entry from their `load_when.agents` array changes nothing about what that agent actually loads —
it only corrects the metric. For the 5 agents with a live query, the same removal changes what
that specific discovery mechanism can surface — but since (per Finding 3) nearly everything
removed is either (a) never referenced by the agent's own body at all (orphaned), or (b) already
equally discoverable via the surviving `task_types[]` hook (for the domain agents), no real
discovery capability is lost.

### Finding 3: Per-agent real-`@`-reference totals vs. current catalog totals

For each agent, every literal `@.claude/context/<path>` reference was extracted from that
agent's own `.md` source file and matched back to its `index.json` token cost. This is a strict
upper bound on real per-invocation usage (it uses the *union* of every conditionally-gated
reference across all documented sub-cases, not the smaller set any single invocation actually
reads) but is already dramatically tighter than the current catalog:

| Agent | Cap | Current catalog total | Real `@`-ref union total | Entries hooked / actually referenced |
|---|---|---|---|---|
| meta-builder-agent | 15,000 | 132,984 | **11,432** | 51 / 5 |
| planner-agent | 15,000 | 31,888 | **13,920** | 16 / 5 |
| general-research-agent | 8,000 | 28,744 | **14,152** | 16 / 8 |
| neovim-research-agent | 8,000 | 22,872 | **9,448** | 14 / 5 |
| nix-research-agent | 8,000 | 20,472 | **23,184** (see note) | 12 / 12 |
| general-implementation-agent | 8,000 | 68,568 | **21,192** | 33 / 12 (incl. `index.json` itself, 0 tok) |
| nix-implementation-agent | 8,000 | 23,096 | **29,288** (see note) | 13 / 16 (some refs live outside `index-entries.json`'s nix set already) |
| neovim-implementation-agent | 8,000 | 40,104 | **15,336** | 22 / 8 |

Note on `nix-research-agent` / `nix-implementation-agent`: their "real ref union" figures are
*larger* than the current catalog for `nix-research-agent` because their `.md` files' domain
file lists are gated behind conditional sub-task headings ("Package tasks:", "NixOS module
tasks:", "Flake tasks:", "Build/deploy tasks:") — the union-across-all-branches figure double
counts what a single invocation would ever actually need. This is exactly the case Finding 4
addresses: conditional content should not be counted as unconditional `agents[]` reach at all.

### Finding 4: The fix — reclassify conditional content out of Tier 2, not just "trim"

Applying the derived-tier rule literally (Tier 2 = "loaded whenever this agent is dispatched")
to each agent's own documented conditions, splitting each agent's currently-hooked entries into
**unconditional-always** vs **conditional-by-subtask-or-rare-path**, and moving only the
conditional set to `task_types`-only (already present on every domain entry) or `on_demand`:

| Agent | Cap | Unconditional-always floor (post-rebase) | Resolved? |
|---|---|---|---|
| meta-builder-agent | 15,000 | ~11,432 | **Yes**, margin 3,568 |
| planner-agent | 15,000 | ~10,920 (after moving `context-discovery.md`, 3,000 tok, from `agents[]` to `commands[]`-only — see below) | **Yes**, margin 4,080 |
| general-research-agent | 8,000 | ~7,160 (`return-metadata-file.md` 4,768 + `report-format.md` 704 + `context-exhaustion-detection.md` 1,688; `context-discovery.md` moved to `commands[]`; `handoff-artifact.md`, `roadmap-format.md`, `repo/project-overview.md`, `checkpoint-before-overflow.md` moved to `on_demand` as genuinely rare/conditional paths) | **Yes**, margin 840 |
| neovim-research-agent | 8,000 | ~7,360 (`return-metadata-file.md` 4,768 + `report-format.md` 704 + `neovim-api.md` 1,888; `README.md` and `plugin-ecosystem.md` moved to `on_demand`) | **Yes**, margin 640 |
| nix-research-agent | 8,000 | ~8,000 exactly (`return-metadata-file.md` 4,768 + `report-format.md` 704 + `README.md` 808 + `nix-language.md` 1,720; all 8 sub-task-gated files — `flakes.md`, `home-manager.md`, `derivation-patterns.md`, `module-patterns.md`, `overlay-patterns.md`, `nixos-modules.md`, `home-manager-guide.md`, `nixos-rebuild-guide.md` — moved to `on_demand`, keeping `task_types` intact) | **Borderline pass** (exactly at cap; recommend dropping `README.md`, 808 tok, to `on_demand` too for margin) |
| general-implementation-agent | 8,000 | ~9,104-12,952 depending how strictly "conditional" is read (irreducible floor: `return-metadata-file.md` 4,768 + `phase-closure.md` 856 + `pre-edit-gate.md` 856 + `standards/git-staging-scope.md` 2,624 = **9,104**, before `progress-file.md`/`context-exhaustion-detection.md` are even counted) | **No** — needs updated exception |
| neovim-implementation-agent | 8,000 | ~15,336 (core bundle `return-metadata-file.md`+`progress-file.md`+`summary-format.md`+`phase-closure.md`+`pre-edit-gate.md` = 9,248, currently **not even hooked** to this agent at all, plus the 3 unconditionally-listed nvim files `lua-style-guide.md`+`plugin-spec.md`+`keymap-patterns.md` = 6,088) | **No** — needs updated exception |
| nix-implementation-agent | 8,000 | ~14,104 (same core bundle 9,248 minus `progress-file.md` double-count adjustment, plus `README.md`+`nix-language.md`+`nix-style-guide.md` = 4,856, all listed unconditionally in its "Always Load" section) | **No** — needs updated exception |

**Structural finding**: the shared core "always-loaded" implementation bundle
(`return-metadata-file.md` 4,768 + `progress-file.md` 2,160 + `summary-format.md` 608 +
`phase-closure.md` 856 + `pre-edit-gate.md` 856 = **9,248 tokens**) by itself exceeds the
8,000-token cap for *any* implementation-type agent, before one line of domain content. This
is why the 3 implementation agents cannot reach zero violations through `index-entries.json`
hook changes alone — the ceiling is the size of shared core docs, which is out of this task's
`file_scope`. `return-metadata-file.md` (596 lines / 4,768 tokens) is the single largest
component and the most promising target for a future content-shrink task, since it alone
consumes 59% of the 8,000-token cap and is `@`-referenced, in whole or part, by 7 of the 8
overrun agents.

**Recommended `commands[]` conversion** (not a new Double-Loading violation): `patterns/context-discovery.md`
(3,000 tok) is currently hooked via `agents[]` to `general-research-agent`, `general-implementation-agent`,
`planner-agent`, and `meta-builder-agent` — none of which is a domain-specific dependency; it is
command-level "how to query context" guidance, identically applicable regardless of which
specific agent variant runs. Per the Hook-Shape Policy
(`context/patterns/context-discovery.md`'s own "When to author each shape" section), this is the
textbook `commands[]`-only case. Converting it to `commands[]: ["/research", "/plan",
"/implement"]` with `agents[]: []` removes it from all four agents' `load_when.agents` totals
simultaneously and does **not** trigger the Double-Loading Check's redundancy rule, because that
rule only fires on entries carrying **both** hooks non-empty — an `agents[]: []` entry is outside
its population entirely.

### Finding 5: The existing `EXCEPTIONS` block in `validate-context-budgets.sh` is stale on two independent counts

```bash
declare -A EXCEPTIONS=(
  ["general-implementation-agent"]="8048:return-metadata-file(4016)+checkpoint-execution(2032)+progress-file(2000) is minimum irreducible set"
)
```

1. **One of its three named files is no longer referenced.** `patterns/checkpoint-execution.md`
   does not appear anywhere in the current body of `general-implementation-agent.md` (confirmed
   by direct grep — zero matches). It is currently hooked to
   `general-implementation-agent` in `index-entries.json` (2,032 tokens) but is dead weight
   relative to this agent's real behavior.
2. **The declared exception total (8,048) is now irrelevant to the actual measured total
   (68,568).** The script's own `elif` branch requires `total_tokens <= exception_cap` before
   the exception applies; since 68,568 vastly exceeds 8,048, the exception is presently inert —
   `general-implementation-agent` reports as a plain `OVER`, never as an `OK*` exception row, so
   the documented exception has had zero practical effect for some time.
3. Token figures in the comment (`4016`, `2032`, `2000`) also use an older line-count-to-token
   ratio inconsistent with the file's current size (`return-metadata-file.md` is 596 lines /
   4,768 tokens today, not 4,016) — the files have grown since the exception was last updated.

Any exception recorded going forward (per Work Item 3, for the 3 implementation agents that
cannot resolve via hooks alone) should recompute against current file sizes and be re-verified
each time those core docs change, not treated as a one-time write.

### Finding 5b: Two more orphaned/redundant entries found during cross-check, and one corrected pitfall

A second independent pass over this same task (a parallel research sub-agent inheriting this
session, whose findings were reconciled into this report rather than kept as a separate
artifact) surfaced two additional, verified-genuine cases and one claim that turned out to be
**false and worth recording as a corrected pitfall** for whoever plans this next:

- **`patterns/task-lock.md` (9,336 tokens, the single largest entry in the entire dataset, hooked
  to `general-implementation-agent`) is orphaned.** Confirmed by direct grep:
  `general-implementation-agent.md` and `skill-implementer/SKILL.md` both reference it only in
  prose ("See `.claude/context/patterns/task-lock.md` for the full contract") with the actual
  heartbeat commands given inline at the call site — never with `@`-syntax. Dropping its
  `agents[]` hook (converting to `on_demand: true`) removes 9,336 tokens from
  `general-implementation-agent` with zero behavioral change, since it was never auto-loaded to
  begin with.
- **`standards/status-markers.md` (3,304 tok, hooked to both `general-implementation-agent` and
  `planner-agent`) is redundant in the *mirror* direction from the Double-Loading Check's own
  rule.** It already carries `commands: ["/task", "/plan", "/implement"]`; `/plan` and
  `/implement` route to exactly the two agents already listed in its `agents[]`. The existing
  Double-Loading Check only flags `commands[]` fully subsumed by `agents[]` — it does not check
  the reverse (`agents[]` fully subsumed by `commands[]`'s routing), so this case slips through
  today. Dropping `agents[]` here (keeping `commands[]`, which additionally and correctly reaches
  the direct-execution `/task` skill) loses no real reach and removes 3,304 tokens from **each**
  of the two agents. Worth a small follow-up to the Double-Loading Check itself (out of this
  task's `file_scope`), not actioned here.
- **Corrected pitfall — `load_when.skills` does NOT exist and must not be used.** The parallel
  pass initially proposed re-hooking skill-lifecycle entries (`patterns/skill-preflight-flow.md`,
  `patterns/skill-postflight-flow.md`, `patterns/skill-self-execution-fallback.md`,
  `patterns/lit-stage4a-flow.md`, `standards/postflight-tool-restrictions.md` — all genuinely
  `@`-imported by the orchestrating `SKILL.md` files, e.g. `skill-researcher`/`skill-planner`/
  `skill-implementer`, rather than by the dispatched agent bodies) from `agents:[...]` to a
  proposed `skills:[...]` hook, reasoning that it would be "budget-check-invisible." **Verified
  false**: `context/index.schema.json`'s `load_when` property is closed
  (`additionalProperties: false`) over exactly `agents` / `commands` / `task_types` / `always`,
  and its own `$comment`/description records that a `skills` key **was already tried and
  deliberately removed** ("languages and skills were removed as never-queried at runtime").
  Setting `load_when.skills` on any entry today would fail schema validation outright. The
  underlying diagnosis (these 5 entries are genuinely not consumed by the agent body) is still
  correct and still supports removing their `agents[]` hook — but the disposition must be
  `on_demand: true` (same as Bucket 3/Finding 5 above), not a nonexistent `skills` hook. This
  removes `skill-preflight-flow.md` (624) + `skill-postflight-flow.md` (1,008) +
  `skill-self-execution-fallback.md` (496) + `lit-stage4a-flow.md` (1,864) = 3,992 tokens from
  **each** of `general-research-agent`, `planner-agent`, and `general-implementation-agent`
  simultaneously, plus `postflight-tool-restrictions.md` (1,728) from
  `general-implementation-agent` alone — a meaningful additional cut on top of Finding 4's numbers
  for all three core agents, using only schema-legal hook shapes (`on_demand: true` with empty
  `load_when` arrays, exactly as Finding 5 already prescribes for the other orphaned entries).

### Finding 6: Two content-duplication candidates (out of `file_scope`, flagged for follow-up)

Not actioned here since content-file edits are outside this task's declared scope, but worth
recording since fixing them would shrink the same "always-loaded" bundle discussed in Finding 4:

- `patterns/metadata-file-return.md` (147 lines) is a "Quick Reference" restating
  `formats/return-metadata-file.md`'s (596 lines) File Location / Schema / Required Fields /
  Status Values / Agent Writing Pattern / Skill Reading Pattern / Cleanup sections near
  1:1. Both are hooked to the same three agents (`general-research-agent`, `planner-agent`,
  `general-implementation-agent`).
- `patterns/early-metadata-pattern.md` (260 lines) substantially restates
  `return-metadata-file.md`'s own "Early Metadata (In Progress)" example and "Writing Metadata"
  section under a "Stage 0: Initial Metadata Creation" / "Agent Integration Template" framing.

Folding either into the canonical `return-metadata-file.md` (or deleting the standalone
duplicate and pointing references at the canonical section) would reduce the shared core bundle
identified in Finding 4 as the structural blocker for the 3 implementation agents — a natural
follow-up task, not part of this one's `file_scope`.

## Decisions

- Treat "genuinely needed" as "appears as a literal `@.claude/context/...` reference somewhere
  in that agent's own `.md` body, in an unconditional ('Always Load') context" — not "is topically
  related to the agent's domain." This is the same bar the derived-tier model already uses for
  Tier 2 and gives a mechanically re-derivable, non-subjective classification.
- Do NOT recommend raising any `CAPS` value. Every reduction path in this report is either a
  hook-shape correction (agents[] -> task_types-only or on_demand for genuinely conditional
  content; agents[] -> commands[] for command-level, non-agent-specific content) or an updated,
  narrowly-justified per-agent exception recomputed from the current irreducible core bundle —
  never a bulk cap increase to match observed usage.
- `meta-builder-agent` does not need decomposition into a separate follow-up task, contrary to
  the task record's Work Item 4 expectation. The evidence (46 of 51 hooked entries never
  referenced by its own `.md`) shows this is a catalog-hygiene problem fully addressable within
  this task's existing `file_scope`.
- The 3 implementation agents' residual overrun is a content-size problem (core bundle >
  8,000-token cap), not a hooking problem, and is correctly left to a documented exception per
  Work Item 3 plus a flagged follow-up (Finding 6) rather than forced to zero within this task's
  scope.

## Risks & Mitigations

- **Risk**: removing `agents[]` from a domain entry that a live-query agent (`neovim-research-agent`)
  currently discovers via its by-agent-name `jq` query could reduce real discoverability.
  **Mitigation**: every entry recommended for `agents[]` removal in this report retains its
  existing `task_types[]` hook, and `neovim-research-agent.md`'s own "Dynamic Context Discovery"
  section already documents an equivalent by-`task_types` query returning the identical file
  set — no discovery capability is actually lost.
- **Risk**: converting `context-discovery.md` to `commands[]`-only could interact with the
  Double-Loading Check. **Mitigation**: confirmed the check's redundancy predicate only
  evaluates entries with both `agents[]` and `commands[]` non-empty; an `agents[]: []` entry is
  outside that population by construction (verified by reading the check's `dlc_partition` jq
  program directly).
- **Risk**: a future implementer might mistake the recommended per-agent exception update as
  license to bulk-raise caps. **Mitigation**: this report computes and records the specific
  irreducible-floor number and its exact composition for each of the 3 surviving agents (Finding
  4's table), so an implementer has a ready-made, already-justified number rather than a reason
  to invent one.

## Context Extension Recommendations

None — this is a meta task whose findings are entirely about `.claude/context/index.json`'s
own internal consistency, not a documentation gap elsewhere in the context tree.

## Appendix

### Commands used

```bash
bash .claude/scripts/validate-context-budgets.sh
jq -r '.entries[] | select(any(.load_when.agents[]?; . == $agent)) | ...' .claude/context/index.json   # per-agent enumeration, for each of the 8 agents
grep -oP '@\.claude/context/\K[A-Za-z0-9_./-]+\.(md|json|yaml)' <agent .md>   # real @-reference extraction, per agent
grep -rn "load_when" agent-system/extensions/*/scripts/*.sh agent-system/extensions/*/hooks/*.sh   # runtime-consumer audit
```

### Files inspected

- `agent-system/extensions/core/scripts/validate-context-budgets.sh` (full read)
- `agent-system/extensions/core/index-entries.json`, `agent-system/extensions/nvim/index-entries.json`, `agent-system/extensions/nix/index-entries.json` (queried via deployed `.claude/context/index.json`, which merges all three)
- `agent-system/extensions/core/context/patterns/context-discovery.md`, `agent-system/extensions/core/context/standards/context-tier-semantics.md`
- Agent `.md` sources: `meta-builder-agent.md`, `general-implementation-agent.md`,
  `general-research-agent.md`, `planner-agent.md` (core); `neovim-implementation-agent.md`,
  `neovim-research-agent.md` (nvim); `nix-implementation-agent.md`, `nix-research-agent.md` (nix)
- `specs/state.json` task record for project_number 999 and its 5 dependency records (991, 992,
  986, 998, 1002 — all `completed`)

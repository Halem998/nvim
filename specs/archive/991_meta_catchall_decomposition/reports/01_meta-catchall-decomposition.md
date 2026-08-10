# Research Report: Break the meta task_types catch-all, derive tier algorithmically

**Task**: 991 - meta_catchall_decomposition
**Task type**: meta
**Sources/Inputs**: `agent-system/extensions/*/index-entries.json` (19 extensions), `.claude/context/index.json` (merged deploy artifact), `agent-system/extensions/core/scripts/validate-context-budgets.sh`, prerequisite research reports in `specs/archive/987_context_budget_enforcement_and_index_schema/` and `specs/archive/990_index_entries_schema_migration/`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The description's three headline numbers resolve as: **25** meta-only entries (not ~24),
  **86** meta-tagged entries (not 123), **0** entries with an authored `tier` field (exact match).
- **The 123 figure is a documented mis-read, not drift.** The prerequisite census counted
  entries where the `task_types` *key is present* in `load_when` (126 today, 40 of them holding
  an empty array). The count of entries whose `task_types` array actually contains `"meta"` is
  86, and has been 85-86 across every recent revision of the file. Section 5 of the prerequisite
  report narrated the key-presence count as if it were the meta-tagged count. The plan should
  target 86, and should not expect to find ~37 additional entries.
- The prerequisite report's section 5 thematic grouping **exists and is usable**; it covers 24 of
  the 25 current meta-only entries. One entry (`patterns/system-defect-discrimination.md`, 382L)
  was added after that census and needs a group assignment.
- All 25 meta-only entries live in `core/index-entries.json`. No other extension has a single
  meta-only entry; only `nvim` carries `"meta"` at all outside core (1 entry, which also has
  other hooks).

## Context & Scope

Four work items, researched in order: (S1) measured inventory, (S2) concrete thematic grouping,
(S3) trimming rule for the wider meta set, (S4) algorithmic tier derivation in
`validate-context-budgets.sh`, (S5) the broken `load_when.agents` values, (S6) baseline
validator run.

All proposed edits target `agent-system/extensions/**`. `.claude/` was read only as the merged
deploy artifact for cross-checking; nothing under it is an edit target.

## Findings

### S1. Measured inventory

Measured against the source store (`agent-system/extensions/*/index-entries.json`), 2026-08-09.

#### (a) Entries whose ONLY non-empty `load_when` hook is `task_types: ["meta"]`

Criterion: `always` falsy AND `agents` empty AND `commands` empty AND `task_types == ["meta"]`.

| Extension | Count |
|-----------|-------|
| core | **25** |
| all 18 others | 0 |

Total **25**, summing to **5,070 lines**. Description says ~24 — the divergence is one entry,
`patterns/system-defect-discrimination.md` (382L), added to the index after the prerequisite
census was taken. Full list, descending by line count:

```
571  standards/git-safety.md
400  reference/team-wave-helpers.md
382  patterns/system-defect-discrimination.md      <- not in the prerequisite's list of 24
313  orchestration/subagent-validation.md
305  patterns/file-metadata-exchange.md
275  patterns/postflight-control.md
257  patterns/mcp-tool-recovery.md
246  formats/events-format.md
216  standards/postflight-tool-restrictions.md
212  standards/git-integration.md
197  reference/workflow-diagrams.md
188  formats/handoff-artifact.md
177  formats/errors-format.md
166  orchestration/sessions.md
146  patterns/team-orchestration.md
140  standards/ci-workflow.md
137  schemas/errors-schema.json
134  patterns/infra-failure-discrimination.md
126  checkpoints/checkpoint-gate-out.md
124  checkpoints/checkpoint-commit.md
111  formats/team-metadata-extension.md
 81  checkpoints/checkpoint-gate-in.md
 78  schemas/events-schema.json
 46  validation.md
 42  routing.md
```

Minor line_count drift vs. the prerequisite list is also present (e.g.
`standards/postflight-tool-restrictions.md` 205 -> 216); the values above are current.

#### (b) Entries carrying `"meta"` in `task_types`

| Extension | Entries total | Carrying `"meta"` |
|-----------|---------------|-------------------|
| core | 136 | **86** |
| nvim | 24 | 1 |
| all 17 others | 314 | 0 |

Total **87** across the source store; the merged `.claude/context/index.json` (187 entries)
agrees exactly at 87.

Breakdown of core's 86:

| Shape | Count |
|-------|-------|
| meta + at least one `agents` hook | 49 |
| meta + `commands` hook, no `agents` | 12 |
| meta as the only hook (= set (a)) | 25 |

**The description's 123 is wrong, and the reason is identifiable.** Section 2 of the prerequisite
report tabulates a `task_types` column at 123/129 for core; section 5 then re-narrates that
number as "123 of 129 entries carrying `task_types: ["meta"]`". Reproducing both counts today:

| Measure | Count |
|---------|-------|
| `load_when` has a `task_types` **key** (any value, including `[]`) | **126** |
| ...of which the array is empty | 40 |
| `task_types` array actually contains `"meta"` | **86** |

126-vs-123 is ordinary growth of the file (129 -> 136 entries since the census). The 123 column
was a key-presence census, so it swept in the 40 entries with `task_types: []`. Historical
spot-checks confirm the meta count never was 123:

| Revision | core entries | contain "meta" |
|----------|--------------|----------------|
| `7ef80ae7e` | 133 | 86 |
| `dd7c0c076` | 133 | 86 |
| `2869f0f61` | 132 | 85 |
| `b0b52350d` | 132 | 85 |
| HEAD | 136 | 86 |

**Planning consequence**: work item 2 ("trim the wider 123-entry set") operates on 86 entries,
61 of which already carry a narrower hook. The trimming surface is therefore much smaller than
the description implies, and the exercise is mostly "drop a redundant `meta` from entries that
already have real hooks" rather than "find hooks for 123 orphans".

#### (c) Entries carrying an authored `tier` field

**Zero**, in every one of the 19 extensions and in the merged deploy index. Matches the
description exactly and confirms the premise of work item 3: `validate-context-budgets.sh`
queries a field nothing populates.

#### Resolved-context sanity check (`meta-builder-agent`)

Using the documented adaptive query (OR of `always == true`, `agents` contains
`meta-builder-agent`, `task_types` contains `"meta"`, `commands` contains `/meta`) against the
merged index:

| Measure | Value |
|---------|-------|
| Entries resolved | **93** |
| Total `line_count` | **26,987** |
| ...of which `always: true` | 3 |
| ...matching on `agents: [meta-builder-agent]` | 51 |
| ...matching on `commands: [/meta]` | 28 |

This 93-entry / ~27k-line resolved set is the before-state for S3.

**Critical asymmetry discovered here** (drives S3 and the verification bar, see S4/S6): the
validator's per-agent budget check counts **only `load_when.agents` matches** — it never reads
`task_types`. `meta-builder-agent`'s reported 130,360 tokens = 16,295 lines comes entirely from
the 51 `agents`-hooked entries, not from the 86 meta-tagged ones.

### S2. The thematic grouping, made concrete

**The prerequisite grouping exists and was found**, at
`specs/archive/987_context_budget_enforcement_and_index_schema/reports/01_context-budget-schema-reconciliation.md`,
section 5 ("The meta catch-all, concretely"), lines 213-235. It is used verbatim below as the
group structure; no competing grouping was invented. The report itself flags it as "a
planning-phase decision, not resolved here", so the per-group hook *values* below are this
report's concretization of that structure, not a decided fact.

| # | Group | Entries | Lines | Prerequisite's stated hook intent |
|---|-------|---------|-------|-----------------------------------|
| G1 | Checkpoint lifecycle | `checkpoints/checkpoint-gate-in.md`, `checkpoints/checkpoint-commit.md`, `checkpoints/checkpoint-gate-out.md` | 331 | `agents` = implementer/planner agents that run gate-in/commit/gate-out; not a task type |
| G2 | Error/event records | `formats/errors-format.md`, `formats/events-format.md`, `schemas/errors-schema.json`, `schemas/events-schema.json` | 638 | writer-side agents + `commands: ["/errors"]`, possibly `/distill --review` |
| G3 | Orchestration + handoff | `formats/handoff-artifact.md`, `orchestration/sessions.md`, `orchestration/subagent-validation.md`, `patterns/file-metadata-exchange.md`, `patterns/infra-failure-discrimination.md`, `patterns/mcp-tool-recovery.md`, `patterns/postflight-control.md` | 1,638 | `commands: ["/orchestrate"]` plus research/plan/implement agents — "genuinely broad, but via explicit `agents` enumeration, not the `meta` catch-all" |
| G4 | Team mode | `patterns/team-orchestration.md`, `reference/team-wave-helpers.md`, `formats/team-metadata-extension.md` | 657 | `--team` skills only; `synthesis-agent` + team skills |
| G5 | Git / CI / commit discipline | `standards/git-safety.md`, `standards/git-integration.md`, `standards/ci-workflow.md`, `standards/postflight-tool-restrictions.md` | 1,139 | implementer (git-committing) agents specifically, **not** researchers |
| G6 | Quick-reference, drop entirely | `routing.md`, `validation.md`, `reference/workflow-diagrams.md` | 285 | no `load_when` hook at all — genuinely on-demand, found by grep |
| G7 | **Unassigned (new)** | `patterns/system-defect-discrimination.md` | 382 | not in the prerequisite's list of 24 |

Sum G1-G7 = 25 entries, 5,070 lines. Prerequisite listed 24 / ~4,700; the delta is G7.

**G7 assignment recommendation** (this report's, flagged as new): its summary is "Discriminating
an agent-system defect from ordinary task-work failure via a two-signal (schema violation +
source-store attribution) predicate, plus the detection-point registry, recursion guard, and
dedup rule". That is the same audience as G2 (error-record writers) plus the orchestrator
detection points — recommend folding it into **G2**, hooks `commands: ["/errors", "/orchestrate"]`
plus the same writer-side agent set. It should not go to G3 (it is about classifying a failure,
not about the handoff mechanics) and it must not go to G6 (it is consumed at a specific
detection point, not grepped for).

**Concrete hook proposals per group.** Only agent names verified present in the source store are
used (see S5 for the roster check); each proposal states its effect on the capped agents.

- **G1** -> `agents: ["general-implementation-agent", "general-implementation-hard-agent",
  "planner-agent", "planner-hard-agent"]`, `task_types: []`. Deliberately excludes
  `meta-builder-agent` and the research agents — `/meta` creates tasks, it does not run the
  commit lifecycle. Adds 331 lines to `general-implementation-agent` (already OVER).
- **G2 (+G7)** -> `commands: ["/errors", "/orchestrate"]`, `agents: []`, `task_types: []`.
  Command-only, because the schemas are consumed by whoever is *writing* an error/event record
  at that moment, which is a command-phase fact, not an agent identity. Adds 0 lines to any
  capped agent — the cheapest of the six groups.
- **G3** -> `commands: ["/orchestrate"]`, `agents: []`, `task_types: []`. The prerequisite
  suggests "plus every research/plan/implement agent"; **recommend against** the agent half.
  Enumerating research+plan+implement agents on 1,638 lines would add ~1,638 lines each to
  `general-research-agent`, `general-implementation-agent`, `planner-agent`, and the neovim/nix
  pairs — six agents already OVER budget. Command-scoping preserves reachability for the
  `/orchestrate` path (the actual consumer) at zero per-agent budget cost.
- **G4** -> `agents: ["synthesis-agent"]`, `commands: []`, `task_types: []`. `synthesis-agent`
  is uncapped, so this is budget-free. The team skills are not agents and have no `load_when`
  key of their own; `commands` cannot express "--team" (it is a flag, not a command), so
  `synthesis-agent` is the only expressible hook.
- **G5** -> `agents: ["general-implementation-agent", "general-implementation-hard-agent"]`,
  `task_types: []`. Explicitly excludes every research agent, per the prerequisite. Adds 1,139
  lines to `general-implementation-agent` — the single largest budget impact of the whole
  exercise, and the item most likely to need a documented cap change (see S4/S6).
- **G6** -> all `load_when` arrays empty. **This trips the validator's existing Dead Entry
  Check**, which flags any entry with no `always`, no `agents`, no `commands`, no `task_types`
  and `tier != 4`. Three entries are already flagged today for exactly this reason
  (`reference/artifact-templates.md`, `contracts/convergence.md`,
  `contracts/orchestrator-discipline.md`). The plan must therefore pair G6 with a `tier: 4`
  authored field on those entries, or with a derivation rule that classifies all-empty entries
  as Tier 4 — which is precisely the fallthrough case S4 has to decide. G6 and S4's fallthrough
  are the same decision seen twice.

### S3. Trimming rule for the wider meta set

**Stated rule** (checkable by a single jq predicate):

> An entry keeps `"meta"` in `load_when.task_types` **iff** it is consumed specifically by
> meta-typed work — that is, by `meta-builder-agent` or the `/meta` command — **and** it has no
> other hook that already reaches those consumers. An entry that already carries
> `agents: [... "meta-builder-agent" ...]` or `commands: [... "/meta" ...]` drops `"meta"` as
> redundant. An entry that has some other hook and is *not* meta-specific drops `"meta"` as
> wrong. An entry whose only hook is `"meta"` is handled by S2, not by this rule.

Applied to core's 86 meta-tagged entries:

| Class | Count | Disposition |
|-------|-------|-------------|
| meta + at least one `agents` hook | 49 | **Drop `"meta"`.** Redundant where `agents` already names `meta-builder-agent`; wrong where it does not (the entry is agent-scoped, and `"meta"` re-broadens it to every meta-typed research/plan/implement dispatch). |
| meta + `commands` hook, no `agents` | 12 | **Drop `"meta"`.** Same argument via `commands`; check each for `/meta` membership and add it where the entry is genuinely meta-specific and `/meta` is absent. |
| meta only | 25 | Handled by S2 (gain a real hook, lose `"meta"`). |
| **Result** | **0 entries retain `"meta"`** | The `meta` task_type ceases to be a load_when discriminator in core. |

`nvim/index-entries.json` has the one remaining meta-tagged entry outside core; it carries other
hooks and falls in the first class.

**Before / after for `meta-builder-agent`'s resolved context** (adaptive query: `always` OR
`agents` OR `task_types` OR `commands: /meta`, against the merged index):

| | Entries | Total lines | Approx. tokens |
|---|---------|-------------|----------------|
| Before | 93 | 26,987 | ~215,900 |
| After (trim only, S3 alone) | 51 agents + 3 always + `/meta` commands survivors | see note | — |
| After (trim + S2 hooks as proposed) | **~57** | **~16,600** | **~133,000** |

Note on the "after" figure: dropping `"meta"` removes the 25 meta-only entries and the
`task_types` arm of the OR entirely. What remains is 3 `always` entries (334L), the 51
`agents: [meta-builder-agent]` entries (16,295L), plus whatever `commands: ["/meta"]` entries
survive the class-2 review (28 entries match `/meta` today, but 25 of them also carry an
`agents` hook, so the marginal add is small). S2's proposals deliberately route **zero** of the
25 meta-only entries to `meta-builder-agent`, so the S2 work does not add anything back.

**The honest conclusion**: trimming takes `meta-builder-agent` from ~27,000 resolved lines to
~16,600 — a real ~38% reduction in what the adaptive query actually loads — but it moves the
**validator's** number not at all, because the validator ignores `task_types`. Both facts are
true and the plan must state both; reporting only the first would misrepresent the verification
bar.

### S4. `validate-context-budgets.sh`: the `tier` queries and the derivation replacement

Source of truth: `agent-system/extensions/core/scripts/validate-context-budgets.sh` (228 lines).
It reads `.tier` at **four** call sites, not one.

**Call site 1 — verbose per-agent listing (line 118):**

```bash
    jq -r --arg agent "$agent" \
      '.entries[] | select(any(.load_when.agents[]?; . == $agent)) | "    Tier \(.tier // "?") \(.line_count * 8) tok  \(.path)"' \
      "$INDEX_FILE" | sort -t' ' -k3 -rn
```

**Call site 2 — the "entries with tier field" check named in the verification bar (lines 145-160), verbatim:**

```bash
# All entries have tier field
echo "--- Tier Classification Check ---"
missing_tier=$(jq '[.entries[] | select(.tier == null)] | length' "$INDEX_FILE")
total_entries=$(jq '.entries | length' "$INDEX_FILE")
echo "Total entries: $total_entries"
echo "Entries with tier field: $((total_entries - missing_tier))"
if [[ $missing_tier -eq 0 ]]; then
  echo "Status: OK (all entries have tier)"
else
  echo "Status: FAIL ($missing_tier entries missing tier field)"
  VIOLATIONS=$((VIOLATIONS + 1))
  if [[ "$VERBOSE" == "true" ]]; then
    echo "Missing tier:"
    jq -r '.entries[] | select(.tier == null) | "  \(.path)"' "$INDEX_FILE"
  fi
fi
```

**Call site 3 — Dead Entry Check (lines 166-190), guards on `.tier != 4` twice:**

```bash
dead_count=$(jq '
  [.entries[] | select(
    .tier != 4 and
    (.load_when.always == false or (.load_when.always == null)) and
    ((.load_when.agents // []) | length) == 0 and
    ((.load_when.commands // []) | length) == 0 and
    ((.load_when.task_types // []) | length) == 0 and
    ((.load_when.skills // []) | length) == 0 and
    ((.load_when.languages // []) | length) == 0
  )] | length' "$INDEX_FILE")
```

**Call site 4 — Double-Loading Check (lines 196, 203):**

```bash
double_loaded=$(jq '[.entries[] | select(.tier == 3 and (.load_when.agents | length) > 0 and (.load_when.commands | length) > 0)] | length' "$INDEX_FILE")
```

Since `.tier` is `null` on all 187 entries: call site 1 prints `Tier ?` everywhere; call site 2
fails with 187 missing; call site 3's `.tier != 4` is vacuously true (`null != 4`) so the check
happens to work by accident; call site 4's `.tier == 3` is never true so the check is a silent
no-op that has never fired. **All four must be converted**, not just call site 2 — converting
only the named one leaves call site 4 dead and would let a real double-loading violation stay
invisible.

**Proposed derivation.** Define one jq function, reused at all four sites:

```jq
def derived_tier:
  if (.load_when.always // false) == true then 1
  elif ((.load_when.agents // []) | length) > 0 then 2
  elif (((.load_when.commands // []) | length) > 0
        or ((.load_when.task_types // []) | length) > 0) then 3
  else 4
  end;
```

Rules, in the description's order plus the undecided case:

| Condition | Tier |
|-----------|------|
| `always == true` | 1 |
| non-empty `agents` | 2 |
| non-empty `commands` or `task_types` only | 3 |
| **all hooks empty** | **4** (decided here) |

**The all-hooks-empty fallthrough: decided as Tier 4, with justification.** The description does
not name this case; it must be decided because 3 entries hit it today and S2's G6 proposal
deliberately adds 3 more. Options considered:

1. **Tier 4 (recommended).** Tier 4 already means "on-demand, never auto-loaded" in this
   codebase — that is exactly what the Dead Entry Check's `.tier != 4` exemption encodes, and it
   is exactly what G6's "loaded by an agent only if it greps for them" describes. Deriving 4
   makes the Dead Entry Check *self-satisfying*: every all-empty entry derives to 4, is exempted,
   and the check reports 0 forever.
2. **Error / no tier.** Would keep the Dead Entry Check meaningful but makes the Tier
   Classification Check unsatisfiable while any all-empty entry exists, so the verification bar
   could never pass without deleting `reference/artifact-templates.md`,
   `contracts/convergence.md`, and `contracts/orchestrator-discipline.md`.
3. **Tier 3.** Wrong on its face: an entry with no `commands` and no `task_types` is not loaded
   by a command or task type.

Option 1 is chosen. **Its cost must be stated in the plan**: deriving 4 from emptiness converts
the Dead Entry Check from a real check into a tautology, so the current 3 dead-entry violations
disappear by definition rather than by being fixed. To preserve the signal, the plan should
replace the Dead Entry Check with an explicit-intent check — an entry may be all-empty only if
it carries an authored marker (e.g. `"on_demand": true`, or a retained authored `tier: 4`),
and an all-empty entry *without* that marker is still reported. That keeps "someone forgot to
hook this file" distinguishable from "this file is deliberately grep-only", which is the whole
point of the check.

**Note on the Double-Loading Check after derivation.** Under `derived_tier`, an entry with
non-empty `agents` derives to Tier 2, so `derived_tier == 3 and agents|length > 0` is
*unsatisfiable* — the check becomes structurally dead rather than accidentally dead. The plan
should restate its intent directly, dropping the tier predicate:
`select((.load_when.agents|length) > 0 and (.load_when.commands|length) > 0)`. **Measured today
that predicate matches 49 of 187 entries** — so restating it turns a silent no-op into 49
findings at once. This is a behavior change the plan must own explicitly: either triage the 49
as a separate work item, or restate the check as a reported *warning* rather than a violation so
it does not block the verification bar. Folding it in silently would replace one dead check with
one that fails immediately.

### S5. The two broken `load_when.agents` values

Roster verification, three-way:

| Roster | Count |
|--------|-------|
| Agent names referenced by any `load_when.agents` in the source store | 68 |
| Agent `.md` files in `agent-system/extensions/*/agents/` | 76 |
| Agent `.md` files deployed to `.claude/agents/` | 16 |

Referenced-but-absent from the **source store**: **none** (all 68 resolve to a real file).
Referenced-but-absent from the **deployed** `.claude/agents/`, restricted to entries that
actually appear in the deployed `.claude/context/index.json`: exactly **two names**.

| # | Offending agent name | Source-store file | Entry `path` | Current `agents` array |
|---|----------------------|-------------------|--------------|------------------------|
| 1 | `cslib-research-hard-agent` | `agent-system/extensions/core/index-entries.json` | `contracts/adversarial-verification.md` | `["general-research-hard-agent", "cslib-research-hard-agent", "lean-research-hard-agent"]` |
| 2 | `lean-research-hard-agent` | same file, same entry | `contracts/adversarial-verification.md` | same |

Both broken values live in **one core entry**. The agents themselves exist
(`agent-system/extensions/cslib/agents/cslib-research-hard-agent.md`,
`agent-system/extensions/lean/agents/lean-research-hard-agent.md`, both declared in their
manifests' `provides.agents`) but the `cslib` and `lean` extensions are not loaded in this
deploy, so neither reaches `.claude/agents/`. Core, which *is* always loaded, names them anyway.

Other references to these two names are **not** defects and must be left alone — they live in
`lean/index-entries.json` and `cslib/index-entries.json`, which only enter the merged index when
those extensions are loaded, at which point the agents are deployed too:

- `cslib/index-entries.json` -> `project/cslib/standards/citation-conventions.md`
- `lean/index-entries.json` -> `contracts/context-hygiene.md`, `contracts/reference-grounding.md`,
  `contracts/anti-analysis.md`, `contracts/adversarial-verification.md`

**Recommended fix**: remove the two extension-owned names from the core entry, leaving

```json
"load_when": {"agents": ["general-research-hard-agent"], "commands": [], "task_types": []}
```

Rationale: core must be extension-agnostic. The established pattern for an extension to extend a
core-owned file's hooks is already in use — `lean/index-entries.json` declares its own entry for
the same `contracts/adversarial-verification.md` path with `agents: ["lean-research-hard-agent"]`.
Removal from core loses nothing for lean. For parity, `cslib/index-entries.json` should gain the
matching entry (`contracts/adversarial-verification.md`, `agents: ["cslib-research-hard-agent"]`);
it has no adversarial-verification entry today, so plain removal from core would otherwise
silently un-index that contract for cslib.

**Latent issue worth recording** (out of scope, no action proposed): the deployed index has zero
duplicate `path` values today, but core and lean both declare `contracts/adversarial-verification.md`.
Loading lean would produce two entries for one path. Whether the loader merges or appends was not
determined; the S5 fix incidentally removes one horn of it, and adding the cslib entry re-creates
it for a cslib+lean deploy. The plan should confirm loader dedup behavior before adding the cslib
entry.

### S6. Baseline validator run (before-state)

Command: `bash .claude/scripts/validate-context-budgets.sh`. Output verbatim:

```
=== Context Budget Validation ===
Index: /home/benjamin/.config/nvim/.claude/context/index.json

--- Agent Budget Check ---
Agent                                 Tokens      Cap       Status
-------------------------------------------------------------------
nix-research-agent                     19896     8000   OVER:11896
spawn-agent                             5568     8000           OK
general-research-agent                 28744     8000   OVER:20744
code-reviewer-agent                     5544     8000           OK
general-implementation-agent           56800     8000   OVER:48800
nix-implementation-agent               22520     8000   OVER:14520
planner-agent                          29200    15000   OVER:14200
neovim-research-agent                  22872     8000   OVER:14872
neovim-implementation-agent            40104     8000   OVER:32104
meta-builder-agent                    130360    15000  OVER:115360

--- Tier 1 Check ---
Always-loaded entries: 3 (target: 2)
Always-loaded total lines: 334 (target: ≤500)
Status: OK

--- Tier Classification Check ---
Total entries: 187
Entries with tier field: 0
Status: FAIL (187 entries missing tier field)

--- Dead Entry Check ---
Dead entries found: 3
  reference/artifact-templates.md (Tier ?)
  contracts/convergence.md (Tier ?)
  contracts/orchestrator-discipline.md (Tier ?)

--- Double-Loading Check ---
Tier 3 entries with both agents and commands: 0 -- OK

=== Summary ===
Violations: 10

FAIL: 10 violation(s) found
```

Exit code **1**. Ten violations: 8 per-agent budget overruns, 1 tier classification, 1 dead
entries.

## Decisions

1. **Use the prerequisite's section-5 grouping verbatim as the group structure** (found at
   report lines 213-235); concretize hook values per group rather than inventing new groups.
2. **Assign the one un-grouped entry** (`patterns/system-defect-discrimination.md`) to G2.
3. **All-hooks-empty derives to Tier 4**, and the Dead Entry Check is replaced with an
   explicit-intent check so the signal is not lost to a tautology.
4. **All four `.tier` call sites are converted**, not only the one named in the verification bar.
5. **G3 is command-scoped, not agent-enumerated**, contra the prerequisite's tentative
   suggestion, on budget grounds.
6. **The 123 figure is corrected to 86** in all downstream planning.

## Risks & Mitigations

- **The verification bar as written is not reachable by this task's work.** "Zero per-agent
  budget violations" requires eliminating 8 overruns totalling ~252k tokens of overshoot, driven
  by `load_when.agents` breadth across core+nvim+nix — a surface this task's `file_scope`
  (`core/index-entries.json`, `validate-context-budgets.sh`) only partly covers, and which
  `meta` trimming does not touch at all. *Mitigation*: the bar's own escape clause ("or each
  remaining violation carries a documented, deliberate cap change") is the intended path. The
  plan should either (a) raise the `CAPS` entries to measured post-work values with written
  justification per agent, or (b) explicitly re-scope the bar to "tier check passes via
  derivation + no *new* budget violations introduced". Option (b) is more honest; option (a) is
  what the bar literally licenses.
- **S2's work makes budgets worse, not better.** G1 (+331L) and G5 (+1,139L) both land on
  `general-implementation-agent`, already 48,800 tokens over. *Mitigation*: prefer
  command-scoping wherever a command genuinely reaches the consumer (G2, G3, G6 add zero); accept
  and document the G1/G5 increase, since correctness of the hook outranks the cap.
- **Deriving Tier 4 from emptiness silently retires a working check.** Covered above;
  mitigation is the explicit-intent marker.
- **The Double-Loading Check becomes unsatisfiable under derivation.** Restate its predicate
  without the tier term; treat any newly-surfaced matches as a finding to triage, not as a
  regression.
- **Dropping `"meta"` from all 86 entries could un-index a file some meta dispatch relies on.**
  *Mitigation*: the trimming rule only drops `"meta"` from entries that already carry another
  hook (61 of 86); the remaining 25 gain a hook first (S2) and lose `"meta"` second, never the
  reverse. Sequence the plan phases accordingly.

## Context Extension Recommendations

- **Topic**: `load_when` tier semantics. **Gap**: Tier 1-4 are referenced by
  `validate-context-budgets.sh` and by the prerequisite reports, but no context file defines what
  each tier means or how it is determined. **Recommendation**: fold a short "Tier semantics"
  section into `context/patterns/context-discovery.md`, or add
  `context/reference/index-tier-semantics.md`, stating the derivation table from S4 as the single
  authority once implemented.
- **Topic**: index census methodology. **Gap**: the 123-vs-86 error arose from a key-presence
  census being narrated as a value census. **Recommendation**: record the canonical jq predicates
  (key-present vs. non-empty vs. contains-value) alongside the schema contract so future censuses
  state which they used.

## Appendix

**Queries used** (all read-only, against the source store unless noted):

```bash
# meta-only entries, per extension
jq '[.entries[]? | select(((.load_when.always // false) == false)
    and ((.load_when.agents // []) | length == 0)
    and ((.load_when.commands // []) | length == 0)
    and ((.load_when.task_types // []) == ["meta"]))] | length' */index-entries.json

# key-presence vs non-empty vs contains-"meta" (the 123/126/86 reconciliation)
jq '{has_key:   ([.entries[]|select(.load_when|has("task_types"))]|length),
     key_empty: ([.entries[]|select((.load_when|has("task_types")) and ((.load_when.task_types|length)==0))]|length),
     contains:  ([.entries[]|select((.load_when.task_types//[])|index("meta"))]|length)}' \
  agent-system/extensions/core/index-entries.json

# meta-builder-agent resolved context (adaptive OR query), merged deploy index
jq '[.entries[] | select(((.load_when.always//false)==true)
     or ((.load_when.agents//[])|index("meta-builder-agent"))
     or ((.load_when.task_types//[])|index("meta"))
     or ((.load_when.commands//[])|index("/meta")))]
    | {n: length, lines: ([.[].line_count // 0]|add)}' .claude/context/index.json

# broken agent-name detection (deployed scope)
comm -23 <(jq -r '.entries[].load_when.agents//[]|.[]' .claude/context/index.json | sort -u) \
         <(ls .claude/agents/*.md | xargs -n1 basename | sed 's/\.md$//' | sort -u)
```

**References**:
- `specs/archive/987_context_budget_enforcement_and_index_schema/reports/01_context-budget-schema-reconciliation.md`
  — section 2 (field-usage census, origin of the 123 figure), section 5 (the thematic grouping,
  lines 172-240), section 6 (Tier-1 bloat).
- `specs/archive/990_index_entries_schema_migration/reports/01_index-entries-schema-migration.md`
  — schema migration context; contains no meta-count figures.
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` — 228 lines, four `.tier`
  call sites at lines 118, 147/158, 168/183, 196/203.

# Research Report: Task #1002

**Task**: 1002 - Author the context tier-semantics standard for the derived tier classification
**Started**: 2026-08-10T06:00:00Z
**Completed**: 2026-08-10T06:12:00Z
**Effort**: Small (single new standards file + one index entry + one comment pointer)
**Dependencies**: Task 991, Task 998 (both already resolved into the current codebase state; no
open blocking work remains for this task's research)
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), specs/state.json, specs/TODO.md,
live run of validate-context-budgets.sh
**Artifacts**:
- This report: `specs/1002_context_tier_semantics_doc/reports/01_context-tier-semantics.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The tier-derivation rule (Tier 1-4, keyed on `load_when` shape) is fully implemented and
  load-bearing inside `agent-system/extensions/core/scripts/validate-context-budgets.sh`'s
  `DERIVED_TIER` jq function (lines 62-89), but has **zero** documentation anywhere a human or
  agent would find it outside that one script's header comment. A repo-wide grep for
  `derived_tier` / `context-tier-semantics` confirms no cross-reference exists today.
- `context/index.schema.json`'s entry `$comment` (lines 36 and 128) already states, in prose, that
  `tier` was deliberately removed and is meant to be derived from `load_when` shape, and that
  `on_demand` exists precisely because deriving Tier 4 from emptiness would otherwise make the Dead
  Entry Check a tautology. This is the authoritative rationale to surface in the new doc, not
  re-derive independently.
- The natural, precedented home is `context/standards/context-tier-semantics.md` (peer of
  `standards/status-markers.md`, which plays the identical "human-readable gloss over a
  machine-readable source of truth" role for the task-status enum).
- The new file should be indexed as **Tier 4 (on_demand: true, all `load_when` hooks empty)** —
  every existing `on_demand:true` entry in `index-entries.json` already follows this exact pattern
  (empty `agents`/`commands`/`task_types`), and every one of the 10 tracked agents is *already*
  over its context budget cap (confirmed by a live run of `validate-context-budgets.sh`), so any
  non-empty hook would strictly worsen an already-failing budget. This choice is also thematically
  apt: a doc about tier semantics can itself be the worked example of "why an entry lands in Tier
  4."
- Recommended `line_count` is in the 150-220 range based on comparable narrow-topic standards docs
  (`postflight-tool-restrictions.md`: 216 lines; `orchestrator-runtime-files.md`: 272 lines) — the
  exact final number must be set from `wc -l` on the actual written file (Rule R requires an exact
  match, not an estimate).

## Context & Scope

Task 1002 asks for a new context standards file documenting the tier-classification semantics for
`context/index.json` entries, plus the accompanying index entry and a pointer comment from the
`derived_tier` function back to the new doc. `file_scope` is exactly two files:
`agent-system/extensions/core/context/standards/context-tier-semantics.md` (new) and
`agent-system/extensions/core/index-entries.json` (add one entry). A third touch —
`validate-context-budgets.sh`'s header comment, to point at the new file — is explicitly named in
the task's WORK item 4 even though it falls outside the two-file `file_scope`; the plan/implement
stage should treat that comment edit as in-scope despite the narrower `file_scope` listing, since
the task description itself requires it ("Point the derived_tier function's header comment at the
new file so the two do not drift").

This is a documentation-only task: the derivation logic itself is correct and already deployed
(confirmed live) and is explicitly **not** to be changed.

## Findings

### Codebase Patterns

**The derivation rule, verified directly from source** (`validate-context-budgets.sh` lines 81-89):

```
Tier 1: load_when.always == true                                    (always loaded)
Tier 2: non-empty load_when.agents                                  (agent-scoped)
Tier 3: non-empty load_when.commands or load_when.task_types        (command/task-type-scoped)
Tier 4: else (every load_when hook empty)                           (on-demand fallthrough)
```

This is a **first-match-wins, total, exhaustive** function over four cases — every entry
classifies, there is no fifth "unclassified" bucket (the script's own "Tier Classification Check"
treats non-classification as impossible by construction and would only fire on a jq bug).
Live run against the currently deployed `.claude/context/index.json` (189 entries) reports
`Tier 1: 3, Tier 2: 147, Tier 3: 33, Tier 4: 6` — close to, but not byte-identical with, the
task description's stated snapshot (`Tier 1: 3, Tier 2: 144, Tier 3: 34, Tier 4: 6`, 187 entries).
This is expected drift between the deployed tree and the moment the task was written, not a
discrepancy the new doc needs to freeze — the doc should describe the **rule**, not hardcode a
point-in-time count (if a distribution snapshot is wanted for illustration, mark it explicitly as
an example, not a live invariant).

**Precedence order matters and should be stated explicitly in the new doc**: an entry with both
`load_when.always == true` AND a non-empty `agents[]` lands in Tier 1 (first match wins), not Tier
2. In practice no entry does this today, but the rule table's ordering is part of the semantics
and a future entry author needs to know Tier 1 dominates.

**The schema-side rationale already exists and should be quoted/paraphrased, not reinvented**
(`context/index.schema.json` entry `$comment`, lines 36-... and the `on_demand` property
description at line 128):
- `tier` was removed from the schema (not merely undocumented) because "no entry in practice ever
  populated it accurately" — `additionalProperties: false` makes an authored `tier` key
  schema-illegal, not just discouraged.
- `on_demand` exists **because of** Tier 4's fallthrough-on-emptiness design: without an explicit
  marker, "never auto-loaded" (Tier 4) and "someone forgot to hook this up" (also, mechanically,
  Tier 4) would be indistinguishable, collapsing the Dead Entry Check into a tautology. Setting
  `on_demand: true` is the author's explicit statement of intent that an entry is *deliberately*
  reachable only via grep/explicit Read.

**The Dead Entry Check's actual predicate** (`validate-context-budgets.sh` lines 217-227,
`DEAD_PRED`) is independent of the derived tier value — it fires when every `load_when` hook is
empty AND `on_demand` is not `true`, regardless of tier. The new doc should be precise that "Tier
4" and "the Dead Entry Check" are related-but-distinct: Tier 4 is a classification outcome,
`on_demand` is the escape hatch that keeps the *check* meaningful despite that classification.
This distinction is exactly what task WORK item 2 asks the new doc to cover, and it is the most
likely point of future author confusion (an author might think setting `on_demand:true` changes
an entry's tier — it does not; a Tier-4-classified entry with `on_demand:true` is still Tier 4, it
is just no longer flagged dead).

**Precedented doc home and style**: `context/standards/status-markers.md` is the closest structural
analogue — both documents are a "human-readable gloss over a machine-derived/schema-driven source
of truth," and `status-markers.md` states this relationship explicitly in its own "Single source"
section (lines 19-26): *"This document is the authoritative human-readable gloss over that pair
... not an independent third source. If this document and the schema/library ever disagree, the
schema/library wins."* The new file should open with an equivalent framing: the
`derived_tier` jq function in `validate-context-budgets.sh` is the single source of truth; this
document explains and motivates it, and if they disagree the script wins.

**Existing `on_demand:true` entries as the load_when precedent** — every current on-demand entry
(`reference/artifact-templates.md`, `reference/workflow-diagrams.md`, `routing.md`,
`validation.md`, `contracts/convergence.md`, `contracts/orchestrator-discipline.md`) has **all
three** `load_when` arrays empty (`agents: []`, `commands: []`, `task_types: []`) alongside
`on_demand: true`. There is no partial pattern (e.g. narrow `commands[]` plus `on_demand`) in the
codebase today — the new entry should follow this exact, uniform shape.

**Budget headroom, verified live**: running
`bash .claude/scripts/validate-context-budgets.sh` shows all 10 tracked agents already **over**
their cap (e.g. `meta-builder-agent`: 132,960 / 15,000 cap, over by 117,960;
`general-implementation-agent`: 68,568 / 8,000 cap, over by 60,568). This is the standing defect
that Task 999 (declared dependent on this task in TODO.md's dependency wave table) exists to fix.
Because every candidate agent is already failing, adding this entry to **any** agent's `agents[]`
hook — even meta-builder-agent, the most plausible candidate since it is the agent that edits
`context/index-entries.json` and `context/index.schema.json` — would mechanically worsen an
already-red number with zero counterbalancing benefit, and the task description's own admonition
("a load_when hook narrow enough not to worsen any agent's budget") is best satisfied by the empty,
`on_demand: true` shape rather than by any narrow-but-nonempty hook.

**`check-extension-docs.sh` verification gates named in the task's VERIFICATION BAR**:
- **Rule R** (source `line_count` accuracy, lines 600-641): the new entry's `line_count` must
  exactly equal the actual line count of the written file, or the check fails with a mismatch
  report. This must be computed from the final file with `wc -l`, not estimated in the plan.
- **Rule T** (schema conformance, lines 664-726): the new entry must have `path`, `domain`,
  `subdomain`, `summary` (≤200 chars), `line_count`; must not use forbidden keys `description` or
  `tags`; and `load_when` (if present) must use only `agents`/`commands`/`task_types`/`always`.

### External Resources

None consulted — this is a pure codebase-documentation task with no external dependency; all
authority lives in the local script, schema, and sibling standards docs already surveyed above.

### Recommendations

1. **File location and identity**: `agent-system/extensions/core/context/standards/context-tier-semantics.md`,
   domain `core`, subdomain `standards` (matches every sibling file in that directory).

2. **Content outline** (mirrors `status-markers.md`'s proven shape: definitions section, then
   rationale, then a table, then cross-references):
   - Header stating single-source-of-truth relationship to `validate-context-budgets.sh`'s
     `DERIVED_TIER` jq function (script wins on disagreement).
   - The four-tier rule table, in first-match-wins order, each with the exact `load_when`
     predicate and its operational meaning (when in an agent's session the entry actually loads).
   - Why the authored `tier` field was abandoned, quoting/paraphrasing `index.schema.json`'s entry
     `$comment` and citing its `additionalProperties: false` enforcement.
   - The `on_demand` marker: what it is for, why it exists specifically as a consequence of Tier
     4's fallthrough-on-emptiness design, and — the single most actionable guidance for a future
     entry author — a concrete decision rule for when to set it ("set `on_demand: true` if and
     only if all four `load_when` arrays are empty by deliberate design, i.e., the file is meant to
     be discoverable only via grep or explicit Read, never through automatic loading; leaving it
     unset on an all-empty entry is a Dead Entry Check violation, not a lesser tier").
   - A short worked example: this very file's own index entry (Tier 4, `on_demand: true`) as a
     self-referential illustration.
   - Cross-reference to `context/patterns/context-discovery.md`'s "Hook-Shape Policy" section
     (agents[] vs commands[] vs both) as the companion doc for *which* hook to use when an entry is
     NOT on-demand — the two documents are adjacent but answer different questions (tier doc:
     "what tier does this shape produce and what does on_demand mean"; discovery doc: "which shape
     should I author for a given loading intent").
   - Pointer noting that `validate-context-budgets.sh`'s comment above `DERIVED_TIER` links back to
     this file (satisfies WORK item 4 bidirectionally).

3. **Index entry** (append to `agent-system/extensions/core/index-entries.json`'s `entries`
   array):
   ```json
   {
     "path": "standards/context-tier-semantics.md",
     "domain": "core",
     "subdomain": "standards",
     "summary": "Derived tier classification (1-4) for context index entries: rule, rationale, on_demand marker",
     "line_count": <exact wc -l of final file>,
     "keywords": ["tier", "derived_tier", "on_demand", "index.json", "load_when", "context-budget"],
     "topics": ["context-architecture"],
     "load_when": {
       "agents": [],
       "commands": [],
       "task_types": []
     },
     "on_demand": true
   }
   ```
   `summary` is comfortably under the 200-char schema cap. `on_demand: true` must be set explicitly
   — omitting it on an all-empty-hooks entry is exactly what the Dead Entry Check flags as a
   violation (confirmed live: `dead_count` is currently 0 across the deployed index, and adding an
   all-empty entry without the marker would immediately break that to 1).

4. **`validate-context-budgets.sh` header comment** (WORK item 4): add a one-line pointer inside
   the existing `# --- Tier derivation ---` comment block (around line 62-70, before or after the
   existing prose) naming the new file's path, e.g. append: `"See
   context/standards/context-tier-semantics.md for the full human-readable rationale and the
   on_demand decision rule; this comment states the rule, that file explains it."` This is a
   comment-only edit inside a shell script and carries no execution-behavior risk.

5. **Verification sequence for the implementer**: write the file, `wc -l` it, insert the matching
   `line_count` into the index entry, run
   `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (or its deployed
   equivalent) to confirm Rules R and T pass, then run
   `bash .claude/scripts/validate-context-budgets.sh` (or the source-store script directly against
   a test index) to confirm the tier distribution changes by exactly one Tier-4 entry and zero
   budget lines change (since the new entry carries no `agents`/`commands`/`task_types` hook, no
   agent's token total can move).

## Decisions

- **Doc location**: `context/standards/context-tier-semantics.md` — decided by direct precedent
  (`status-markers.md` plays an identical "human-gloss over machine-truth" role) and by the task
  description's own suggestion ("a standards/ file under core context is the natural home").
- **load_when shape**: all-empty + `on_demand: true` (Tier 4 / on-demand) — decided because (a) it
  is the uniform pattern for every existing on-demand entry in the index, (b) every tracked agent
  is already over budget so any nonempty hook strictly worsens a red number, and (c) the content is
  reference material consulted only when authoring or auditing index entries, not needed
  automatically during ordinary agent work.
- **Do not touch the derivation logic**: the task is documentation-only; `DERIVED_TIER` in
  `validate-context-budgets.sh` is treated as correct and frozen for this task's scope.

## Risks & Mitigations

- **Risk**: `line_count` mismatch at write time (Rule R gate). **Mitigation**: compute `wc -l` on
  the actual final file content immediately before writing the index entry; do not estimate from
  this report's outline.
- **Risk**: forgetting `on_demand: true` on the new all-empty entry, silently turning it into a
  Dead Entry Check violation and breaking `validate-context-budgets.sh`'s exit code.
  **Mitigation**: explicit reminder above; the implementer should re-run the budget script after
  writing the entry and confirm `Dead entries: 0`.
- **Risk**: the file drifts from the script if `DERIVED_TIER`'s rule table is ever changed without
  updating this doc. **Mitigation**: the doc explicitly declares the script as the single source of
  truth (mirroring `status-markers.md`'s own pattern) and the script's header comment is pointed
  back at the doc, so the two are mutually discoverable even if a future edit updates only one.
- **Risk (sequencing, named in the task itself)**: this file lands in core `context/`, which a
  separate "docs truth sweep" task also claims wholesale. Per the task description, this task is
  deliberately not gated behind that sweep; if both are in flight, the sweep should treat this new
  file as current truth rather than re-deciding its content.

## Context Extension Recommendations

None beyond the gap this task itself closes — the task's own premise (no context file documents
`derived_tier`) is the gap, and this task's deliverable is the fix. No further undocumented topics
were surfaced during this research pass.

## Appendix

**Files read**:
- `agent-system/extensions/core/scripts/validate-context-budgets.sh` (full)
- `agent-system/extensions/core/context/index.schema.json` (full)
- `agent-system/extensions/core/context/standards/status-markers.md` (full, as style precedent)
- `agent-system/extensions/core/context/patterns/context-discovery.md` (Hook-Shape Policy section)
- `agent-system/extensions/core/context/README.md` (directory structure section)
- `agent-system/extensions/core/index-entries.json` (queried via `jq` for standards/ and
  `on_demand:true` entries)
- `specs/TODO.md` (task 1002's full description and dependency wave table)

**Commands run**:
- `bash .claude/scripts/validate-context-budgets.sh` (live budget/tier-distribution snapshot)
- `jq` queries against `index-entries.json` and deployed `.claude/context/index.json`
- `grep -rn "derived_tier\|context-tier-semantics"` across `agent-system/` (zero pre-existing
  cross-references, confirming the documented gap is real)
- `grep -rln "Tier 1\|Tier 2\|Tier 3\|Tier 4"` across `agent-system/` (confirmed no unrelated
  "tier" usage collides with this concept's naming)

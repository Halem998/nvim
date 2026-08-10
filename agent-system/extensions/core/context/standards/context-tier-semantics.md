# Context Tier Semantics Standard

**Created**: 2026-08-10
**Purpose**: Explain the derived tier classification (1-4) that `validate-context-budgets.sh`
computes for every `index.json` entry, and the `on_demand` marker that keeps the Dead Entry Check
meaningful once Tier 4 is a fallthrough rather than an authored claim.
**Audience**: Context authors, `/meta` agent, system maintainers

---

## Single Source of Truth

The `derived_tier` jq function inside `validate-context-budgets.sh`'s `DERIVED_TIER` block (see
its `# --- Tier derivation ---` comment) is the authoritative definition of tier classification.
This document explains and motivates that function; it does not redefine it. If this document and
the script ever disagree, **the script wins** — treat any mismatch here as a documentation bug to
fix, not as license to reinterpret the script's behavior.

This is the same "human-readable gloss over a machine-readable source of truth" relationship that
`context/standards/status-markers.md` establishes for the task-status enum, glossing
`context/schemas/state-schema.json` and `scripts/lib/status-vocabulary.sh` in exactly the same
spirit: prose for understanding, script for truth.

## Why Tier Is Derived, Not Authored

Earlier revisions of the entry schema allowed an author to write a `tier` field directly.
`context/index.schema.json`'s entry `$comment` records why that was abandoned: no entry in
practice ever populated `tier` accurately. Authors default-guessed, copy-pasted from a
neighboring entry, or never updated it after `load_when` changed underneath it, so the field
drifted from the loading behavior it was supposed to describe.

The fix was structural, not just a style guideline: `tier` is not merely discouraged, it is
**schema-illegal**. The entry shape sets `additionalProperties: false`, so an authored `tier` key
fails schema validation outright rather than silently surviving as stale metadata. Tier is instead
computed algorithmically from the shape of `load_when` every time a script needs it — it cannot go
stale because it is never stored.

## The Four-Tier Rule Table

`derived_tier` evaluates the cases below **in order, first match wins**, over the entry's
`load_when` object. The evaluation is total: every entry lands in exactly one tier, because case 4
is an unconditional fallthrough.

| Tier | Predicate (on `load_when`) | Operational meaning |
|------|-----------------------------|----------------------|
| 1 | `always == true` | Loaded into every agent's session unconditionally, regardless of which agent, command, or task type is active. The broadest and most expensive reach; use sparingly. |
| 2 | `agents` non-empty | Loaded whenever one of the listed agents is dispatched, independent of which command triggered that dispatch. |
| 3 | `commands` or `task_types` non-empty | Loaded whenever one of the listed commands runs, or whenever a task of one of the listed types is active — but not tied to a specific agent. |
| 4 | every hook empty (`always` unset/false, `agents`/`commands`/`task_types` all empty) | Never auto-loaded by any hook. Reachable only on demand: an agent greps for it, or a human/agent explicitly `Read`s the path. This is the fallthrough case, not an authored claim. |

### Precedence Is Real, Not Incidental

The first-match-wins order means an entry with `load_when.always == true` **and** a non-empty
`load_when.agents` still lands in Tier 1, not Tier 2 — `always` dominates unconditionally once
present. No entry in the index does this today, but the ordering is part of the semantics a future
author needs to know: adding `agents` to an already-`always`-true entry has zero effect on its
tier or its load reach, since `always: true` already causes it to load everywhere those agents
would have triggered it anyway.

The same reasoning applies going down the table: Tier 2's predicate is only reached once Tier 1's
predicate has already failed, and so on through Tier 3 into the Tier 4 fallthrough. There is no
case where an entry matches more than one tier's predicate and the "wrong" one is chosen — the
order removes that ambiguity by construction.

## `on_demand`: Why It Exists and When to Set It

Before tier was derived, "all `load_when` hooks are empty" and "never actually loaded" were the
same fact, so a Dead Entry Check could flag such entries directly. Once Tier 4 became a derived
fallthrough on emptiness, that equivalence broke: **every** Tier 4 entry now trivially satisfies
"all hooks empty" by definition, which would make a naive dead-entry predicate fire on every Tier
4 entry uniformly — including ones that are legitimately, deliberately grep-only or Read-only by
design. A check that always fires on an entire tier is not a check; it is a tautology.

`on_demand` is the fix: an explicit-intent marker, independent of tier, that an entry's author
sets to declare "I meant for this entry to have no automatic load hook." `context/index.schema.json`
describes it precisely: it exempts an all-hooks-empty entry from the Dead Entry Check, and its
absence on such an entry is treated as the intended dead-entry signal, not a false positive to
suppress after the fact.

**Decision rule for a future author**: set `on_demand: true` if and only if all three
`load_when` arrays (`agents`, `commands`, `task_types`) are empty **by deliberate design** — the
file is meant to be discoverable only via grep or an explicit `Read`, never auto-injected into any
agent's context. If you leave `on_demand` unset (or `false`) on an entry whose hooks are all
empty, that is not a lesser tier or a softer classification — it is exactly the condition the Dead
Entry Check exists to catch, and the entry will be reported as dead.

## Tier 4 vs. the Dead Entry Check: Two Independent Axes

The most common point of confusion for a future entry author is believing that `on_demand: true`
**changes** an entry's tier. It does not, on either axis:

- **Tier** is a classification outcome, computed once from `load_when` shape. An entry with all
  hooks empty is Tier 4 whether or not `on_demand` is set. Setting `on_demand` does not move it to
  some other tier — there is no "Tier 4, but exempted" tier; Tier 4 is Tier 4.
- **`on_demand`** is an intent marker consumed only by the Dead Entry Check's predicate, which is
  independent of the derived tier value. Its sole effect is whether that specific check flags the
  entry — it does not feed back into `derived_tier` at all, and no other tier-consuming site reads
  it.

In short: `on_demand: true` on a Tier 4 entry stops it from being flagged dead. It does not, and
cannot, reclassify the entry into a different tier.

## Worked Example: This File's Own Index Entry

This document's own `index-entries.json` entry is a direct, self-referential illustration of the
rule above. It carries `load_when: { "agents": [], "commands": [], "task_types": [] }` and
`on_demand: true`. Walking it through the rule table:

- `load_when.always` is unset -> Tier 1 predicate fails.
- `load_when.agents` is empty -> Tier 2 predicate fails.
- `load_when.commands` and `load_when.task_types` are both empty -> Tier 3 predicate fails.
- All hooks are empty -> Tier 4 by fallthrough.

Because that emptiness is deliberate — this is a standards document meant to be found by an
author grepping for tier/`on_demand` guidance or navigating from `context-discovery.md`, not
content any agent needs preloaded into its budget — the entry sets `on_demand: true`, which keeps
it out of the Dead Entry Check's flagged set.

## Related Document: Which Shape to Author

This document answers "what tier does a given `load_when` shape produce, and what does
`on_demand` mean." It deliberately does not re-cover which shape (`agents[]` vs. `commands[]` vs.
both) an author should choose for a given loading intent — that question, including when using
both hooks together is legitimate versus redundant, is the `context/patterns/context-discovery.md`
"Hook-Shape Policy: `agents[]` vs. `commands[]` vs. Both" section's job. Read that section first
when deciding how to hook a new entry; read this document when interpreting what tier the result
lands in and how to handle the on-demand case.

## Cross-Reference Back to the Script

`validate-context-budgets.sh`'s `# --- Tier derivation ---` comment block, immediately preceding
the `DERIVED_TIER` assignment, names this file in turn — the two are mutually discoverable from
either direction, so a future change to the derivation logic has a documented place to update
prose, and a future reader of either can find the other.

## A Note on Distribution Counts

Any tier-distribution counts (how many entries currently fall into each tier) are a live,
constantly shifting property of `index.json` as entries are added, removed, or re-hooked — never a
frozen invariant of the classification rule itself. This document intentionally omits point-in-time
counts. To see the current distribution, run `validate-context-budgets.sh` directly against the
index you care about; treat any number reported there as a snapshot, not a fact to encode here.

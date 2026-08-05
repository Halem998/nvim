# Research Report: Migrate All 19 Extensions' index-entries.json to the Reconciled Schema

- **Task**: 990 - index_entries_schema_migration
- **Started**: 2026-08-05T00:00:00Z
- **Completed**: 2026-08-05T00:00:00Z
- **Effort**: ~1.5 hours (empirical jq audit across 19 extensions, live check-extension-docs.sh run)
- **Dependencies**: 987 (context_budget_enforcement_and_index_schema, status completed — landed the
  reconciled `index.schema.json` and `check-extension-docs.sh` Rule T in `advisory` mode)
- **Sources/Inputs**: `agent-system/extensions/*/index-entries.json` (all 19), the source-store
  copy of `agent-system/extensions/core/context/index.schema.json`, the source-store copy of
  `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule T implementation, lines
  644–730), each of the 12 migration-map extensions' `manifest.json` `routing` block, a live run
  of `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`, and the
  prerequisite task's research report
  (`specs/987_context_budget_enforcement_and_index_schema/reports/01_context-budget-schema-reconciliation.md`,
  particularly its §2 and §4 field-usage/migration tables)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Context & Scope

Task 987's Phase A already landed: `index.schema.json` now declares the reconciled entry shape
(`path`/`domain`/`summary`/`line_count` required; `subdomain`/`topics`/`keywords`/`load_when`
optional; `additionalProperties: false` closes both the entry and the `load_when` object), and
`check-extension-docs.sh` already implements Rule T (`check_index_entries_schema`) gated by
`SCHEMA_CONFORMANCE_GATE_MODE` (default `advisory`). This task is the migration itself — editing
all 19 extensions' *source* `index-entries.json` files (in `agent-system/extensions/**`, never
`.claude/**`) to stop tripping Rule T, per the five WORK items in the task description, so the
gate can eventually be promoted `advisory` -> `hard` in a follow-up task (not this one).

A live run of `check-extension-docs.sh` was used as ground truth for scope, rather than trusting
the task description's own summary numbers — this surfaced several material corrections, detailed
below.

## Findings

### Confirmed: the "17 of 19" correction is exactly right

Per-extension Rule T violation counts (any entry with `description`, `tags`, or a forbidden
`load_when` key):

```
core:      9/130   cslib:  16/16   email:    1/8    epidemiology: 0/15 (clean)
filetypes: 11/11   formal: 46/46   founder: 34/34   latex:  10/10
lean:      31/31   literature: 6/6   memory:   8/8   nix:    11/11
nvim:      23/24   present: 26/36   python:   6/6    slidev:  0/15 (clean)
typst:     26/26   web:    23/23   z3:        5/5
```

17 of 19 extensions violate Rule T today; only `epidemiology` and `slidev` are clean. This matches
the task description's correction exactly (not the prerequisite's original 14-extension
hypothesis). The live gate currently emits **580 total advisory lines**, all `advisory`-mode
(`SCHEMA_CONFORMANCE_GATE_MODE` defaults `advisory`; exit code 0 today), broken down as:
`load_when.languages` 275, `description` 147, `tags` 94, `load_when.topics` 40, `load_when.skills`
24. These five categories sum to 580, confirming Rule T flags nothing else — no missing
required field and no invalid `domain` enum value exist anywhere in the 470-entry corpus today.

### Correction 1: description-bearing entry count is 147, not 166

The task description's WORK item 1 states "166 description-bearing entries." The live,
per-extension count across the 10 named extensions is:

```
cslib 16 + email 8 + filetypes 11 + latex 10 + lean 31 + nix 11 + python 6 + typst 26 + web 23 + z3 5 = 147
```

147 matches Rule T's own live "forbidden key 'description'" advisory count exactly (147). The
plan/implementation should treat **147** as the true entry count for WORK item 1, not 166.

### Correction 2: `tags` exists in only 6 of the 10 named extensions, not all 10

WORK item 2 says "rename tags to keywords (same 10 extensions)" (implying cslib, email,
filetypes, latex, lean, nix, python, typst, web, z3 all carry `tags`). The live data shows only
**6** of those 10 extensions actually have a `tags` field on any entry — `cslib` (16), `latex`
(10), `lean` (31), `python` (6), `typst` (26), `z3` (5), totaling **94** entries (matches Rule T's
live "forbidden key 'tags'" count exactly). **`email`, `filetypes`, `nix`, and `web` carry
`description` but never `tags`** — WORK item 2 is a no-op for those four extensions, not an error
to chase. No entry anywhere already has both `tags` and `keywords` populated, so the rename is a
clean, conflict-free `tags -> keywords` key rename for the 6 extensions where it applies.

### Correction 3: the summary 200-char cap makes WORK item 1 genuinely editorial, not just "usually"

Spot-checking is not the only evidence that folding `description` into `summary` is editorial:
several entries' `description` + `summary` combined length already exceeds the schema's
`summary.maxLength: 200` constraint, meaning a naive concatenation is not just stylistically bad
but schema-invalid. Concrete over-200-combined-length examples requiring real compression:

| Extension | Path | `description` len | `summary` len | combined |
|---|---|---|---|---|
| email | `domain/staleness-detection.md` | 359 | 150 | 509 |
| lean | `contracts/context-hygiene.md` | 121 | 273 | 394 |
| lean | `contracts/adversarial-verification.md` | 148 | 240 | 388 |
| email | `domain/wrapper-contracts.md` | 250 | 85 | 335 |
| lean | `contracts/reference-grounding.md` | 80 | 191 | 271 |
| lean | `contracts/anti-analysis.md` | 107 | 179 | 286 |
| email | multiple others (`email-preferences.md`, `archive-mode-risk.md`, `bulk-bucket-review.md`, `design/email-to-memory-preferences.md`) | — | — | 205–236 |

At least 9 entries across `email` and `lean` need the merged summary to be an actual rewrite
(picking/compressing the more informative phrasing), not concatenation. Some `lean` entries even
have `summary` *longer* than `description` already (e.g. `context-hygiene.md`: summary 273 chars
is itself already over the 200 cap and must shrink regardless of `description`). The plan should
budget real editorial time here, not a scripted merge.

### Correction 4: WORK item 5's "already carries non-empty commands" premise has one exception

WORK item 5 claims literature's 6 and memory's 8 `load_when.skills` entries are safe to delete
because "both extensions' entries already carry non-empty commands ... on the same entries." This
holds for all 6 literature entries and 7 of memory's 8 entries. **One entry is the exception**:

```json
// project/memory/memory-troubleshooting.md
"load_when": {
  "skills": ["skill-learn", "skill-distill"]
}
```

This entry has **no** `agents`, `commands`, `task_types`, or `always` — `skills` is its *only*
reachability hook. A blind delete per WORK item 5 orphans this entry (post-delete
`load_when: {}` matches nothing in `context-discovery.md`'s adaptive query). Every sibling memory
entry that only carries `skill-learn`-style single-skill hooks also carries a matching `commands`
array (e.g. `learn-usage.md` has `commands: ["/learn"]`); the natural, minimally-invasive fix is
to give `memory-troubleshooting.md` a `commands: ["/learn", "/distill"]` array (mirroring
`domain/memory-reference.md`'s and `README.md`'s pattern, which already pair those two skills with
those two commands) at the same time its `skills` array is deleted, not simply delete-and-move-on.

### Correction 5: `core` and `email` are also in scope for `load_when.skills` deletion, not just literature/memory

The task description's own "CORRECTION" paragraph already establishes that `core`'s 9 entries are
part of the true 17-extension scope (the "load_when.skills violation the 14-count did not
enumerate"), but WORK item 5's explicit instruction text names only literature and memory. To hit
the verification bar (`grep -rn 'load_when.skills'` returns zero across **all**
`agent-system/extensions/*/index-entries.json`), `core`'s 9 entries and **one entry in `email`**
not named anywhere in the WORK items must also be resolved:

- **`email`**: 1 entry, `project/email/design/email-to-memory-preferences.md`, has
  `load_when: {agents: [], languages: [], task_types: ["email"], skills: [...], commands: []}`.
  Safe to delete `skills` outright — `task_types: ["email"]` already provides reachability.
- **`core`**: 9 entries. 8 are safe to delete `skills` outright, since each also carries a
  populated `agents` and/or `commands` array providing continued reachability
  (`patterns/batch-drain-loop.md`, `patterns/context-exhaustion-detection.md`,
  `patterns/context-protective-lead.md`, `patterns/subagent-continuation-loop.md`,
  `patterns/task-lock.md`, `patterns/topic-assignment-pattern.md`,
  `standards/git-staging-scope.md`, `standards/orchestrator-runtime-files.md`). **One is not
  safe**: `patterns/lit-stage4a-flow.md` has
  `load_when: {skills: [skill-planner, skill-researcher, skill-planner-hard,
  skill-researcher-hard, skill-implementer-hard, skill-implementer], task_types: []}` — an empty
  `task_types` array matches nothing (the adaptive `any(...)` query is vacuously false on `[]`),
  and there is no `agents`/`commands` fallback. Deleting `skills` here orphans the file. The
  natural replacement is an `agents` array naming the agents that run those six skills
  (`general-research-agent`, `general-research-hard-agent`, `general-implementation-agent`,
  `general-implementation-hard-agent`, `planner-agent`, `planner-hard-agent`), mirroring how
  `subagent-continuation-loop.md` already expresses the same kind of skill-implied reachability
  via `agents`. The stray empty `task_types: []` should also be dropped (an empty array is inert
  and adds noise).

### Correction 6: `formal`'s 40 `load_when.topics` entries are a real Rule T violation not covered by any WORK item

`formal/index-entries.json`'s 46 entries never use `description`/`tags`, but 40 of them nest a
`topics` array **inside `load_when`** rather than at the entry's top level:

```json
"load_when": {
  "agents": ["logic-research-agent", "formal-research-agent"],
  "languages": ["logic", "formal"],
  "topics": ["modal", "kripke", "semantics", "accessibility"]
}
```

`load_when.topics` is not one of the four allowed `load_when` keys
(`agents`/`commands`/`task_types`/`always`), so Rule T flags it (40 of the 580 total advisory
lines). This is distinct from WORK item 3's `languages -> task_types` rename and is **not
mentioned anywhere in the task's five WORK items**, yet it is required to satisfy the verification
bar ("zero Rule T advisories across all 19 extensions"). `topics` *is* a valid, already-declared
**entry-level** field (`index.schema.json`'s `$defs.entry.properties.topics`, "Semantic topics
covered by this file"), and `formal`'s entries currently have no entry-level `topics` field at
all — so the correct fix is to **hoist** each entry's `load_when.topics` array up to a top-level
`entries[i].topics` array (not delete the data; these are meaningful search keywords), while
deleting the nested `load_when.topics` key. This is additional migration work the plan should add
as an explicit sub-item alongside WORK item 3 for `formal` specifically.

### Confirmed: WORK item 3's per-extension languages->task_types value map (§4 of the prerequisite report)

Verified live against each extension's `manifest.json` `routing` block — the 1:1 mapping in the
prerequisite report's §4 table is accurate for all 12 extensions:

| Extension | `languages` value(s) | -> `task_types` value(s) |
|---|---|---|
| cslib | `cslib` | `cslib` |
| formal | `formal` (46), `logic` (23), `math` (22), `physics` (3) | unchanged strings; manifest routing keys are `formal`, `formal:logic`, `formal:math`, `formal:physics` — see open question below |
| latex | `latex` | `latex` |
| lean | `lean4` (30 of 31 entries; 1 entry has no `languages`) | `lean4` |
| nix | `nix` | `nix` |
| python | `python` | `python` |
| typst | `typst` | `typst` |
| web | `web` | `web` |
| z3 | `z3` | `z3` |
| founder | `founder` (34) | `founder` |
| present | `present` (26) | `present` |
| nvim | `neovim` (23) | `neovim` (directory is `nvim`, task_type string is `neovim` — pre-existing mismatch, confirmed still present live; preserve, do not "fix") |

### New finding: `founder` needs array-union merge, not overwrite, for 11 entries

`founder` is the only extension where `load_when.languages` and `load_when.task_types` are
**already both populated on the same 11 entries** (e.g.
`patterns/legal-planning.md`: `languages: ["founder"]`, `task_types: ["contract-review",
"legal"]`). WORK item 3's rename must **union** `"founder"` into the existing `task_types` array
for these 11 entries (yielding e.g. `["founder", "contract-review", "legal"]`), not overwrite the
existing values — an overwrite would silently drop the 11 pre-existing, more-specific task_types
(`contract-review`, `legal`, `project-timeline`, `sheet`, `finance`, etc.) that are the actual
routing discriminators for those files. `present` (26 `languages`-only + 10 `task_types`-only,
zero overlap) and all other extensions in the table have no such overlap and are a pure rename.

### Confirmed: WORK item 4 (filetypes `["deck"]` deletion) is safe as described

Both `filetypes` entries with `load_when.languages: ["deck"]`
(`patterns/pitch-deck-structure.md`, `patterns/touying-pitch-deck-template.md`) already carry
non-empty `agents` (4 agents each) and `commands` (`/convert`, `/deck`), confirming the task
description's claim that these entries load correctly today and `["deck"]` is dead noise with no
valid routing target (no manifest anywhere declares a `deck` task_type). Deleting the array
outright, as instructed, is correct and lossless.

### Confirmed: literature's 6 skills entries are all safely deletable as described

All 6 `literature/index-entries.json` entries with `load_when.skills` also carry non-empty
`commands` (a mix of `/literature`, `/research`, `/plan`, `/implement`) on the same entry — no
exception here, unlike memory (Correction 4 above).

## Decisions

- Treat **17 of 19** extensions as the true Rule T scope (task description's own correction),
  and treat the **live `check-extension-docs.sh` run's 580-line breakdown** (languages 275,
  description 147, tags 94, topics 40, skills 24) as the authoritative per-category count for
  planning — not the task description's "166" description figure, which the plan should silently
  correct to 147.
- WORK item 1's fold-in is per-entry editorial work across the real 147 entries, and at minimum
  the 9+ entries in the "combined length > 200 chars" table above require an actual rewritten
  summary (not concatenation) to stay within `summary.maxLength: 200`.
- WORK item 2's rename applies only to `cslib`, `latex`, `lean`, `python`, `typst`, `z3` (94
  entries) — `email`, `filetypes`, `nix`, `web` have no `tags` field to rename.
- WORK item 3's rename requires an array-union merge (not overwrite) for `founder`'s 11
  already-dual-keyed entries, and needs an additional `formal`-specific step: hoist
  `load_when.topics` (40 entries) to entry-level `topics`, since this is required by the
  verification bar but not named in WORK item 3's text.
- WORK item 5's deletion needs one exception handled explicitly: give
  `project/memory/memory-troubleshooting.md` a `commands: ["/learn", "/distill"]` array before or
  while deleting its `skills` array, to avoid orphaning it.
- Two additional, WORK-item-unnamed-but-verification-bar-required deletions must be folded into
  the plan: `email`'s 1 `load_when.skills` entry (safe, `task_types` already present) and
  `core`'s 9 `load_when.skills` entries (8 safe; `patterns/lit-stage4a-flow.md` needs a
  replacement `agents` array — see Correction 5 — before its `skills` key is deleted).

## Risks & Mitigations

- **Blind scripted edits will orphan two entries**: `memory/memory-troubleshooting.md` and
  `core/patterns/lit-stage4a-flow.md`. Mitigation: the plan must call out these two entries by
  path with their required replacement hooks (Corrections 4 and 5), and post-migration
  verification should re-run `context-discovery.md`'s adaptive jq query for the affected
  agents/skills to confirm both files remain reachable, not just check Rule T's exit code.
- **`founder`'s array-union requirement is easy to miss** if the migration is done as a single
  `jq` "rename languages key to task_types key" transform across all 12 extensions uniformly — 11
  founder entries would silently lose their existing `task_types` values. Mitigation: handle
  `founder` as a distinct union-merge step, verified by diffing `task_types` array length
  before/after for those 11 paths.
- **`formal`'s `load_when.topics` -> entry-level `topics` hoist is unscoped work relative to the
  task description's literal WORK items.** Mitigation: this report documents it explicitly so the
  plan can add it as an in-scope sub-step of WORK item 3 (same extension, same phase) rather than
  it being discovered mid-implementation or, worse, left unfixed and failing the verification bar.
- **Verification bar's grep check (`load_when.languages\|load_when.skills`) does not itself catch
  the `load_when.topics` violation** (formal) or leftover `description`/`tags` keys — only Rule
  T's full run does. The plan should treat "zero Rule T advisories" as the binding, complete
  check and the grep command as a narrower spot-check subset of it, not the other way around.
- **`formal`'s bare `logic`/`math`/`physics` `languages` values vs. the manifest's colon-form
  `formal:logic`/`formal:math`/`formal:physics` routing keys** is an open naming question the
  prerequisite report flagged as "a `/plan`-stage decision" and this report did not resolve
  further — WORK item 3's instruction says migrate "1:1," which this report reads as "keep the
  bare string values unchanged" (i.e. `task_types: ["formal", "logic", "math", "physics"]`,
  matching the literal current `languages` values), consistent with how `nvim`'s pre-existing
  `neovim`/`nvim` mismatch is explicitly preserved rather than invented around. The plan should
  state this interpretation explicitly rather than leave it implicit.
- **`formal` also carries a non-schema `category` field** on all 46 entries (in addition to its
  already-present `subdomain`), which is a genuine `additionalProperties: false` violation of
  `index.schema.json` but is **not** checked by Rule T's jq predicates and **not** covered by the
  verification bar's two checks. This is out of scope for this task (not named in any WORK item,
  not required to pass verification) but is flagged here as a real, separate defect for a future
  task — deleting it now as a "bonus" fix is not recommended since it's unverified whether
  `category`'s content should be discarded or folded into `subdomain`/`topics`.

## Context Extension Recommendations

- **Topic**: index-entries.json migration completeness relative to Rule T.
- **Gap**: no context file documents that Rule T's true positive set can include categories the
  task description's own WORK items don't enumerate (as happened here with `core`, `email`, and
  `formal`'s `load_when.topics`). A future task planner reading only a task description's WORK
  items, without re-running the live gate, would under-scope the same way task 990's own
  description under-scoped by naming 166 vs. the real 147, and by omitting `core`/`email`/
  `formal`'s topics nesting entirely.
- **Recommendation**: none needed as a standing context file — this is a one-time
  planning-accuracy lesson best captured as a plan-stage cross-check ("re-run the live gate,
  don't trust the task description's summary counts") rather than new persistent context, since
  Rule T itself is the authoritative, already-documented source of truth.

## Appendix

- Live gate run: `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
  (exit 0, `SCHEMA_CONFORMANCE_GATE_MODE` at its `advisory` default; 580 "ADVISORY (not yet
  blocking): Rule T: ..." lines).
- Per-extension violation counts and per-category totals computed via `jq` directly against each
  `agent-system/extensions/*/index-entries.json`, cross-checked against the live gate's own
  advisory-line counts (they matched exactly: languages 275, description 147, tags 94, topics 40,
  skills 24).
- `manifest.json` `routing.research` keys read directly for all 12 languages-bearing extensions in
  the WORK item 3 migration map (cslib, formal, latex, lean, nix, python, typst, web, z3, founder,
  present, nvim) to confirm the prerequisite report's §4 table against current state.
- `index.schema.json` re-read directly from `agent-system/extensions/core/context/` (source
  store) to confirm the entry- vs. load_when-level `topics` field distinction underlying
  Correction 6.

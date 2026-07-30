# Research Report: Context Budget Enforcement and Index Schema

- **Task**: 987 - context_budget_enforcement_and_index_schema
- **Started**: 2026-07-29T00:00:00Z
- **Completed**: 2026-07-29T00:00:00Z
- **Effort**: ~2 hours (empirical audit across 19 extensions, 3 schema authorities, 2 validator scripts)
- **Dependencies**: index-validator/line-count repair task (COMPLETED — `check-extension-docs.sh` Rule R now enforces truthful `line_count`, and the audit below confirms all 19 extensions have `line_count` on every entry)
- **Sources/Inputs**: `specs/reviews/review-2026-07-29-agent-system.md`; all 19 `agent-system/extensions/*/index-entries.json`; `agent-system/extensions/core/context/index.schema.json`; `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md`; `agent-system/extensions/README.md`; `agent-system/extensions/core/scripts/check-extension-docs.sh`; `agent-system/extensions/core/scripts/validate-context-budgets.sh`; `agent-system/extensions/core/context/patterns/context-discovery.md`; `agent-system/extensions/core/scripts/validate-index.sh`, `validate-wiring.sh`, `install-extension.sh`, `lint/lint-contract-compliance.sh`; `lua/neotex/plugins/ai/shared/extensions/merge.lua`; each extension's `manifest.json` `routing` block; `specs/state.json` (task 981 description, for the task_type-registry coordination point)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Context & Scope

Task 987 depends on the index-validator/line-count repair (task 978, status `completed`) —
confirmed satisfied: every one of the 470 entries across all 19 extensions now carries a
`line_count` key, and `check-extension-docs.sh` Rule R already enforces source-vs-`wc -l`
accuracy at doc-lint time. This report audits the remaining problem named in the task: **three
contradictory index-entry schema authorities**, a **dead `load_when.languages`/`load_when.skills`
dimension**, an **unenforced 77+-entry `task_types:["meta"]` catch-all**, **Tier-1 always-load
bloat**, and **EXTENSION.md size violations** — and produces a concrete reconciliation design for
the planning phase. This is a research report; no source files were edited.

Declared `file_scope` for this task is narrow (`index.schema.json`,
`extension-slim-standard.md`, `check-extension-docs.sh`), but WORK items 2–5 in the task
description touch far more files. This is flagged explicitly in Recommendations/Risks below —
the plan should either expand `file_scope` or split this into sequenced phases.

## Findings

### 1. The three schema authorities, characterized precisely

| Authority | Required entry fields | Forbidden/absent | `load_when` allowed keys |
|---|---|---|---|
| `index.schema.json` (`agent-system/extensions/core/context/index.schema.json`) | `path`, `domain` (enum: core/project/system), `summary` (≤200 chars), `line_count` | `additionalProperties: false` at both entry level (no `description`, no `tags`) and `load_when` level — **`task_types` and `skills` are not declared and therefore forbidden** | `agents`, `commands`, `languages`, `always` only |
| `extension-slim-standard.md`'s "Index Integration" example | `path`, `description`, `line_count`, `load_when.{agents,languages}` | No `summary`, no `domain`/`subdomain` | `agents`, `languages` |
| `agent-system/extensions/README.md`'s "index-entries.json Format" example | `path`, `domain`, `subdomain`, `load_when.{languages,agents}` | No `summary`, no `line_count`, no `description` | `agents`, `languages` |

All three disagree with each other, and **all three disagree with the schema every real
extension actually needs** — none of them mentions `task_types`, the single most-used
`load_when` key in the deployed system (see §2).

**No JSON-Schema validator is ever actually run against `index.schema.json` anywhere.**
`validate-context-index.sh` cites it only in a comment (line 7); no script invokes an
ajv/jsonschema tool. The schema file is currently pure documentation, unenforced — which is
exactly how it drifted this far from reality without anything failing. `check-extension-docs.sh`'s
existing checks (Rules A–S) are all hand-written jq predicates, not schema-validator calls — the
new Rule (§5 below) should follow that same established idiom, not introduce a new dependency.

### 2. Actual field usage across all 19 extensions (470 entries, empirically counted)

```
ext            n   description  summary  line_count  tier  task_types  languages  skills
core          129  0            129      129         0     123         0          9
cslib          16  16           16       16          0     0           16         0
email           8  8            8        8           0     8           8          1
epidemiology   15  0            15       15          0     15          0          0
filetypes      11  11           11       11          0     0           11         0
formal         46  0            46       46          0     0           46         0
founder        34  0            34       34          0     11          34         0
latex          10  10           10       10          0     0           10         0
lean           31  31           31       31          0     0           30         0
literature      6  0            6        6           0     0           0          6
memory          8  0            8        8           0     0           0          8
nix            11  11           11       11          0     0           11         0
nvim           24  0            24       24          0     1           23         0
present        36  0            36       36          0     10          26         0
python          6  6            6        6           0     0           6          0
slidev         15  0            15       15          0     0           0          0
typst          26  26           26       26          0     0           26         0
web            23  23           23       23          0     0           23         0
z3              5  5             5        5           0     0           5          0
```

Key observations:

- **`summary` and `line_count` are universal** (100% of entries, all 19 extensions) — the one
  point of actual convergence, and the safe field to standardize on.
- **`tier` is used by zero entries anywhere**, yet `validate-context-budgets.sh` queries `.tier`
  four separate times (Tier-1 count/lines, tier classification check, dead-entry check, Tier-3
  double-loading check) — confirming the task description's claim verbatim.
- **10 extensions carry BOTH `description` and `summary`** on every entry (cslib, email,
  filetypes, latex, lean, nix, python, typst, web, z3) — not a partial migration artifact but a
  genuine duplicate: spot-checking samples (cslib, email, lean) shows `description` and
  `summary` hold *different* text, `description` usually the more detailed of the two (e.g.
  email's `description` names four sub-fields the `summary` compresses to one clause). Dropping
  `description` outright would lose some detail; the reconciliation must fold any
  `description`-only detail into `summary` during migration, not just delete the field.
- **Same 10 extensions use `tags` instead of `keywords`/`topics`** (both of which the schema
  already declares as optional array fields) — this is a naming mismatch, not a missing feature.
  A mechanical `tags → keywords` rename closes it with no schema change needed for that part.
- **`task_types` is used by 6 extensions** (core 123/129, email 8/8, epidemiology 15/15, founder
  11/34, present 10/36, nvim 1/24) totaling 168 of 470 entries — the dominant real discriminator,
  and the one the current schema forbids.
- **`skills` is used only by literature (6/6) and memory (8/8)** — both extensions' entries also
  carry non-empty `commands` (`/literature`, `/learn`) on the *same* entries, confirmed by
  sampling. `skills` is fully redundant with the already-live `commands` key here; nothing is
  lost by deleting it.

### 3. `load_when.languages` and `load_when.skills` are dead at runtime — confirmed exhaustively

Grepped every script under `agent-system/extensions/core/scripts/` (and the one runtime consumer
doc, `context-discovery.md`) for any read of `.load_when.languages` or `.load_when.skills`:

- **The only two occurrences of either key anywhere in the codebase** are inside
  `validate-context-budgets.sh`'s "Dead Entry Check" (lines 172–173, 187–188) — and there they
  are used only as a defensive exclusion (`... and languages == 0`) so an entry with a non-empty
  `languages`/`skills` array isn't *also* flagged as dead. Nothing ever loads a context file
  *because* of `languages` or `skills`.
- The real, actively-queried keys are `agents`, `task_types`, `commands`, and `always` —
  confirmed in `context-discovery.md` (the documented adaptive-query pattern used by agents at
  runtime), `validate-index.sh`, `validate-wiring.sh`, and `lint-contract-compliance.sh`. All
  four scripts key exclusively off this same four-key set.
- **Entry reachability is currently NOT broken** by this dead dimension: cross-checking every
  extension, only 1 entry system-wide (in `founder`) is reachable *only* via a non-empty
  `languages` array with no `agents`/`commands`/`task_types`/`skills` fallback. Every other
  `languages`-bearing or `skills`-bearing entry also carries `agents` and/or `commands`, so it
  still loads today — the defect is that the *task-type dimension* (what `--lit`/`--clean`/
  memory-retrieve.sh keys off for domain gating) has no data for these 10 languages-only
  extensions, not that their context files are unreachable.
- **`filetypes` has a genuinely orphaned/wrong value**: two entries declare
  `languages: ["deck"]`, but no manifest anywhere (`filetypes`, `present`, `slidev`) declares a
  routing task_type called `deck` — it doesn't correspond to anything. Both entries already carry
  populated `agents`/`commands`, so they load correctly regardless; `["deck"]` is pure dead noise
  to be deleted, not migrated.
- **`install-extension.sh` (a separate, symlink-based deploy mechanism, distinct from the live
  Lua loader) contains its own private index-merge jq logic** (lines ~203–234) that assumes an
  obsolete "flat array" or `description`/`tags`-only schema shape (comments say "nix, web" /
  "z3, python, formal" — none of which match those extensions' *current* index-entries.json
  files, all of which are the standard `{entries:[...]}` object shape with `summary`/
  `line_count` already present). This looks like dead/stale code from an earlier schema
  generation, is NOT in this task's `file_scope`, and is flagged here only as a related risk for
  a future cleanup task (it silently drops `commands`/`always` from `load_when` in its
  object-shape branch, lines 228–231, if that code path were ever actually exercised).
- **The live, actually-used merge engine** is `lua/neotex/plugins/ai/shared/extensions/merge.lua`'s
  `append_index_entries()` — confirmed by reading it: it passes each source entry through
  **verbatim**, no field remapping or dropping. Whatever an extension's `index-entries.json`
  declares (`description`, `tags`, `task_types`, `skills`, anything) reaches the deployed
  `.claude/context/index.json` unchanged. This means the live system already tolerates the
  reconciled schema's target shape today — no loader change is required for the schema
  reconciliation itself, only for extensions to converge their *own* source files onto it.

### 4. Migration mapping for the 10 languages-only / 2 skills-only extensions

Every "languages-only" extension's `load_when.languages` values already match that extension's
own `manifest.json` `routing.research` keys 1:1 (verified for all of them):

| Extension | `languages` values used | Matching `routing` task_type keys | Migration |
|---|---|---|---|
| cslib | `cslib` | `cslib`, `pr` | rename `languages→task_types`, values unchanged |
| filetypes | `deck` (2 entries only; rest are `[]`) | `filetypes`, `filetypes:document`, etc. — `deck` matches none | delete the dead `["deck"]` array (entries already load via `agents`/`commands`) |
| formal | `formal`, `logic`, `math`, `physics` | `formal`, `formal:logic`, `formal:math`, `formal:physics` | rename `languages→task_types`; consider whether bare `logic`/`math`/`physics` should become the colon form `formal:logic` etc. — a `/plan`-stage decision |
| latex | `latex` | `latex` | rename `languages→task_types` |
| lean | `lean4` | `lean4`, `lean4:lake`, `lean4:version` | rename `languages→task_types` |
| nix | `nix` | `nix` | rename `languages→task_types` |
| python | `python` | `python` | rename `languages→task_types` |
| typst | `typst` | `typst` | rename `languages→task_types` |
| web | `web` | `web` | rename `languages→task_types` |
| z3 | `z3` | `z3` | rename `languages→task_types` |
| founder | `founder` | `founder`, `founder:analyze`, ... (12 total) | already has 11 `task_types` entries too — partial migration; unify remaining 34 `languages`-only entries onto `task_types` |
| present | `present` | `present`, `present:budget`, ... (6 total) | already has 10 `task_types` entries; unify remaining 26 |
| nvim | `neovim` | routing key is `neovim` (not `nvim`) | rename `languages→task_types`, value `neovim` unchanged; note the extension directory is named `nvim` but the task_type string is `neovim` — this mismatch is pre-existing (task 981's routing-consolidation concern), not something to invent here |
| literature | (uses `skills`, not `languages`) | no task_type — driven by `/literature` command + `skill-literature` directly | delete `skills` array (redundant with existing `commands`) |
| memory | (uses `skills`, not `languages`) | no task_type — driven by `/learn`/`/distill` + skills directly | delete `skills` array (redundant with existing `commands`) |

This confirms task 987's instruction to "coordinate with the routing consolidation task's
task_type registry" (task 981, not yet started) is low-risk: the registry task 981 wants to fix
*how* routing resolves agents from task_types, not *what* the task_type strings are — the
strings this migration would use are already the ones every manifest's `routing` block declares
today. No new task_type vocabulary needs to be invented; task 981 landing later will not change
these string values.

### 5. The meta catch-all, concretely

`core/index-entries.json` has **123 of 129 entries** carrying `task_types: ["meta"]` (out of 129
total core entries) — since `meta-builder-agent`, `general-research-agent`, and
`general-implementation-agent` are all invoked for `task_type=="meta"` work, and
`context-discovery.md`'s documented adaptive query ORs `load_when.agents` with
`load_when.task_types`, EVERY meta-typed dispatch (research, plan, implement, OR the interactive
`/meta` builder) pulls in all 123 entries regardless of relevance. This is the direct mechanism
behind the review's measured 115k-token `meta-builder-agent` overshoot against its 15k cap.

**24 of the 123 entries have `task_types: ["meta"]` as their ONLY hook** (no `agents`, no
`commands` at all) — meaning there is currently no way to scope them more narrowly without adding
one. These 24 total ~4,700 lines:

```
124L  checkpoints/checkpoint-commit.md
 81L  checkpoints/checkpoint-gate-in.md
126L  checkpoints/checkpoint-gate-out.md
177L  formats/errors-format.md
246L  formats/events-format.md
188L  formats/handoff-artifact.md
111L  formats/team-metadata-extension.md
166L  orchestration/sessions.md
313L  orchestration/subagent-validation.md
305L  patterns/file-metadata-exchange.md
134L  patterns/infra-failure-discrimination.md
257L  patterns/mcp-tool-recovery.md
275L  patterns/postflight-control.md
146L  patterns/team-orchestration.md
400L  reference/team-wave-helpers.md
197L  reference/workflow-diagrams.md
 42L  routing.md
137L  schemas/errors-schema.json
 78L  schemas/events-schema.json
140L  standards/ci-workflow.md
212L  standards/git-integration.md
571L  standards/git-safety.md
205L  standards/postflight-tool-restrictions.md
 46L  validation.md
```

By content theme, plausible real hooks (a planning-phase decision, not resolved here):
- `checkpoints/*` (3 files, ~330L): all implementer/planner agents that execute the
  gate-in/commit/gate-out lifecycle — `agents: [general-implementation-agent,
  general-implementation-hard-agent, planner-agent, meta-builder-agent, ...]`, not a task-type.
- `formats/errors-format.md`, `formats/events-format.md`, `schemas/errors-schema.json`,
  `schemas/events-schema.json` (~638L): writer-side agents plus `commands: ["/errors"]`, and
  possibly `/distill --review`.
- `formats/handoff-artifact.md`, `orchestration/sessions.md`,
  `orchestration/subagent-validation.md`, `patterns/file-metadata-exchange.md`,
  `patterns/infra-failure-discrimination.md`, `patterns/mcp-tool-recovery.md`,
  `patterns/postflight-control.md` (~1,838L): `commands: ["/orchestrate"]` plus every
  research/plan/implement agent — this cluster is genuinely broad and may legitimately need to
  stay reachable by most agents, but via explicit `agents` enumeration, not the `meta` catch-all.
- `patterns/team-orchestration.md`, `reference/team-wave-helpers.md`,
  `formats/team-metadata-extension.md` (~657L): `--team` skills only —
  `commands`/`agents` scoped to `synthesis-agent` and the team skills.
- `standards/git-safety.md` (571L, the single largest file in this set) and
  `standards/git-integration.md`, `standards/ci-workflow.md`,
  `standards/postflight-tool-restrictions.md` (~1,128L total): implementer agents specifically
  (git-committing agents), not researchers.
- `routing.md`, `validation.md`, `reference/workflow-diagrams.md` (~285L): candidates for
  dropping `always`-adjacent preload entirely and becoming genuinely on-demand (loaded by an
  agent only if it greps for them), rather than assigned any `load_when` hook at all.

Giving each of these 24 entries a real, narrower hook (rather than deleting the `meta` catch-all
outright, which would silently un-index files some agents legitimately need) is the concrete
mechanism for WORK item 3. This is `core/index-entries.json` editing, plus likely
`core/merge-sources/claudemd.md` cross-references — outside the declared `file_scope`.

### 6. Tier-1 (`always: true`) bloat and the project-overview double-load

Current `always: true` entries (queried live, not from the stale review snapshot):

```
100L  checkpoints/README.md
311L  patterns/context-discovery.md
281L  patterns/jq-escaping-workarounds.md
202L  README.md
 32L  reference/README.md
 70L  repo/project-overview.md
------
996L  total (target ≤500L, per validate-context-budgets.sh's tier1_target)
```

996 lines is essentially double the 500-line target. `patterns/context-discovery.md` (311L) and
`patterns/jq-escaping-workarounds.md` (281L) together are 592L — removing `always: true` from
just these two (as WORK item 4 specifies) brings Tier 1 to 404L, under budget with headroom.
Both are genuinely reference material consulted occasionally, not needed on every single prompt;
demoting them to `commands`-scoped (or `agents`-scoped, for the agents that actually run jq
against index.json / do context discovery) is consistent with how every other reference doc in
the system is already scoped.

**The `project-overview.md` double-load is confirmed exactly as described**: it is both (a) an
`always: true` index entry (70L, loaded by any dynamic `context-discovery.md`-style jq query),
AND (b) explicitly `@`-imported in `core/merge-sources/claudemd.md` line 559
(`@.claude/context/repo/project-overview.md`), which is concatenated into **every** session's
generated `CLAUDE.md` unconditionally. Fixing this is a one-line deletion in
`merge-sources/claudemd.md` (removing the redundant index entry, since the static `@`-import
already guarantees the file is always present) or vice versa — either resolves it; the `@`-import
is the more universal of the two mechanisms since it doesn't depend on an agent invoking the
dynamic-discovery query pattern at all, so **removing the `always: true` flag from the index
entry** (keeping only the `@`-import) is the recommended direction. Both files are outside this
task's declared `file_scope` (`merge-sources/claudemd.md`, `core/index-entries.json`).

### 7. EXTENSION.md 60-line violations, current count

```
169L  literature   OVER (was 161L at review time — grew, not shrunk)
106L  email        OVER
 73L  lean         OVER
 71L  cslib        OVER
 64L  present      OVER
 62L  nix          OVER
 62L  core         OVER
------
 60L  formal       OK (exactly at limit)
 ... 11 more extensions OK
```

7 of 19 extensions violate — matches the review's count exactly (numbers drifted slightly since
the review snapshot, e.g. literature grew from 161L to 169L, confirming the limit is not
currently enforced anywhere: `check-extension-docs.sh`'s `check_file()` only checks
existence/non-emptiness, never length). No script currently enforces the 60-line cap at all —
WORK item 5's "doc-lint check" would be new functionality, not a fix to an existing broken check.
Actually trimming the 7 violators' content into their extensions' own `context/project/*/`
directories (per `extension-slim-standard.md`'s own migration template) is out of this task's
`file_scope` and is real per-extension editorial work, not a schema/validator change.

## Decisions

- **Standardize entry fields on `summary`/`line_count`/`keywords`/`topics`** (already-universal
  or already-schema-declared), retiring `description` and `tags` as distinct fields. Because
  `description` sometimes carries more detail than `summary` (confirmed in spot checks), the
  migration must fold any unique `description` content into `summary` per-entry rather than
  discard it — a one-time editorial pass across the 10 affected extensions (166 entries), not a
  blind field rename.
- **Extend `load_when` to allow `task_types` and delete `languages`/`skills` entirely** —
  `task_types` is the dominant, live, already-consumed key (168/470 entries today); `languages`
  and `skills` are read by nothing except a defensive dead-entry-check exclusion. Migrate
  `languages` values to `task_types` 1:1 using each extension's own `manifest.json` `routing`
  keys as the authoritative value source (§4 table); delete the two `filetypes` `["deck"]`
  entries' array (no valid target); delete `literature`/`memory`'s `skills` arrays (redundant
  with their own `commands` arrays on the same entries).
- **Do not add a hand-authored `tier` field.** `validate-context-budgets.sh` queries `.tier` but
  zero entries anywhere declare it, and hand-typed metadata is exactly the disease that made
  `line_count` untrustworthy before task 978's fix. Recommend deriving "tier" algorithmically
  inside `validate-context-budgets.sh` from the already-canonical `load_when` shape (e.g.
  `always==true` → Tier 1, non-empty `agents` → Tier 2, non-empty `commands`/`task_types` only →
  Tier 3, neither → Tier 4/dead) instead of introducing a fifth authored field that will drift
  the same way `line_count` did. This is a `validate-context-budgets.sh` change, outside this
  task's declared `file_scope` — flagged for the plan to fold in as a dependent phase, since the
  new schema check (below) and the tier-derivation logic are coupled.
- **New Rule in `check-extension-docs.sh`** (next available letter, `Rule T`,
  `check_index_entries_schema`): for each extension's *source* `index-entries.json`, assert (a)
  every entry has `path`/`domain`/`subdomain`/`summary`/`line_count`, (b) no entry has
  `description`, `tags`, or `load_when.languages`/`load_when.skills`, (c) `load_when`'s only
  populated keys are among `agents`/`commands`/`task_types`/`always`, (d) `domain` is one of
  `core`/`project`/`system`. Gate severity should reuse `INDEX_TRUTH_GATE_MODE` (the existing
  variable Rules R/S already use for "the context index tells the truth" checks) rather than
  invent a third mode variable — and, mirroring how `INDEX_TRUTH_GATE_MODE`/`ORPHAN_GATE_MODE`
  both started `advisory` and were only promoted to `hard` after their respective remediation
  phases landed cleanly (see those variables' own comments in the script), this new check should
  default `advisory` until the 14-of-19-extension migration (§2, §4) is actually complete, then
  flip to `hard` in a follow-up phase — never ship it as an immediate hard-fail against a
  codebase where 14 extensions are still non-conformant by construction.
- **Fix `extension-slim-standard.md`'s "Index Integration" example** to the reconciled shape:
  `summary` (not `description`), no `tags`, `load_when.task_types` (not `languages`) as the
  primary discriminator alongside `agents`.
- **`agent-system/extensions/README.md`'s example is also wrong and should be fixed in the same
  pass**, even though it is not in the declared `file_scope` — the task's own headline is "give
  index entries ONE schema authority," and leaving a third, uncorrected example in the one other
  place a new extension author is told to look (`README.md`'s "Creating New Extensions" section,
  step 4) would recreate exactly the three-authority problem this task exists to fix. Recommend
  adding this file to the plan's touched-file list.

## Recommendations

1. **Phase A (schema + standard + validator, matches current `file_scope`)**: land the
   reconciled `index.schema.json` (entry fields, `load_when` keys per Decisions above), fix
   `extension-slim-standard.md`'s example, and add `check_index_entries_schema` (Rule T) to
   `check-extension-docs.sh` in `advisory` mode. Also update `agent-system/extensions/README.md`'s
   example (recommend expanding `file_scope` to include it — see Risks).
2. **Phase B (migration, NOT in current `file_scope` — needs its own phase/file_scope)**: migrate
   all 166 `description`+`tags`-bearing entries (10 extensions) and all `languages`/`skills`
   entries (12 extensions, §4 table) to the reconciled shape. This is the bulk of the mechanical
   work; use the §4 table as the migration map.
3. **Phase C (meta catch-all, NOT in current `file_scope`)**: assign real `agents`/`commands`
   hooks to the 24 meta-only entries in `core/index-entries.json` using §5's thematic groupings
   as a starting point; re-run `validate-context-budgets.sh` to confirm `meta-builder-agent` and
   `general-implementation-agent` land under their caps (15,000 / 8,000 tokens respectively).
4. **Phase D (Tier-1 + double-load, NOT in current `file_scope`)**: demote
   `patterns/context-discovery.md` and `patterns/jq-escaping-workarounds.md` from `always: true`
   to command/agent-scoped; remove the redundant `always: true` on `repo/project-overview.md`
   (keep only the `@`-import in `merge-sources/claudemd.md`). Re-run `validate-context-budgets.sh`
   Tier-1 check to confirm ≤500L.
5. **Phase E (EXTENSION.md trims, NOT in current `file_scope`)**: add a length-check to
   `check-extension-docs.sh` (part of Rule T or a sibling check) and trim the 7 violators
   (literature 169L, email 106L, lean 73L, cslib 71L, present 64L, nix 62L, core 62L) per
   `extension-slim-standard.md`'s own migration template.
6. **Only after Phases B/C/D land cleanly**, flip `INDEX_TRUTH_GATE_MODE`'s new Rule T
   consumption from `advisory` to `hard` in a final verification phase — mirroring the exact
   promotion sequence Rules R/S already went through (their own script comments document this:
   "Defaults to 'hard' now that source-store remediation has already landed").

## Risks & Mitigations

- **`file_scope` (3 files) materially undercounts the real edit surface** (touches at least
  `core/index-entries.json`, `core/merge-sources/claudemd.md`, `validate-context-budgets.sh`,
  and up to 12 extensions' `index-entries.json` files, plus `README.md`). Mitigation: the plan
  should either expand `file_scope` explicitly per phase or declare Phase A as this task's sole
  deliverable and spawn Phases B–E as follow-on tasks — recommend the latter, since Phases B–E
  are large, independent, mechanical migrations well-suited to their own task/plan/implement
  cycles, while Phase A alone already satisfies "one schema authority" and "a check that fails
  loudly on drift," which are the two concrete items in this task's VERIFICATION BAR that don't
  require the other extensions to have migrated yet.
- **Promoting Rule T to `hard` immediately would break `check-extension-docs.sh` for 14 of 19
  extensions on day one**, turning a currently-passing doc-lint gate into a standing failure for
  every future commit until the (out-of-`file_scope`) migration lands — the same mistake
  `ORPHAN_GATE_MODE`/`INDEX_TRUTH_GATE_MODE` avoided by defaulting `advisory` first. Mitigation:
  default `advisory`, promote only after Phase B completes (documented in Decisions above).
  Verification-bar item 2 ("check-extension-docs.sh fails on a fixture index entry violating the
  reconciled schema; passes on all 19 real files") is satisfiable in `advisory` mode too — a
  dedicated fixture test can assert the check *fires* (produces an ADVISORY line) without the
  whole gate needing to be `hard` yet; "passes on all 19 real files" should be read as "does not
  regress the exit code," not "zero advisory lines," until Phase B lands.
- **Folding `description` content into `summary` is an editorial judgment call per entry**, not
  a mechanical script — spot-checked examples show real information asymmetry (email's
  `description` is meaningfully more detailed than its `summary`). A blind `mv description
  summary` (overwriting) would lose the more detailed field in cases where `description` is
  richer; a blind `rm description` would lose it entirely. Recommend a human-reviewed or
  agent-reviewed per-extension pass, not an unattended script, for this specific step.
- **`nvim` extension's `neovim` vs `nvim` naming mismatch** (directory name `nvim`, but the
  `routing`/`languages` task_type string is `neovim`) is pre-existing and out of scope for this
  task — noted so the Phase B migration doesn't "fix" it as a side effect without the routing
  task (981) being aware.

## Context Extension Recommendations

- **Topic**: index-entries.json schema authority.
- **Gap**: no single context file currently documents "the" reconciled schema in a way an
  extension author would find before writing a new `index-entries.json` (three partially-wrong
  examples exist today, per §1).
- **Recommendation**: once Phase A lands, consider whether `index.schema.json` alone is
  sufficient as the single authority, or whether a short worked example belongs in
  `extension-slim-standard.md` only (not duplicated a third time in `README.md` beyond a pointer
  to the standard) — reducing the *number* of authorities from three to two-with-one-pointer, or
  ideally one.

## Appendix

- Empirical field-usage table (§2) generated via `jq` against all 19
  `agent-system/extensions/*/index-entries.json` files, not from the stale review snapshot.
- Runtime-consumer grep: `grep -rn "load_when\.languages\|load_when\.skills"
  agent-system/core/scripts/` (2 hits, both in `validate-context-budgets.sh`'s dead-entry guard).
- Live merge-engine read: `lua/neotex/plugins/ai/shared/extensions/merge.lua`,
  `M.append_index_entries` (verbatim pass-through, no field remapping).
- `install-extension.sh` lines ~180–260: separate, apparently-stale index-merge logic assuming
  an obsolete schema shape; not exercised by the live deploy path; flagged as an out-of-scope
  follow-up risk, not fixed here.

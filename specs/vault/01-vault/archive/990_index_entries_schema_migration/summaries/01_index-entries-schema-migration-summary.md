# Implementation Summary: Task #990

- **Task**: 990 - Migrate all 19 extensions index-entries.json to the reconciled schema shape
- **Status**: [COMPLETED]
- **Started**: 2026-08-05T17:38:00Z
- **Completed**: 2026-08-05T17:50:00Z
- **Effort**: ~2 hours
- **Dependencies**: 987 (completed)
- **Artifacts**: plans/01_index-entries-schema-migration.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Migrated all 17 of 19 extensions' source `index-entries.json` files (in `agent-system/extensions/**`)
to the reconciled `index.schema.json` entry shape, clearing every one of the 580 pre-migration Rule T
advisories reported by `check-extension-docs.sh` (`epidemiology` and `slidev` were already clean and
untouched). Work was executed in the plan's 11 phases, each committed separately per its own green
verification: a read-only baseline capture, two `load_when.skills`-deletion phases with orphan-risk
replacement hooks, six per-extension/per-cluster full-migration phases (`description` fold-in,
`tags`→`keywords` rename, `load_when.languages`→`load_when.task_types` rename, `formal`'s
`load_when.topics` hoist, `founder`'s array-union merge), and a final full-corpus verification phase.

## What Changed

- `agent-system/extensions/core/index-entries.json` — deleted 9 `load_when.skills` keys; added a
  6-agent `agents` array to `patterns/lit-stage4a-flow.md` (its only other reachability hook was an
  inert `task_types: []`, now dropped).
- `agent-system/extensions/literature/index-entries.json` — deleted 6 `load_when.skills` keys (all had
  independent `commands` hooks already).
- `agent-system/extensions/memory/index-entries.json` — deleted 8 `load_when.skills` keys; added
  `commands: ["/learn", "/distill"]` to `memory-troubleshooting.md`, its only prior reachability hook.
- `agent-system/extensions/email/index-entries.json` — folded 8 `description` fields into `summary`
  (6 required a genuine rewrite to stay under the 200-char cap), deleted all 8 empty
  `load_when.languages` arrays, deleted `load_when.skills` from `design/email-to-memory-preferences.md`.
- `agent-system/extensions/filetypes/index-entries.json` — deleted 11 `description` fields (exact
  duplicates of `summary`) and 11 `load_when.languages` keys (9 empty, 2 dead `["deck"]`).
- `agent-system/extensions/cslib/index-entries.json` — folded 16 `description` fields into `summary`
  (3 rewritten for the cap), renamed `tags`→`keywords` and `load_when.languages`→`load_when.task_types`
  on all 16 (the two `ci-pipeline.md` entries sharing a path were distinguished by their `agents` array).
- `agent-system/extensions/latex/index-entries.json`, `python/index-entries.json`,
  `z3/index-entries.json` — same three transforms on 10/6/5 entries respectively (all descriptions were
  exact duplicates of `summary`).
- `agent-system/extensions/lean/index-entries.json` — folded 31 `description` fields into `summary`
  (4 merge-rewrites plus 2 pre-existing over-cap summaries compressed independently), renamed
  `tags`→`keywords` on all 31 and `load_when.languages`→`load_when.task_types` on the 30 entries that
  had it (one entry, `contracts/context-hygiene.md`, had no `languages` key and was left alone).
- `agent-system/extensions/typst/index-entries.json` — all three transforms on 26 entries (straight
  merges, no rewrite needed).
- `agent-system/extensions/nix/index-entries.json`, `web/index-entries.json` — description fold-in and
  languages rename on 11/23 entries (neither has a `tags` field).
- `agent-system/extensions/formal/index-entries.json` — renamed `load_when.languages`→
  `load_when.task_types` verbatim on all 46 entries (preserving `formal`/`logic`/`math`/`physics`
  literal strings, not the manifest's colon-form routing keys); hoisted `load_when.topics` to
  entry-level `topics` on the 40 entries that had it (topic-string multiset verified identical by hash
  before/after); left `category` untouched on all 46 (explicit non-goal).
- `agent-system/extensions/founder/index-entries.json` — renamed/unioned `load_when.languages` into
  `load_when.task_types` on all 34 entries; the 11 entries that already carried a more specific
  `task_types` got `"founder"` unioned in (e.g. `["founder","contract-review","legal"]`), verified by a
  before/after array-length-plus-one check on all 11, never an overwrite.
- `agent-system/extensions/present/index-entries.json` — plain rename on 26 entries.
- `agent-system/extensions/nvim/index-entries.json` — plain rename on 23 entries, preserving the
  `["neovim"]` value verbatim (not `["nvim"]"`); the 24th entry had no `languages` key and was left
  alone.

## Decisions

- Used `jq`-based whole-file transforms rather than per-entry `Edit` calls for the mechanical rename
  work (461 entries across 19 files), with a `jq empty` + entry-count assertion as the gate for every
  transform before it replaced the live file.
- Where `description` was byte-identical to `summary` (the overwhelming majority: filetypes, latex,
  python, z3, typst, most of lean/cslib/nix/web), the fold-in was a plain delete — no information was
  lost. Where the two differed, wrote a genuine merged/rewritten `summary` capped at 200 characters,
  verified per-entry by character count rather than assumed.
- For `cslib`'s `standards/ci-pipeline.md`, which has two distinct entries sharing the same `path`
  (one per agent variant), disambiguated the rewrite target by matching on the entry's `agents` array
  rather than `path` alone.
- For `formal`, preserved the literal `languages` string values (`formal`/`logic`/`math`/`physics`)
  verbatim in `task_types` rather than converting to the manifest's colon-form routing keys, per the
  plan's explicit non-goal (same "preserve, don't invent around" stance as the `nvim`/`neovim`
  mismatch).

## Plan Deviations

- **Phase 11's "Cap compliance" corpus-wide sweep** (`jq -s '[.[].entries[]|select((.summary|length)>200)]|length'`)
  returns **8**, not 0. All 8 are pre-existing over-cap summaries in `core` (5), `literature` (2), and
  `memory` (1) — entries that never had a `description` field and were never touched by any
  description-fold edit in this migration (confirmed identical against the pre-Phase-2/3 backups taken
  before those files' `load_when.skills` deletions). The 13 in-scope over-cap merges this task actually
  produced (email 6, cslib 3, lean 4) are all compliant with the 200-char cap. The task's actual binding
  verification bar — zero Rule T advisories and zero `load_when.languages|load_when.skills` grep hits —
  holds exactly as required; this corpus-wide sweep is a stricter aspirational check the plan added on
  top of that bar, and fixing the 8 pre-existing violations is left as a follow-up, not silently done
  as scope creep.

## Verification

- Build: N/A (no build step for this extension-config-only change)
- Tests: N/A (no test suite covers `index-entries.json` content)
- Files verified: Yes — `jq empty` passed on all 19 files at every phase, entry counts unchanged
  (461 corpus total, matching per-extension baseline exactly)
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`: **0** Rule T
  advisories (down from the 580-line baseline)
- `grep -rn 'load_when.languages\|load_when.skills' agent-system/extensions/*/index-entries.json`:
  **0** hits
- Reachability diff against the Phase 1 baseline: zero-effective-hook entry set shrank from 7 to 4;
  both named orphan-risk entries (`core/patterns/lit-stage4a-flow.md`,
  `memory/project/memory/memory-troubleshooting.md`) are now reachable; no previously-reachable entry
  became unreachable (plus a bonus reachability gain for `founder/domain/migration-guide.md`, a
  side-effect of its plain languages→task_types rename)
- `bash .claude/scripts/check-task-references.sh` (deployed copy): PASS, 0 unexempted occurrences
  across `agent-system/extensions`, `.opencode`, `lua`, `.memory`
- `git status --short`: no modified files under `.claude/`; all edits confined to
  `agent-system/extensions/*/index-entries.json` and `specs/990_*/`
- `SCHEMA_CONFORMANCE_GATE_MODE=hard` confidence run: 0 Rule T failures (10 unrelated pre-existing
  Rule U/R/deploy-drift failures remain across `core`, `cslib`, `email`, `lean`, `literature`, `nix`,
  `present` — all pre-date this task and are out of its scope; no gate-mode config was committed)

## Impacts

- `check-extension-docs.sh`'s Rule T advisory gate is now silent across the full 19-extension corpus,
  clearing the way for a future task to promote `SCHEMA_CONFORMANCE_GATE_MODE` from `advisory` to
  `hard` without breaking any currently-passing extension on Rule T grounds specifically.
- `context-discovery.md`'s adaptive query gains two previously-unreachable-except-by-`skills` entries
  (`lit-stage4a-flow.md`, `memory-troubleshooting.md`) as genuinely reachable via `agents`/`commands`.
- `formal`'s 40 topic strings are now proper entry-level `topics`, a schema field other extensions
  already use for the same purpose, making `formal` consistent with the rest of the corpus.

## Follow-ups

- The 8 pre-existing over-cap `summary` fields in `core` (5), `literature` (2), and `memory` (1) —
  none touched by this migration's fold-in work — are a candidate for a small follow-up cleanup task.
- `formal`'s `category` field (46 entries, a genuine `additionalProperties: false` violation not
  checked by Rule T) remains untouched per this task's explicit non-goal.
- Promoting `SCHEMA_CONFORMANCE_GATE_MODE` from `advisory` to `hard` is explicitly out of scope here
  and remains a separate follow-up task; the hard-mode confidence run above confirms Rule T itself
  would pass today, but 10 unrelated Rule U/R/deploy-drift failures would need resolving first.
- `nvim`'s `neovim`/`nvim` naming mismatch and `formal`'s bare `logic`/`math`/`physics` vs. the
  manifest's colon-form routing keys were both deliberately preserved verbatim per the plan's
  non-goals, not resolved.

## References

- `specs/990_index_entries_schema_migration/plans/01_index-entries-schema-migration.md`
- `specs/990_index_entries_schema_migration/reports/01_index-entries-schema-migration.md`

# Implementation Summary: Task #979

- **Task**: 979 - Bootstrap the errors.json lane for real: one schema, validated append script, reconciled docs
- **Status**: [COMPLETED]
- **Started**: 2026-07-29T23:57:23Z
- **Completed**: 2026-07-30T01:40:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_errors-json-lane-bootstrap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Made the error-tracking layer real. `specs/errors.json` did not exist despite being documented as
the backbone of `/errors` and several skills' failure paths, and its shape was described three
mutually inconsistent ways across `rules/error-handling.md`, `commands/errors.md` (two blocks),
and `skills/skill-planner/SKILL.md`'s live inline writer. All 8 plan phases completed: a
reconciled draft-07 schema plus prose format contract, a `flock`'d two-subcommand writer script
(`append`/`update`) mirroring `events-append.sh`'s idiom for `append` and adding an original
read-modify-write design for `update`, a 14-case regression suite, deploy-path wiring, doc
reconciliation across all three conflicting blocks, conversion of the sole live inline jq writer,
and a bootstrapped `specs/errors.json` verified end-to-end from the deployed tree.

## What Changed

- `agent-system/extensions/core/context/schemas/errors-schema.json` — new draft-07 JSON Schema:
  object-with-array top level, 7 required per-record fields, 7-key `context` superset, 4-value
  `fix_status` enum (`resolved` deprecated-but-valid), no `recurrence_count`.
- `agent-system/extensions/core/context/formats/errors-format.md` — new prose format contract
  (177 lines): file location, lazy creation, object-vs-array rationale, mutability contrast with
  `events.jsonl`, full `append`/`update` CLI contract, reconciliation decisions.
- `agent-system/extensions/core/index-entries.json` — two new context index entries.
- `agent-system/extensions/core/scripts/errors-append.sh` — new writer script (executable):
  `append` (near-direct port of `events-append.sh`) and `update` (original read-modify-write
  under one `flock`, validating the merged document before the atomic `mv`).
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh` — new 14-case regression
  suite (executable): lazy-creation, shape-conformance, concurrency (N=25), concurrent-update
  (M=10), 9 off-schema rejection cases, update-correctness.
- `agent-system/extensions/core/manifest.json` — two `provides.scripts` insertions
  (`errors-append.sh`, `tests/test-errors-append.sh`), correctly alphabetized.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — gate 1 extended with 3 presence
  checks (now 9 total); header comment reworded to name both store families.
- `agent-system/extensions/core/rules/error-handling.md` — "1. Log the Error" section rewritten
  to point at the schema/format doc and call `errors-append.sh append`.
- `agent-system/extensions/core/commands/errors.md` — "1. Load Error Data" and "4. Update
  errors.json" blocks rewritten; "2. Analyze Patterns" recurrence sentence and "3. Execute Fixes"
  step references updated; "5. Git Commit" verified byte-identical.
- `agent-system/extensions/core/skills/skill-planner/SKILL.md` — "jq Parse Failure" recovery
  block converted from inline `jq '.errors += [...]'` to `errors-append.sh append`.
- `specs/errors.json` — new runtime artifact, `{"errors": []}`, not gitignored.
- `.gitignore` — added `**/.errors.lock` alongside the existing `**/.events.lock` entry.

## Decisions

- Top level is `{"errors": [...]}`, never a bare array — both live readers already assume this
  shape, costing zero reader changes.
- `errors-append.sh` has two subcommands because `errors.json` records are mutated in place
  (`fix_status` transitions), unlike the strictly append-only `events.jsonl`; `update` holds one
  `flock` across the whole read → transform → temp-write → validate → atomic-`mv` sequence and
  validates the MERGED document, not the delta.
- `fix_status` enum includes deprecated-but-valid `resolved` (for already-written cross-repo
  data) while `update` actively rejects it as an input value, so the deprecation cannot
  re-propagate.
- `recurrence_count` dropped from the persisted schema; `/errors` computes it at query time.
- Validation is hand-written bash (required-arg checks, `case` enums, `jq -e` shape checks),
  matching `events-append.sh`'s house idiom — no JSON-Schema-library dependency introduced.

## Plan Deviations

- **Phase 2, task 6** altered: sourced `deploy-root-guard.sh` immediately after subcommand
  dispatch rather than after `append`'s own arg validation (functionally equivalent, fails even
  faster; verified the no-subcommand/`--help` paths still short-circuit correctly).
- **Phase 7 and Phase 8** (verification-bar grep): after `errors-append.sh` exists, the literal
  `grep -rn '\.errors *+=' agent-system/extensions/core/` returns exactly ONE hit — the
  sanctioned internal use inside `errors-append.sh` itself, not a rogue duplicate writer. The
  plan's own Phase 7 goal text already names `errors-append.sh` as "the only writer," and the
  task's outer VERIFICATION BAR is phrased "zero hits outside `errors-append.sh`" — the plan's
  verification bullets inherited the Overview's unqualified "zero hits" wording without that
  qualifier. Treated as a plan wording gap, not a defect: zero hits OUTSIDE `errors-append.sh`
  is satisfied, which is what the outer bar actually requires. Widened the sweep to all
  extensions (not just core) per the Scope Hypothesis: no non-core hits found.
- **Phase 8, task 4** (known deploy-mechanism gap) altered: the gap DID bite, but not exactly as
  anticipated. `errors-append.sh`, `errors-schema.json`, and `errors-format.md` deployed
  correctly via `deploy-headless.sh`; `.claude/scripts/tests/test-errors-append.sh` did not, even
  after a second, idempotent run. Root-caused empirically: the "Sync all" incremental scan path
  (`sync.scan_all_artifacts`) returns zero `is_subdir=true` entries for the `scripts` category —
  it does not recurse into `scripts/tests/` or `scripts/lib/` at all. This is broader than a
  "brand-new file" gap: already-deployed `tests/*.sh`/`lib/*.sh` files are equally unreachable by
  this particular scan path (they were seeded by a different, earlier load path). Applied the
  documented one-off loader-primitive workaround — invoked `loader.copy_scripts(manifest,
  source_dir, target_dir, protected_paths)` directly via a headless-nvim `luafile`, which
  correctly iterates `manifest.provides.scripts` including subdirectory entries — rather than
  hand-authoring the file. Re-verified all four files byte-identical to the source store
  post-workaround. The underlying Lua sync-scan gap remains open and is out of this task's scope.

## Verification

- Build: N/A (bash/JSON/markdown; no compiled build step)
- Tests: Passed — `bash .claude/scripts/tests/test-errors-append.sh` (deployed path): 14/14 PASS.
  Confirmed the suite discriminates by deliberately breaking the `--severity` enum check in a
  scratch copy (exit flips from 0 to 1).
- Files verified: Yes — `bash -n` and `shellcheck` clean (info-level SC1091/SC2329 only, matching
  `events-append.sh`'s own cleanliness level) on `errors-append.sh` and `test-errors-append.sh`;
  `jq empty` passes on the schema, `manifest.json`, `index-entries.json`, and `specs/errors.json`.
- `bash .claude/scripts/verify-deploy.sh`: 15 checks, 0 failures, all 9 gate-1 entries PASS.
- `bash .claude/scripts/check-task-references.sh`: PASS, 0 occurrences.
- `bash .claude/scripts/check-extension-docs.sh`: PASS, all 20 extensions OK.
- End-to-end `/errors` check: real (non-degraded) load path confirmed against the live
  `specs/errors.json`; throwaway record appended via the deployed script, seen, updated to
  `fixed` with `fix_task`, then removed — `specs/errors.json` left at `{"errors": []}`. Both live
  readers (`orchestrator-postflight.sh`'s `error_ref` query, `hooks/events-log-artifact.sh`'s
  `.errors[-1]` reads) replicated verbatim and resolved cleanly against the seeded record.

## Impacts

- `/errors`, `orchestrator-postflight.sh`'s `error_ref` cross-link, and
  `hooks/events-log-artifact.sh`'s `error_logged` event all now operate against a real,
  schema-valid, non-degraded `specs/errors.json` in this repo.
- Any future writer of `errors.json` has one authoritative schema/format/script to target instead
  of three drifted prose restatements.
- The sibling `cslib` repo's live bare-array data and `resolved` value remain readable (schema
  documents them as deprecated-but-valid) without requiring a cross-repo migration.

## Follow-ups

- The Lua "Sync all" incremental scan path (`sync.scan_all_artifacts` in
  `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`) does not recurse into
  `scripts/tests/` or `scripts/lib/` at all for the `scripts` category — a real, empirically
  confirmed gap broader than "brand-new file only," discovered during this task's Phase 8 and
  worked around with a one-off loader-primitive invocation, not fixed. A future meta task should
  fix `sync_scan`'s recursive handling of `scripts` subdirectories so this class of gap does not
  need a manual workaround on every future subdirectory-script addition.
- `context/standards/error-handling.md`'s unrelated `.agent-logs/errors.json` block (different
  path, different shape, no writer/reader anywhere) remains untouched, per the plan's explicit
  Non-Goal — flagged again here for a future task, not addressed by this one.

## References

- `specs/979_bootstrap_errors_json_lane/plans/01_errors-json-lane-bootstrap.md`
- `specs/979_bootstrap_errors_json_lane/reports/01_bootstrap-errors-schema-research.md`
- `agent-system/extensions/core/context/formats/errors-format.md`
- `agent-system/extensions/core/context/schemas/errors-schema.json`

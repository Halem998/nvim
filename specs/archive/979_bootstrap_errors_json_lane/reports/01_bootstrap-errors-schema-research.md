# Research Report: Task #979

**Task**: 979 - Bootstrap the errors.json lane for real: one schema, validated append script, reconciled docs
**Started**: 2026-07-29T23:29:18Z
**Completed**: 2026-07-29T23:45:18Z
**Effort**: Research only (no code written)
**Dependencies**: Task 976 (per state.json; not directly re-verified — orthogonal to this task's schema work)
**Sources/Inputs**: Live codebase inspection (agent-system source store + deployed `.claude/`), live `specs/errors.json` data in a sibling repo (`/home/benjamin/Projects/cslib`), abandoned task 954/955 descriptions (state.json), `events.jsonl`/`events-append.sh`/`events-schema.json` as the pattern to mirror
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Every claim in the task description is empirically confirmed.** `specs/errors.json` does not
  exist in this repo (nvim). The three schema blocks exist at the cited locations and are
  genuinely inconsistent. Only 7 fields (`id`, `timestamp`, `type`, `severity`, `message`,
  `context`, `fix_status`) appear in all three.
- **The live data in the sibling `cslib` repo adds two more confirmed defects beyond what tasks
  954/955 catalogued**: `specs/errors.json` there is a **bare array**, not `{"errors": [...]}`
  (matching defect #4 from task 955's inventory, now independently re-verified), and its
  `fix_status` field contains the value `"resolved"` (matching defect #5), which is not in any
  documented enum.
- **Grep confirms only ONE real inline writer exists** anywhere in `agent-system/extensions/core`:
  the `.errors += [{...}]` block at `skill-planner/SKILL.md:488`. Every other "log to errors.json"
  reference in the codebase (18+ hits) is prose narration with no executable jq. The verification
  bar's "grep for inline writes returns zero hits outside errors-append.sh" is therefore a
  one-file conversion, not a sweep.
- **`errors.json` is NOT append-only like `events.jsonl`, and this is the single most important
  design deviation from the "mirror events-append.sh" instruction.** `commands/errors.md`'s Fix
  Mode explicitly mutates an existing record in place (`fix_status` unfixed -> in_progress ->
  fixed, plus adding `fixed_date`/`fix_task`). `errors-append.sh` therefore needs an **append**
  subcommand (mirroring `events-append.sh` directly) **and** an **update** subcommand
  (read-modify-write under the same `flock`, with schema validation on the merged result) that has
  no existing precedent anywhere in `core/scripts/` — `events-append.sh` is currently the *only*
  script in the whole core scripts directory using `flock`, and it never needs an update path.
- **"Schema-validated" in this codebase's idiom means hand-written bash validation kept
  hand-in-sync with the JSON Schema doc, not runtime JSON-Schema-library invocation.**
  `events-append.sh` never calls a JSON Schema validator against `events-schema.json` — it
  validates required-arg presence, the `category` enum via a `case` statement, and JSON-shape via
  plain `jq`. Python's `jsonschema` (4.26.0) is installed on this machine but is invoked nowhere in
  `core/scripts/`. `errors-append.sh` should follow the same idiom for consistency, not introduce
  a new validation dependency.
- **The "UNBLOCKS: tasks 951, 952, 953" claim in the task description is not literally accurate**
  and should not be treated as a real dependency edge when planning. Their own descriptions
  explicitly state "Do NOT build on errors.json" — they use `event_type: system_defect` on
  `events.jsonl` instead, and their `state.json` `dependencies` arrays chain 951 <- 952 <- 953,
  with no edge to/from 979. The relationship is thematic ("a healthier error-tracking layer helps
  the whole ecosystem"), not a hard prerequisite.

## Context & Scope

Task 979 asks to design one authoritative `errors.json` schema (from a field union across three
mutually-inconsistent documented shapes), write a formal JSON Schema file, write a validated,
`flock`'d append script mirroring `events-append.sh`, bootstrap `specs/errors.json` in this repo,
and rewrite the three conflicting doc blocks plus the one real inline writer to point at the new
schema/script. It subsumes abandoned tasks 954 (source-store defect lane) and 955 (schema
reconciliation), whose full descriptions (preserved in `state.json` since their directories were
never created) contain additional verified defect inventories that this research re-verified
rather than took on faith.

This report verifies every empirical claim against the live tree, enumerates every reader and
writer of `errors.json`, studies the `events.jsonl` substrate in the depth needed to decide what
can be mirrored directly versus what needs original design, and recommends one reconciled schema
plus a deploy-wiring plan, in preparation for `/plan 979`.

## Findings

### Claim Verification (empirical, against the live tree)

| Claim | Verified? | Evidence |
|---|---|---|
| `specs/errors.json` does not exist in the nvim repo | Yes | `ls specs/errors.json` -> No such file or directory |
| `rules/error-handling.md` documents `context{session_id,command,task,phase,checkpoint}` + `trajectory` + `recovery` | Yes | Full block read; matches exactly |
| `commands/errors.md` ~line 21 documents `context{command,task,agent,file}` + `recurrence_count`, no `trajectory`/`recovery` | Yes | Lines 21-42 read verbatim |
| `commands/errors.md` ~line 186 documents a second, undocumented-elsewhere update shape with `fixed_date`/`fix_task` | Yes | Lines 186-192 read verbatim; `recurrence_count`/`fixed_date`/`fix_task` appear NOWHERE else in `core/` (grep, 0 other hits) |
| `skill-planner/SKILL.md` ~line 487 writer prose uses `recovery` + `fix_status`, no `trajectory`/`recurrence_count` | Yes | Lines 480-498 read verbatim — this is also the ONE live inline `.errors += [...]` jq writer in the whole core extension |
| Only 7 fields appear in all three | Yes | `id, timestamp, type, severity, message, context, fix_status` — confirmed by direct set intersection |

### Enumerated Readers and Writers of `errors.json`

**Writers (code, not prose)**:
- `agent-system/extensions/core/skills/skill-planner/SKILL.md:488` — the sole inline
  `.errors += [{...}]` jq write, guarded by a `> specs/tmp/errors.json && mv` pattern (no `flock`,
  no schema validation beyond jq's own parse success).

Grepping `agent-system/extensions/core/` for the literal pattern `\.errors *+=` returns exactly
this one hit. Every other mention of "log to errors.json" (18 files: `spawn.md`,
`skill-reviser/SKILL.md`, `skill-status-sync/SKILL.md`, `mcp-tool-recovery.md`,
`checkpoint-execution.md`, `subagent-return.md`, `command-structure.md`, `docs/README.md`,
`architecture/system-overview.md`, `orchestration/architecture.md`, `git-safety.md` (5 hits),
`creating-commands.md`, `docs/guides/user-guide.md`, `early-metadata-pattern.md` (2 hits),
`implementation-workflow.md`, `merge-sources/claudemd.md`, `workflow-diagrams.md`,
`multi-task-creation-standard.md`) is narrative prose ("Log to errors.json", "Log error to
errors.json") with no accompanying jq block.

**Readers (code)**:
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh:242-245` — cross-links the
  latest error matching the current `session_id` into an `events.jsonl` `error_ref`. Guards with
  `[ -f specs/errors.json ] && jq empty specs/errors.json`, then reads `.errors[]? | select(...)`
  — assumes the object-with-array form. Comment at line 229-230 explicitly documents "Never fatal:
  absence/malformedness of errors.json degrades to an empty error_ref" — i.e. it already silently
  degrades, exactly as the task description states.
- `agent-system/extensions/core/hooks/events-log-artifact.sh:93,146-167` — a PostToolUse hook that
  fires on writes matching `specs/errors.json|*/specs/errors.json`, reads
  `.errors[-1].context.session_id`, `.errors[-1].context.task`, `.errors[-1].id`,
  `.errors[-1].severity`, and emits a corresponding `error_logged` event. Also assumes the
  object-with-array form (`.errors[-1]`).

**Both readers assume `{"errors": [...]}`.** This matters directly for the "pick object-with-array
over bare array" decision (see Decisions below): the only two readers in this codebase already
agree on the object form, so adopting it costs zero reader changes; the cslib repo's live bare
array is the anomaly, not a form with any reader support.

**A fourth, unrelated schema exists and is explicitly OUT of this task's file_scope**:
`agent-system/extensions/core/context/standards/error-handling.md:774-799` documents a
`.agent-logs/errors.json` file (different path, different shape: `level`, `stack_trace`,
`recovery_attempted`, `context.user`) that has no writer or reader anywhere in `core/scripts/` or
`core/hooks/`. This looks like generic/imported boilerplate unconnected to the live
`specs/errors.json` lane. It is not in task 979's declared `file_scope` and this report does not
recommend touching it, but flags it so the plan does not conflate the two files by accident.

### Live Data: cslib's `specs/errors.json`

`/home/benjamin/Projects/cslib/specs/errors.json` exists and is live (spot-checked, not modified).
Confirmed:
- **Bare array**, not `{"errors": [...]}` (`jq -r 'type'` -> `array`). This directly contradicts
  both readers above, which is the exact silent-degradation failure mode the task describes —
  independently re-verified here, not merely inherited from task 955's prose.
- Entries follow the `rules/error-handling.md` shape most closely: `id`, `timestamp`, `type`,
  `severity`, `message`, `context{session_id, command, task}` (no `phase`/`checkpoint` in the
  examples read), `trajectory{delegation_path, failed_at_depth}`, `recovery{suggested_action,
  auto_recoverable}`, `fix_status`.
- `fix_status` values observed: `unfixed` and **`resolved`** (undocumented anywhere) —
  independently confirms defect #5 from task 955's inventory against current live data.
- An older, unrelated file at `/home/benjamin/Projects/.OLD/errors.json` (a different, apparently
  defunct project structure — bare array, fields `type/severity/context{command, task_number,
  session_id}/message/fix_status`) additionally uses `fix_status: "not_addressed"` and
  `context.task_number` instead of `context.task`. This is old enough (different context field
  name, different directory convention) that it is best treated as historical noise, not a live
  convention to accommodate — flagged for completeness, not recommended as an enum input.

### The `events.jsonl` Pattern — What Transfers Directly and What Does Not

`events-append.sh` (166 lines) is the house style to mirror:
- `set -euo pipefail`, explicit usage block, explicit exit codes (0/1).
- Validates required args present, validates `--category` against a closed `case` enum, validates
  `--detail-json` parses as a JSON object via `jq -e 'type == "object"'`, validates numeric args
  with bash regex — **all hand-written bash checks, not a call into a JSON-Schema validator.**
  `events-schema.json` (draft-07) exists purely as the documented, human/machine-readable contract
  that these hand-written checks are supposed to stay in sync with; nothing in the codebase
  actually loads it at runtime. This is the correct idiom to replicate for `errors-append.sh`
  rather than introducing `python3 -m jsonschema` or `ajv` (neither is otherwise used anywhere in
  `core/scripts/`, even though `jsonschema` 4.26.0 happens to be installed on this machine).
- Builds the JSON line via `jq -c -n --arg ...`, **never string concatenation**.
- Appends under `flock -x 200` on a sibling `.lock` file, opened via `200> "$LOCK_FILE"`.
- Lazily creates the target file on first write — `specs/events.jsonl` "is not pre-created... It
  comes into existence the first time `scripts/events-append.sh` is invoked -- mirroring the
  existing `specs/errors.json` convention (which also does not exist until the first error is
  logged)" (`events-format.md`). **This existing doc already asserts errors.json is
  lazily-created by convention** — worth propagating that same lazy-create behavior into
  `errors-append.sh` itself (in addition to the task's explicit ask to pre-create
  `specs/errors.json` with an empty shape in this repo right now), so the script behaves correctly
  in any repo, deployed or not, regardless of whether this bootstrap step has run there yet.
- Sources `deploy-root-guard.sh` immediately after resolving `SCRIPT_DIR`/`PROJECT_ROOT`, which
  fails loudly if invoked from the agent-system source store rather than a deployed
  `.claude/scripts/` or `.opencode/scripts/` tree. `errors-append.sh` should do the same.

**What does NOT transfer directly**: `events.jsonl` is a strict append-only log — "lines are never
rewritten or reordered in place; corrections are expressed as new lines... never mutation of an
earlier line" (`events-format.md`). `errors.json` records are living, mutable state:
`commands/errors.md`'s Fix Mode (`--fix N`) explicitly does a read-modify-write cycle — "Update
error status to 'in_progress'" ... "Update error status to 'fixed'" ... adds `fixed_date` and
`fix_task` — already implemented today via the exact `jq '...' specs/errors.json > specs/tmp/... &&
mv` pattern seen in the one live writer. `errors-append.sh` therefore cannot be a pure append
script; it needs (at minimum) two subcommands:
1. **append** — new error record, directly mirroring `events-append.sh`'s `jq -c -n` +
   single-write-under-flock shape (JSON Lines is NOT the target format here, though — see
   Decisions below on object-with-array vs JSONL).
2. **update** — locate an existing record by `id`, mutate `fix_status`/`fixed_date`/`fix_task`
   (or other fields), and rewrite the whole file, still under the same `flock`, still validated
   against the schema after the merge (so a corrupt update is rejected loudly rather than silently
   written).

This read-modify-write-under-lock pattern has **no existing precedent** in `core/scripts/` —
`events-append.sh` is the only script using `flock` anywhere in that directory (grep confirms 1
hit across `*.sh`). The planner should treat the `update` subcommand as original design work, not
copy-paste from `events-append.sh`.

### Field Union and Recommended Schema

Union of all fields observed across the three docs plus live data (context sub-fields shown
nested):

| Field | rules/error-handling.md | commands/errors.md (read) | commands/errors.md (update) | skill-planner writer | live cslib data |
|---|---|---|---|---|---|
| `id` | Y | Y | - | Y | Y |
| `timestamp` | Y | Y | - | Y | Y |
| `type` | Y | Y | - | Y | Y |
| `severity` | Y | Y | - | Y | Y |
| `message` | Y | Y | - | Y | Y |
| `context.session_id` | Y | - | - | Y | Y |
| `context.command` | Y | Y | - | Y | Y |
| `context.task` | Y | Y | - | Y | Y |
| `context.phase` | Y | - | - | - | - |
| `context.checkpoint` | Y | - | - | Y | - |
| `context.agent` | - | Y | - | - | - |
| `context.file` | - | Y | - | - | - |
| `trajectory.*` | Y | - | - | - | Y |
| `recovery.*` | Y | - | - | Y | Y |
| `fix_status` | Y (`unfixed`) | Y (`unfixed\|in_progress\|fixed`) | Y | Y | Y (`unfixed`, `resolved`) |
| `recurrence_count` | - | Y | - | - | - |
| `fixed_date` | - | - | Y | - | - |
| `fix_task` | - | - | Y | - | - |

**Recommendation** (for the planner to confirm/adjust):

1. **Top level**: `{"errors": [...]}` — object-with-array, not bare array (see Decisions).
2. **Per-record required**: `id`, `timestamp`, `type`, `severity`, `message`, `context`,
   `fix_status`. `type` and `severity` stay open/free strings documented with common values
   (mirroring `events-schema.json`'s `event_type` openness) rather than closed enums, since
   `rules/error-handling.md`'s category list (`delegation_hang`, `timeout`, `jq_parse_failure`,
   etc.) is already treated as extensible in practice.
3. **`context` sub-object — union superset, all optional except none** (none of the individual
   sub-fields are used by every writer, so none should be schema-required): `session_id`,
   `command`, `task`, `phase`, `checkpoint`, `agent`, `file`. This directly satisfies the task's
   instruction to "make context sub-fields a superset."
4. **`trajectory` (optional object)**: `delegation_path` (array of strings), `failed_at_depth`
   (integer). Present in the majority-precedent doc and in live data; keep as optional rather than
   required since the one live inline writer (`skill-planner`) does not populate it.
5. **`recovery` (optional object)**: `suggested_action` (string), `auto_recoverable` (boolean).
   Present in the majority-precedent doc, the live writer, and live data.
6. **`fix_status` enum**: recommend `unfixed | in_progress | fixed | resolved`, with `resolved`
   documented as a **deprecated synonym for `fixed`**, retained in the enum only for
   backward-compatible validation of already-written cross-repo data (the live cslib file), with
   `errors-append.sh`'s update subcommand defaulting new writes to `fixed` and never emitting
   `resolved`. This resolves the task's "add ... or normalize it away" instruction without
   requiring an out-of-scope cross-repo data migration. `not_addressed` (found only in the
   apparently-defunct `.OLD` file) is NOT recommended for inclusion — it has no live writer and no
   presence in any current doc.
7. **`recurrence_count`**: recommend **dropping from the persisted schema**. No writer anywhere
   populates it, and `commands/errors.md`'s own "2. Analyze Patterns" section already describes
   recurrence as something `/errors` *computes* at analysis time by grouping errors (by `type`),
   not a field any writer maintains incrementally. Keeping it as a schema field with no writer
   would just be a second dead-field defect of exactly the kind this task exists to eliminate.
   Document this as an explicit reconciliation decision (computed-at-query-time, not
   stored) rather than silently deleting it.
8. **`fixed_date` / `fix_task`**: recommend **keeping as optional fields**, populated by the new
   `errors-append.sh update` subcommand when transitioning `fix_status` to `fixed`. Unlike
   `recurrence_count`, these describe real, intended functionality (`commands/errors.md`'s Fix
   Mode section 4 already specifies writing them) that simply never had an implementing script
   until now — this task is the natural place to finally implement it.

### Deploy-Path Wiring

- `agent-system/extensions/core/manifest.json`'s `scripts` array (`"provides.scripts"`) is a flat,
  alphabetically-sorted list of filenames; `errors-append.sh` needs to be inserted between
  `"deploy-root-guard.sh"` and `"events-append.sh"` (alphabetical: `err` < `eve`).
- `context/schemas/` is registered as a **whole-directory** copy target in the manifest's
  `context` section (line 216, `"schemas"`), not a per-file list — so `errors-schema.json` will be
  picked up automatically once the file exists in that directory, with no manifest change needed
  beyond the scripts-array entry above.
- `verify-deploy.sh`'s gate 1 (lines ~119-138) currently checks presence of the six
  events-store deploy artifacts (`events-append.sh`, `events-query.sh`, both event hooks,
  `events-schema.json`, `events-format.md`). Recommend adding `errors-append.sh` and
  `errors-schema.json` to that same presence-check loop as a small, low-risk addition — this is
  the only place in the codebase that currently gates on the events-store files actually landing
  in a deployed `.claude/`, and `errors-append.sh` deserves the same coverage now that it exists.
- **`specs/errors.json` itself is not a deploy artifact** — it lives under `specs/**`, outside
  `agent-system/extensions/**` entirely, so no manifest/deploy-wiring applies to it directly.
  Recommend two complementary behaviors: (a) `errors-append.sh` lazily creates
  `specs/errors.json` with `{"errors": []}` on first invocation in any repo that does not yet have
  it (mirroring `events-append.sh`'s lazy-create precedent, and matching `events-format.md`'s
  existing claim that this is already the `errors.json` convention), and (b) as this task's
  explicit bootstrap step, create `specs/errors.json` with `{"errors": []}` directly in this repo
  now, so `/errors` has something schema-valid to read immediately without waiting for the first
  real error.
- **Known deploy-mechanism gap, worth flagging to the planner** (documented independently in
  `agent-system/extensions/core/rules/source-store-deploy-boundary.md`'s "Known gap" section): the
  headless "Load Core" sync path does not always re-run `copy_scripts` for already-loaded
  extensions, so a brand-new `scripts/*.sh` file can silently fail to reach an existing deploy's
  `.claude/scripts/`. This repo's core extension is already loaded, so after this task lands, a
  manual "Sync all" / `<leader>al` (or the documented one-off loader-primitive workaround) may be
  needed to actually get `errors-append.sh` onto this repo's live `.claude/scripts/` — the plan
  should account for verifying the file actually deployed, not just that it was authored in the
  source store.

### Documentation Blocks Requiring Rewrite (confirmed exact locations)

1. `agent-system/extensions/core/rules/error-handling.md` — the JSON example under "1. Log the
   Error" (currently restates the full schema inline) should be replaced with a short field list
   plus a pointer to `context/schemas/errors-schema.json`, mirroring how `events-format.md`
   handles this for `events.jsonl` ("The formal machine-checkable contract lives in
   `context/schemas/events-schema.json`... the two must stay in sync").
2. `agent-system/extensions/core/commands/errors.md` — **two** blocks: the "1. Load Error Data"
   read-shape JSON (lines ~21-42) and the "4. Update errors.json" update-shape JSON (lines
   ~186-192). Both should point at the schema file; the update block's prose ("Mark fixed errors")
   should be rewritten to invoke `errors-append.sh update` instead of showing inline JSON.
3. `agent-system/extensions/core/skills/skill-planner/SKILL.md` — the "jq Parse Failure" recovery
   block (lines 482-498) is the one real inline writer; replace the inline `jq '.errors += [...]'`
   pipeline with a call to `errors-append.sh append` with equivalent arguments
   (`--session`, `--task`, `--checkpoint`, `--message`, etc.).

## Decisions

- **Object-with-array over bare array** for `specs/errors.json`'s top level, because: (1) both
  live readers (`orchestrator-postflight.sh`, `events-log-artifact.sh`) already assume `.errors[]`
  / `.errors[-1]` and would need zero changes; (2) it allows future top-level metadata
  (`schema_version`, etc.) without a breaking shape change later; (3) the cslib repo's bare-array
  file is the documented anomaly to fix, not a precedent to adopt — adopting it would mean
  changing two working readers to accommodate one broken writer's drift.
- **`fix_status` enum expanded to `unfixed | in_progress | fixed | resolved`**, with `resolved`
  documented as deprecated-but-schema-valid (see Findings above) rather than either silently
  dropped (which would make the schema reject real, currently-live cslib data the moment that
  repo's core extension is redeployed with schema validation) or promoted to a first-class
  parallel-meaning value (which would just re-introduce the same "two words, one meaning" drift
  this task exists to fix).
- **`recurrence_count` dropped from the persisted schema**, computed by `/errors`' analysis mode
  at query time instead (grouping by `type`), since no writer has ever populated it and
  `commands/errors.md`'s own prose already describes it as an analysis-time computation.
- **`errors-append.sh` needs two subcommands (`append`, `update`)**, not one, because unlike
  `events.jsonl` (strictly append-only), `errors.json` records are mutated in place by the
  existing, documented Fix Mode workflow. This is flagged as the most significant place where
  "mirror events-append.sh" cannot be a literal 1:1 port.
- **Validation style**: hand-written bash arg/enum/jq-shape checks kept in sync with the JSON
  Schema doc, matching `events-append.sh`'s existing idiom — not a runtime JSON-Schema-library
  call, even though `jsonschema` is installed locally. Introducing a new validation dependency
  pattern that nothing else in the codebase uses is out of scope and inconsistent with house style.

## Risks & Mitigations

- **Risk**: A read-modify-write `update` subcommand under `flock` is genuinely novel (no
  precedent in `core/scripts/`) and is easy to get subtly wrong (e.g. losing the lock across the
  temp-file rename, or validating before vs. after the merge). **Mitigation**: validate the merged
  result (not just the delta) before the atomic `mv`, and hold the `flock` for the entire
  read-jq-write-mv sequence, not just the write.
- **Risk**: The known deploy-mechanism gap (new scripts not always reaching an already-loaded
  extension's deployed tree via headless sync) could make `errors-append.sh` exist in the source
  store but not actually be callable in this repo's `.claude/scripts/` after implementation.
  **Mitigation**: the implementation/verification phase should explicitly check
  `.claude/scripts/errors-append.sh` exists and is executable post-deploy, not just that the
  source-store file was written.
- **Risk**: Migrating the `commands/errors.md` Fix Mode's git-staging block (which currently
  hand-stages `specs/errors.json`) to call `errors-append.sh update` could silently change staging
  behavior. **Mitigation**: keep the existing targeted-staging pattern from
  `git-staging-scope.md` unchanged; only the JSON-mutation step should route through the new
  script, not the git commit step.
- **Risk**: Treating "UNBLOCKS: tasks 951, 952, 953" as a real dependency could lead the planner
  to gate this task's completion on those three, which is backwards — they explicitly avoid
  `errors.json`. **Mitigation**: this report recommends the planner note the relationship as
  advisory/thematic only, matching the actual `dependencies` arrays in `state.json`.

## Context Extension Recommendations

- **Topic**: `errors.json` schema documentation currently lives split across three files with no
  single source of truth even after this task's docs are rewritten to "point at the schema" —
  consider whether a short `context/formats/errors-format.md` (mirroring `events-format.md`'s
  role for `events.jsonl`) would be a cleaner target for those pointers than the raw schema file
  alone, since the schema JSON itself does not carry prose about the append/update script contract,
  lazy-creation semantics, or the `fix_status` deprecation note. This is a call for the planner to
  make, not a decision made here — the task's WORK item 1 only asks for the schema file itself.

## Appendix

### Search Queries / Commands Used

- `ls specs/errors.json`, `find . -iname "errors.json"` (existence check)
- `grep -rn "\.errors *+=" agent-system/extensions/core/` (inline writer sweep)
- `grep -rln "errors\.json" agent-system/extensions/` (full reference enumeration, 27 files)
- `grep -n "flock" agent-system/extensions/core/scripts/*.sh` (precedent check — 1 hit, events-append.sh only)
- `jq -r 'type'` / `jq -r '.[].fix_status'` against `/home/benjamin/Projects/cslib/specs/errors.json` (live data verification)
- `which ajv`, `python3 -c "import jsonschema; print(jsonschema.__version__)"` (validator tooling availability check)
- Direct reads of `rules/error-handling.md`, `commands/errors.md`, `skill-planner/SKILL.md` (lines 475-504), `events-append.sh`, `events-schema.json`, `events-format.md`, `orchestrator-postflight.sh` (lines 220-260), `events-log-artifact.sh` (lines 70-169), `manifest.json` (scripts array + schemas dir), `verify-deploy.sh` (lines 100-150), `deploy-root-guard.sh`, `source-store-deploy-boundary.md`
- Full-text reads of abandoned task 954 and 955 descriptions via `jq` against `specs/state.json`
  (their directories were never created, so the descriptions preserved in state.json are the only
  surviving record of their defect inventories)
- TODO.md reads of tasks 951, 952, 953, 950 for the "UNBLOCKS" claim cross-check

### References

- `agent-system/extensions/core/scripts/events-append.sh` (pattern to mirror)
- `agent-system/extensions/core/context/schemas/events-schema.json` (schema pattern to mirror)
- `agent-system/extensions/core/context/formats/events-format.md` (format-doc pattern to mirror)
- `agent-system/extensions/core/rules/error-handling.md`, `commands/errors.md`,
  `skills/skill-planner/SKILL.md` (the three inconsistent schema blocks + the one real writer)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh`,
  `hooks/events-log-artifact.sh` (the two real readers)
- `specs/state.json` project_number 954, 955 (superseded task descriptions with defect inventories)
- `/home/benjamin/Projects/cslib/specs/errors.json` (live cross-repo data used for empirical
  verification only; not read/write target of this task)

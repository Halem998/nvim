# Research Report: One state.json schema, one status vocabulary, converted extension writers

- **Task**: 984 - Give specs/state.json a machine-enforced schema and make the status vocabulary a single source of truth
- **Started**: 2026-08-09T17:58:00Z
- **Completed**: 2026-08-10T01:03:00Z
- **Effort**: ~3 hours research
- **Dependencies**: None remaining (969, 962, 988 all landed and are archived-completed; their outputs are incorporated as verified findings below)
- **Sources/Inputs**:
  - Live source-store files under `agent-system/extensions/core/` (schemas, standards, reference, formats, scripts)
  - Live `specs/state.json` (data-level empirical check)
  - `specs/reviews/review-2026-07-29-agent-system.md` (state-machinery section, T10 proposal)
  - `specs/archive/state.json` (completion summaries for tasks 950, 962, 969, 988)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The review's core claims are real but two are **partially stale**: task 962 (already completed)
  added a full `[PR READY]` definition to `status-markers.md`, and task 969 (already completed)
  already extended `state-write.sh` with `--state-file`/`--init` for archive/vault targets — the
  prerequisite item 5 needs before non-core writers can be converted (item 5 itself stays
  explicitly out of scope for this task's plan, per the user's framing).
- The two vocabulary docs still genuinely disagree, but the precise shape of the divergence is
  narrower and more interesting than "13 vs 12, one has X the other doesn't": `status-markers.md`
  defines `[PR READY]` fully in prose but **its own summary mapping table omits it** (internal
  self-inconsistency introduced by task 962's partial fix); `state-management-schema.md` never
  mentions `revising`/`revised` anywhere in the file. Both statuses are unreachable through
  `update-task-status.sh`'s `map_status()` (no `revise` case exists), and `skill-reviser` itself
  documents skipping them entirely ("No intermediate 'revising' status is needed... Skip
  preflight status update"). **`revising`/`revised` are dead vocabulary, not merely
  under-documented** — the schema decision should very likely be to delete them, not reconcile
  them into the enum.
- Live `specs/state.json` no longer has the two originally-cited data defects (no stray `updated`
  field, no entry missing `title` — all 15 active entries have it) — those were apparently
  cleaned up since the review. The undocumented-field inventory is otherwise confirmed exactly as
  described: 4 undocumented top-level fields (`active_topics`, `completed_projects`,
  `memory_health`, `version`) + `repository_health`'s 3 undocumented sub-fields
  (`todo_count`, `fixme_count`, `build_errors`) + 4 undocumented per-entry fields (`topic`,
  `description`, `session_id`, `title`).
- The 4 "phantom" documented fields need a nuanced verdict, not uniform treatment: `vault_count`/
  `vault_history` are genuinely zero everywhere (active and archive) but that's **expected**
  — the vault trigger (`next_project_number > 1000`) has never fired, this is not dead code.
  `effort` is zero in the *current* 15 active entries but appears 276 times in archive — very
  much alive, just naturally sparse in an early-lifecycle snapshot. `next_artifact_number`
  (not named in the review but also zero in the active snapshot) appears 308 times in archive —
  same story. `reflection` (a newer field) is genuinely zero everywhere including archive —
  either not yet exercised or a mechanism not yet actually wired to fire.
- `command-structure.md` has exactly **8 distinct defect sites** (not 2), confirming the task
  description's count precisely: 6 sites carry the wrong store path (`.claude/state.json` instead
  of `specs/state.json`), wrong array name (`.tasks[]` instead of `.active_projects[]`), and wrong
  key name (`.number` instead of `.project_number`) — lines 74-75, 183-184, 541, 687, 748, and the
  819-820 write-idiom block (which additionally models the exact unprotected `jq ... > tmp.json;
  mv tmp.json ...` pattern `state-write.sh` exists to eliminate) — plus 2 more sites (lines 80,
  160) carrying the fabricated vocabulary `research_complete`/`ready`.
- `state-template.json` and `self-healing-implementation-details.md` are not just stale/dead —
  **both are actively wired into `index-entries.json`'s `load_when`** and get injected into live
  agent context today: the template loads for `meta-builder-agent` and `/task`; the self-healing
  spec loads for `/errors` and `/fix-it`. `ensure_state_json()` has zero callers/implementers
  anywhere outside its own defining doc — confirmed never built.
- `generate-todo.sh`'s `format_status()` has exactly the claimed permissive `*)` catch-all
  (uppercases whatever string arrives, no failure) alongside 12 known cases (matching
  `state-management-schema.md`'s 12-value list, i.e. also missing `revising`/`revised`).
- The codebase has an explicit, already-documented **convention against JSON-Schema-library
  runtime validators**: `errors-format.md` states outright "Nothing in `core/scripts/` uses one" —
  `events-append.sh`/`errors-append.sh` hand-validate via bash `case`/`jq`-shape checks mirroring
  their schema files. `validate-state.sh` should follow this same idiom, not introduce an `ajv`/
  `python3 -m jsonschema` dependency. `phase-heading-patterns.sh` (a *different*, phase-heading-
  level enum) is a good precedent for "one sourced shared library, many consumers" — worth
  replicating at the task-status-enum layer via a new `scripts/lib/status-vocabulary.sh`.
- `verify-deploy.sh` currently has 9 numbered gates (`── N. description ──` blocks with
  `say`/`pass`/`fail` helpers); a new schema-validation gate is a clean Gate 10 insertion.
- The vocabulary is independently re-typed at the executable layer in at least 8 core scripts
  (each hardcoding 5-12 of the status tokens: `generate-todo.sh`, `update-task-status.sh`,
  `generate-task-order.sh`, `orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`,
  `reconcile-task-status.sh`, `update-phase-status.sh`, `update-plan-status.sh`), which is the
  meaningful subset of the review's "~20 sites" claim — dozens of other files mention a single
  status token in passing (error messages, single case arms) and are not "re-typings" of the
  vocabulary in the same sense.
- Task 950 (abandoned, subsumed into this task) independently found and cited exactly the same
  `command-structure.md` two-defect starting point this research re-verified and then expanded to
  the full 8-site inventory — its abandonment note explicitly says the fix belongs here, "against
  a machine-enforced status enum instead of prose reconciliation."
- The ~110 non-core writer count (item 5, explicitly OUT of scope for this task's plan) was
  spot-checked and is directionally correct: `founder` has ~25 files with inline
  `jq .../mv .../state.json` idioms, `present` ~10, `lean`/`cslib` 4 each, `epidemiology` 1 — the
  prerequisite (`state-write.sh --state-file`/`--init`, task 969) is already built and available
  for whatever follow-on task takes this on.

## Context & Scope

This is a `meta` research task studying `specs/state.json`'s lack of a machine-enforced schema and
the disagreement between the two documents claiming to be the authoritative status vocabulary. The
task's `file_scope` is: `agent-system/extensions/core/context/schemas/`,
`context/standards/status-markers.md`, `context/reference/state-management-schema.md`,
`context/formats/command-structure.md`, `scripts/generate-todo.sh`,
`scripts/update-task-status.sh` (all under `agent-system/extensions/core/`). Item 5 (~110
hand-rolled extension state writers) is explicitly split out of this task's plan per the task
description and the delegation instructions — verified only lightly, as a scoping sanity check,
not planned here.

All defects below were re-verified empirically against the live repository rather than trusted
from the review text, per the delegation instructions. Three prerequisite tasks named in the
review/task description (950, 962, 969) plus one unrelated hygiene task (988) have already landed
and are archived `completed` — their outputs are folded into the findings below rather than
re-proposed.

## Findings

### 1. state.json schema and validator (work item 1)

**No schema exists.** `agent-system/extensions/core/context/schemas/` currently has
`errors-schema.json`, `events-schema.json`, `frontmatter-schema.json`,
`orchestrator-handoff-schema.json`, `subagent-frontmatter.yaml` — no `state-schema.json`.
`events-schema.json` (draft-07, `required`/`properties`/`additionalProperties: false`) is the
correct structural precedent named in the task description.

**No validator exists.** `validate-handoff.sh` is the closest structural precedent for a
`validate-state.sh`: argument parsing, `--help`, colored PASS/FAIL/WARN counters, and (critically)
**hand-rolled bash + jq checks that reference the schema file only in comments** — it does not
shell out to a JSON-Schema engine. This is not an oversight; it is documented policy.
`context/formats/errors-format.md` states directly: "Both subcommands are hand-validated in the
`events-append.sh` idiom -- required-arg presence, closed-enum `case` checks, integer regex
checks, and `jq`-shape checks -- never a runtime JSON-Schema-library call (`ajv`,
`python3 -m jsonschema`). Nothing in `core/scripts/` uses one." The one mention of `ajv` in the
whole source store is a *documentation aside* in a migration guide
(`docs/guides/development/context-index-migration.md:242`, "If ajv-cli is available"), never an
actual runtime dependency. **`validate-state.sh` should follow the same idiom as
`events-append.sh`/`errors-append.sh`/`validate-handoff.sh`: bash + jq checks that mirror
`state-schema.json`, not a new external-tool dependency.**

**Live data is cleaner than the review's snapshot.** Neither of the two originally-cited data
defects is present in current `specs/state.json`:
```bash
jq -c '.active_projects[] | select(has("updated"))' specs/state.json   # -> empty
jq -c '.active_projects[] | select(has("title") | not)' specs/state.json  # -> empty (15/15 have title)
```
These were apparently repaired by other work since 2026-07-29. The undocumented/phantom-field
inventory otherwise holds up precisely:

| Category | Verified detail |
|---|---|
| Undocumented top-level fields (4) | `active_topics` (array of topic strings), `completed_projects` (array — currently empty, `[]`), `memory_health` (object: `last_distilled`, `distill_count`, `total_memories`, `never_retrieved`, `health_score`, `status`), `version` (string, currently `"1.1.0"`) |
| Undocumented `repository_health` sub-fields (3) | Live has `todo_count`, `fixme_count`, `build_errors` in addition to the documented `last_assessed`/`status` |
| Undocumented per-entry fields (4) | `topic`, `description`, `session_id`, `title` — present on all 15 live active entries but absent from `state-management-schema.md`'s Field Reference table (though `completion_summary`/`roadmap_items` DO appear in that doc's top-of-file JSON example while still missing from its own Field Reference table below — an internal doc inconsistency worth fixing alongside the rest) |
| "Phantom" fields, re-verified with nuance | `vault_count`/`vault_history`: 0 everywhere (active + archive) — but this is **expected**, the vault trigger (`next_project_number > 1000`) has never fired; not dead code. `effort`: 0/15 in the current active snapshot, but 276 occurrences in `specs/archive/state.json` — genuinely live, just naturally sparse pre-completion. `next_artifact_number` (not named by the review but same shape): 0/15 active, 308 in archive — same story. `reflection`: 0 occurrences anywhere including archive — the one field that may genuinely be unexercised so far (it is a newer mechanism per `state-management-schema.md`'s own description of its producer/consumer wiring) |

**Recommendation for the schema decision**: the schema should document all 9 confirmed-live
undocumented fields as legitimate optional properties (not reject them), keep `vault_count`/
`vault_history`/`effort`/`next_artifact_number` as documented-optional (their zero count in the
*current* snapshot is a lifecycle-timing artifact, not evidence they're unused), and treat
`reflection` as documented-optional pending its first real population.

### 2. Status vocabulary: the actual divergence (work item 2)

Both files were read in full and diffed conceptually against each other and against
`update-task-status.sh`'s executable behavior.

**`context/standards/status-markers.md`** (stamped 2026-01-05, but touched more recently by task
962): defines 14 markers in full prose sections — `NOT STARTED`, `RESEARCHING`, `RESEARCHED`,
`PLANNING`, `PLANNED`, `REVISING`, `REVISED`, `IMPLEMENTING`, `PR READY`, `COMPLETED`, `PARTIAL`,
`BLOCKED`, `ABANDONED`, `EXPANDED`. But its own "TODO.md vs state.json Mapping" summary table
lists only 13 rows and **omits `[PR READY]`/`pr_ready` entirely** — a self-inconsistency, not
merely "missing pr_ready" as a blanket file-level claim. This is very likely an artifact of task
962's fix: it added the full `[PR READY]` prose section but did not add the corresponding row to
the pre-existing summary table.

**`context/reference/state-management-schema.md`**: its "Status Values Mapping" table
(the file's only enumeration of the vocabulary) has exactly 12 rows: `not_started`,
`researching`, `researched`, `planning`, `planned`, `implementing`, `pr_ready`, `completed`,
`blocked`, `abandoned`, `partial`, `expanded`. `revising`/`revised` do not appear **anywhere** in
this 428-line file (confirmed via grep — zero hits for either string).

**Neither file is a superset of the other**, confirming the review's core claim, but the precise
shape matters for item 2's schema decision:

**`revising`/`revised` are dead, not just under-documented.** Three independent pieces of
evidence converge:
1. `update-task-status.sh`'s `map_status()` has explicit cases for `research`, `plan`,
   `implement`, `pr_ready`, `partial`, `blocked` — **no `revise` case at all**. Any
   `preflight:revise`/`postflight:revise` call falls into the catch-all `*)` arm and exits 1.
   `revising`/`revised` are therefore unreachable through the one canonical status writer.
2. `state-management-schema.md`, the file documenting the actual live JSON shape, never mentions
   them.
3. `skill-reviser/SKILL.md` (the one skill that would plausibly use them) says directly: **"No
   intermediate 'revising' status is needed for revision. The task transitions directly to
   'planned' on success (via postflight). Skip preflight status update."** — an explicit,
   documented decision to bypass them.

Given this, the schema/vocabulary reconciliation in item 2 has a clear empirical answer: **delete
`revising`/`revised` from `status-markers.md`** (both the prose sections and any residual table
row) rather than adding `revise` cases to `map_status()` to make them reachable — the one
consumer that would use them has already opted out by design.

**`generate-todo.sh`'s `format_status()`** (lines 117-134) confirms the claimed permissive
catch-all exactly:
```bash
format_status() {
  local raw="$1"
  case "$raw" in
    not_started)  printf '%s' "NOT STARTED" ;;
    ... # 10 more explicit cases, 12 total, matching state-management-schema.md's 12-row table
    *)            printf '%s' "$(echo "$raw" | tr '[:lower:]' '[:upper:]')" ;;
  esac
}
```
An off-schema value like `"in_progress"` (a real value from a *different*, `.return-meta.json`
vocabulary — see the cross-vocabulary confusion warning already documented in
`return-metadata-file.md`) or a typo would silently render as `"IN_PROGRESS"`/`"FOOBAR"` in
TODO.md rather than failing loudly, exactly as claimed. Deleting this arm (work item 2's
instruction) is a clean, mechanical fix once the enum is centralized — but doing it before
centralizing the enum would break `revising`/`revised` rendering if those are kept (another point
in favor of deleting them first, as recommended above).

**Re-typing inventory** (work item 2's "~20 sites" framing): the meaningful subset — files that
independently *enumerate* most/all of the vocabulary as a closed set, not files that merely
mention one status word in passing — is at least these 8 core scripts, each hardcoding 5-12 of
the status tokens as `case`/`jq` literals:

| Script | Distinct status tokens hardcoded |
|---|---|
| `generate-todo.sh` | 12 |
| `generate-task-order.sh` | 12 |
| `orchestrate-batch-admit.sh` | 12 |
| `orchestrate-triage-classify.sh` | 11 |
| `reconcile-task-status.sh` | 11 |
| `update-task-status.sh` | 9 (via `map_status`'s target-argument space, a related but distinct enumeration) |
| `update-plan-status.sh` | 7 |
| `update-phase-status.sh` | 5 |

Plus the two prose docs (`status-markers.md`, `state-management-schema.md`) themselves, plus
`context/patterns/skill-lifecycle.md`, `context/routing.md`, `docs/guides/user-guide.md`, and
`hooks/tts-notify.sh` (which each contain runs of 3+ consecutive status tokens, suggesting a
retyped list rather than incidental single mentions) — comfortably reaching the review's ~20-site
estimate without needing to count every file with a single passing status-word mention (34+ files
match a bare grep for `not_started` alone, but most of those are single-value error strings or
one `case` arm referencing one value, not vocabulary re-typings).

**A working single-source precedent already exists at a different layer**:
`scripts/lib/phase-heading-patterns.sh` is "the ONLY place the canonical `### Phase N: {name}
[STATUS]` grammar, the closed status-marker enum, and non-conforming-heading detection are
defined" for the **phase-heading** vocabulary (a different, narrower enum than the task-level
status vocabulary this task is about — `NOT STARTED`, `IN PROGRESS`, `COMPLETED`, `PARTIAL`,
`BLOCKED`, `COMPLETED WITH EXCLUSIONS`). Its header explicitly documents a self-verifying
consumer-discovery mechanism ("the current consumer list is found live via `grep -rl
'phase-heading-patterns.sh' agent-system/extensions`"). This is a directly reusable pattern for
item 2: a new `scripts/lib/status-vocabulary.sh` (or similar), sourced by `generate-todo.sh`,
`update-task-status.sh`, and the other scripts above, with the JSON schema's `enum` as the single
generation source (or at minimum, cross-checked against it in a test) and prose docs pointing at
it rather than restating it.

### 3. Bootstrap template and self-healing spec (work item 3)

**`state-template.json`** (69 lines, `_schema_version: "1.0.0"`) is completely divergent from live
shape: it has `project_numbering`, `state_references`, `completed_projects` (with a *different*
shape than live's empty top-level array), `pending_tasks`, `reviews_summary`, `archive_summary`,
`recent_activities`, `schema_info` — none of which exist in live `state.json`. Zero scripts read
it; the only two references anywhere are `index-entries.json` (context-index registration) and
the self-healing doc itself.

**`self-healing-implementation-details.md`** (594 lines) specs `ensure_state_json()`, a Python
pseudocode function that reconstructs `state.json` **from TODO.md** — the review's characterized
"inverts the canonical direction" is accurate: `state-management.md` is unambiguous that
`state.json` is the sole source of truth and TODO.md is generated *from* it, never the reverse.
`grep -rln "ensure_state_json"` across the entire core source store returns **only the file that
defines it** — zero callers, zero other implementers, confirming "never implemented" precisely.

**Both files are not merely dead — they are actively injected into live agent context today**,
which is a stronger and more urgent finding than "safe to delete because nothing references
them":
```json
{"path":"templates/state-template.json", ...,
 "load_when":{"agents":["meta-builder-agent"],"task_types":[],"commands":["/task"]}}
{"path":"repo/self-healing-implementation-details.md", ...,
 "load_when":{"agents":[],"task_types":[],"commands":["/errors","/fix-it"]}}
```
Per the context-discovery mechanism (`index-entries.json`'s `load_when` matching against
agent/command/task_type), `meta-builder-agent` and every `/task` invocation load the stale v1.0.0
template into context, and every `/errors`/`/fix-it` invocation loads the 594-line fictional
self-healing spec. This means work item 3 is not cleanup of inert files — it is removing content
that is actively poisoning two live commands' and one live agent's context with a schema shape
and a recovery direction that do not match reality. `index-entries.json` entries for both files
must be removed/updated as part of whatever remediation is chosen (retire+delete, or
rewrite-to-match-schema — either way the `index-entries.json` wiring needs a corresponding edit).

One unrelated, low-priority loose end: `root-files/settings.local.json` (a root-file, install-only
per the source-store/deploy-boundary convention — not itself part of this task's file_scope) has
a stale `Bash(mv ...)` permission-allowlist entry referencing this file's old path; harmless but
worth a one-line note for whoever eventually touches that file.

### 4. command-structure.md (work item 4) — exact site inventory

`command-structure.md` is 965 lines. Re-sweeping the whole file (not just the 2 sites task 950
originally cited) surfaces **exactly 8 distinct defect sites**, matching the task description's
"8 sites, not 2" precisely:

**Store-path / array-name / key-name defects (6 sites, all using the wrong
`.tasks[]`/`.number` shape instead of `.active_projects[]`/`.project_number`, 5 of 6 also using
the wrong `.claude/state.json` store path instead of `specs/state.json`)**:

| Lines | Snippet context | Wrong store? |
|---|---|---|
| 74-75 | `<step_3>` of `/plan`'s argument_parsing: `task_status=$(jq -r ".tasks[]..." .claude/state.json)` (×2 lines) | Yes |
| 183-184 | `<state_management><reads>` block, same query duplicated | Yes |
| 541 | Step_2 of another command's workflow | Yes |
| 687 | Pattern 1 "Read-Only Query" worked example | Yes |
| 748 | Pattern 2 "Status Update" **wrong** example — uses bare `state.json` (no `.claude/` prefix, so at least not doubly wrong, but still wrong array/key names) | Partially (bare `state.json`, still not `specs/state.json`) |
| 819-820 | Mistake 3 "Updating State Directly" — wrong example additionally models the exact unprotected `jq ".tasks[]... " .claude/state.json > tmp.json; mv tmp.json .claude/state.json` idiom `state-write.sh`'s mutex exists to eliminate | Yes |

**Fabricated-vocabulary defects (2 sites)**:

| Line | Text |
|---|---|
| 80 | `- Status must be "research_complete" or "ready"` |
| 160 | `Task not ready → "Task {task_number} status is {status}, expected research_complete or ready"` |

Neither `research_complete` nor `ready` is valid in any of the three real vocabularies in this
system (task-status, `.return-meta.json` status, or phase-heading status) — task 950's abandonment
note already flagged this as a plausible contamination source for an agent's off-schema
`.return-meta.json` write in production.

The "Correct" worked examples immediately following the "Wrong" blocks at lines 748 and 819
reference a `status-sync-manager` delegation abstraction that doesn't literally name any real
mechanism in this codebase (the real path is `skill_preflight_update()`/
`skill_postflight_update()` in `skill-base.sh` → `update-task-status.sh`, or the standalone
`skill-status-sync` skill) — worth normalizing while editing these blocks, though this is a softer
finding than the 8 hard defect sites above (not itself miscounted vocabulary/store/array/key, just
an imprecise abstraction name) and is noted here for the plan to weigh, not counted in the 8.

### 5. Extra invariant checks (work item 6) — grounding for validate-state.sh --deep

- **project_number uniqueness**: cheap `jq 'group_by(.project_number) | map(select(length>1))'`
  check; a good candidate for the `--deep` mode.
- **TODO.md sync**: `generate-todo.sh` already exists as a pure function
  (state.json → TODO.md); a regen-to-temp-file + `diff` against the live TODO.md is a
  straightforward invariant, consistent with how `verify-deploy.sh`'s Gate 8 already shells out to
  run a test suite and fail on nonzero exit.
- **Dependency-graph integrity**: `dependencies` arrays exist per-entry; dangling (references a
  `project_number` not in `active_projects` or `archive/state.json`), self-referential, and
  cyclic checks are all straightforward `jq`/graph-walk checks over the existing field — no new
  data needed.
- **Terminal-status immutability**: `status-markers.md` already documents `COMPLETED`/
  `ABANDONED`/`EXPANDED` as terminal (no further transitions) and `update-task-status.sh` already
  enforces the transition ladder via `map_status`'s closed case statement — a `--deep` check would
  compare a proposed new status against the last-known status from git history/backup rather than
  live JSON alone, since state.json itself has no "previous status" field to diff against
  in-place.

### 6. Item 5 spot-check (out of scope for this task's plan, verification only)

Confirmed directionally: `grep`-based scan of non-core extension `SKILL.md` files for
`jq .../mv .../state.json`-style idioms found founder ~25 files, present ~10, lean 4, cslib 4,
epidemiology 1 (28 files total matched by this narrower grep; the review's ~110 count is likely
counting individual `jq` invocations rather than files, consistent with founder having by far the
most). The prerequisite this item depends on — `state-write.sh --state-file`/`--init` support for
non-default targets — is **already built and shipped** by task 969 (its own completion summary:
"Extended state-write.sh with --state-file and --init, converted every hand-rolled archive/vault
state.json write site"). This means a follow-on task for item 5 has no remaining blocker before it
can start; it was left as "extends 969" in the review and that extension has already happened for
the archive/vault half — only the non-core-extension half remains.

## Decisions

- **Recommend deleting `revising`/`revised` from the enum** rather than reconciling them into
  `map_status()`, based on the three-way empirical evidence in Finding 2 (unreachable via the
  canonical writer, absent from the schema-reference doc, and explicitly bypassed by the one
  skill that would use them).
- **Recommend `validate-state.sh` follow the existing hand-rolled bash+jq idiom** (`events-append.sh`/
  `errors-append.sh`/`validate-handoff.sh`), not a new `ajv`/`jsonschema` runtime dependency — this
  is documented, established policy in this codebase, not merely a stylistic preference.
- **Recommend keeping `vault_count`/`vault_history`/`effort`/`next_artifact_number` as
  documented-optional** in the new schema rather than treating their current zero-population in
  the active snapshot as evidence of dead code — archive data shows all but `reflection` are
  demonstrably live once tasks complete or the vault threshold triggers.
- Item 5 (non-core extension writer conversion) stays out of this task's plan, per the delegation
  instructions; its prerequisite (`state-write.sh --state-file`/`--init`) is confirmed already
  available for a follow-on task.

## Risks & Mitigations

- **Risk**: deleting `revising`/`revised` from `status-markers.md` could surprise a reader who
  expects the plan-level `- **Status**:` subset (which explicitly does NOT include them either —
  confirmed, that subset is `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`)
  to still document a task-level state some future skill might want. **Mitigation**: note in the
  schema's changelog/migration note that `revising`/`revised` were removed as dead vocabulary,
  with a pointer to `skill-reviser/SKILL.md`'s explicit "skip preflight" decision as the reason,
  so a future implementer doesn't silently reintroduce them.
- **Risk**: `index-entries.json` edits for `state-template.json`/`self-healing-implementation-details.md`
  are outside this task's declared `file_scope`. **Mitigation**: the planning phase should decide
  whether to extend `file_scope` to include `index-entries.json` (a single, small, well-justified
  addition — without it, deleting/rewriting the two files leaves two `load_when`-wired but
  now-broken or misleading index entries still injecting content into `meta-builder-agent`,
  `/task`, `/errors`, and `/fix-it`).
- **Risk**: deleting `generate-todo.sh`'s permissive `*)` arm before centralizing the enum could
  break rendering for any currently-valid-but-undocumented status in flight (there are none live
  today, but the ordering still matters for the plan's phase sequencing — the enum
  reconciliation should land before the catch-all deletion, not after).

## Context Extension Recommendations

- **Topic**: single-source status/schema pattern
- **Gap**: no context doc currently documents `phase-heading-patterns.sh` as a *reusable pattern*
  for other closed-vocabulary problems in this codebase (it's documented only as the phase-heading
  grammar's own anchor). A short pattern doc under `context/patterns/` generalizing "one sourced
  shared library + self-discovering consumer list via `grep -rl`" would help future single-source
  consolidations (this task's item 2, and the review's other "N competing implementations" defect
  classes) reuse a proven shape instead of re-deriving one.
- **Recommendation**: after this task lands a `scripts/lib/status-vocabulary.sh`, consider
  extracting the shared "sourced-library + self-discovering consumers" shape into a documented
  pattern referencing both `phase-heading-patterns.sh` and the new library as worked examples.

## Appendix

### Search/verification commands used (representative, not exhaustive)

```bash
jq '.active_projects[] | select(.project_number==984)' specs/state.json
grep -n "state.json\|status vocabular\|status-markers\|command-structure.md" specs/reviews/review-2026-07-29-agent-system.md
grep -n "map_status" -A 60 agent-system/extensions/core/scripts/update-task-status.sh
grep -n "format_status" -A 40 agent-system/extensions/core/scripts/generate-todo.sh
grep -n "\.claude/state\.json\|\.tasks\[\]\|\.number ==" agent-system/extensions/core/context/formats/command-structure.md
grep -rln "ensure_state_json\|state-template.json\|self-healing-implementation-details" agent-system/extensions/core/
jq -c '.active_projects[] | select(has("updated")) or select(has("title")|not)' specs/state.json
jq -r '[.active_projects[] | keys[]] | unique | .[]' specs/state.json
grep -n "ajv\|jsonschema" agent-system/extensions/core/context/formats/errors-format.md
grep -n "── [0-9]\." agent-system/extensions/core/scripts/verify-deploy.sh
```

### References

- `agent-system/extensions/core/context/schemas/events-schema.json` — draft-07 precedent
- `agent-system/extensions/core/scripts/validate-handoff.sh` — bash+jq validator-shape precedent
- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh` — single-source-library
  precedent (different, narrower enum)
- `agent-system/extensions/core/context/formats/errors-format.md` — explicit no-runtime-JSON-Schema-
  library policy statement
- `agent-system/extensions/core/scripts/verify-deploy.sh` — 9 existing numbered gates; a schema
  validator becomes Gate 10
- `specs/archive/state.json` (project_number 950, 962, 969, 988) — completion summaries for the
  three prerequisite tasks and one unrelated hygiene task already landed

# Research Report: Task #995

**Task**: 995 - Convert surviving extension state.json writers to state-write.sh
**Started**: 2026-08-09
**Completed**: 2026-08-09
**Effort**: ~2-3 hours estimated for conversion + lint (research only, this report)
**Dependencies**: Task 983 (skill-skeleton collapse, COMPLETED/archived), Task 984 (state schema/status vocabulary, COMPLETED — item 5 explicitly deferred to this task), Task 969 (state-write.sh archive/vault coverage, COMPLETED, precedent for the lint methodology)
**Sources/Inputs**: Codebase grep across `agent-system/extensions/{founder,present,web,lean,cslib,epidemiology}/**`, `agent-system/extensions/core/scripts/state-write.sh`, `agent-system/extensions/core/context/schemas/state-schema.json`, `agent-system/extensions/core/scripts/verify-deploy.sh`, prior task summaries (969, 983, 984)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The skill-skeleton collapse (task 983) landed and fully cleaned two of the six extensions:
  **web** (0 survivors) and **epidemiology's `skills/` directory** (0 survivors — both skills now
  delegate to `update-task-status.sh`). It did NOT clean **founder**, **present**, **lean**, or
  **cslib**.
- Within the task's declared `file_scope` (the `skills/` subdirectory of each of the six named
  extensions), **29 `SKILL.md` files contain 69 hand-rolled `specs/state.json` read-modify-write
  sequences** using a fixed shared temp path (`specs/tmp/state.json`, `specs/state.json.tmp`, or
  `/tmp/state.tmp`) and no mutex — exactly the corruption/serialization gap `state-write.sh`
  exists to close.
- **Scope gap found and flagged**: the declared `file_scope` lists only `skills/` for
  founder/present/web/lean/cslib/epidemiology, but WORK item 1 of the task description explicitly
  calls for re-grepping the **FULL source store**. Doing so surfaces **16 additional survivor
  files (22 occurrences) in `commands/*.md`** for founder (10 files), present (5 files), and
  epidemiology (1 file — `epi.md`, meaning epidemiology is NOT fully clean once `commands/` is
  counted). These command-level sites are a structurally different operation (task *creation*,
  touching `next_project_number`, not postflight status/artifact updates) and are outside the
  literal `file_scope` string but inside the task description's own instructions. Recommend the
  planner make an explicit scope decision (expand file_scope now vs. spin a companion/follow-up
  task) rather than silently under- or over-delivering.
- One genuine **cross-repo path bug** found during the sweep:
  `cslib/skills/skill-pr-implementation/SKILL.md` writes to a hardcoded absolute path
  (`/home/benjamin/Projects/cslib/specs/state.json`) instead of the relative `specs/state.json`
  every other site uses — a single-user, single-machine hardcode that breaks for any other
  deployment. This should be corrected (dropped in favor of relative `specs/state.json`, matching
  the sibling call to `update-task-status.sh preflight` two stages earlier in the same file) as
  part of the conversion, not preserved.
- Two **schema-conformance risks** found (not blocking, but worth flagging to the planner):
  `base_branch` (written by `skill-pr-implementation`/`skill-pr-review-implementation`) and
  `forcing_data` (written by several founder `commands/*.md` task-creation sites) are not present
  in `projectEntry` in `state-schema.json`, which sets `additionalProperties: false`. Converting
  the write mechanism to `state-write.sh` does not by itself fix this — a `validate-state.sh
  --deep` run (or a future hard schema gate) would still reject these fields. Out of this task's
  stated scope ("preserving each site's semantics"), but should be logged as a follow-up.
- No repo lint currently exists for the "hand-rolled state.json writer" class outside the core
  extension's own callers; task 969 built one scoped to `agent-system/extensions/core/` only.
  WORK item 3 calls for generalizing it to cover the full source store — recommend a new
  `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`, following the
  existing `lint-routing-wiring.sh`/`lint-postflight-boundary.sh` pattern (source-store copy +
  deployed `.claude/` copy, wired as gate 12 in `verify-deploy.sh`, own `bash -n` + fixture test
  under `scripts/tests/`).

## Context & Scope

Task 995 was split out of task 984 (state schema/status vocabulary) specifically because
converting extension writers *before* the skill-skeleton collapse (task 983) would have been
partially wasted work — the collapse eliminates many hand-rolled blocks by routing domain skills
through a shared skeleton that calls `update-task-status.sh`. Task 983 is now COMPLETED and
archived (`specs/archive/983_extract_shared_skill_stage_skeleton/`), so this research re-grepped
the full source store as WORK item 1 instructs, rather than trusting the pre-collapse inventory
counts quoted in the task description (founder ~44, present ~22, web, lean, cslib — two via
`/tmp/state.tmp` — epidemiology).

The declared `file_scope` for this task is:
```
agent-system/extensions/founder/skills/, agent-system/extensions/present/skills/,
agent-system/extensions/web/skills/, agent-system/extensions/lean/skills/,
agent-system/extensions/cslib/skills/, agent-system/extensions/epidemiology/skills/
```

## Findings

### The target pattern: `state-write.sh`

`agent-system/extensions/core/scripts/state-write.sh` (deployed to
`.claude/scripts/state-write.sh`) is the single mutex-guarded writer for `specs/state.json` and,
via `--state-file`, for archive/vault-root state files. Contract summary relevant to this
conversion:

- `state-write.sh <jq-filter> --session-id SID [--arg NAME VALUE]... [--argjson NAME VALUE]...
  [--regen-todo] [--dry-run]`
- Acquires `specs/.scope-lock` (fail-closed; honors `SCOPE_MUTEX_HELD=1` guest mode when nested
  inside an outer holder's bracket — relevant since these skills' Stage 7/Stage 8 sequences run
  back-to-back and could pass `SCOPE_MUTEX_HELD` between calls if ever merged into one script
  block, though the existing core-skill conversions keep them as separate `state-write.sh`
  invocations, each acquiring its own bracket).
- Stages through a private `mktemp` file under `specs/tmp/`, validates JSON before `mv`, and
  atomically replaces the target.
- Exit codes: 0 success, 1 usage error, 2 mutex-acquire failure (ABORT), 3 jq transform failure, 4
  invalid-JSON validation failure.

### Live conversion precedent (already-landed pattern to copy)

`skill-status-sync` (core, already converted) shows the canonical two-step "update status" /
"append artifact" shape:

```bash
# Status update
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == {task_number})) |= . + {
    status: $status,
    last_updated: $ts
  }' \
  --session-id "{session_id}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg status "{target_status}"

# Artifact append
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == {task_number})).artifacts += [{"path": $path, "type": $type}]' \
  --session-id "{session_id}" \
  --arg path "{artifact_path}" --arg type "{artifact_type}"
```

`skill-researcher` (core, already converted) shows the safer binding style for the task number
itself — `--argjson num "$task_number"` bound into the filter as `$num`, rather than the
string-interpolated `'$task_number'` the surviving founder/present/lean/cslib sites use today:

```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == $num)).next_artifact_number = $new_num' \
  --session-id "$session_id" \
  --argjson num "$task_number" --argjson new_num "$artifact_number"
```

`skill-web-research`/`skill-web-implementation` (already fully converted, 0 survivors) are the
closest structural analogue to the extensions still needing conversion and are the best
side-by-side "after" reference during implementation.

### Full inventory: survivors inside the declared `file_scope` (`skills/` only)

29 files, 69 hand-rolled write sites, all of the shape
`jq '...' specs/state.json > <shared-temp-path> && mv <shared-temp-path> specs/state.json`
(three temp-path variants observed: `specs/tmp/state.json`, `specs/state.json.tmp`,
`/tmp/state.tmp`) — no `mktemp`, no mutex, shared/fixed staging path.

| Extension | Files (survivor count) | Occurrences |
|---|---|---|
| founder | 15: `skill-finance`, `skill-strategy`, `skill-deck-research`, `skill-deck-implement`, `skill-deck-plan`, `skill-project`, `skill-consult`, `skill-financial-analysis`, `skill-meeting`, `skill-founder-implement`, `skill-market`, `skill-legal`, `skill-founder-plan`, `skill-analyze`, `skill-founder-spreadsheet` | 37 |
| present | 5: `skill-slides`, `skill-budget`, `skill-timeline`, `skill-grant`, `skill-funds` | 17 |
| lean | 4: `skill-lean-research`, `skill-lean-research-hard`, `skill-lean-implementation`, `skill-lean-implementation-hard` | 10 |
| cslib | 5: `skill-cslib-vet`, `skill-pr-implementation`, `skill-pr-review-implementation`, `skill-pr-review-research`, `skill-cslib-research-hard` | 5 |
| web | 0 (already fully converted — uses `state-write.sh`) | 0 |
| epidemiology | 0 (both skills delegate to `update-task-status.sh`) | 0 |
| **Total** | **29 files** | **69** |

Representative example (`founder/skills/skill-finance/SKILL.md`, Stage 7/Stage 8):

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
This is a two-call sequence per skill (status update, then a two-step filter-out/append artifact
link per the repo's jq-safety convention) — the same shape repeats near-verbatim across all 15
founder skill files and the 5 present skill files (Stage 7 + Stage 8, ~2-3 write sites each). The
4 lean files and 5 cslib files follow the same shape but with lower per-file occurrence counts
(cslib's PR-related skills write to state.json only once each, for artifact linking or a
`base_branch` field).

### Non-standard variants requiring individual attention

- **`cslib/skills/skill-pr-implementation/SKILL.md` (line ~117-124)** — writes to a
  **hardcoded absolute path**, not the project-relative `specs/state.json` every other site uses:
  ```bash
  CSLIB_DIR="/home/benjamin/Projects/cslib"
  CSLIB_STATE="$CSLIB_DIR/specs/state.json"
  ...
  jq ... "$CSLIB_STATE" > /tmp/state.tmp && mv /tmp/state.tmp "$CSLIB_STATE"
  ```
  This is a single-user, single-machine hardcode inconsistent with the same file's own Stage 2
  (`bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"`,
  which resolves `specs/state.json` relative to the invoking repo, wherever it is checked out).
  Recommend the conversion drop `CSLIB_DIR`/`CSLIB_STATE` entirely and write the relative
  `specs/state.json` like every sibling skill — `state-write.sh` resolves relative
  `--state-file` values against the caller's cwd exactly as this raw `jq`/`mv` pair did, so the
  conversion is also the bug fix.
- **`cslib/skills/skill-pr-review-implementation/SKILL.md`** and
  **`skill-pr-review-research/SKILL.md`** use `/tmp/state.tmp` (machine-global, not
  project-scoped) as the shared staging path — worth calling out separately from the more common
  `specs/tmp/state.json` variant since `/tmp/state.tmp` collides across concurrent invocations
  from *any* project on the machine, not just concurrent invocations within one repo.
- **`cslib/skills/skill-cslib-vet/SKILL.md`** additionally performs **task creation** (prepending
  a new entry to `.active_projects` and bumping `next_project_number`), not just a status/artifact
  update — same operation shape as the `commands/*.md` sites described below, and worth converting
  with the same care around `next_project_number` race safety that `state-write.sh`'s single mutex
  already provides.

### Scope-boundary finding: survivors also exist in `commands/*.md`, outside the declared `file_scope`

The task's own WORK item 1 says to re-grep the **FULL source store**, not just the six declared
`skills/` directories. Doing so finds hand-rolled write sites in `commands/*.md` for three of the
six extensions — these are task-*creation* sites (building a fresh `.active_projects` entry and
incrementing `next_project_number`), structurally different from the skills' postflight
status/artifact-update sites, but the identical anti-pattern (`jq ... specs/state.json >
specs/tmp/state.json && mv ...`, no mutex, fixed shared temp path):

| Extension | `commands/*.md` files affected | Occurrences |
|---|---|---|
| founder | 10: `finance.md`, `strategy.md`, `deck.md`, `project.md`, `consult.md`, `analyze.md`, `meeting.md`, `market.md`, `legal.md`, `sheet.md` | 10 |
| present | 5: `budget.md`, `slides.md` (x2), `timeline.md` (x2), `grant.md` (x4), `funds.md` | 10 |
| epidemiology | 1: `epi.md` (x2) | 2 |
| **Total** | **16 files** | **22** |

This means **epidemiology is not fully clean** once `commands/` is counted, even though its
`skills/` directory (the declared scope) is. Example (`founder/commands/finance.md`, task
creation):

```bash
jq --argjson num "$next_num" --arg name "$slug" --arg desc "Financial analysis: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg task_type "finance" \
   --argjson forcing_data "$forcing_data_json" \
   '. + {next_project_number: ($num + 1)} |
    .active_projects += [{ project_number: $num, project_name: $name, status: "not_started",
      task_type: $task_type, description: $desc, created: $ts, forcing_data: $forcing_data,
      artifacts: [] }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Recommendation**: this is a genuine ambiguity between the letter of the declared `file_scope`
(narrowly `skills/`) and the task description's own WORK item 1 instruction (FULL source store).
The planner/orchestrator should make an explicit call:
- **Option A** — treat this as in-scope now (matches WORK item 1's literal instruction and the
  VERIFICATION BAR's "grep ... across the FULL source store returns zero"); expand file coverage
  to include the 16 `commands/*.md` files above.
- **Option B** — treat `commands/*.md` as a distinct, smaller follow-on task (these are
  task-creation sites, not postflight sites, so they may warrant a different jq-safety review
  given they touch `next_project_number`), and narrow the VERIFICATION BAR grep to the declared
  `skills/` scope for *this* task, explicitly noting the `commands/` residual as a known gap
  (mirroring how task 969's summary declared and justified its own scoped-grep exclusion list
  rather than claiming an unqualified "zero hits").

Either is defensible, but silently doing only `skills/` while the VERIFICATION BAR text says "FULL
source store" would leave the bar unsatisfiable, and silently doing both without flagging the
`file_scope` mismatch would under-communicate a real scope expansion. This report deliberately
does not pick for the planner.

### Schema-conformance risk (informational, not blocking this task)

`agent-system/extensions/core/context/schemas/state-schema.json`'s `projectEntry` definition sets
`additionalProperties: false` and does not list `base_branch` or `forcing_data` among its
properties. Two write sites in the survivor set populate these fields:
- `base_branch` — `cslib/skills/skill-pr-implementation/SKILL.md` and
  `skill-pr-review-implementation/SKILL.md`.
- `forcing_data` — several founder `commands/*.md` task-creation sites (e.g. `finance.md`,
  `strategy.md`).

Converting the *write mechanism* to `state-write.sh` does not change this — `state-write.sh` has
no schema-validation step of its own; it only stages/validates that the output is well-formed
JSON, not schema-conformant. If `validate-state.sh --deep` (wired as verify-deploy.sh gate 10) or
a future hard schema gate is ever run against a cslib/founder-deployed `specs/state.json`
containing these fields, it would fail. This task's WORK item 2 says "preserving each site's
semantics," so out-of-band schema changes are arguably out of scope here — but the finding should
be handed to whoever owns `state-schema.json` maintenance (or folded into this same conversion if
the planner judges it cheap enough — adding two optional string properties to `projectEntry` is a
small, additive schema change).

### Lint: no generalized "hand-rolled state.json writer" repo lint exists yet

`agent-system/extensions/core/scripts/lint/` currently has: `lint-agent-contracts.sh`,
`lint-contract-compliance.sh`, `lint-postflight-boundary.sh`, `lint-routing-wiring.sh` — none of
these check for hand-rolled `state.json` write sequences. Task 969 (state-write.sh archive/vault
coverage) built a **one-off verification grep** for that conversion, but scoped it to
`agent-system/extensions/core/` only, with an explicitly enumerated exclusion list (its own
summary: "scoping the verification grep to `agent-system/extensions/core/` plus an enumerated
exclusion list" — not a generalized, permanently-wired lint). It also recorded a caveat directly
relevant to this task: the grep only catches writes that redirect through a *literal*
`state.json`/`archive/state.json` path text adjacent to the redirect — writes indirected through
a shell variable (as `archive-task.sh`/`vault-operation.sh` originally did, and as
`skill-pr-implementation`'s `$CSLIB_STATE` does today) will not be caught by a naive grep and need
individual verification (`bash -n`, dry-run, or direct inspection) rather than relying on the grep
alone as a regression proof.

WORK item 3 of this task calls for generalizing that one-off check into a **permanently wired
repo lint** "where the other repo lints run." The existing lint scripts share a common shape worth
copying:
- Live at `agent-system/extensions/core/scripts/lint/lint-<name>.sh`, deployed to
  `.claude/scripts/lint/lint-<name>.sh`.
- `lint-postflight-boundary.sh` is the closest precedent for a *content-pattern* lint (as opposed
  to `lint-routing-wiring.sh`'s manifest-structure lint) — it is checked in `verify-deploy.sh`
  against **both** the source-store copy (existence check) and the deployed-tree copy (execution),
  since deploy state can drift from source.
- `verify-deploy.sh` currently runs gates numbered up to 11 (`lint-contract-compliance.sh`); a new
  lint would naturally land as gate 12, following the same `say "N. <description>"` / `fail
  "<message>" "<remediation hint>"` idiom used by every existing gate.
- Each existing lint has its own `scripts/tests/test-lint-<name>.sh` fixture suite (pass/fail
  fixtures) — the task's own VERIFICATION BAR ("fails on a fixture containing a hand-rolled write
  and passes on the clean tree") maps directly onto this convention.

Recommended grep basis for the new lint (broader than task 969's one-off, covering all three
observed temp-path variants and, per the caveat above, explicitly documented as *not* a substitute
for reviewing variable-indirected writes):
```bash
grep -rn 'jq .*specs/state\.json\|jq .*"\$[A-Z_]*STATE[A-Z_]*"' \
  agent-system/extensions/*/{skills,commands}/**/*.md \
  | grep -E '(mv .*state\.json|state\.json > |> .*state\.tmp|state\.json\.tmp)'
```
with an explicit exclusion list (mirroring 969's pattern) for `state-write.sh` itself, the one
legitimate archive->vault rename in `skill-todo/SKILL.md` (`mv archive/state.json state.json`,
not a `jq`-staged write), and any illustrative/decision-record prose under `specs/**` (already
exempt from the no-task-references rule's tree, and equally not a live writer).

## Decisions

- Confirmed via direct grep (not assumed from the pre-collapse inventory in the task description)
  that the skeleton collapse (task 983) already fully converted **web** and **epidemiology's
  `skills/`**, so the conversion work for those two extensions inside the declared `file_scope` is
  zero — the planner should not budget phases for them beyond a confirming re-grep.
- Treated the `commands/*.md` findings as a reportable scope-boundary finding rather than silently
  including or silently excluding them, since the declared `file_scope` and the task's own
  VERIFICATION BAR text disagree on breadth (see "Scope-boundary finding" above) — this is a
  decision for planning, not research, to resolve.
- Treated the `base_branch`/`forcing_data` schema gaps as informational findings for the schema
  owner, not as in-scope defects for this conversion task, per WORK item 2's "preserving each
  site's semantics" instruction — changing what's written is a different task than changing how
  it's written.

## Risks & Mitigations

- **Risk**: 69+ mechanical edits across 29 files (plus up to 22 more across 16 command files if
  scope is expanded) is a high-volume, error-prone mechanical conversion where a single dropped
  `--session-id` or malformed `--argjson` binding silently breaks a skill's postflight status
  update. **Mitigation**: convert one extension at a time as separate phases (founder, present,
  lean, cslib, plus a decision on commands/), each ending with a `bash -n`-equivalent markdown
  bash-fence extraction/lint pass (the same technique task 969's summary used: "116 bash fences
  extracted from 5 edited markdown files"), and a live dry-run smoke test per extension (the task's
  own VERIFICATION BAR already calls for "A founder/present skill dry-run exercises the converted
  write path").
- **Risk**: the `/tmp/state.tmp` and `$CSLIB_STATE` cslib sites are structurally different enough
  (different variable names, one hardcoded absolute path) that a single mechanical find/replace
  across all 29 files will miss them. **Mitigation**: handle the 3 cslib PR-related files
  (`skill-pr-implementation`, `skill-pr-review-implementation`, `skill-pr-review-research`) and
  `skill-cslib-vet` (task-creation shape) as individually-reviewed sites rather than batch
  find/replace targets, exactly as flagged above.
- **Risk**: a naive regex-only lint (per the 969 caveat) will not catch a future variable-indirected
  hand-rolled write, giving false confidence. **Mitigation**: document the limitation explicitly in
  the new lint's header comment (mirroring `state-write.sh`'s own header discipline), and pair the
  lint with the VERIFICATION BAR's dry-run smoke test rather than relying on the grep alone.

## Context Extension Recommendations

- **Topic**: repo-wide hand-rolled state-writer detection.
- **Gap**: no permanent, generalized lint exists for the "hand-rolled `specs/state.json`
  read-modify-write" anti-pattern class outside the one-off scoped grep task 969 used and did not
  preserve as reusable tooling.
- **Recommendation**: land `lint-state-writer-boundary.sh` (or similarly named) under
  `agent-system/extensions/core/scripts/lint/`, wired into `verify-deploy.sh` as the next gate,
  with its own fixture test — this closes WORK item 3 and gives future extensions (any not yet
  written) a standing guardrail instead of relying on periodic manual re-grep tasks like this one.

## Appendix

### Search queries used

```bash
# Per-extension survivor file/occurrence counts (declared file_scope)
grep -rln "mv .*state\.json\|state\.json > \|> .*state\.tmp\|/tmp/state\.tmp" \
  agent-system/extensions/{founder,present,web,lean,cslib,epidemiology}/skills/

# Full-source-store sweep beyond declared file_scope (commands/, agents/, scripts/)
grep -rn "mv .*state\.json\|state\.json > \|> .*state\.tmp\|/tmp/state\.tmp|state\.json\.tmp" \
  agent-system/extensions/{founder,present,web,lean,cslib,epidemiology} \
  --include="*.sh" --include="*.md"

# Cross-check: which skills already call state-write.sh (conversion precedent)
grep -rl "state-write\.sh" agent-system/extensions/*/skills/*/SKILL.md

# Schema conformance check for observed non-standard fields
grep -n "base_branch\|forcing_data\|additionalProperties" \
  agent-system/extensions/core/context/schemas/state-schema.json
```

### Files referenced

- `agent-system/extensions/core/scripts/state-write.sh` (target mechanism, full header contract)
- `agent-system/extensions/core/context/schemas/state-schema.json` (`projectEntry`,
  `additionalProperties: false`)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate numbering/wiring pattern, gates
  3-11)
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh`,
  `lint-postflight-boundary.sh` (lint-authoring precedent)
- `specs/archive/969_extend_state_write_to_archive_and_vault_targets/summaries/01_extend-state-write-archive-vault-summary.md`
  (verification-grep precedent and its documented caveats)
- `specs/archive/983_extract_shared_skill_stage_skeleton/summaries/01_shared-skill-stage-skeleton-summary.md`
  (confirms skeleton collapse landed)
- `specs/984_state_schema_and_status_vocabulary_single_source/summaries/01_*.md` (confirms item 5
  fully deferred, zero extension-writer conversion done there)

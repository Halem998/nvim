# Research Report: Task #1004

**Task**: 1004 - Fix /todo repository-metrics sync: build_errors is structurally always 0 and the technical_debt frontmatter target does not exist
**Started**: 2026-08-10
**Completed**: 2026-08-10
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core), state-schema.json, generate-todo.sh, skill-todo/SKILL.md, git-tracked deploy trees (.claude/, .opencode/)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed both defects exactly as described, at the cited line numbers, in the source store
  (`agent-system/extensions/core/commands/todo.md`, `agent-system/extensions/core/scripts/generate-todo.sh`).
- Found a **third, previously undocumented defect**: the `status` value todo.md's jq derivation
  produces (`"needs_attention"`) is not even a member of the enum `state-schema.json` declares for
  `repository_health.status` (`healthy | manageable | concerning | critical`). Any real fix must
  reconcile this, not just remove `|| true`.
- Confirmed empirically that this repo (the Neovim config itself) has **neither a Makefile nor a
  package.json** at its root — it is a live instance of exactly the "no probe applies" case the
  task description warns about. `make check 2>/dev/null || npm run lint 2>/dev/null` would take the
  `else` branch on this very repo even with `|| true` removed.
- Confirmed there is **no consumer of the `technical_debt` frontmatter block anywhere in the source
  store** (`agent-system/extensions/**`). The only places that reference a `technical_debt:` YAML
  block are `todo.md` itself (instructing the write) and the `.opencode/` tree (a separately
  git-tracked, non-agent-system deploy target, out of scope per the source-store rule). This
  resolves Defect 2's "verify a real consumer first" instruction: **take option (b)** — delete Step
  5.7.3, let `state.json` be the sole home for `repository_health`.
- Confirmed `generate-todo.sh` performs a full regenerate-and-atomic-`mv` on every run (no
  read-modify-write of the existing file), so any hand-written frontmatter block is unconditionally
  destroyed on the very next `/todo` run — corroborating the task's claim.
- Found a precedent in the same schema file for expressing "not measured": `memory_health.last_distilled`
  is typed `["string", "null"]`. The same pattern (`["integer", "null"]`) is directly reusable for
  `build_errors` to express "not measured" without inventing new schema conventions.
- `skill-todo/SKILL.md` (agent-system/extensions/core/skills/skill-todo/SKILL.md) has **no stage at
  all** covering repository-metrics sync (verified against its full stage list: 16 stages, none
  named or containing metrics/health/build_errors/technical_debt logic). The task's WORK item 4
  ("mirror the change") assumes an existing stage to update — there is none. This is a finding for
  the plan to account for, not a mirroring target.

## Context & Scope

Researched the `/todo` command's "Sync Repository Metrics" stage (`todo.md` Step 5.6) and its two
defects: an unconditionally-true build-health probe, and an instruction to write YAML frontmatter
that `generate-todo.sh` never emits and that nothing consumes. Scope is limited to the source store
(`agent-system/extensions/core/**`); `.claude/**` is confirmed to be the disposable deployed copy
(identical byte-for-byte to the source-store file for `skill-todo/SKILL.md`, and `.claude/` is
blanket-gitignored per `.gitignore:6`), so no `.claude/**` edits are in scope or needed.

## Findings

### Codebase Patterns

**Defect 1 location** — `agent-system/extensions/core/commands/todo.md:758-763`:
```bash
# Build errors (0 if project-specific lint/check passes)
if make check 2>/dev/null || npm run lint 2>/dev/null || true; then
  build_errors=0
else
  build_errors=1
fi
```
Confirmed the `|| true` makes the `if` unconditionally true. Confirmed downstream derivation at
`todo.md:774`:
```
"status": (if ($build_errors | tonumber) == 0 then "healthy" else "needs_attention" end)
```

**Schema/vocabulary mismatch (new finding)** — `agent-system/extensions/core/context/schemas/state-schema.json:32-49`
declares:
```json
"status": { "type": "string", "enum": ["healthy", "manageable", "concerning", "critical"] }
```
`"needs_attention"` is not in this enum. `agent-system/extensions/core/context/reference/state-management-schema.md:285`
independently documents the same 4-value enum. Neither `validate-state.sh` nor `state-write.sh`
performs deep type/enum validation on `repository_health` (confirmed: `validate-state.sh` only
checks top-level key names and the 12-value task-status enum on `active_projects[].status`;
`state-write.sh` only validates jq filter syntax) — so this mismatch is currently silent, but it is
still a real spec inconsistency the fix should not perpetuate. The plan should either (a) map the
probe outcome onto the documented 4-value enum, or (b) revise the enum to include whatever new
status vocabulary the fix introduces (e.g. adding `"unknown"`/`"not_measured"`), updating both
`state-schema.json` and `state-management-schema.md` together. Given the task allows extending the
schema for the "not measured" case anyway, extending the enum at the same time is the lower-risk
path (one coordinated schema edit vs. two skewed sources of truth).

**Repo reality check**: `ls` at repo root confirms no `Makefile`, no `package.json`. This is a
Neovim Lua configuration repo whose agent-system is also deployed into Python, Lean, Nix, LaTeX,
Z3, web, etc. project trees (per `agent-system/extensions/*`). No single project-specific check
command is portable across these targets — confirming the task's framing that a fix addressing only
the `|| true` (leaving `make check || npm run lint` as the sole probe) would flip the failure mode
from false-GREEN to false-RED on the majority of deployment targets, including this very repo.

**Precedent for "not measured" typing** — `agent-system/extensions/core/context/schemas/state-schema.json:63`:
```json
"last_distilled": { "type": ["string", "null"] }
```
in `memory_health`, maintained by `/distill`. This is a directly reusable pattern: extend
`build_errors` to `{"type": ["integer", "null"]}` with `null` meaning "not measured" (no applicable
probe found), rather than inventing a new sentinel value or string-typed field.

**Defect 2 evidence** — `agent-system/extensions/core/scripts/generate-todo.sh:314-323`
(`generate_todo()`) emits only:
```bash
printf -- '---\n'
printf 'next_project_number: %s\n' "$next_num"
printf -- '---\n'
```
No `technical_debt` or `repository_health` keys are ever written. The function is called from the
non-dry-run path as `generate_todo() > "$TEMP_FILE"; mv "$TEMP_FILE" "$TODO_FILE"` (lines 494-497)
— a full atomic overwrite, never a read-modify-write — so **any** hand-authored frontmatter
addition is silently destroyed on the next `/todo` (or any other `generate-todo.sh`-driven) run.
This matches the task's claim precisely and rules out any variant of "just also hand-write it" as a
fix.

**Consumer search for `technical_debt` (Defect 2's decision gate)** — grepped the full repo for
`technical_debt` and `repository_health`. Findings:
- `technical_debt`: appears only in `agent-system/extensions/core/commands/todo.md` (the
  instruction itself, describing a block that doesn't exist) and its deployed copies
  (`.claude/commands/todo.md`, gitignored) and in the **separately git-tracked** `.opencode/` tree
  (`.opencode/commands/todo.md`, `.opencode/context/**/state-template.json`,
  `.opencode/context/**/self-healing-implementation-details.md`). `.opencode/` is a parallel,
  independently-tracked deploy target for the OpenCode CLI, not generated from
  `agent-system/extensions/**` by any script found (no `agent-system/**/*.sh` references
  `opencode`), and is out of scope under the binding source-store rule (which names
  `agent-system/extensions/**` vs. `.claude/**` only). **No file under `agent-system/extensions/**`
  reads or consumes a `technical_debt` frontmatter block.**
- `repository_health`: real consumers exist, but all read `state.json`, never TODO.md frontmatter:
  `agent-system/extensions/core/scripts/validate-state.sh` (top-level key presence check),
  `agent-system/extensions/memory/skills/skill-distill/SKILL.md:276,2467` (mirrors
  `repository_health.status` vocabulary for its own `memory_health.status` thresholds, and notes
  `memory_health` is "a top-level sibling of `repository_health` in state.json").

This directly answers the task's Option (a)-vs-(b) gate for Defect 2: **no real consumer of the
frontmatter block exists in the source store, so option (b) applies** — delete Step 5.7.3, leave
`repository_health` living solely in `state.json` (which is already its actual, working home; Step
5.7.2's `state-write.sh` call is correct and unaffected).

**`skill-todo/SKILL.md` mirror check** — read the full stage list (16 stages: ParseArguments,
ReconcileScan, ScanTasks, TopicRevision, DetectOrphans, DetectMisplaced, ScanRoadmap,
ScanMetaSuggestions, HarvestMemories, DryRunOutput, InteractivePrompts, ArchiveTasks, UpdateRoadmap,
UpdateREADME, UpdateChangelog, CreateMemories, GitCommit, OutputResults) and grepped for
`metrics|health|debt|todo_count|fixme`. The only hit is unrelated (`memory_health`, stage 14/16,
already-correct distill-suggestion logic). **There is no "Sync Repository Metrics" stage in
`skill-todo/SKILL.md` to mirror the fix into.** The task's WORK item 4 phrasing ("mirror the change
into skill-todo/SKILL.md, which describes the same stage") does not match what's on disk — treat
this as informational for the plan (nothing to edit there for this defect) rather than a missed
mirroring step. Confirmed via `diff` that `agent-system/extensions/core/skills/skill-todo/SKILL.md`
and `.claude/skills/skill-todo/SKILL.md` are byte-identical (deployed copy, not independently
editable), and that `.opencode/skills/skill-todo/SKILL.md` is a stale/divergent variant outside the
binding source-store scope.

### External Resources

Not applicable — this is a self-contained internal tooling defect; no external library/API
research was needed.

### Recommendations

**Defect 1 — meaning and probe** (WORK items 1-2):

Adopt reading **(a) "the tree is structurally sound"** as `build_errors`'s definition. Rationale:
`/todo` runs on every task-archival cycle across a heterogeneous set of deployment targets (this
Lua/Neovim repo plus Python, Lean, Nix, LaTeX, Z3, web extension targets per
`agent-system/extensions/*`); a project-specific "the project's own check command passes" (reading
b) has no single portable command, is expensive (full `lake build`/`nix flake check`/full pytest
run) to run on every `/todo` invocation, and — as demonstrated empirically against this very repo
root — has no applicable command on a plurality of targets today. Reading (a) can be satisfied
cheaply and portably using tooling this agent-system already hard-depends on everywhere
(`bash`, `jq`): e.g. `bash -n` syntax-checking every tracked `*.sh` file and `jq empty` validating
every tracked `*.json` file, summing failures into an integer count. This is a real, executable
regression probe (a broken edit to any of the extensive `agent-system/**/scripts/*.sh` tree, or a
malformed `state.json`/`state-schema.json`, will genuinely fail it) — not a rubber-stamp. When zero
such files are found (degenerate case), or if the plan prefers a per-language-marker probe chain
(Makefile/package.json/pyproject.toml/lakefile.lean/flake.nix) that can come up empty on an unknown
project layout, the field must be able to express "not measured" rather than guessing 0 or 1 —
reuse the `["type", "null"]` union pattern already present at `memory_health.last_distilled`
(`state-schema.json:63`): change `build_errors` to `{"type": ["integer", "null"]}`, `null` =
not measured. Remove the `|| true`. Update `status` derivation to a three-way (or explicit
null-check) branch so "not measured" does not fall through to either "healthy" or "needs_attention".

Whatever probe is chosen, also fix the enum mismatch found above: either emit one of
`state-schema.json`'s existing four values (`healthy`/`manageable`/`concerning`/`critical`) from the
derivation instead of the non-existent `"needs_attention"`, or extend the enum (and its mirror in
`state-management-schema.md`) to include the new not-measured status value. Keep `state-schema.json`
and `state-management-schema.md` synchronized — they currently agree with each other and disagree
only with `todo.md`'s implementation.

**Defect 2 — resolve in ONE direction** (WORK item 3): take **option (b)** per the consumer search
above. Delete Step 5.7.3 (`todo.md:783-807`, "Update TODO.md frontmatter" instructions and the
`technical_debt:`/`repository_health:` YAML block shown) entirely. Step 5.7.2's `state-write.sh`
call already correctly persists `repository_health` to `state.json`; no `generate-todo.sh` change is
needed for Defect 2 under option (b) (only Defect 1's probe/status logic touches `todo.md`'s Step
5.7.1/5.7.2 bash block). Renumber/adjust the remaining Step 5.7.4 "Report metrics sync" tracking
bullets if they referenced the now-deleted frontmatter update.

**WORK item 4** (mirror into `skill-todo/SKILL.md`): no action needed — confirmed no existing stage
covers this territory in that file, so there is nothing to mirror. If the plan wants
`skill-todo/SKILL.md` to eventually gain full parity with `todo.md`'s Step 5.6, that is a separate,
larger scope-expansion decision (adding a wholly new stage) outside this defect-fix task's stated
WORK items 1-3; recommend the plan explicitly scope WORK item 4 as "confirmed not applicable" rather
than silently skipping it.

**Verification bar mapping**:
- "Fixture repo whose check command FAILS produces non-zero/failed build_errors and non-healthy
  status" -> create a scratch fixture dir with a `*.sh` file containing a deliberate syntax error
  (e.g. unmatched quote), run the new probe logic against it, assert `build_errors > 0` and
  `status != "healthy"`. This must be an actual executed script/test per the task, not a reasoned
  claim.
- "Fixture repo with no recognised check command does not silently report either 0 or 1" -> create
  a scratch fixture dir with none of the probe's trigger files, run the probe, assert the result is
  the "not measured" (`null`) sentinel, not `0` or `1`.
- "Running generate-todo.sh twice leaves frontmatter byte-identical" -> trivially satisfied by
  option (b) (Defect 2), since `generate-todo.sh` is unchanged and already deterministic given a
  fixed `state.json`; still worth an explicit two-run `diff` assertion in the test since it is named
  as a hard verification bar.

## Decisions

- Defect 1 field meaning: **reading (a)**, "structurally sound" (parseable/syntax-valid), not
  reading (b) "project's own check command passes" — portability and cost favor (a); this repo's
  own root (no Makefile/package.json) is live proof reading (b) has no universal probe.
- Defect 1 schema: extend `build_errors` to `{"type": ["integer", "null"]}`; `null` = not measured.
  Reconcile the `status` derivation with `state-schema.json`'s existing 4-value enum (fix the
  `"needs_attention"` mismatch found during this research) rather than leaving two disagreeing
  vocabularies.
- Defect 2: **option (b)** — delete Step 5.7.3 from `todo.md`; `state.json` remains the sole home
  for `repository_health`. No real consumer of a `technical_debt` TODO.md-frontmatter block exists
  anywhere in `agent-system/extensions/**`.
- WORK item 4: no `skill-todo/SKILL.md` edit is needed for this defect — that file has no
  repository-metrics stage today to mirror into.

## Risks & Mitigations

- **Risk**: a `bash -n`/`jq empty`-based structural probe could still return 0 findings (and thus a
  possibly-misleading "healthy") on a repo with no `*.sh`/`*.json` files at all. **Mitigation**: this
  is exactly the "not measured" case — the schema change (nullable `build_errors`) exists precisely
  so this degenerate case is represented honestly rather than defaulting to 0.
- **Risk**: extending `state-schema.json`'s enum or type could be seen as scope creep beyond "fix
  the two defects." **Mitigation**: the task text explicitly authorizes this ("if the schema cannot
  express that, extend it rather than picking a misleading number"); the enum mismatch is a
  pre-existing latent bug uncovered while implementing the required fix, not unrelated scope.
- **Risk**: deleting Step 5.7.3 could look like leaving Defect 2 "half-fixed" if a future contributor
  expects TODO.md frontmatter to carry health data. **Mitigation**: document the decision inline in
  `todo.md` near Step 5.7.2 (a one-line note: "repository_health lives in state.json only; TODO.md
  frontmatter does not mirror it — no consumer exists") so the decision's rationale survives, not
  just its absence.

## Context Extension Recommendations

- **Topic**: repository_health status vocabulary.
  **Gap**: `state-schema.json`'s declared enum (`healthy|manageable|concerning|critical`) and
  `todo.md`'s actual derivation (`healthy|needs_attention`) have silently disagreed with no
  validation catching it (`validate-state.sh` does not deep-validate `repository_health`).
  **Recommendation**: after this fix, consider adding a `repository_health.status` enum check to
  `validate-state.sh` (mirroring its existing 12-value task-status enum check pattern) so this class
  of drift cannot recur silently. Not required for this task's verification bar, but a natural
  follow-up the plan may want to flag as future work.

## Appendix

**Files inspected**:
- `agent-system/extensions/core/commands/todo.md` (Step 5.6, lines 743-815; Step 5.5 lines 662-741
  for surrounding context)
- `agent-system/extensions/core/scripts/generate-todo.sh` (frontmatter emission, lines 314-323;
  atomic-write main path, lines 476-501)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (full stage list, 1096 lines)
- `agent-system/extensions/core/context/schemas/state-schema.json` (`repository_health`,
  `memory_health` definitions)
- `agent-system/extensions/core/context/reference/state-management-schema.md`
  (`repository_health`/`Repository Health Fields` documentation)
- `agent-system/extensions/core/scripts/validate-state.sh`, `state-write.sh` (validation depth check)
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` (repository_health/memory_health
  consumer reference)
- `specs/state.json` (`.repository_health` current live value), `specs/TODO.md` (frontmatter as
  actually generated)
- `.gitignore`, `.claude/commands/todo.md`, `.opencode/commands/todo.md`,
  `.opencode/context/**/state-template.json` (deploy-boundary / consumer-search verification)

**Commands run**: `grep -rn "technical_debt"`, `grep -rln "repository_health"`,
`git ls-files`/`git check-ignore -v` (deploy-tree boundary verification), `ls Makefile package.json`
(repo-root probe-applicability check), `diff` between source-store and deployed `skill-todo/SKILL.md`.

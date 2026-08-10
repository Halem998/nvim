# Implementation Plan: Task #1004

- **Task**: 1004 - Fix /todo repository-metrics sync: build_errors is structurally always 0 and the technical_debt frontmatter target does not exist
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/1004_fix_todo_repository_metrics_sync/reports/01_repository-metrics-sync-fix.md
- **Artifacts**: plans/01_repository-metrics-sync-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/todo` command's "Sync Repository Metrics" stage carries a build-health probe that can never
report failure, an instruction to write TODO.md frontmatter that no generator emits and no
consumer reads, and a status vocabulary that disagrees with the declared schema. The core
architectural move in this plan is to **extract the probe out of markdown prose and into a real,
executable script** (`scripts/assess-repo-health.sh`), because the task's verification bar demands
executed fixture tests and a bash snippet embedded in an instruction file cannot be tested — it
can only be re-read. Once the probe is a script with a JSON contract, `todo.md` shrinks to a call
site, the schema is reconciled once, and the three verification bars become ordinary assertions in
a fixture-driven suite following the repo's existing `scripts/tests/` convention.

### Research Integration

The plan adopts every decision the research settled, and adds one finding made while validating
those decisions against the live tree:

- **Defect 1 meaning**: reading (a), "the tree is structurally sound", via a portable `bash -n` /
  `jq empty` probe over tracked `*.sh` / `*.json` files. Reading (b) is rejected — this repo root
  has neither `Makefile` nor `package.json`, and the agent system deploys into Lua, Python, Lean,
  Nix, LaTeX, Z3, and web trees with no common check command.
- **Defect 1 schema**: `build_errors` becomes `{"type": ["integer", "null"]}`, reusing the
  `memory_health.last_distilled` precedent for "not measured".
- **Third defect (research)**: `"needs_attention"` is not in the declared enum
  (`healthy|manageable|concerning|critical`). Reconciled here by emitting only declared values and
  extending the enum by exactly one member (`unknown`) for the not-measured case, updating
  `state-schema.json` and `state-management-schema.md` together.
- **Defect 2**: option (b) — delete the frontmatter step. No consumer exists anywhere under
  `agent-system/extensions/**`.
- **WORK item 4**: confirmed not applicable. `skill-todo/SKILL.md` has no repository-metrics stage
  to mirror into; this plan explicitly scopes it out rather than inventing a stage.

**Fourth defect, found while verifying the research's line citations** (not in the report, and it
changes what Phase 4 must fix): the Step 5.7.2 `jq` filter references `$build_errors`, but the
only binding passed is `--arg errors "$build_errors"`. `$build_errors` is undefined *inside* the
filter. Verified by execution:

```
$ echo '{}' | jq --arg errors "0" '... (if ($build_errors|tonumber)==0 then ...)'
jq: error: $build_errors is not defined at <top-level>, line 1, column 74
jq: 1 compile error
```

So the literal instruction as written cannot run at all — `state-write.sh` would exit 3 (jq
transform failed). The live `specs/state.json` nonetheless holds a populated
`repository_health`, which means the agent executing this markdown has been silently repairing the
binding at runtime. That is the strongest available evidence for this plan's central move: prose
that is *executed* but never *compiled* accumulates defects invisibly. Phase 4's rewrite must
eliminate the hand-assembled filter/binding mismatch, not merely correct the variable name.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- `build_errors` reflects a real, portable, executed structural probe that can fail.
- "Not measured" is representable and distinguishable from both 0 and 1.
- The emitted `status` value is always a member of the schema's declared enum.
- `repository_health` has exactly one home (`state.json`), with the decision recorded in place.
- All three verification bars are met by executed tests, wired into the standing test harness.

**Non-Goals**:
- Adding a repository-metrics stage to `skill-todo/SKILL.md` (no such stage exists; adding one is a
  separate scope decision).
- Editing `.opencode/**` (a separately tracked deploy target, outside the source-store rule's scope).
- Editing `.claude/**` (disposable deploy artifact; regenerated from the source store).
- Adding deep `repository_health` validation to `validate-state.sh` (flagged as follow-up).
- Making the probe run any project-specific build, lint, or test command.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New script/test not added to `manifest.json` `provides.scripts`, so it never deploys | H | M | Phase 5 registers both and asserts presence in the deployed tree; this is a known recurring defect class in this repo |
| Probe walks a huge tree and makes `/todo` slow | M | M | Enumerate via `git ls-files` where available; `bash -n` and `jq empty` are parse-only, no execution |
| Fixture dirs are not git repos, so a git-only enumeration finds nothing and every fixture reports "not measured" | H | M | Script must support a non-git `find` fallback; Phase 2 asserts the failing fixture reports a *failure*, which cannot pass if the fallback is missing |
| Probe sources a script as a side effect | H | L | `bash -n` is syntax-check-only and never executes; explicitly no `source`/`eval` in the probe |
| Enum extension seen as scope creep | L | L | Task text authorizes schema extension; the mismatch is a latent bug uncovered by the required fix |
| Deleting the frontmatter step reads as a half-fix to a later contributor | M | M | Phase 4 leaves an inline rationale note beside the surviving state.json write |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (and 3, for phase 4) |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extract the health probe into an executable script [COMPLETED]

**Goal**: Create `agent-system/extensions/core/scripts/assess-repo-health.sh`, a standalone,
portable, testable probe that emits the full `repository_health` object as JSON on stdout and
never writes state itself.

**Tasks**:
- [x] Create the script with `set -uo pipefail`, a header comment block matching the conventions of
      neighbouring core scripts, and `--help`. *(completed)*
- [x] Accept `--root PATH` (default: repo root resolved via `git rev-parse --show-toplevel` with a
      script-relative fallback), so fixtures can be pointed at a temp dir. *(completed)*
- [x] Enumerate candidate files: `git ls-files` when `--root` is inside a git work tree, else
      `find` over the root, excluding `.git/`. Collect `*.sh` and `*.json` separately. *(completed)*
- [x] Structural probe: run `bash -n` on each `*.sh` and `jq empty` on each `*.json`, counting
      failures into `build_errors`. Never `source`, `eval`, or execute a candidate file. *(completed)*
- [x] Degenerate case: when zero `*.sh` **and** zero `*.json` candidates are found, emit
      `build_errors: null` (JSON null, not the string "null", not 0, not 1). *(completed)*
- [x] Compute `todo_count` and `fixme_count` over the same enumerated set, preserving the existing
      source-file extension filter (`*.lua *.py *.js *.ts *.tex`) from the current Step 5.7.1. *(completed)*
- [x] Derive `status` from `build_errors` using only declared enum members:
      `null -> "unknown"`, `0 -> "healthy"`, `>0 -> "critical"`. *(completed)*
- [x] Emit `last_assessed` as `date -u +%Y-%m-%dT%H:%M:%SZ`. *(completed)*
- [x] Emit the whole object as one JSON document built with `jq -n --argjson`/`--arg` (never by
      string-concatenating JSON), so the output is well-formed by construction. *(completed)*
- [x] `chmod +x` the script. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the probe needs exactly two file classes (`*.sh`,
`*.json`) to be a non-rubber-stamp check. Confirm at implementation time by running the finished
script against this repo root and checking that the candidate count is non-trivial (hundreds of
`*.sh` under `agent-system/**/scripts/`); if the count is near zero, the enumeration is wrong and
the probe would be a rubber stamp regardless of the rest of the logic.

**Files to modify**:
- `agent-system/extensions/core/scripts/assess-repo-health.sh` - new file, the whole probe.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/assess-repo-health.sh` passes.
- Running it against the repo root emits JSON that `jq empty` accepts and whose keys are exactly
  `last_assessed, todo_count, fixme_count, build_errors, status`.
- `manageable` and `concerning` are deliberately never emitted by this derivation. They remain
  declared enum members reserved for a future graded metric (e.g. thresholded `todo_count`); record
  this in the script header so a reader does not mistake them for dead vocabulary.

---

### Phase 2: Fixture-driven test suite for the probe [NOT STARTED]

**Goal**: Prove the probe fails in its failing direction, using executed tests — the exact
property the original defect lacked.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` following
      `context/standards/shell-script-testing.md`: `set -uo pipefail`, `pass`/`fail`/`info`
      helpers, `PASSED`/`FAILED` counters, `mktemp -d` workdir with `trap ... EXIT`, exit 0/1.
- [ ] Resolve the script under test through the deploy-tree-first / source-store-fallback candidate
      list used by the sibling suites.
- [ ] **Bar 1 (failing fixture)**: build a temp dir containing a `*.sh` file with a deliberate
      syntax error (unmatched quote) and a malformed `*.json` file. Assert `build_errors > 0` AND
      `status != "healthy"` AND `status` is a member of the declared enum.
- [ ] **Bar 2 (no-probe fixture)**: build a temp dir containing only files of unrecognised types
      (e.g. a `.txt` and a `.lua`). Assert `build_errors` is JSON `null` — explicitly assert it is
      neither `0` nor `1` — and that `status == "unknown"`.
- [ ] **Clean fixture (control)**: a temp dir with a valid `*.sh` and a valid `*.json`. Assert
      `build_errors == 0` and `status == "healthy"`. Without this control, Bar 1 could pass from a
      probe that always fails.
- [ ] **Enum-conformance assertion**: read the `status` enum out of
      `context/schemas/state-schema.json` with `jq` and assert every status the suite observed is a
      member — an anti-drift check modelled on `test-status-vocabulary.sh` family (a).
- [ ] Non-git-fixture assertion: since `mktemp -d` dirs are not git work trees, Bars 1-2 passing is
      itself the proof that the `find` fallback works; add an `info()` line naming this so the
      coupling is visible.
- [ ] `chmod +x` the suite.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` - new file.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` exits 0 with every
  case reporting `[PASS]`.
- Negative control: temporarily invert the probe's failure counter, confirm Bar 1 and the clean
  control both go `[FAIL]`, then revert. A test that cannot fail is the defect being fixed;
  demonstrate this one can.

---

### Phase 3: Reconcile the state schema and its documentation mirror [COMPLETED]

**Goal**: Make the declared schema able to express both "not measured" and the not-measured status,
with the JSON schema and its prose mirror changed in the same phase so they cannot skew.

**Tasks**:
- [x] In `context/schemas/state-schema.json`, change `repository_health.build_errors` from
      `{"type": "integer"}` to `{"type": ["integer", "null"]}`, and extend its description to state
      that `null` means "no applicable structural probe found — not measured", citing the
      `memory_health.last_distilled` precedent. *(completed)*
- [x] In the same file, extend `repository_health.status.enum` from four to five members by adding
      `"unknown"`, and add a description naming which member each `build_errors` outcome maps to,
      including that `manageable` and `concerning` are currently unemitted-but-reserved. *(completed)*
- [x] In `context/reference/state-management-schema.md`, update the "Repository Health Fields"
      documentation to the same five-value enum and the same nullable `build_errors` typing, using
      the same wording, so the two sources agree textually as well as semantically. *(completed)*
- [x] Check the example `repository_health` block near the top of `state-management-schema.md` and
      leave it valid under the new schema (it already is — `healthy` remains a member). *(completed:
      verified — example block at line 33 shows "status": "healthy", still valid)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/context/schemas/state-schema.json` - nullable `build_errors`,
  five-value `status` enum.
- `agent-system/extensions/core/context/reference/state-management-schema.md` - mirrored prose.

**Verification**:
- `jq empty agent-system/extensions/core/context/schemas/state-schema.json` passes.
- `jq '.properties.repository_health.properties.status.enum' ...` returns exactly the five expected
  values, and `.build_errors.type` returns `["integer","null"]`.
- `grep` confirms `state-management-schema.md` names all five values and no longer states a
  four-value enum anywhere.
- The live `specs/state.json` `.repository_health` object still conforms (its `status` is
  `"healthy"`, its `build_errors` is `0` — both still valid).

---

### Phase 4: Rewrite todo.md's Sync Repository Metrics stage [NOT STARTED]

**Goal**: Replace the inline probe with a call to the Phase 1 script, eliminate the undefined-`jq`-
variable defect by passing one `--argjson` object instead of hand-assembling bindings, and delete
the frontmatter step per Defect 2 option (b).

**Tasks**:
- [ ] Replace the Step 5.7.1 inline metrics block with a single invocation of
      `bash .claude/scripts/assess-repo-health.sh`, capturing its JSON output into one variable.
      (The command file is executed from a deployed tree, so it references the `.claude/scripts/`
      path — that is a *runtime reference*, not a source-store edit target.)
- [ ] Rewrite the Step 5.7.2 `state-write.sh` call to `.repository_health = $health` with a single
      `--argjson health "$health_json"` binding. This removes the hand-assembled
      `todo`/`fixme`/`ts`/`errors` bindings entirely and, with them, the `$build_errors`-undefined
      defect class — there is no longer a derivation inside the filter to get wrong.
- [ ] Delete Step 5.7.3 ("Update TODO.md frontmatter") in full, including the `technical_debt:` and
      `repository_health:` YAML blocks it displayed.
- [ ] Add a short rationale note beside the surviving state.json write: `repository_health` lives in
      `state.json` only; TODO.md frontmatter does not mirror it, because `generate-todo.sh` fully
      overwrites TODO.md on every run and no consumer of such a block exists.
- [ ] Update the Step 5.7.4 "Report metrics sync" tracking bullets: drop any reference to the
      deleted frontmatter update, and make `metrics_build_errors` explicitly able to report "not
      measured".
- [ ] Fix the section/sub-step numbering skew while in the file: the section is `### 5.6` but its
      sub-steps are labelled `5.7.1`-`5.7.4`, and the following section is `### 5.7` with `5.8.x`
      sub-steps. Renumber the sub-steps of this stage to match their own section number.
- [ ] Confirm no task-number references are introduced (deliverable rule).

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the numbering skew is local to Step 5.6/5.7 and does not
cascade through the rest of `todo.md`. Confirm before renumbering by grepping all `### 5.` and
`**Step 5.` headings in the file; if the skew is file-wide, renumber only this stage and leave the
rest, noting it rather than silently widening the diff.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 5.6 stage rewritten; Step 5.7.3 deleted.

**Verification**:
- Extract the new `jq` filter and its `--argjson` binding from the rewritten block and execute them
  against a throwaway JSON document. It must compile and produce the expected object. This is the
  in-phase check that the load-bearing embedded code actually runs — the precise gap that let the
  `$build_errors` defect survive.
- `grep -c "technical_debt" agent-system/extensions/core/commands/todo.md` returns 0.
- `grep "|| true" agent-system/extensions/core/commands/todo.md` shows no occurrence in this stage.
- `grep "needs_attention" agent-system/extensions/core/commands/todo.md` returns nothing.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` passes.

---

### Phase 5: Wire, deploy, and prove idempotence end to end [NOT STARTED]

**Goal**: Register the new files so they actually reach a deployed tree, satisfy the third
verification bar, and confirm the standing gates are green.

**Tasks**:
- [ ] Add `assess-repo-health.sh` and `tests/test-assess-repo-health.sh` to
      `agent-system/extensions/core/manifest.json` `provides.scripts`. This allowlist is explicit —
      an unregistered script never deploys, and the failure is silent.
- [ ] Add an `assess-repo-health.sh` entry to the "Utility Scripts" list in
      `agent-system/extensions/core/merge-sources/claudemd.md`, describing it and naming its caller
      (`/todo`'s Sync Repository Metrics stage), matching the style of the neighbouring entries.
- [ ] **Bar 3 (frontmatter idempotence)**: add a case to the Phase 2 suite that copies a minimal
      synthetic `state.json` into the temp workdir, runs
      `generate-todo.sh --state <fixture> --todo <fixture-todo> --no-log` twice, and asserts the
      YAML frontmatter region of the two outputs is byte-identical (`diff` on the extracted
      frontmatter, or on the whole file). `generate-todo.sh` is unmodified by this plan, so this
      case is a regression lock, not a fix — state that in the case's `info()` line.
- [ ] Run the full suite runner: `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Deploy and confirm both new files landed in `.claude/scripts/` and `.claude/scripts/tests/`,
      and that the deployed `.claude/commands/todo.md` carries the rewritten stage.
- [ ] Run `verify-deploy.sh` and confirm the lint gates (notably the state-writer boundary gate and
      the doc-lint gate) are green.
- [ ] Optionally exercise the real path once: run the deployed probe against this repo root and
      confirm the emitted object would validate against the updated schema.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that manifest registration plus a deploy is sufficient for
the new files to reach `.claude/`. Confirm by checking the files exist in the deployed tree after
the deploy step — do not infer it from the manifest edit alone, since the whole reason this step
exists is that the manifest/deploy coupling has failed silently before.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - two `provides.scripts` entries.
- `agent-system/extensions/core/merge-sources/claudemd.md` - Utility Scripts entry.
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` - idempotence case added.

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` passes and both new paths appear in
  `provides.scripts`.
- `run-all.sh` exits 0 and its summary reports the new suite among those discovered (not skipped).
- `verify-deploy.sh` reports no new failures relative to a pre-change baseline.
- `.claude/scripts/assess-repo-health.sh` exists and is executable after deploy.

---

## Testing & Validation

- [ ] **Bar 1**: a fixture repo whose probe FAILS produces `build_errors > 0` and a `status` that is
      not `"healthy"` — asserted by an executed test, not by reading the code.
- [ ] **Bar 2**: a fixture repo with no recognised probe reports `build_errors: null`, explicitly
      asserted to be neither `0` nor `1`, with `status == "unknown"`.
- [ ] **Bar 3**: `generate-todo.sh` run twice against a fixed fixture state leaves the frontmatter
      byte-identical.
- [ ] Control case: a clean fixture reports `build_errors == 0` / `status == "healthy"`, so Bar 1
      cannot be satisfied by an always-failing probe.
- [ ] Negative-control demonstration: the suite is shown to fail when the probe is deliberately
      broken, then reverted.
- [ ] Every `status` value the suite observes is a member of the schema's declared enum.
- [ ] The rewritten `jq` filter in `todo.md` compiles and runs when executed against a throwaway
      document.
- [ ] `run-all.sh` and `verify-deploy.sh` are green.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/assess-repo-health.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-assess-repo-health.sh` (new)
- `agent-system/extensions/core/commands/todo.md` (Step 5.6 rewritten, 5.7.3 deleted)
- `agent-system/extensions/core/context/schemas/state-schema.json` (nullable `build_errors`, +`unknown`)
- `agent-system/extensions/core/context/reference/state-management-schema.md` (mirrored)
- `agent-system/extensions/core/manifest.json` (two script registrations)
- `agent-system/extensions/core/merge-sources/claudemd.md` (Utility Scripts entry)

## Rollback/Contingency

Every change is additive or confined to four existing files, all git-tracked in the source store.
`git revert` of the phase commits restores prior behaviour; `.claude/**` is regenerated by the next
deploy and needs no manual rollback. If the probe proves too slow in practice during Phase 5, the
contingency is to narrow enumeration to `agent-system/**` and `specs/*.json` rather than to
reintroduce an unconditional constant — the schema's `null` ("not measured") exists precisely so
that a narrowed or absent probe can be reported honestly instead of guessed.

## Follow-Up (out of scope, flagged)

- Add a `repository_health.status` enum check to `validate-state.sh`, mirroring its existing
  task-status enum check, so this class of vocabulary drift cannot recur silently. The research
  recommends this; it is not required by any of the three verification bars.
- Decide separately whether `skill-todo/SKILL.md` should gain a repository-metrics stage at all.

# Implementation Plan: Task #135

- **Task**: 135 - Sweep for and remove artifacts orphaned by the orchestrate-engine consolidation
- **Status**: [IMPLEMENTING]
- **Effort**: 4.7 hours
- **Dependencies**: 114, 120, 123, 126, 128, 130, 133 (all complete — the tree being swept is final)
- **Research Inputs**: `specs/135_remove_refactor_orphans/reports/01_orphan-sweep-findings.md`
- **Artifacts**: plans/01_orphan-sweep-removal.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase bounded the orphan blast radius to a single deletion event (three
`skill-team-*` SKILL.md files) and enumerated, with per-candidate evidence, exactly what that
deletion left behind: one dead reference file, four stale-prose repair sites, and six cleared
false positives. This plan executes those removals and repairs, keeps `index-entries.json`
internally consistent across them, and — because the same detection blind spot will recur when
the hard-engine skill is deleted — leaves behind an on-demand `audit-deletion-references.sh`
detector so the next sweep does not have to re-derive the method.

Definition of done: `team-wave-helpers.md` and its index row are gone; the four stale-prose sites
state the current reality (`--team` is an `/orchestrate` flag, not a `/research`/`/plan`/
`/implement` one); `index-entries.json` `line_count` values match the filesystem; a reusable
detector exists and is manifest-declared; and the full gate set shows no NEW findings against a
baseline captured at implementation time.

### Research Integration

Every phase below traces to a numbered candidate in the research report. The report's central
methodological finding — that reachability analysis and glob/pattern-prose auditing catch
**disjoint** defect classes, and that `team-wave-helpers.md` is reachable by every structural
test while dead by every semantic one — is what makes Phase 7's detector a *checklist producer*
for human triage rather than a pass/fail lint. The report's explicit warning about conflating
two different `--team` subjects inside one file is encoded as a hard constraint in Phase 5.

The report's pre-sweep `verify-deploy.sh` baseline (4 of 27 checks failing) is **not** carried
forward as a number. Phase 1 re-captures it, because the tree has been redeployed since the
report was written and a stale baseline would make the acceptance diff meaningless.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied and no roadmap phases requested.

## Goals & Non-Goals

**Goals**:
- Resolve the one confirmed removal (`context/reference/team-wave-helpers.md` + its
  `index-entries.json` row) with a stated reason.
- Repair the four confirmed stale-prose sites (`context/patterns/skill-lifecycle.md`,
  `context/patterns/multi-task-operations.md`, `README.md`, `rules/artifact-formats.md`) so none
  of them asserts `--team` is a flag on `/research`, `/plan`, or `/implement`.
- Correct the factually **inverted** Dispatch Model Comparison table row.
- Keep `index-entries.json` internally consistent, `line_count` rows included.
- Produce a re-runnable detector (`scripts/audit-deletion-references.sh`), manifest-declared, so
  the next artifact deletion can re-run this sweep's method instead of re-deriving it.
- Leave a reproducible record: method, every candidate, and its disposition
  (removed / repaired / kept-with-reason).

**Non-Goals**:
- No restructuring or renaming of surviving files. This is a removal sweep.
- No renumbering of `multi-task-operations.md`'s `## N.` section headings (see Phase 5 — the
  numbering is externally cross-referenced by name, and renumbering is reorganization, not
  removal).
- No deletion of `skill-orchestrate-hard/SKILL.md` or any base lifecycle skill/command — those
  are separate, not-yet-started successor tasks and are explicitly live.
- No repurposing of `team-wave-helpers.md` into a generic reference:
  `context/patterns/team-orchestration.md` already fills that role, so repurposing would create
  redundancy rather than remove an orphan.
- The detector is **not** added to the standing lint suite as an auto-fail gate (see Decisions).
- Two of the four adjacent baseline findings are deliberately left out of scope (see Decisions).

## Decisions Recorded at Plan Time

### Adjacent findings: what is folded in, what is deferred, and why

The research report's "Adjacent findings" section documents four gate failures **not** caused by
the team-mode deletion. Per the delegation instruction not to silently absorb or silently drop
them, each gets an explicit disposition:

| Adjacent finding | Disposition | Reason |
|---|---|---|
| `index-entries.json` `line_count` drift on `patterns/system-defect-discrimination.md` (409 declared, 420 actual) | **Folded in** (Phase 6) | Acceptance criterion 4 ("`index-entries.json` stays internally consistent") is stated absolutely, not as a baseline diff — this drift blocks it outright. This sweep must run `generate-context-line-counts.sh` anyway for its own edits, and that tool's `--write` mode corrects every drifting row in one pass; excluding this one row would require *extra* effort to un-fix. Same defect class, same tool, same phase. |
| `scripts/tests/test-force-phases.sh` undeclared in `manifest.json` `provides.scripts` | **Deferred** | Not an orphan (nothing was deleted that created it) — it is an omission in a sibling task's output. Acceptance criterion 3 is baseline-relative, and a Phase 1 baseline captured at implementation time already contains it, so it does not block acceptance. Recorded as a follow-up in Phase 8's summary. |
| 4 × `lint-state-writer-boundary.sh` violations in `scripts/tests/test-force-phases.sh` (lines 261, 307, 317, 327) | **Deferred** | Same reason, plus: routing four hand-rolled `jq … > state.json.tmp && mv` writes through `state-write.sh` is a behavioural change to a test file that must still pass afterwards. That is code work with its own verification profile, sitting inside an otherwise `prose`-dominant documentation sweep. Folding it in would blur the sweep's scope exactly as the report warns. Recorded as a follow-up in Phase 8's summary. |
| 2 pre-existing undeclared scripts + `validate-state.sh --deep` unknown-field findings + `run-all.sh` flakiness-under-nesting | **Out of scope, already characterised** | All confirmed pre-existing and unrelated by two independent baselines. Absorbed by the Phase 1 baseline. |

### `multi-task-operations.md` lines 636-662 are off-limits

Lines 636-643 (the "Note on `--team`" paragraph) and lines 660-662 (the
`### --team Flag Not Supported` section) describe **multi-task `/orchestrate`'s** own lack of
`--team` support. That is a different, already-correct claim about a different command than the
defect this sweep repairs. They must survive byte-identical. Line 672's table row, which sits
past that range, IS a defect and IS repaired (Phase 5).

**Observation deferred, not dropped**: line 662 reads `` `/orchestrate` does not support the
`--team` flag `` without the "multi-task" qualifier that line 636 carries. Read standalone it is
now misleading, since single-task `/orchestrate --team` is the sanctioned team path. This plan
does **not** edit it, per the binding instruction to leave 636-662 untouched and per the report's
own recommendation. It is recorded here and must be carried into Phase 8's summary as a
one-line-qualifier follow-up candidate for a future editor to decide on.

### Detector: on-demand script, not a standing lint

Adopting the report's recommendation. The glob/pattern-prose axis requires judgment — a file
legitimately discussing "team" in an unrelated sense is a false positive, and six such files were
cleared by hand during research. An auto-fail gate on that axis would be too noisy to run
unattended and would train readers to ignore it. The detector therefore prints a **triage
checklist** and exits 0 on hits; only genuine usage errors (bad arguments) exit non-zero. It is
invoked deliberately by the next task that deletes an artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Repairing `multi-task-operations.md` Section 7 accidentally damages the already-correct `/orchestrate`-scoped `--team` content in the same file | H | M | Phase 5 carries exact line ranges for both subjects and a verification step that diffs lines 636-662 for byte-identity before the phase closes |
| Deleting `team-wave-helpers.md` without its `index-entries.json` row leaves a dangling row (or vice versa) | M | M | Phase 4 is declared `Commit Mode: atomic-batch` — the file removal and the row removal are one objective; the intermediate state is expected red and is not committed |
| Someone reads `load_when.agents: ["synthesis-agent"]` and concludes the file is in use, blocking the removal | M | M | Recorded explicitly: `load_when` governs injection mechanics, not content correctness; `synthesis-agent.md`'s own Context References section never cites the file (verified by grep in research) |
| Line numbers cited in this plan drift before implementation | M | M | Every phase locates its edit site by an anchored `grep -n` on quoted content, never by trusting the line number alone; cited numbers are hypotheses, flagged as such per phase |
| Renumbering `multi-task-operations.md` sections breaks external cross-references | M | L | Explicit non-goal; Section 7 is rewritten in place and keeps its number |
| The new detector script trips the very doc-lint defect this sweep is cleaning up (undeclared in `provides.scripts`) | M | M | Phase 7 is `atomic-batch`: script + manifest entry land together, verified by a `check-extension-docs.sh` run inside the phase |
| Baseline drift makes the acceptance diff unreadable | H | L | Phase 1 captures a fresh baseline at implementation time and stores it under `specs/`; Phase 8 diffs against that file, never against a number quoted from the report |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 7 | 1 |
| 3 | 6 | 2, 4, 5 |
| 4 | 8 | 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Phase 7 shares Wave 2 with the content
repairs because its file territory (`scripts/` + `manifest.json`) is disjoint from theirs; its
post-sweep confirmation step lives in Phase 8, not in Phase 7 itself, which is what keeps it
order-independent.

---

### Phase 1: Capture fresh pre-sweep baseline [COMPLETED]

**Goal**: Establish, at implementation time, the exact gate state the acceptance criteria will be
diffed against — so "no NEW findings" is a measured claim, not an inherited one.

**Tasks**:
- [x] Create `specs/135_remove_refactor_orphans/baseline-pre-sweep.txt`. *(completed)*
- [x] Run and append full output (stdout+stderr, with exit code) for each of:
  - `bash .claude/scripts/verify-deploy.sh`
  - `bash .claude/scripts/check-extension-docs.sh`
  - `bash .claude/scripts/check-task-references.sh`
  - `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` (standalone, **not**
    nested inside `verify-deploy.sh` — the nested run is a known concurrency flake)
  - each of `agent-system/extensions/core/scripts/lint/*.sh --verbose` (all six:
    `lint-agent-contracts`, `lint-contract-compliance`, `lint-lifecycle-status-var`,
    `lint-postflight-boundary`, `lint-routing-wiring`, `lint-state-writer-boundary`)
  - `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
  *(completed: all 8 commands captured; also captured a companion `--findings` run to
  `baseline-pre-sweep-findings.txt` for a finer-grained Phase 8 diff — 11 FINDING lines, 0
  unexpected)*
- [x] Record, in the baseline file's header, the count of failing checks and a one-line
  characterisation of each failure, so Phase 8's diff is human-readable. *(completed)*
- [x] Confirm the working tree is otherwise clean of unrelated staged changes before starting.
  *(completed: nothing staged; unrelated modified/untracked files present from concurrent
  sessions but out of this task's territory)*

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The report observed 4 of 27 `verify-deploy.sh` checks failing and 4
`lint-state-writer-boundary.sh` violations. Treat both as hypotheses only. Confirm by reading the
freshly captured baseline; if the counts differ from the report, record the difference in the
baseline header and proceed — the baseline file, not the report, is authoritative for Phase 8.

**Files to modify**:
- `specs/135_remove_refactor_orphans/baseline-pre-sweep.txt` - new; captured gate output

**Verification**:
- The baseline file exists, is non-empty, and contains a labelled section per command above.
- Each section records an exit code.

---

### Phase 2: Repair `context/patterns/skill-lifecycle.md` [COMPLETED]

**Goal**: Remove the two assertions that the deleted per-command team skills are a live category
of lifecycle skill.

**Tasks**:
- [x] Locate the roster line by anchored grep for `their \`--hard\`\s*$` / `the team skills` in
  `agent-system/extensions/core/context/patterns/skill-lifecycle.md` (hypothesised line 6).
  *(completed)*
- [x] Drop `the team skills, ` from the lifecycle-skill roster. Do not substitute a replacement
  clause — `skill-orchestrate`'s team fan-out is a stage inside one skill, not a member of this
  roster, and adding it would misdescribe the roster's own subject. *(completed)*
- [x] Locate the `**Multi-task vs. team mode**` paragraph by anchored grep (hypothesised lines
  262-264). *(completed: confirmed at lines 262-264)*
- [x] Rewrite it to state: multi-task invokes one skill instance per task; team mode is
  `skill-orchestrate`'s internal Stage 3.6/3.6a fan-out on `/orchestrate` only, and `--team` is
  not accepted by `/research`, `/plan`, or `/implement`. Delete the
  `/research 7, 22 --team` combined example and the `N_tasks * team_size` arithmetic, both of
  which describe a routing model that no longer exists. *(completed)*
- [x] Confirm no task-number reference was introduced (this file is outside `specs/**`).
  *(completed: 0 hits)*

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly 2 edit sites in this file (hypothesised lines 6 and 262-264).
Confirm at implementation time with
`grep -niE "team skill|--team|team mode|team_size" agent-system/extensions/core/context/patterns/skill-lifecycle.md`
and reconcile the full hit list against these two sites before editing. If a third site appears,
evaluate it against the report's false-positive bar and record the disposition rather than
silently editing or silently skipping it.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` - remove "the team skills"
  from the roster; rewrite the multi-task-vs-team-mode paragraph

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no code fence or structural
  element crossed.
- `grep -n "team skill" <file>` returns no hit.
- `grep -n -- "--team" <file>` returns only hits that scope `--team` to `/orchestrate`.

---

### Phase 3: Repair `README.md` and `rules/artifact-formats.md` [COMPLETED]

**Goal**: Fix the two smaller standalone sites that still show `--team` on `/research`.

**Tasks**:
- [x] In `agent-system/extensions/core/README.md`, locate the multi-task-syntax line by anchored
  grep for `Flags like` (hypothesised line 46) and drop `` `--team`, `` from the flag list,
  leaving `--force`, `--fast`, `--hard`. *(completed: confirmed at line 46)*
- [x] Cross-check `agent-system/extensions/core/merge-sources/claudemd.md`'s equivalent
  multi-task line (which already reads `Flags like --force apply to all tasks`) and confirm the
  README now agrees with it. If it does not, align the README to the merge source, not the
  reverse. *(completed: neither line mentions `--team`; the merge source's "Flags like --force"
  is a non-exhaustive summary and does not contradict the README's fuller `--force, --fast,
  --hard` list — no reconciliation edit needed)*
- [x] In `agent-system/extensions/core/rules/artifact-formats.md`, locate the
  `**Team Mode Example**:` block (hypothesised lines 70-78) and retarget its command from
  `/research 309 --team` to `/orchestrate 309 --team`. Retarget rather than delete: the
  `01_teammate-{letter}-findings.md` / `01_team-research.md` naming convention the example
  illustrates is still live under `/orchestrate --team`, so the example documents a real
  mechanism under a new owner. *(completed: retargeted at line 72)*
- [x] Leave the `**Team Mode** (parallel teammates):` naming-convention block at hypothesised
  line 50 untouched — it is command-agnostic and remains correct. *(completed: untouched)*

**Timing**: 0.3 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly 2 edit sites across 2 files. Confirm with
`grep -rn -- "--team" agent-system/extensions/core/README.md agent-system/extensions/core/rules/artifact-formats.md`
before editing; the expected post-edit state is one hit in each file, both scoped to
`/orchestrate`.

**Files to modify**:
- `agent-system/extensions/core/README.md` - drop `--team` from the multi-task flag list
- `agent-system/extensions/core/rules/artifact-formats.md` - retarget the Team Mode Example to
  `/orchestrate`

**Verification**:
- Diff read-through confirms prose/code-fence-content-only changes.
- No `--team` remains associated with `/research`, `/plan`, or `/implement` in either file.

---

### Phase 4: Remove `context/reference/team-wave-helpers.md` and its index row [COMPLETED]

**Goal**: Delete the one confirmed dead file together with its `index-entries.json` entry, as a
single atomic change.

**Tasks**:
- [x] Re-confirm the removal reason before deleting, and record it in the commit body: the file
  documents dispatch mechanics belonging to three skills that no longer exist — this is
  "nothing points here because the thing it documents is gone", not "nothing points here yet".
  Two independent confirmations: its own closing line globs
  `` .claude/skills/skill-team-*/SKILL.md `` against a pattern with zero matches, and it is the
  sole remaining `skill-team` hit anywhere in the tree. *(completed: both confirmed)*
- [x] Confirm `agent-system/extensions/core/agents/synthesis-agent.md` does not cite the file in
  its Context References section (`grep -n "team-wave-helpers"` over `agents/`) — the
  `load_when.agents: ["synthesis-agent"]` binding makes the file mechanically injected but never
  designedly consumed, and this distinction is what justifies the removal. *(completed: 0 hits)*
- [x] Delete `agent-system/extensions/core/context/reference/team-wave-helpers.md`. *(completed)*
- [x] Delete the corresponding entry object from
  `agent-system/extensions/core/index-entries.json` (hypothesised around line 1433-1455, keyed on
  `"path": "reference/team-wave-helpers.md"`), preserving surrounding JSON comma structure and
  the file's existing array-formatting conventions. *(completed: confirmed at lines 1433-1455)*
- [x] Confirm no other extension's `index-entries.json` declares the same path. *(completed: core
  only)*

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Exactly 1 file deleted and exactly 1 `index-entries.json` entry removed,
from `core` only. Confirm with
`grep -rn "team-wave-helpers" agent-system/ .claude/ --include="*.json" --include="*.md"` before
and after; the expected post-state is zero hits under `agent-system/` (hits under `.claude/`
persist until the next redeploy and are not a defect).

**Files to modify**:
- `agent-system/extensions/core/context/reference/team-wave-helpers.md` - **deleted**
- `agent-system/extensions/core/index-entries.json` - remove the `reference/team-wave-helpers.md`
  entry object

**Verification**:
- `jq . agent-system/extensions/core/index-entries.json` parses cleanly.
- `bash agent-system/extensions/core/scripts/validate-index.sh` passes (enumerated direct
  dependent 1).
- `bash agent-system/extensions/core/scripts/validate-context-index.sh` passes (enumerated direct
  dependent 2).
- `bash .claude/scripts/check-extension-docs.sh` reports no *new* finding versus the Phase 1
  baseline (enumerated direct dependent 3).
- `grep -rn "skill-team" agent-system/` returns zero hits.

---

### Phase 5: Repair `context/patterns/multi-task-operations.md` [COMPLETED]

**Goal**: Remove every claim that `--team` is a flag on `/research`/`/plan`/`/implement`, fix the
inverted support-matrix row, and leave the file's already-correct `/orchestrate`-scoped `--team`
content byte-identical.

This is the delicate phase. The file is declared
`load_when.commands: ["/research", "/plan", "/implement"]`, so its content is actively injected
into those three commands' context on every multi-task invocation — a wrong claim here is not
dormant documentation, it is live context.

**Tasks**:
- [x] **Before any edit**, snapshot lines 636-662 to a scratch file
  (`sed -n '636,662p' > /tmp/…/mto-preserve.txt`). This range is the correctness anchor for this
  phase's verification. *(completed)*
- [x] Fix the parsing-example table rows (hypothesised lines 88-89): replace the
  `` `7, 22-24 --team` `` and `` `42 --team --team-size 3` `` rows with flag examples that are
  actually valid on these commands (e.g. `` `7, 22-24 --hard` `` and `` `42 --clean --lit` ``).
  Keep the table's shape — it illustrates parser behaviour, and the parser still accepts arbitrary
  flag strings; only these two *examples* are misleading. *(completed: confirmed at lines 88-89,
  no drift from hypothesised numbers)*
- [x] Fix the backward-compatibility bullet (hypothesised line 108): change the
  `/research 7 --team` example to a flag these commands accept. *(completed: confirmed at line
  108, no drift)*
- [x] Fix the duplicate example (hypothesised line 532): same change. *(completed: confirmed at
  line 532, no drift)*
- [x] Rewrite `## 7. Interaction with --team Flag` (hypothesised lines 344-371, ending before
  `## 8. Batch Git Commit Format`) **in place, keeping the section number 7**. Do NOT delete the
  section and renumber 8-13: the numbering is externally cross-referenced by section name from
  `docs/architecture/batch-admit-schema.md` and `context/patterns/batch-orchestration-guardrails.md`,
  and renumbering is reorganization, which is an explicit non-goal.
  The replacement content must state:
  - `--team` is not a flag on `/research`, `/plan`, or `/implement`, in single-task or multi-task
    form. There is no combined multi-task-plus-team mode on these commands.
  - Team mode is `/orchestrate`'s flag, served by `skill-orchestrate`'s Stage 3.6/3.6a fan-out.
  - Retitle the heading to reflect the new content (e.g. `## 7. Team Mode Is Not a Flag Here`),
    keeping the `## 7.` prefix.
  - Retain the Flag Compatibility Table but drop its `--team` and `--team-size` rows; keep
    `--force` and the focus-prompt row, and keep the **Not supported** note about per-task flags,
    which is still accurate.
  - Delete the cost-warning paragraph — it prices a combination that cannot be invoked.
  *(completed: retitled "## 7. Team Mode Is Not a Flag Here"; confirmed the two cross-referencing
  files cite Section 5a, not 7, so the rename is safe)*
- [x] Fix the Dispatch Model Comparison table's `Team mode support` row (hypothesised line 672).
  It currently reads `` Yes (`--team` flag) `` for `/research, /plan, /implement` and `No` for
  `/orchestrate` — the exact inverse of reality. Correct it to `No` for the three lifecycle
  commands and, for the `/orchestrate` column, a value that does not contradict the
  multi-task-scoped section above it: `` Single-task only (`--team`) ``. *(completed: row shifted
  to line 662 after Section 7's rewrite shortened the file by 10 lines; fixed at its actual
  location)*
- [x] Confirm no task-number reference was introduced. *(completed: 0 hits)*

**Tasks — do not touch**:
- [x] Lines 636-643 (`**Note on `--team`**` paragraph) and lines 660-662
  (`### --team Flag Not Supported`) must survive byte-identical. They describe multi-task
  `/orchestrate`'s own lack of `--team` support — a different claim about a different command
  than the defect above. The report's stated risk is precisely that a repair pass conflates the
  two because both use the same flag name in the same file.

**Timing**: 1.0 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 5 edit sites (hypothesised lines 88-89, 108, 344-371, 532, 672) and exactly
1 preserved range (636-662). Confirm the full hit list at implementation time with
`grep -n -- "--team\|team-size\|team mode\|Team mode\|team_size" agent-system/extensions/core/context/patterns/multi-task-operations.md`
and reconcile every hit against either the edit list or the preserved range before editing. A hit
belonging to neither must be triaged and its disposition recorded, not silently handled.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` - four example/table
  fixes plus an in-place rewrite of Section 7

**Verification**:
- `diff <(sed -n '636,662p' <file>) /tmp/…/mto-preserve.txt` — must be empty. Line numbers may
  have shifted; if so, re-locate the range by its `**Note on \`--team\`**` and
  `### \`--team\` Flag Not Supported` anchors and diff the located range.
- `grep -n -- "--team" <file>` — every surviving hit is either inside the preserved range or
  explicitly scopes `--team` to `/orchestrate`.
- The `## 7.` heading still exists; headings `## 8.` through `## 13.` are unchanged.
- Diff read-through confirms all changes are prose or fenced-example content.

---

### Phase 6: Restore `index-entries.json` internal consistency [COMPLETED]

**Goal**: Bring every `line_count` row back into agreement with the filesystem, including the
rows this sweep changed and the one pre-existing drift folded in by decision.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and
  capture the full list of drifting entries. *(completed: 3 mismatches, all in core)*
- [x] Reconcile the list against expectations: rows for `patterns/skill-lifecycle.md` and
  `patterns/multi-task-operations.md` should drift because Phases 2 and 5 edited them;
  `patterns/system-defect-discrimination.md` should drift because of the pre-existing defect
  folded in here; `reference/team-wave-helpers.md` should be absent entirely because Phase 4
  removed it. Any *other* drifting row is unexpected — investigate and record before writing.
  *(completed: exactly the 3 expected rows drifted — skill-lifecycle.md 316->317,
  multi-task-operations.md 685->675, system-defect-discrimination.md 409->420 — matching the
  Scope Hypothesis exactly; team-wave-helpers.md correctly absent from the check output since
  its row no longer exists)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.
  *(completed: 3 changed)*
- [x] Review `git diff agent-system/extensions/core/index-entries.json` and confirm **only**
  `line_count` values changed — the tool performs a surgical line-oriented substitution
  specifically to keep this diff reviewable, so any array reformatting in the diff indicates
  something went wrong. *(completed: diff shows exactly 3 one-line line_count substitutions, no
  array reformatting)*
- [x] Re-run `--check` and confirm it exits clean. *(completed: exit 0, "CHECK PASSED: all
  line_count values are exact")*

**Timing**: 0.4 hours

**Depends on**: 2, 4, 5

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly 3 `line_count` values change in `core`'s `index-entries.json`
(`skill-lifecycle.md`, `multi-task-operations.md`, `system-defect-discrimination.md`). The
`system-defect-discrimination.md` row is hypothesised to move 409 → 420. Confirm from the
`--check` output before running `--write`; a different count or a different set of rows is a
signal to stop and re-read, not to proceed.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - `line_count` corrections only

**Verification**:
- `generate-context-line-counts.sh --check` exits 0.
- `jq . agent-system/extensions/core/index-entries.json` parses cleanly.
- `bash agent-system/extensions/core/scripts/validate-index.sh` and
  `validate-context-index.sh` pass (enumerated direct dependents).
- `git diff --stat` shows only `index-entries.json` touched by this phase.

---

### Phase 7: Build the reusable deletion-reference detector [COMPLETED]

**Goal**: Leave the sweep's method behind in re-runnable form, so the next artifact deletion
(the hard-engine skill removal, on exactly this pattern) can run it instead of re-deriving it.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/audit-deletion-references.sh` accepting one or
  more deleted artifact names:
  `bash audit-deletion-references.sh skill-team-research skill-team-plan skill-team-implement`.
  *(completed; deviation noted below on the script's own internal example text)*
- [x] Implement three passes, each printing a labelled, separately-countable section:
  1. **Literal-name grep** — each supplied name, verbatim, across `agent-system/extensions/`.
  2. **Wildcard-expanded grep** — for each name, derive and search stem variants
     (`{name}-*`, `*-{name}`, and the common-prefix stem, e.g. `skill-team` from
     `skill-team-research`), case-insensitively. This is the pass that catches glob and
     path-pattern references a literal grep structurally cannot see, and it is the pass that
     found all three of this sweep's real candidates.
  3. **Reachability delegation** — invoke the existing
     `check-extension-docs.sh` / `generate-context-line-counts.sh --check` reachability and
     `line_count` checks rather than reimplementing them, and surface their findings under this
     script's own heading.
  *(completed: all three passes implemented and verified against a live no-longer-existent
  target (the three deleted skill-team-* names, 0 hits post-sweep) and a live still-existing
  target (`skill-orchestrate-hard`, 117 literal + 419 wildcard hits, confirming both passes
  actually find real content) — see verification below)*
- [x] Print a **triage checklist** — one line per hit, with file, line, and matched text — and a
  closing note stating plainly that reachability and pattern-prose auditing catch disjoint defect
  classes: a file can be perfectly reachable (valid index row, live `load_when` binding) while
  its content is entirely dead, so hits require reading, not a pass/fail verdict. *(completed)*
- [x] Exit 0 when hits are found (hits are candidates, not failures); exit non-zero only on a
  usage error (no arguments) or a missing dependency. *(completed)*
- [x] Add a header comment stating: this is an **on-demand** script, deliberately NOT part of the
  standing lint suite, because false positives on the prose axis would make it too noisy to run
  unattended; invoke it from the task that performs a deletion. *(completed)*
- [x] Declare `audit-deletion-references.sh` in `agent-system/extensions/core/manifest.json`'s
  `provides.scripts` array, in alphabetical position. *(completed: between assess-repo-health.sh
  and census-count.sh)*
- [x] Contains no task-number references (the script and its comments are deliverables outside
  `specs/**`). *(completed: 0 hits)*

**Deviation**: the script's own usage example and internal comments were written using a generic
placeholder (`old-artifact-a`, etc.) rather than the literal `skill-team-research`/
`skill-team-plan`/`skill-team-implement` names, discovered mid-phase to be necessary: with the
literal names in its own source, the script became a permanent 4-hit Pass-2 self-reference
against itself (its own usage/comment text matching the `skill-team` stem), which would have
made Phase 8's "confirm it now reports zero hits" closing check permanently fail. Behavior is
unaffected — this only changes illustrative text, not logic.

**Timing**: 1.2 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: 1 new script plus 1 one-line `manifest.json` addition. The script is
hypothesised at roughly 100-150 lines. Confirm the manifest entry landed with
`jq -r '.provides.scripts[]' manifest.json | grep audit-deletion-references`; confirm the script
is the only new file with `git status --short`.

**Files to modify**:
- `agent-system/extensions/core/scripts/audit-deletion-references.sh` - new; three-pass detector
- `agent-system/extensions/core/manifest.json` - declare the new script in `provides.scripts`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/audit-deletion-references.sh` (syntax check).
- Running it with no arguments exits non-zero and prints usage.
- Running it with the three deleted skill names completes, prints all three labelled sections,
  and exits 0.
- `bash .claude/scripts/check-extension-docs.sh` reports no new undeclared-script finding for
  this file (this is the check the `atomic-batch` mode exists to keep green).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` passes standalone.

---

### Phase 8: Final gate run, baseline diff, and reproducibility record [NOT STARTED]

**Goal**: Prove the acceptance criteria hold, and leave a record a later reader can follow
without redoing the analysis.

**Tasks**:
- [ ] Re-run every command from Phase 1 and capture output to
  `specs/135_remove_refactor_orphans/baseline-post-sweep.txt`.
- [ ] Diff post-sweep against pre-sweep. Acceptance requires **no NEW findings** — pre-existing
  findings carried in the Phase 1 baseline are not regressions. Enumerate any delta explicitly.
- [ ] Confirm `bash .claude/scripts/check-task-references.sh` reports 0 findings.
- [ ] Confirm `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` passes
  standalone (the nested-inside-`verify-deploy.sh` run is a known concurrency flake and does not
  count against acceptance; note it as such if it recurs).
- [ ] Run `bash agent-system/extensions/core/scripts/audit-deletion-references.sh
  skill-team-research skill-team-plan skill-team-implement` post-sweep and confirm it now reports
  zero hits under `agent-system/` for all three passes — closing the loop between the detector
  and the sweep it encodes.
- [ ] Write `specs/135_remove_refactor_orphans/summaries/01_orphan-sweep-summary.md` containing:
  - The search method, stated as method (literal grep / wildcard-expanded grep / reachability),
    with the note that the first two catch disjoint classes from the third.
  - A dispositions table: every candidate from the research report — the 1 removal, the 4 repair
    sites, and the 6 cleared false positives — each marked removed / repaired / kept-with-reason,
    with the reason stated.
  - The pre/post baseline diff result.
  - Pointer to `audit-deletion-references.sh` as the re-runnable artifact, and its recorded
    on-demand-not-standing-lint status.
  - **Deferred items**, carried forward explicitly: (a) `test-force-phases.sh` undeclared in
    `provides.scripts`; (b) its 4 `lint-state-writer-boundary.sh` violations at lines 261, 307,
    317, 327; (c) the missing "multi-task" scope qualifier on `multi-task-operations.md` line 662.
    Each with the reason it was left out.
- [ ] Confirm the summary is the only new file under `specs/` besides the two baseline captures.

**Timing**: 0.7 hours

**Depends on**: 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The post-sweep run is hypothesised to show the same failure set as Phase 1's
baseline minus the `index-entries.json` `line_count` drift (fixed in Phase 6). Any other delta is
a regression this phase must resolve or explicitly justify before the task closes — do not accept
a delta by narrating it.

**Files to modify**:
- `specs/135_remove_refactor_orphans/baseline-post-sweep.txt` - new
- `specs/135_remove_refactor_orphans/summaries/01_orphan-sweep-summary.md` - new

**Verification**:
- The full gate set runs; the post/pre diff is captured and contains no new findings.
- `check-task-references.sh`: 0 findings.
- `run-all.sh` standalone: 0 failed.
- The detector reports zero remaining hits for the three deleted names.
- The summary's dispositions table accounts for 11 candidates (1 + 4 + 6) with no gaps.

---

## Testing & Validation

- [ ] `bash .claude/scripts/verify-deploy.sh` — no NEW findings versus the Phase 1 baseline
- [ ] `bash .claude/scripts/check-extension-docs.sh` — no NEW findings versus the Phase 1 baseline
- [ ] `bash .claude/scripts/check-task-references.sh` — 0 findings
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` (standalone) — 0 failed
- [ ] All six `agent-system/extensions/core/scripts/lint/*.sh --verbose` — no NEW findings
- [ ] `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` — exits 0
- [ ] `jq . agent-system/extensions/core/index-entries.json` and `manifest.json` — parse cleanly
- [ ] `grep -rn "skill-team" agent-system/` — 0 hits
- [ ] `multi-task-operations.md` lines 636-662 byte-identical to the pre-edit snapshot
- [ ] No task-number reference introduced anywhere outside `specs/**`
- [ ] No file written under `.claude/**` (source-store boundary)

## Artifacts & Outputs

- `specs/135_remove_refactor_orphans/baseline-pre-sweep.txt` (new)
- `specs/135_remove_refactor_orphans/baseline-post-sweep.txt` (new)
- `specs/135_remove_refactor_orphans/summaries/01_orphan-sweep-summary.md` (new)
- `agent-system/extensions/core/scripts/audit-deletion-references.sh` (new)
- `agent-system/extensions/core/context/reference/team-wave-helpers.md` (deleted)
- `agent-system/extensions/core/index-entries.json` (row removed; `line_count` corrections)
- `agent-system/extensions/core/manifest.json` (one `provides.scripts` entry)
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` (repaired)
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` (repaired)
- `agent-system/extensions/core/README.md` (repaired)
- `agent-system/extensions/core/rules/artifact-formats.md` (repaired)

## Rollback/Contingency

Every phase commits independently (Phases 4 and 7 as declared atomic batches), so rollback is
per-phase `git revert` of that phase's commit — no phase leaves a half-state that a later phase
depends on except Phase 6, which depends on Phases 2/4/5 having landed and must be reverted with
or before them.

If Phase 5's preserved-range diff fails, revert that phase's commit and redo the edits with the
snapshot restored first; do not attempt to hand-repair the preserved range in place.

If the Phase 8 baseline diff shows a new finding that cannot be attributed to a specific phase,
bisect by reverting phase commits in reverse order (8, 7, 6, 5, 4, 3, 2) and re-running the gate
set after each — the phase boundaries are the bisection points.

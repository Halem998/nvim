# Research Report: Orphan Sweep for the Orchestrate-Engine Consolidation

- **Task**: 135 - Find and remove orphans left behind by the orchestrate-engine consolidation refactor
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T00:00:00Z
- **Effort**: ~2 hours research
- **Dependencies**: None (runs after the consolidation family: successor tasks 116-127 plus 128/130/133)
- **Sources/Inputs**: Codebase (agent-system/extensions/core), git history, specs/ summaries for the consolidation family, `check-extension-docs.sh`, `verify-deploy.sh`, `validate-state.sh --deep`, `run-all.sh`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- Only **three source-store files** were ever deleted by the consolidation
  (`skills/skill-team-research`, `skill-team-plan`, `skill-team-implement`, verified by diffing
  every deletion from the consolidation's first commit to HEAD) — the orphan surface is bounded
  to content that referenced, described, or depended on those three skills.
- The confirmed known instance, `context/reference/team-wave-helpers.md` (400 lines), is
  genuinely dead: it is the **only** remaining file anywhere in the tree that names
  `skill-team-*` in any form (literal or glob), and its "Related Files" section still points a
  glob (`skills/skill-team-*/SKILL.md`) at nothing. Recommend **delete**.
- The glob/pattern-reference audit — grepping for prose ("team skill", "team wave") rather than
  the literal deleted names — surfaced **two more genuine content orphans** that a literal-name
  grep structurally cannot find, exactly the blind spot the task describes:
  `context/patterns/skill-lifecycle.md` (2 spots) and `context/patterns/multi-task-operations.md`
  (a whole obsolete section plus 4 other spots, one of them a factually **inverted** table row).
  Both are load-bearing, actively-injected files (`multi-task-operations.md` is declared
  `load_when.commands: ["/research","/plan","/implement"]`), not cosmetic docs.
- Two smaller, standalone prose fixes: `README.md`'s multi-task syntax line and
  `rules/artifact-formats.md`'s "Team Mode Example" block both still show `--team` on
  `/research`, which no longer accepts it.
- A **reachability audit** (every `index-entries.json` row resolved against the filesystem, and
  every on-disk `context/*.md` file checked against the index) found the tree is otherwise
  completely consistent — 0 dangling rows, 0 undeclared files. This confirms `team-wave-helpers.md`
  is *not* a reachability defect (its row is valid and, via `load_when.agents`, mechanically
  "reachable") — it is a pure content-staleness defect, findable only by reading, not by any
  path-existence check. This is the report's central methodological finding.
- Three companion files that *also* mention "team" (`team-metadata-extension.md`,
  `team-orchestration.md`, `file-footprint-overlap.md`) were checked and are **already correctly
  repaired or generically valid** — false positives ruled out, not orphans.
- A fresh `verify-deploy.sh` baseline (captured before any change) shows **4 of 27 checks
  failing**. Two are confirmed pre-existing and unrelated (matches task 123's own baseline
  exactly, same project numbers). Two are new since that baseline, both traceable to a sibling
  consolidation-family task (126) and not to the team-mode deletion: a manifest-registration gap
  and a `index-entries.json` line-count drift of the exact kind the acceptance criteria warns
  about, plus 4 `state.json` hand-rolled-write lint violations in one test file. These are
  reported for the planning phase to triage, not acted on here.

## Context & Scope

The task requires a search method capable of finding dangling references that a literal
name-grep cannot: files that refer to a deleted artifact through a **glob or path pattern**
rather than its literal name, files with **dangling path-like strings**, and test fixtures that
**silently SKIP** on a missing path instead of failing. The scope is bounded to the
orchestrate-engine consolidation's actual blast radius (verified below), not a repo-wide orphan
hunt. `skill-orchestrate-hard` and the base lifecycle skills/commands are explicitly **live**,
not orphans — their own deletions are separate, not-yet-started successor tasks (121, 124, 125).

## Findings

### Blast-radius verification (what was actually deleted)

```
git log --diff-filter=D --name-only 95b98cf8b..HEAD -- agent-system/
```

(`95b98cf8b` = "task 116: create core agent system consolidation metatask", the family's root
commit in the current vault epoch — task numbers are recycled across vault epochs in this repo,
so commit-message grep alone is not a safe scoping method; anchoring on this commit's hash and
walking forward is.)

Result: **exactly three files deleted**, all in one commit (`d5bd6bb99`, task 123 phase 7):
`skills/skill-team-research/SKILL.md`, `skills/skill-team-plan/SKILL.md`,
`skills/skill-team-implement/SKILL.md`. Every other consolidation-family task (114, 117-120, 122,
126, 128, 130, 133) modified or added files; none deleted anything else under `agent-system/`.
This means the orphan search has one and only one deletion event to trace references against.

### Detection methods used, and why

| Method | What it catches | What it missed here |
|---|---|---|
| Literal-name grep (`skill-team-research\|skill-team-plan\|skill-team-implement`) | Direct textual references to the deleted names | Everything below — 0 hits anywhere except the one file's own glob line |
| Glob/pattern-reference audit (grep for `skill-team`, `team skill`, `team-skill`, `team wave`, case-insensitive, then read every hit) | Files that name the deleted skills via a wildcard, or describe their mechanism in prose without ever spelling the literal name | This is the method that actually found `team-wave-helpers.md`'s glob line and both `skill-lifecycle.md`/`multi-task-operations.md` prose defects |
| Reachability (`index-entries.json` row → filesystem, and filesystem → `index-entries.json` row, both directions) | Dangling index rows, undeclared files, `line_count` drift | Nothing new — confirms the tree is structurally clean; **does not** and structurally **cannot** catch `team-wave-helpers.md`, whose row is valid and whose `load_when.agents` binding makes it mechanically reachable despite dead content |
| Test-fixture path audit (grep test suites referencing `skill-orchestrate`/`team`/`force-phases`/`hard_contracts` for silent-SKIP-on-missing-path patterns) | Fixtures degrading to permanent silent SKIP | The one known instance (`test-lint-lifecycle-status-var.sh`'s `REAL_TEAM_IMPLEMENT` fixture) was already fixed in task 123; no new instance found within this blast radius. `test-session-runtime-files.sh` still hard-requires `skill-orchestrate-hard/SKILL.md`, but that file is still live, so this is not currently a defect — it is an already-documented risk for task 121 (the `-hard` deletion) to retarget before it deletes that file |

**The methodological point worth recording explicitly**: reachability analysis and glob/pattern
auditing are not redundant, they catch disjoint failure classes. `team-wave-helpers.md` proves
this — it is reachable by every structural test and dead by every semantic one.

### Candidate 1 — `context/reference/team-wave-helpers.md` (400 lines)

**Evidence**: Sole remaining hit anywhere in the tree for `skill-team` in any form. Its own final
line is `` - `.claude/skills/skill-team-*/SKILL.md` - Skill implementations `` — a glob pointing
at a directory pattern with zero matches. Its body describes dispatch mechanics specific to the
deleted skills (`"Team skills route teammates based on the task's language field"`, a
per-command `next_artifact_number` advance/reuse split that mirrors the deleted skills' own
Stage 4a/4b split, not `skill-orchestrate`'s current single Stage 3.5/3.6 flow). `load_when.agents:
["synthesis-agent"]` makes the file mechanically load into `synthesis-agent`'s context on every
invocation, but `synthesis-agent.md`'s own Context References section never cites it — the file
was never actually consumed by design, only declared.
**Recommendation**: **Remove.** Delete the file and its `index-entries.json` entry (line
~1433-1455). `team-orchestration.md` (Candidate — kept, see below) already serves as the generic,
implementation-agnostic wave-coordination reference `team-wave-helpers.md`'s own summary claims
to be duplicating; repurposing would create redundant reference material rather than removing an
orphan. This exact removal is what task 123's own "Follow-ups" section already recommended.

### Candidate 2 — `context/patterns/skill-lifecycle.md` (316 lines, `on_demand: true`)

**Evidence**: Two now-false spots, found only via the prose grep (no literal skill name used):
- Line 6: `` `skill-researcher`, `skill-planner`, `skill-implementer`, their `--hard` variants, the
  team skills, and every extension's... `` — lists "the team skills" as a still-existing category
  of lifecycle skill alongside the base three. False since the three team skills are deleted.
- Lines 262-264: `` **Multi-task vs. team mode**... team mode (`--team`) has a single team skill
  spawn multiple agents for *one* task. Combined (`/research 7, 22 --team`)... each task routes to
  the team skill... `` — describes the deleted per-command team-skill routing model as current
  behavior. `/research` no longer accepts `--team` at all; team fan-out is `skill-orchestrate`'s
  internal Stage 3.6/3.6a, not a separate "team skill."

**Recommendation**: **Repair.** Line 6: drop "the team skills" from the lifecycle-skill roster
(or replace with "and `skill-orchestrate`'s team-fan-out branch," if the pattern doc's authors
want to keep team mode mentioned at all). Lines 262-264: rewrite to describe
`skill-orchestrate`'s Stage 3.6/3.6a fan-out on `/orchestrate` only, not a `/research`-routable
"team skill." Not caught by task 123's 19-file inventory because it names the mechanism ("the
team skills") rather than any of the three literal skill names.

### Candidate 3 — `context/patterns/multi-task-operations.md` (685 lines)

**Evidence**: This is the largest and most consequential finding. The file's own header states
its audience is `/research`, `/plan`, `/implement`, and `index-entries.json` declares
`load_when.commands: ["/research", "/plan", "/implement"]` — meaning this content is actively
injected into those three commands' context on every multi-task invocation, not merely
documentation nobody reads.

Stale spots (all describe `--team` as usable on `/research`/`/plan`/`/implement`, which is false):
- Lines 88-89: parsing-example table rows `` `7, 22-24 --team` `` and `` `42 --team --team-size
  3` ``.
- Line 108: `` Single task with flags (`/research 7 --team`) behaves identically ``.
- Lines 344-365 (whole `## 7. Interaction with --team Flag` section): describes
  `/research 7, 22, 24 --team` as valid "combined usage," with a cost-warning and a
  flag-compatibility table asserting `--team` and `--team-size` apply "to ALL tasks in batch."
- Line 532: duplicate of the line-108 example.
- Line 672 (Dispatch Model Comparison table, "Team mode support" row): reads `` Yes (`--team`
  flag) | No `` for `` /research, /plan, /implement `` vs. `` /orchestrate `` respectively — this
  is not merely stale, it is **backwards**. Current reality is the exact opposite: `/orchestrate`
  supports `--team`, the three lifecycle commands do not.

**What is correct and must not be touched**: lines 636-662 (the "Note on `--team`" paragraph and
the "`--team` Flag Not Supported" section) already correctly and specifically describe
**multi-task `/orchestrate`'s own** lack of `--team` support, including an accurate note that the
deleted team-implement skill's `infer_from_file_overlap(phase, phases)` phase-level application
"is retired with no successor" — this is a different, already-correct claim about a different
command's multi-task mode, not the same defect. Do not conflate the two subjects when repairing.

**Recommendation**: **Repair.** Strip or rewrite the `/research`/`/plan`/`/implement`-scoped
`--team` content (lines 88-89, 108, the whole Section 7, line 532) to state plainly that
`--team` is not a flag on those three commands' multi-task syntax at all. Fix line 672's table
row to reflect the correct (not inverted) support matrix. Leave lines 636-662 exactly as they
are — they are already correct. This file was touched by task 123 (per its summary, "same
retirement, prose form, consistent wording") but that edit evidently addressed a narrower spot
than Section 7 and the table row; the miss is consistent with the task's stated mechanism (glob
`--team`-flag prose scattered through a long doc is not caught by a literal-skill-name grep).

### Candidate 4 — `README.md:46` (core extension README, one line)

**Evidence**: `` Multi-task syntax: `/research`, `/plan`, and `/implement` accept
comma-separated and range task numbers... Flags like `--team`, `--force`, `--fast`, `--hard`
modify behavior. `` — same defect as Candidate 3, standalone.
**Recommendation**: **Repair.** Drop `--team` from this flag list (or note it applies only via
`/orchestrate`).

### Candidate 5 — `rules/artifact-formats.md` (lines 70-78, "Team Mode Example" block)

**Evidence**: Shows `/research 309 --team` producing `01_teammate-a-findings.md` /
`01_teammate-b-findings.md` / `01_teammate-c-findings.md` / `01_team-research.md` as a worked
example immediately after a correct, still-valid "Round 1/Round 2" example for the non-team case.
**Recommendation**: **Repair.** Either delete the example block or retarget it to
`/orchestrate 309 --team`, which is the only command this now actually describes.

### Checked and confirmed NOT orphans (false-positive exclusions, recorded per the non-goals bar)

- **`context/formats/team-metadata-extension.md`** (119 lines): mentions "team skills" only in an
  explicit provenance note already added by task 123 Phase 5 — `` this schema was written by the
  now-retired per-mode team skills that used to... `` and a companion note that the current
  `skill-orchestrate` fan-out "tracks a simpler internal" shape and does not produce this richer
  schema. Already correctly self-describes as historical design reference. **Kept, no action.**
- **`context/patterns/team-orchestration.md`** (146 lines): generic, implementation-agnostic
  wave/teammate/synthesis-pattern description ("the lead agent (skill)", "Teammate A/B/C/D —
  Primary/Alternatives/Critic/Horizons") that matches `synthesis-agent.md`'s current
  teammate-lettering scheme and describes concepts `skill-orchestrate`'s Stage 3.6/3.6a still
  implements. No literal or glob reference to any deleted skill. **Kept, no action** — this is
  the reason repurposing `team-wave-helpers.md` (Candidate 1) would be redundant rather than
  useful.
- **`context/patterns/file-footprint-overlap.md`**, **`context/patterns/skill-self-execution-fallback.md`**,
  **`context/patterns/context-protective-lead.md`**: all three carry explicit "(retired)" /
  "(historical)" annotations already added by task 123. Verified current, not orphans.
- **`agents/synthesis-agent.md:3`** (frontmatter `description`): `` Multi-output synthesis for
  team skills. `` — ambiguous but not clearly false; "team skills" reads naturally as shorthand
  for "skills/modes that run in team mode" (which `skill-orchestrate`'s team-fan-out branch still
  is), not as a claim that a literal `skill-team-*` package exists. Per the non-goals bar
  ("when the two cannot be told apart, leave the file and record the ambiguity"), **left as-is**,
  recorded here as a low-priority reword candidate rather than a defect.
- **`docs/fork-patterns.md`**, **`docs/templates/command-template.md`**,
  **`docs/guides/creating-commands.md`**, **`context/standards/git-staging-scope.md`**: all
  mention "team mode" or "`--team`" in a generic sense (parser capability documentation, a
  cost-comparison table, an illustrative commit-message example) that does not assert `--team` is
  available on `/research`/`/plan`/`/implement` specifically and remains accurate for
  `/orchestrate`. **Kept, no action.**
- **`scripts/parse-command-args.sh`**: still parses `--team`/`--team-size` generically. Not dead
  code — this is the shared parser `commands/orchestrate.md` still uses for its own `--team`
  support; removing it would break the surviving feature.

### Reachability audit (no new findings, but rules out one whole detection axis)

Ran both directions over `agent-system/extensions/core/index-entries.json` against
`agent-system/extensions/core/context/`:
- Every one of 144 declared rows resolves to a file on disk (0 dangling rows).
- Every on-disk `context/*.md` file (137) has a declared row (0 undeclared files).
- One `line_count` mismatch found (see "Adjacent findings" below) — the only structural defect
  in the whole tree.

This confirms the team-mode orphan is invisible to structural/reachability tooling and is only
findable by the glob/pattern-reference-plus-read method above — worth stating plainly for
whoever scopes the reusable detector (see Recommendations).

### Test-fixture silent-SKIP audit (no new findings within this blast radius)

Searched every `scripts/tests/*.sh` file mentioning `SKIP` for a co-occurring reference to
`orchestrate`, `team`, `force-phases`, or `hard_contracts`. One hit
(`test-skill-base-lifecycle.sh`), which uses "SKIP" as normal business-logic vocabulary (a
non-success status must SKIP a downstream call), not a missing-file degradation — not a fixture
defect. The one confirmed silent-SKIP fixture the task description references
(`test-lint-lifecycle-status-var.sh`'s `REAL_TEAM_IMPLEMENT` fixture) was already removed in task
123 phase 4/7. `test-session-runtime-files.sh` still hard-requires
`skill-orchestrate-hard/SKILL.md`, correctly, because that file is still live (task 121, its
deletion, has not started) — already flagged by task 120's own follow-ups as a prerequisite for
that future deletion, not a current defect.

### Adjacent findings from baselining (not orphans — flagged for the planning phase to triage)

A fresh `verify-deploy.sh` run (captured before any change, per the task's binding instruction)
reports **4 of 27 checks failing**, all captured independently for reproducibility:

1. **`check-extension-docs.sh` (doc-lint), 4 core FAILs**:
   - 2 pre-existing, unrelated: `scripts/test-state-write-large-payload.sh` and
     `scripts/tests/test-roadmap-argv-ceiling.sh` undeclared in `provides.scripts` — identical to
     task 123's own recorded baseline.
   - 1 **new**: `scripts/tests/test-force-phases.sh` (added by task 126 phase 7, *after* task
     123's baseline was recorded) is also undeclared in `provides.scripts`.
   - 1 **new**: `index-entries.json` `line_count` mismatch for
     `patterns/system-defect-discrimination.md` (declared 409, actual 420) — two later
     consolidation-family commits (task 128 phase 6, task 133 phase 1) both edited this file
     without regenerating its line count. This is precisely the class of `index-entries.json`
     defect the acceptance criteria calls out by name.
2. **`run-all.sh` (verify-deploy's nested gate 8)**: reports FAIL when run nested inside
   `verify-deploy.sh`, but a standalone run is clean (`58 passed, 0 failed, 0 skipped, 58 total`,
   exit 0). This exact flakiness-under-nesting was already documented and diagnosed by task 123
   ("demonstrated concurrency-induced flake... not a real regression") — reproduced identically
   here, not a new issue.
3. **`validate-state.sh --deep`**: 2 unknown-field findings (`abandon_reason` on project numbers
   94,46,31,64,73,115,132; `blocks_note` on 106,107,109) — byte-identical project-number lists to
   task 123's own recorded baseline. Confirmed pre-existing, unrelated.
4. **`lint-state-writer-boundary.sh`, 4 violations, all new**: `scripts/tests/test-force-phases.sh`
   (lines 261, 307, 317, 327) hand-rolls `jq '...' specs/state.json > specs/state.json.tmp && mv
   ...` instead of routing through `scripts/state-write.sh`. Introduced by task 126 phase 7,
   after task 123's baseline.

None of these four are orphans in the sense this task defines (nothing was deleted that created
them), and none involve the deleted team skills. They are pre-existing-to-this-sweep defects in a
sibling consolidation-family task's output (task 126), surfaced only because establishing an
honest fresh baseline required running the full gate suite. They currently block the acceptance
criterion that "the four lints, run-all.sh, and check-task-references.sh stay green" from being
trivially true before this sweep even starts — recorded here so the planning phase can decide
whether to fold trivial fixes (regenerate `index-entries.json` line counts; add the manifest
entry; route the four test writes through `state-write.sh`) into this task or file them
separately. `check-task-references.sh` itself reports 0 findings (confirmed clean, not among the
4 failures).

## Decisions

- Scoped the deletion blast-radius by diffing every file deletion from the consolidation's root
  commit (`95b98cf8b`) to `HEAD`, rather than trusting task-number grep in commit messages —
  task numbers are recycled across this repo's vault epochs, and a naive `git log --grep="task
  123"` (etc.) picks up unrelated commits from earlier epochs reusing the same number.
- Treated `skill-orchestrate-hard` and the three base lifecycle commands/skills as live, per the
  delegation context and confirmed independently via `specs/state.json` (tasks 121, 124, 125 —
  their respective deletions — are `not_started`/`blocked`).
- Excluded `team-orchestration.md` and `team-metadata-extension.md` from the removal candidate
  list after reading their full content, not just their `load_when` metadata — both are either
  generic/implementation-agnostic or already carry an explicit historical-provenance disclaimer.
- Did not attempt to fix or file the four baseline gate failures (Adjacent findings) — out of
  this research task's remit; documented with enough detail (file, line numbers, exact defect)
  for the planning phase to make a scoping call.

## Risks & Mitigations

- **Risk**: a plan or implementation phase might read `team-wave-helpers.md`'s
  `load_when.agents: ["synthesis-agent"]` binding and conclude it is "in use," reintroducing it
  or hesitating to delete it. **Mitigation**: this report documents explicitly that `load_when`
  reachability and content correctness are orthogonal — the binding proves nothing about whether
  `synthesis-agent.md` actually consumes the file (it does not, verified by grep).
- **Risk**: repairing `multi-task-operations.md` Section 7 without reading lines 636-672 first
  could accidentally delete or contradict the file's already-correct `/orchestrate`-scoped
  "`--team` Flag Not Supported" section, since both subjects use the same flag name in the same
  file. **Mitigation**: called out explicitly above with exact line ranges for each subject.
- **Risk**: folding the four baseline gate failures into this removal sweep could blur the task's
  scope (a lint-boundary bug in a sibling task's test file is not an "orphan"). **Mitigation**:
  presented them in a clearly separated "Adjacent findings" section with a recommendation to let
  planning decide inclusion vs. filing separately, rather than silently absorbing or silently
  dropping them.

## Context Extension Recommendations

- **Topic**: reusable orphan-detection tooling for future consolidation/deletion tasks (the task
  description's re-runnability requirement, and the same blind spot will recur when task 121
  deletes `skill-orchestrate-hard`).
- **Gap**: `check-extension-docs.sh` already automates the reachability axis (index-row ↔
  filesystem, `line_count` drift, undeclared-file detection) well — confirmed by this sweep
  finding 0 new structural issues. There is no automated equivalent for the glob/pattern-prose
  axis that actually caught `team-wave-helpers.md`, `skill-lifecycle.md`, and
  `multi-task-operations.md`; that axis required reading prose for semantic staleness, which is
  inherently harder to fully mechanize, but the *first pass* (grep every `context/**/*.md` for a
  configurable list of "recently deleted artifact name" tokens, expanded with simple wildcard
  variants like `{name}-*`/`*-{name}`/`skill-{name}`, then hand off hits for human/agent review)
  is mechanizable and would have found all three candidates here automatically.
- **Recommendation**: a future task (not this one) should build a small
  `scripts/audit-deletion-references.sh <deleted-name>...` that runs literal-name grep, a
  wildcard-expanded grep, and the existing `check-extension-docs.sh`/index-entries reachability
  check together, and prints a checklist for human/agent triage rather than a pass/fail gate
  (this is inherently a "candidates for review" tool, not a lint, since prose staleness needs
  judgment). Whether it belongs in the standing lint suite: **no**, not as an auto-fail gate — a
  false positive (a file legitimately discussing "team" in an unrelated sense) would make it too
  noisy to run unattended; it belongs as an on-demand script invoked by the next task that
  deletes an artifact with the same "glob-referenced" risk, starting with task 121's
  `skill-orchestrate-hard` deletion.

## Appendix

### Reproducible commands used

```bash
# Blast-radius scoping (the load-bearing anchor for everything else in this report)
git log --diff-filter=D --name-only 95b98cf8b..HEAD -- agent-system/

# Literal-name grep (0 hits confirms task 123's own zero-hits criterion still holds)
grep -rn "skill-team-research\|skill-team-plan\|skill-team-implement" agent-system/

# Glob/pattern-prose audit (the method that found the 3 real candidates)
grep -rniE "skill-team|team-mode-skill|skill_team" agent-system/extensions/ --include="*.md" --include="*.sh" --include="*.json"
grep -rniE "team skill|team-skill|the three team|team wave|wave-based team" agent-system/extensions/core/ --include="*.md"

# Reachability audit (both directions, index-entries.json <-> filesystem)
python3 -c "
import json, os
base='agent-system/extensions/core'; ctx=os.path.join(base,'context')
d=json.load(open(os.path.join(base,'index-entries.json')))
missing=[e['path'] for e in d['entries'] if not os.path.isfile(os.path.join(ctx,e['path']))]
print('missing:', missing)
"

# Baseline gates (run BEFORE any change; re-run identically after to diff)
bash .claude/scripts/verify-deploy.sh
bash .claude/scripts/check-extension-docs.sh
bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet
bash .claude/scripts/validate-state.sh --deep specs/state.json
bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose
```

### References

- `specs/123_delete_team_mode_skills/summaries/01_delete-team-mode-skills-summary.md` — source
  of the confirmed known instance and its own baseline (2 pre-existing doc-lint findings,
  identical `validate-state.sh --deep` project-number lists).
- `specs/117_build_orchestrate_dispatch_prep_stage/summaries/01_dispatch-prep-stage-summary.md`,
  `specs/118_build_hard_contracts_injection/summaries/01_hard-contracts-injection-summary.md`,
  `specs/119_migrate_hard_mode_state_machine_logic/summaries/01_state-machine-migration-summary.md`,
  `specs/120_retarget_hard_mode_tests_to_engine_branch/summaries/01_retarget-hard-mode-tests-summary.md`,
  `specs/122_build_team_mode_fanout_stage/summaries/01_team-fanout-stage-summary.md` — consolidation
  family follow-ups cross-checked, no additional orphan leads beyond what is captured above.
- `specs/126_.../summaries/01_*-summary.md` (phase-forcing flags) — source of the two new
  baseline gate findings (Adjacent findings section).
- `specs/state.json` — task status confirmation for 121 (`not_started`), 124 (`blocked`), 125
  (`not_started`), establishing `skill-orchestrate-hard` and the base lifecycle commands/skills
  as still-live.

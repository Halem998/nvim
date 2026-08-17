# Baseline Byte Accounting: Task 54 (split_eager_rules_budget)

Canonical measurement command (reused by every phase and by Phase 7's re-measure):
```bash
cat ~/.config/CLAUDE.md ~/.config/nvim/CLAUDE.md .claude/CLAUDE.md \
    .claude/rules/git-workflow.md .claude/rules/artifact-formats.md \
    .claude/rules/state-management.md .claude/rules/pr-prohibition.md \
    .claude/rules/source-store-deploy-boundary.md \
    .claude/rules/no-task-references-in-deliverables.md | wc -c
```

## Phase 1 Baseline (recorded before any edit)

- **Git HEAD at baseline**: `3a2e795a2ac2004ab80f1169ffaad7565902fa97`
- **git status --porcelain at baseline**: dirty, but only with foreign/unrelated changes not in
  this task's territory: `.claude-extensions.json`, three `agent-system/extensions/literature/**`
  files, `specs/TODO.md`, `specs/events.jsonl`, `specs/state.json` (all task-lifecycle-mechanical),
  plus untracked `.memory/10-Memories/*.md`, `.memory/learn-harvest-log.json`, and
  `agent-system/extensions/literature/scripts/literature-pyenv/`. None of these paths overlap this
  task's territory contract (Phase 2-7 owned files); observed and recorded, not touched.

### Parent chain

| File | Bytes |
|------|-------|
| `~/.config/CLAUDE.md` | 769 |
| `~/.config/nvim/CLAUDE.md` | 3,046 |
| **Total** | **3,815** |

Matches research expectation (3,815) exactly.

### Generated CLAUDE.md

| File | Bytes |
|------|-------|
| `.claude/CLAUDE.md` | 46,475 |

Matches research expectation (46,475) exactly.

### Six eager rules (deployed tree)

| File | Bytes |
|------|-------|
| `.claude/rules/git-workflow.md` | 11,147 |
| `.claude/rules/artifact-formats.md` | 5,360 |
| `.claude/rules/state-management.md` | 5,148 |
| `.claude/rules/pr-prohibition.md` | 4,628 |
| `.claude/rules/source-store-deploy-boundary.md` | 2,746 |
| `.claude/rules/no-task-references-in-deliverables.md` | 1,489 |
| **Total** | **30,518** |

Matches research expectation (30,518) exactly.

### Whole-prefix canonical figure

`cat <parent chain> .claude/CLAUDE.md <six rules> | wc -c` = **80,808 B**

Matches research expectation (80,808) exactly.

### All ten source-store rule files (`agent-system/extensions/core/rules/*.md`)

| File | Bytes |
|------|-------|
| `artifact-formats.md` | 5,360 |
| `error-handling.md` | 5,420 |
| `git-workflow.md` | 11,147 |
| `no-task-references-in-deliverables.md` | 1,489 |
| `plan-format-enforcement.md` | 3,414 |
| `project-overview-detection.md` | 1,130 |
| `pr-prohibition.md` | 4,628 |
| `source-store-deploy-boundary.md` | 2,746 |
| `state-management.md` | 5,148 |
| `workflows.md` | 759 |
| **Total** | **41,241** |

### Both merge sources

| File | Bytes |
|------|-------|
| `agent-system/extensions/core/merge-sources/claudemd.md` | 24,707 |
| `agent-system/extensions/literature/merge-sources/claudemd.md` | 12,851 |
| **Total** | **37,558** |

### Source store vs. deployed tree parity (the six eager rules)

All six `cmp`-identical between `agent-system/extensions/core/rules/*.md` and `.claude/rules/*.md`:
`git-workflow.md`, `artifact-formats.md`, `state-management.md`, `pr-prohibition.md`,
`source-store-deploy-boundary.md`, `no-task-references-in-deliverables.md` — MATCH, no care needed
for any of the six.

---

## Per-Phase Before/After Table (appended by each phase)

| Phase | File | Before (B) | After (B) | Delta (B) | % Change |
|-------|------|-------------|-----------|-----------|----------|
| 1 | (baseline only, no edits) | — | — | — | — |
| 2 | `core/rules/git-workflow.md` | 11,147 | 7,000 | -4,147 | -37.2% |
| 2 | `core/context/standards/git-workflow-narrative.md` (new, lazy) | 0 | 5,082 | +5,082 | new file |

**Phase 2 note**: the achieved eager core (7,000 B) is higher than the research's ~4,200 B
hypothesis. Reason: the full "No Destructive Git on Uncommitted Work" forbidden-operations list,
exemption summary, and the "snapshot first" instruction were kept in full per the Risks table's
explicit mitigation (only the mode-by-mode `--branch`/`--no-revert` prose moved), and the
Commit Conventions tables plus the retained portions of Git Safety are inherently large. All
KEEP-list items (Commit Conventions tables, Do Not Commit / Create Commits After, the
Commit-Per-Green-Substep Mandate heading + binding paragraph, Never Run, Forbidden-on-a-dirty-tree,
Not-blocked, Always Check Before Commit, Commit Message Format + Session ID format/generation) are
present verbatim — confirmed by direct read of the trimmed file, not asserted.

| 3 | `core/rules/error-handling.md` | 5,420 | 2,987 | -2,433 | -44.9% |
| 3 | `core/context/standards/error-recovery-strategies.md` (new, lazy) | 0 | 4,435 | +4,435 | new file |

**Phase 3 note**: this file was NOT one of the measured eager six (its `paths: .claude/**/*` glob
did not match the session that produced the 30,518 B figure), so this saving is
regression-prevention rather than an immediate cut to the 30,518 B six-rule total — reported here
as its own line, not folded into that total. The write-gating "never discard uncommitted changes
to reach a passing build" constraint was re-anchored as a standalone eager
`## Write-Gating Constraint` section (confirmed present via grep) rather than left inside the
now-moved Build Error Recovery narrative. All explicit KEEP items (Error Categories taxonomy,
condensed Log-the-Error pointer, Preserve Progress/Enable Resume/Report Clearly, Severity Levels
table, Non-Blocking Errors list) are present verbatim in the trimmed file.

| 4 | `core/rules/state-management.md` | 5,148 | 3,850 | -1,298 | -25.2% |
| 4 | `core/context/reference/state-management-schema.md` (existing, appended) | 472 lines | 519 lines | +47 lines | destination for moved narrative |

**Phase 4 note**: destination decision — the moved narrative (Artifacts-Are-Append-Only
enforcement mechanism + known limitation, State-First Update Pattern explanation, Error Handling)
was appended to the EXISTING `context/reference/state-management-schema.md` as a new
"## Enforcement and Update-Pattern Narrative" section, rather than creating a third
`context/standards/` companion. Reason: that schema doc is already the rule's designated
elaboration home (referenced by its own "## Schema Reference" section and the `#file-scope-field`
anchor), so appending there avoids fragmenting elaboration across three files for one rule. The
ASCII status-transition diagram was NOT dropped (both the diagram and the bulleted Restrictions
survive eager, per the "never drop both" instruction) since the achieved core (3,850 B) already
lands close to the ~3,450 B hypothesis without needing that cut. All five KEEP items (Never edit
TODO.md directly, Canonical Sources block, Artifacts-Are-Append-Only core prohibition +
wholesale-assignment prohibition + `+=`/sanctioned-helper instruction, Status Transitions
restrictions bullets, the two `update-task-status.sh`/`generate-todo.sh` one-liners, File
Scope/Schema Reference pointers) are present verbatim — confirmed by grep.

| 5 | `core/rules/pr-prohibition.md` | 4,628 | 2,574 | -2,054 | -44.4% |
| 5 | `cslib/context/project/cslib/pr-command-workflow.md` (new, relocated) | 0 | 3,016 | +3,016 | relocated CSLib content |

**Phase 5 note**: the two relocated CSLib subsections measured 2,999 B combined in the original
file; the new file is 3,016 B (17 B larger, due to the new file's own H1 title and orienting
intro paragraph explaining the relocation — the two workflow subsections themselves are
byte-comparable, differing only in heading level/framing per the plan's stated tolerance). The
eager core (2,574 B) includes the new `<!-- why-eager -->` in-file comment recording why
`pr-prohibition.md`'s `paths: "**/*"` glob is deliberate. All three Prohibited Operations
subsections, the Required Behavior list, and the "Never push branches or create PRs..." sentence
are present verbatim in the trimmed file — confirmed by grep. `cslib/manifest.json` confirmed to
declare `provides.context: ["project/cslib"]` and `task_type: "pr"` routes through cslib
(`skill-pr-review-research`/`pr-review-implementation-agent` etc.) before writing.
`generate-context-line-counts.sh --check` passes (line_count 58, exact). `check-extension-docs.sh`
reports cslib clean (only pre-existing WARNs for routing targets not deployed, since cslib is not
the currently active extension set — unrelated to this change).

| 6 | `literature/merge-sources/claudemd.md` | 12,851 | 8,673 | -4,178 | -32.5% |
| 6 | `core/merge-sources/claudemd.md` (heading reworded only) | 24,707 | 24,770 | +63 | collision fix |

**Phase 6 note**: `context/patterns/lit-stage4a-flow.md` confirmed to exist and is the file all
six `--lit`-capable skills import directly (confirmed via grep: `skill-researcher/SKILL.md` etc.
carry `Follow @.claude/context/patterns/lit-stage4a-flow.md in full`). No skill or script depends
on the removed CLAUDE.md prose itself — `skill-literature/SKILL.md`'s one reference to
"Interactive Sub-Index Setup Detection" names the still-present HEADING for orientation, not the
removed body text, so it remains valid. All four user-facing choices (Use global corpus now /
Create curation task / Search online to ingest / Skip this run) and the "no silent fallback"
guarantee are restated in the condensed replacement; both pointer paths
(`context/patterns/lit-stage4a-flow.md`, `scripts/literature-lit-flag-resolve.sh`) resolve to
files that exist. The core stub's duplicate H2 was resolved by rewording it to
"## Literature Mode (`--lit`) — Extension Pointer" rather than dropping it, since it still serves
non-literature deploys; net core-merge-source change is +63 B, not a saving (expected — Phase 6's
saving is entirely in the literature merge source). The generated-file effect is confirmed
separately at redeploy in Phase 7.

**Phase 2 check-extension-docs.sh note**: `check-extension-docs.sh` reports
`FAIL: deployed rule content drift (deployed != extension source): rules/git-workflow.md` at this
point in the plan. This is EXPECTED and BY DESIGN: the deployed `.claude/` tree is written only by
the single `deploy-headless.sh` redeploy in Phase 7 (per this plan's binding rules and Non-Goals),
so source-vs-deployed drift is expected to persist through Phases 2-6 and is resolved only once,
in Phase 7. Five additional pre-existing drift FAILs (`lint-agent-contracts.sh`,
`orchestrate-recover-outcome.sh`, `orchestrator-postflight.sh`, `skill-base.sh`,
`test-lint-agent-contracts.sh`) were already present in the working tree BEFORE this task's Phase 1
baseline commit (confirmed: Phase 1's `cmp` check found the six eager RULES byte-identical to
deployed, but this drift check also covers `provides.scripts`, which Phase 1 did not check) — they
belong to other, unrelated in-flight work and are out of this task's territory; not touched, not
fixed here. `generate-context-line-counts.sh --check` passes clean (486/486 exact) confirming the
new companion's `index-entries.json` entry is correct.

---

## Phase 7: Redeploy, Re-Measure, and Final Accounting

### Post-redeploy re-measurement (canonical command, run twice — once after the first
`deploy-headless.sh`, once more after Phase 7's own two source edits and a second redeploy)

| Figure | Baseline (Phase 1) | Final (post-redeploy) | Delta | % Change |
|--------|--------------------:|-----------------------:|------:|---------:|
| Parent chain | 3,815 | 3,815 | 0 | 0% (untouched, as expected) |
| Generated `.claude/CLAUDE.md` | 46,475 | 42,798 | -3,677 | -7.9% |
| Six eager rules (sum) | 30,518 | 23,547 | -6,971 | -22.8% |
| **Whole-prefix (`cat ... | wc -c`)** | **80,808** | **70,160** | **-10,648** | **-13.2%** |

### Six eager rules, individually (post-redeploy, deployed tree)

| File | Before (B) | After (B) | Delta (B) | % Change |
|------|-----------:|----------:|----------:|---------:|
| `git-workflow.md` | 11,147 | 7,000 | -4,147 | -37.2% |
| `artifact-formats.md` | 5,360 | 5,360 | 0 | 0% (audited, deliberately untouched) |
| `state-management.md` | 5,148 | 3,850 | -1,298 | -25.2% |
| `pr-prohibition.md` | 4,628 | 2,574 | -2,054 | -44.4% |
| `source-store-deploy-boundary.md` | 2,746 | 2,746 | 0 | 0% (audited, deliberately untouched) |
| `no-task-references-in-deliverables.md` | 1,489 | 2,017 | +528 | +35.5% (why-eager comment added; the file was previously eager-by-omission, now eager-by-recorded-decision) |
| **Total** | **30,518** | **23,547** | **-6,971** | **-22.8%** |

### Complete file-touched table (every file touched across all phases, both classes)

| Category | File | Before (B) | After (B) | Delta (B) |
|----------|------|-----------:|----------:|----------:|
| Eager rule (trimmed) | `core/rules/git-workflow.md` | 11,147 | 7,000 | -4,147 |
| Lazy companion (new) | `core/context/standards/git-workflow-narrative.md` | 0 | 5,082 | +5,082 |
| Eager rule (trimmed) | `core/rules/error-handling.md` | 5,420 | 2,987 | -2,433 |
| Lazy companion (new) | `core/context/standards/error-recovery-strategies.md` | 0 | 4,435 | +4,435 |
| Eager rule (trimmed) | `core/rules/state-management.md` | 5,148 | 3,850 | -1,298 |
| Lazy reference (appended) | `core/context/reference/state-management-schema.md` | 12,838 (472 lines) | ~14,100 (519 lines) | +47 lines |
| Eager rule (trimmed) | `core/rules/pr-prohibition.md` | 4,628 | 2,574 | -2,054 |
| Lazy companion (new, relocated) | `cslib/context/project/cslib/pr-command-workflow.md` | 0 | 3,016 | +3,016 |
| Merge source (trimmed) | `literature/merge-sources/claudemd.md` | 12,851 | 8,673 | -4,178 |
| Merge source (heading reword) | `core/merge-sources/claudemd.md` | 24,707 | 24,770 | +63 |
| Eager rule (comment added) | `core/rules/no-task-references-in-deliverables.md` | 1,489 | 2,017 | +528 |
| Lazy reference (ceiling added) | `core/context/architecture/context-layers.md` | 12,838 (194 lines) | 13,634 (209 lines) | +796 |

No file is described as "slimmed" without a measured number; every row above was directly `wc -c`
or `wc -l` measured, not asserted.

### Pre-Action Audit (re-read each trimmed rule against its KEEP list; locatable quote per item)

- **`git-workflow.md`**: `### Create Commits After`, `### Do Not Commit`, `### Commit-Per-Green-Substep Mandate`
  (heading + binding paragraph), `### Never Run`, `**Forbidden on a dirty tree**`, `**Not blocked**`,
  `### Always Check Before Commit` — all located by grep in the deployed file (line numbers 39,
  47, 55, 77, 97, 122, 126).
- **`error-handling.md`**: `## Error Categories`, `## Severity Levels`, the "Never discard
  uncommitted changes to reach a passing build" write-gating sentence, `## Non-Blocking Errors` —
  all located by grep (line numbers 7, 67, 78, 87).
- **`state-management.md`**: "Never edit TODO.md directly", "Wholesale `.artifacts = [...]`
  assignment is prohibited", "Cannot transition from terminal states", "Cannot mark COMPLETED
  without all phases done" — all located by grep (line numbers 9, 32, 62, 63).
- **`pr-prohibition.md`**: the three "Agents MUST NOT..." Prohibited Operations sentences and the
  "Never push branches or create PRs..." sentence — all located by grep (line numbers 21, 30, 37, 47).

Every pre-action row from the report's four classification tables is present in the deployed,
post-redeploy tree. No constraint was lost.

### Post-Deploy Drift Attribution

`.claude/` is git-ignored (not tracked), so its content cannot be `git diff`-ed directly against a
prior commit. Attribution instead rests on two facts: (1) `verify-deploy.sh` check 5
("declared-vs-deployed parity and content-hash equality") PASSED both times deploy-headless.sh was
run in this phase, confirming every deployed file is now byte-identical to its
`agent-system/extensions/**` source; and (2) every source edit in this task is already attributed
to a named phase via that phase's own commit (Phases 2-6, each a separate `task 54 phase N` commit
touching only its declared territory). The redeploy therefore introduces no untracked drift of its
own — it is a pure sync operation.

**One pre-existing, unattributable-to-this-task drift item was surfaced by the redeploy** (not
caused by any of this task's 6 phases, none of which touch this file):
`check-extension-docs.sh` Rule S reports `deployed context/contracts/return-meta-artifacts-template.md
has no entry in .claude/context/index.json`. Git history shows this file was added by an earlier,
unrelated commit (git log: a prior task's "record contract posture and create canonical template
fragment" commit) that never added its `index-entries.json` entry; the file was apparently never
deployed before this task's Phase 7 redeploy, so this was latent rather than newly introduced. Per
this plan's own Risk table ("Redeploy surfaces unrelated drift ... Unattributable drift is
reported, not absorbed"), this is reported here and left unfixed — it is outside this task's
territory contract (none of Phases 2-7 own `context/contracts/**`).

Separately, `validate-state.sh --deep` (a `verify-deploy.sh` gate, check 10) reports 4 unknown
`active_projects[]` fields (`blockers` on project 52, `parent_task` on projects 54/55/56,
`priority` on projects 52/53, `subtasks` on project 49). Confirmed via `git log`/`git show` that
these fields were already present in `specs/state.json` at this task's own Phase 1 baseline commit
(introduced by the immediately-prior "expand into subtasks" commit, before this task's
implementation began) — not caused by any phase of this plan, which never touches `specs/state.json`.
Reported per the same Risk-table instruction; not fixed here, as `specs/state.json` schema
evolution is outside this task's territory.

**Because of these two pre-existing, unattributable items, `verify-deploy.sh`'s overall exit code
is non-zero even after a clean redeploy of every file this task touched.** All 21 of the other 23
`verify-deploy.sh` checks pass, including the content-hash-equality check that proves this task's
own changes deployed correctly.

### Eager Budget Ceiling

Recorded in `agent-system/extensions/core/context/architecture/context-layers.md`, under Channel 3
("Rules `paths:` frontmatter"), as a new "**Eager budget ceiling**" bullet: class = every
`rules/*.md` file that eagerly loads in a representative session (no `paths:` frontmatter, or a
`paths:` glob matching a representative touched-path set of at minimum `specs/**` and `.claude/**`);
measurement command = the canonical `cat ... | wc -c` command above.

**Achieved-vs-ceiling honesty check**: the final, post-redeploy six-rule sum is **23,547 B**,
which is ABOVE the originally-recommended 20,000 B figure by 3,547 B. Per the plan's own Risk
table ("Achieved total exceeds the recommended <=20,000 B ceiling ... state the ceiling at the
achieved value plus stated headroom, recording the reasoning in-file. Never state a ceiling the
tree already violates."), `context-layers.md` records the ceiling at **24,000 B** (achieved
23,547 B plus a small stated headroom) rather than the original 20,000 B recommendation, with the
KEEP-list-discipline reasoning recorded in-file. The `artifact-formats.md` Example-Flow trim
(~700 B) named as the other optional lever in that Risk row was NOT taken here — even fully taken
it would not have closed the gap to 20,000 B, and `artifact-formats.md` was an explicit Non-Goal
(audited and deliberately left alone at planning time). Closing the remaining gap to a stricter
ceiling is recorded as a named follow-up rather than done opportunistically here.

### Eager-Context Measurement-Harness Correction (record only, no edit to that task's territory)

Handed over verbatim for the eager-context measurement-harness task: its stated model ("rules
lacking `paths:` frontmatter or carrying `paths: "**/*"`") catches only 8,863 B of the (pre-task)
measured 30,518 B, missing `git-workflow.md`, `artifact-formats.md`, and `state-management.md`
(21,655 B combined, ~71% under-count) because those are gated on `specs/**/*` / `.claude/**/*`
globs that DO match a real session's touched paths. The harness must glob-MATCH each rule's
`paths:` value against a representative touched-path set (at minimum `specs/**` and `.claude/**`),
not merely check for absent-or-universal frontmatter.

### Audited-and-Deliberately-Untouched (not an oversight)

`artifact-formats.md` and core's `merge-sources/claudemd.md` (beyond the one-line stub heading
reword in Phase 6) were audited at planning time and contain no comparable verified-redundant
chunk; both were deliberately left alone. Their post-redeploy figures (5,360 B and 24,770 B
respectively) are unchanged from baseline except for the Phase 6 heading reword, confirming no
unintended drift.

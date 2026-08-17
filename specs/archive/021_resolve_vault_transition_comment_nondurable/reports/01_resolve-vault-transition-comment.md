# Research Report: Task #21

**Task**: 21 - resolve_vault_transition_comment_nondurable
**Started**: 2026-08-10T00:00:00Z
**Completed**: 2026-08-10T00:00:00Z
**Effort**: small (two source-store edits + one numbering reconciliation)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/commands/todo.md`, `agent-system/extensions/core/skills/skill-todo/SKILL.md`, `agent-system/extensions/core/scripts/generate-todo.sh`, `agent-system/extensions/core/scripts/deprecated/vault-operation.sh`, `.opencode/**` copies, `specs/state.json`, `specs/vault/01-vault/meta.json`, `specs/TODO.md`
- Archived precedent: `specs/vault/01-vault/archive/653_update_task_creation_commands_state_first/summaries/01_task-creation-migration-summary.md`, `specs/vault/01-vault/archive/248_todo_vault_archival_number_reset/summaries/01_vault-archival-summary.md`
- Independent reproduction of the sed corruption bug and a YAML-parse test of the result
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- **Resolution chosen: Option (a) — delete the hand-insertion step from both live sites.** No
  live document should instruct a caller to hand-edit `specs/TODO.md` for vault transitions.
  Rely on the two durable records that already exist and are already correctly written:
  `specs/state.json` `.vault_history[]` and `specs/vault/{NN}-vault/meta.json`.
- This directly matches the prior recorded decision (the `653_...` archived summary) and is
  structurally identical to the already-accepted `repository_health` precedent at Step 5.6.2 of
  `commands/todo.md`, which deliberately does *not* mirror durable state into TODO.md because
  `generate-todo.sh` fully overwrites the file every run.
- Independently reproduced the corruption: the `skill-todo` sed range `/^---$/,/^---$/` matches
  both frontmatter delimiters, so the `a\` command fires twice — once *inside* the YAML block
  (which then silently mis-parses as a bogus `<!-- Vault transition` key rather than raising an
  error) and once after the closing `---`, with the comment duplicated verbatim.
- The section-heading/substep numbering mismatch in `commands/todo.md` (`### 5.7. Vault
  Operation` heading, `**Step 5.8.1`–`5.8.9**` substeps) is confirmed and reconciled by renaming
  the substeps to `5.7.1`–`5.7.8` (8 remain after deleting the transition-comment step).
- Two scope decisions recorded explicitly per the task's requirement: `deprecated/vault-operation.sh`
  stays untouched (quarantined); all five `.opencode/**` copies are deferred to the separately-tracked
  opencode-drift work-stream, not touched here.
- **Surviving-string count after the fix**: 3 non-deprecated, non-`.opencode` occurrences of the
  literal comment string remain in the source store, and all 3 are legitimate (see Findings ->
  "Post-fix survivor accounting").

## Context & Scope

The task asks for a decision among three options for how (or whether) a vault-transition marker
should appear in `specs/TODO.md`, given that `generate-todo.sh` regenerates the file wholesale
and therefore cannot preserve a hand-inserted HTML comment, and given that the current
hand-insertion instruction (present in two live documents) is empirically both non-durable and
actively corrupting. A decision was already made once before (the `653_...` archived task) and
partially undone by omission — the script that did the insertion was deleted, but the prose
instruction describing the same insertion was re-specified independently in both
`commands/todo.md` and `skill-todo/SKILL.md`, which is why the defect is back. This report
records the decision, the concrete edit shape for each live site, and the two required scope
calls (deprecated script, `.opencode/**` copies), plus an adjacent numbering fix in the same
section of `commands/todo.md`.

## Findings

### Codebase Patterns

**1. `generate-todo.sh` cannot preserve hand-authored content by construction.**
`TODO_FILE` (`agent-system/extensions/core/scripts/generate-todo.sh:65`) is referenced only as
a default path, a CLI arg, an `mktemp` sibling (line 495), and the destination of
`mv "$TEMP_FILE" "$TODO_FILE"` (line 497). There is no read of the pre-existing file anywhere in
the script. This is a deliberate design property, not an oversight — the script's own header
comment states "Atomic write via mktemp + mv ensures no partial/corrupted output," and
`commands/todo.md` Step 5.6.2 already documents the consequence for a different field
(`repository_health`): *"`repository_health` lives in `state.json` only — TODO.md frontmatter
does not mirror it, because `generate-todo.sh` fully overwrites TODO.md on every run (no
read-modify-write of the existing file) and no consumer of a hand-authored TODO.md-frontmatter
debt/health YAML block exists anywhere under `agent-system/extensions/**`."* The vault-transition
comment is the same defect class as the thing 5.6.2 already rejected mirroring.

**2. Independently reproduced the frontmatter-corruption bug.** Given a 3-line frontmatter
(`---`, `next_project_number: 20`, `---`) and running the exact `skill-todo` sed:
```
sed -i "/^---$/,/^---$/{/^---$/{n;a\\
${transition_comment}
}}" test_todo.md
```
produced:
```
---
next_project_number: 20
<!-- Vault transition: 2026-08-10 - tasks numbered 1 through 1008 archived to specs/vault/02-vault/ -->
---

<!-- Vault transition: 2026-08-10 - tasks numbered 1 through 1008 archived to specs/vault/02-vault/ -->
# TODO
```
confirming the task's measured evidence exactly: the range `/^---$/,/^---$/` matches *both*
delimiters, so `a\` fires once after the line following the *opening* `---` (landing inside the
YAML block) and again after the *closing* `---` (the intended location), producing a duplicate.

**New finding beyond the task's measured evidence**: parsing the corrupted block with
`yaml.safe_load` does **not** raise an error — it silently succeeds and returns
`{'next_project_number': 20, '<!-- Vault transition': '2026-08-10 - ... -->'}`. The HTML comment
line contains a colon, so YAML parses it as a second top-level key rather than failing loudly.
This is worse than a parse error: a strict consumer that reads `next_project_number` would still
get the right value and never notice the document is malformed, while any consumer that
iterates all top-level keys (or validates the schema) would see a bogus key with no defined
meaning. This strengthens the case against any hand-insertion approach — the failure mode is
silent corruption, not a loud crash.

**3. The task-range arithmetic is confirmed wrong, and a related — separately scoped — defect
was found while verifying it.** `skill-todo/SKILL.md`'s vault stage computes both the discarded
`transition_comment` text *and* a `task_range` field that gets written into `.vault_history[]`
using the identical formula `$((next_num - renumber_count - 1))`. The `commands/todo.md` version
of the same stage (Step 5.8.8, to become 5.7.8) does **not** include a `task_range` field in its
`vault_history` write — it writes only `{vault_number, vault_dir, created_at}`. The real
`specs/state.json` produced by the actual vault run that exposed this task matches the
`commands/todo.md` shape exactly (no `task_range`, `archived_count`, or `final_task_number` in
`.vault_history[0]` — see Findings -> "Live state" below), meaning the two live documents already
disagree on the `.vault_history[]` schema, independent of the transition-comment defect. This is
**out of scope for this task's resolution** (the task's acceptance criteria are about the
TODO.md comment, not the `vault_history` schema) but is flagged here so it is not silently lost:
a future task should reconcile the two documents' `vault_history` write shape and, if `task_range`
is kept, fix its formula. Do not fix it as part of this task's edit — it would expand the edit
surface beyond what was scoped and reviewed.

**4. Durable records already exist and are correctly populated**, confirming Option (a) loses no
information:
- `specs/state.json` `.vault_history[]` — currently `[{"vault_number": 1, "vault_dir":
  "specs/vault/01-vault/", "created_at": "2026-08-10T19:49:05Z"}]`.
- `specs/vault/01-vault/meta.json` — `{"vault_number": 1, "created_at": "...",
  "archived_count": 1431, "final_task_number": 1020}`.
- The git commit history already carries a human-visible, timestamped signal at the point of
  the operation: commit `842606729` is titled `todo: vault operation - archive to 01-vault,
  renumber 11 tasks`. This is an additional durable, at-a-glance signal beyond `vault_history`
  and `meta.json` that further weakens the "loses the at-a-glance signal" cost named for Option
  (a) in the task prompt — the signal already exists in git log, just not inside TODO.md itself.

**5. Numbering mismatch confirmed.** `commands/todo.md`:
```
778: ### 5.7. Vault Operation (when next_project_number > 1000)
...
782: **Step 5.8.1: Detect vault threshold**:
790: **Step 5.8.2: Identify tasks to renumber**:
806: **Step 5.8.3: User confirmation**:
823: **Step 5.8.4: Create vault directory**:
836: **Step 5.8.5: Create vault meta.json**:
854: **Step 5.8.6: Reinitialize archive**...
862: **Step 5.8.7: Renumber tasks > 1000**:
871: **Step 5.8.8: Reset state**:
893: **Step 5.8.9: Add transition comment to TODO.md**:
```
No other file in the source store cross-references the substep numbers directly except the
quarantined `deprecated/vault-operation.sh` (which mirrors the same `5.8.x` comments internally)
and `deprecated/README.md:43`, which references only the *heading* number ("Step 5.7") and is
therefore unaffected by renumbering the substeps.

**6. `deprecated/vault-operation.sh` carries the exact Python variant of the same bug**, at the
line the task named (comment insertion around line 242), using a Python script guarded by
`2>/dev/null || true` — i.e. it fails silently rather than corrupting on error, but the read
starting after the `---` search still assumes it can locate a stable insertion point in a file
that no longer has any live caller (the script is already superseded per its own
`deprecated/README.md` entry: *"Superseded by the inline threshold check in `commands/todo.md`
Step 5.7."*). It is quarantined under `scripts/deprecated/` and not invoked from any live
skill or command path (grep confirms zero live-tree references to
`scripts/deprecated/vault-operation.sh`).

**7. Live `specs/state.json` and `specs/TODO.md`, checked directly.** `specs/TODO.md`'s current
frontmatter (`next_project_number: 22`) parses cleanly under `yaml.safe_load` with no stray
keys — i.e. the file is presently *not* corrupted, because the most recent regeneration
(`generate-todo.sh`, full overwrite) already erased whatever comment a prior vault run inserted,
independently confirming Finding 1 in the running repository, not just in a synthetic
reproduction.

### External Resources

Not applicable — this is a pure codebase-consistency task with no external dependency.

### Recommendations

**Decision: Option (a).** Delete the transition-comment insertion entirely from both live sites;
rely on `.vault_history[]` + `meta.json` (already durable, already correct) plus the existing
git-commit-message signal. This is chosen over (b) and (c) as follows:

- **(b) rejected.** Rendering the line from `.vault_history` inside `generate-todo.sh` would
  restore a user-visible signal, but it contradicts the specific precedent this repo already
  established at Step 5.6.2 for the structurally identical `repository_health` case — that
  precedent's stated reason ("no consumer of a hand-authored TODO.md-frontmatter ... block
  exists") is exactly as true for vault-transition info as it is for repository_health. Adding a
  second, inconsistent exception (health stays out, vault-transition goes in) with no
  distinguishing rationale would be an unforced divergence from a rule this repo just wrote down
  for a sibling field. It also adds a new rendering branch and test surface for a signal that
  already exists in git log and in two other durable files.
- **(c) rejected, explicitly considered.** Making `generate-todo.sh` preserve hand-authored
  content across regeneration would reintroduce read-modify-write, directly contradicting the
  script's documented atomic mktemp+mv, full-overwrite design (stated in its own header comment)
  and the very design property Step 5.6.2 relies on to justify keeping `repository_health` out
  of TODO.md. Rejected without further exploration.
- **(a) chosen.** Matches the previously recorded decision in the `653_...` archived summary
  (removing the mechanism, keeping the info in `vault_history`), matches the already-accepted
  `repository_health` precedent at 5.6.2, costs zero new code, and the "loses the at-a-glance
  signal" concern named in the task prompt is mitigated by the existing git-commit-message
  signal (Finding 4) that this investigation surfaced.

**Concrete edits (for the implementation phase):**

1. `agent-system/extensions/core/commands/todo.md`:
   - Delete the `**Step 5.8.9: Add transition comment to TODO.md**` block (lines 893-898)
     entirely — its 3-line body never did anything (it is dead code even today: two shell
     variable assignments and a comment, with no insertion command at all; the *executable*
     corrupting version lives only in `skill-todo/SKILL.md`, not here). No replacement text is
     needed, but a one-line rationale note in the style of 5.6.2 ("vault transition info lives in
     `.vault_history[]`/`meta.json` only; TODO.md is fully regenerated and cannot preserve
     hand-authored content — see Step 5.6.2 for the identical rationale") is recommended so a
     future reader does not reintroduce it a third time.
   - Renumber `**Step 5.8.1**`–`**Step 5.8.8**` to `**Step 5.7.1**`–`**Step 5.7.8**` (8 substeps
     remain under the `### 5.7. Vault Operation` heading after step 9's deletion), resolving the
     heading/substep mismatch named in the task's "ALSO IN SCOPE" section.
2. `agent-system/extensions/core/skills/skill-todo/SKILL.md`:
   - Delete the `Add vault transition comment to TODO.md` bash block (the `current_date=...`
     through the closing `sed -i ...` command, roughly lines 876-890) — this is the block that
     actually executes and corrupts, per Finding 2.
   - Update the trailing prose "After sub-step 9.4 completes, continue to Stage 11
     (UpdateRoadmap)" — check whether "sub-step 9.4" is the label for the block being deleted or
     a sibling; if the deleted block was itself sub-step 9.4, renumber/relabel accordingly so the
     "continue to Stage 11" instruction still points at a real, present sub-step. (This report
     did not fully trace the `9.1`-`9.4` sub-step labeling scheme inside `skill-todo/SKILL.md`
     beyond confirming the vault_history write and the transition-comment write are adjacent
     inside whichever sub-step is currently last; the implementer should re-verify the exact
     sub-step boundary before editing so the "continue to Stage 11" cross-reference stays
     accurate.)
3. No change to `agent-system/extensions/core/scripts/deprecated/vault-operation.sh` (see Scope
   Decisions).
4. No change to any `.opencode/**` file in this task (see Scope Decisions).

**Post-fix survivor accounting.** Grepping the full repository for the literal string `"Vault
transition"` today (before the fix) returns these files:
```
agent-system/extensions/core/commands/todo.md                (live — target of edit 1, will drop to 0)
agent-system/extensions/core/skills/skill-todo/SKILL.md       (live — target of edit 2, will drop to 0)
agent-system/extensions/core/scripts/deprecated/vault-operation.sh  (quarantined — scope decision: untouched)
.claude/commands/todo.md                                       (deployed copy of edit-1 target; regenerated on next deploy)
.claude/skills/skill-todo/SKILL.md                              (deployed copy of edit-2 target; regenerated on next deploy)
.opencode/commands/todo.md                                     (scope decision: deferred, see below)
.opencode/scripts/vault-operation.sh                            (scope decision: deferred, see below)
.opencode/extensions/core/commands/todo.md                     (scope decision: deferred, see below)
.opencode/extensions/core/skills/skill-todo/SKILL.md            (scope decision: deferred, see below)
.opencode/skills/skill-todo/SKILL.md                            (scope decision: deferred, see below)
specs/TODO.md                                                   (this task's own description text — a false positive, not a code/prose instruction site)
specs/vault/01-vault/archive/653_.../summaries/01_task-creation-migration-summary.md  (archived historical record — must not be edited, it documents what happened)
specs/vault/01-vault/archive/653_.../reports/01_pipeline-audit.md                     (archived historical record — must not be edited)
specs/vault/01-vault/archive/248_.../summaries/01_vault-archival-summary.md           (archived historical record — must not be edited)
specs/vault/01-vault/archive/248_.../reports/02_vault-renumbering-research.md         (archived historical record — must not be edited)
specs/vault/01-vault/archive/248_.../plans/01_vault-archival-plan.md                  (archived historical record — must not be edited)
```
**After the fix**, grepping the non-deprecated, non-`.opencode` source store (i.e.
`agent-system/extensions/**` excluding `scripts/deprecated/**`) for the literal string should
return **0** occurrences. The `.claude/**` deployed copies are not part of the source store (per
`source-store-deploy-boundary.md`) and will self-correct on the next deploy/reload once the
source-store edit lands — they are not separate survivors to fix by hand. `specs/**` archived and
current files are correctly excluded by the deliverable-rule's `specs/**` exemption and by the
principle that historical archives are not edited retroactively; `specs/TODO.md`'s hit is this
task's own live description text, which will itself be archived/regenerated once the task
completes and is not a second instance of the defect.

## Decisions

- **Resolution: Option (a)** — delete the hand-insertion instruction from both live sites; no
  new rendering machinery is added to `generate-todo.sh`. Reasoning: matches the prior recorded
  decision, matches the accepted 5.6.2 precedent for a structurally identical field, and the
  claimed cost (lost at-a-glance signal) is mitigated by the pre-existing git-commit-message
  signal found during this investigation. This is NOT a silent second divergence from the prior
  decision — it is a direct re-affirmation of it, correcting the gap where the prose instruction
  was left behind after the script was removed.
- **Numbering**: `commands/todo.md`'s `### 5.7. Vault Operation` heading and its substeps are
  reconciled to `5.7.1`–`5.7.8` (was `5.8.1`–`5.8.9`, with `5.8.9` deleted as part of the same
  edit).
- **Scope decision — deprecated script**: `scripts/deprecated/vault-operation.sh` is confirmed to
  have zero live callers and stays untouched. Its internal `5.8.x` step-comment labels will now
  be stale relative to the live doc's renumbered `5.7.x` labels; this is an accepted,
  pre-existing property of quarantined/deprecated code and is not a defect to fix under this
  task.
- **Scope decision — `.opencode/**`**: deferred, not edited by this task. Justification: (1) the
  task description states `.opencode/` "has no agent-system source and is separately tracked" and
  that "separate work already covers opencode drift"; (2) this investigation found direct
  corroboration — `specs/TODO.md`'s own current task list (a sibling entry on "Fix opencode
  agent-fragment path resolution and validator fail-fast") states explicitly that "`.opencode/`
  is NOT currently in use, though the user intends to return to it," and that same entry's
  SOURCE-STORE RULE independently names `.opencode/**` (alongside `.claude/**`) as a "disposable
  deploy artifact," confirming `.opencode/**` is not itself a source tree to hand-edit; (3)
  editing five files here would duplicate effort against, and could conflict with, whatever path
  convention that separately-tracked opencode work settles on. All five `.opencode/**` copies of
  the broken instruction are recorded above (in "Post-fix survivor accounting") specifically so
  they are not silently forgotten — a follow-up task (or the existing opencode-drift work) should
  apply the same fix there once that work's path/sync conventions are settled.
- **Explicitly out of scope, flagged for a future task**: the `task_range`/`archived_count`/
  `final_task_number` field divergence between `commands/todo.md`'s and `skill-todo/SKILL.md`'s
  `.vault_history[]` write shape (Finding 3). Fixing it would expand this task's edit surface
  beyond the transition-comment defect and its adjacent numbering fix.

## Risks & Mitigations

- **Risk**: renumbering `5.8.x` -> `5.7.x` substeps could silently break some other cross-reference
  not caught by the grep in this report. **Mitigation**: the grep for `Step 5\.7\.|Step 5\.8\.`
  across `agent-system/extensions/core/` found only the two files documented above; the
  implementer should re-run the same grep after editing to confirm no dangling `5.8.x` references
  remain outside the intentionally-untouched `deprecated/` tree.
- **Risk**: deleting the `skill-todo/SKILL.md` block without correctly identifying the "sub-step
  9.4" boundary could leave the "continue to Stage 11" cross-reference pointing at the wrong
  place. **Mitigation**: flagged explicitly above for the implementer to re-verify against the
  live file at edit time (this report locates the block but does not fully trace the `9.1`-`9.4`
  labeling scheme).
- **Risk**: a future contributor reintroduces the same instruction a third time (this is
  literally what happened between the `653_...` decision and this task). **Mitigation**:
  recommended the same explicit anti-mirroring rationale note style used at Step 5.6.2, so the
  "why not" is visible at the point future edits would be made, not just in an archived summary
  that a new contributor is unlikely to consult.

## Context Extension Recommendations

- **Topic**: `vault_history` schema consistency between `commands/todo.md` and
  `skill-todo/SKILL.md`.
- **Gap**: the two live documents currently specify different field sets for the same
  `.vault_history[]` array entry (one includes `task_range`/`archived_count`/`final_task_number`
  with a buggy formula, the other includes only `vault_number`/`vault_dir`/`created_at`, matching
  what was actually written to `specs/state.json` in practice). No context file currently
  documents the intended canonical schema for a `vault_history` entry.
- **Recommendation**: a follow-up meta task should reconcile the two documents to a single
  agreed `vault_history` entry schema (recommend the simpler, already-matching-live-behavior
  `commands/todo.md` shape, dropping the redundant/buggy fields that `meta.json` already covers)
  and, if any computed count is kept, fix the `$((next_num - renumber_count - 1))` formula.

## Appendix

### Search queries / verification commands used

- `grep -n "TODO_FILE" agent-system/extensions/core/scripts/generate-todo.sh` — confirmed
  write-only usage.
- `sed -n '860,910p' agent-system/extensions/core/commands/todo.md` and
  `sed -n '850,900p' agent-system/extensions/core/skills/skill-todo/SKILL.md` — located both live
  sites verbatim.
- `grep -n "5.6.2\|repository_health\|not mirrored" commands/todo.md` — located the precedent.
- `grep -n "^### 5\.\|^\*\*Step 5\." commands/todo.md` — confirmed the heading/substep mismatch.
- Independent shell reproduction of the exact `skill-todo` sed against a synthetic 3-line
  frontmatter fixture, followed by a Python `yaml.safe_load` parse of the result (see Findings 2).
- `jq '.vault_history' specs/state.json` and `cat specs/vault/01-vault/meta.json` — confirmed the
  durable records are present and correctly populated for the real vault run.
- `python3` regex + `yaml.safe_load` against the live `specs/TODO.md` frontmatter — confirmed it
  currently parses cleanly (post-regeneration).
- `grep -rn "Vault transition"` across the whole repository — produced the full survivor list
  used in "Post-fix survivor accounting."
- `git log --oneline --all | grep -i vault` — surfaced the `842606729` commit message as an
  existing durable, human-visible signal.
- `grep -n "Step 5\.7\|Step 5\.8\|5\.7\. Vault\|5\.8\.9"` across
  `agent-system/extensions/core/` — confirmed no other live cross-references to the substep
  numbers besides the two edit targets and the (out-of-scope) deprecated tree.

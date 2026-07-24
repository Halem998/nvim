# Research Report: Task #877

**Task**: 877 - Settle the plan-level status marker vocabulary (script vs spec)
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: ~2 hours (research only)
**Dependencies**: None
**Sources/Inputs**: Codebase (scripts, format docs, rules, skill files), git history/blame
**Artifacts**: reports/01_settle-plan-status-vocabulary.md (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The divergence is real and precisely as described: `update-plan-status.sh` (lines 21-27)
  accepts `{IMPLEMENTING, COMPLETED, PARTIAL, NOT_STARTED}`; `plan-format.md` (line 6) documents
  `{NOT STARTED, IN PROGRESS, BLOCKED, ABANDONED, COMPLETED}`. Overlap is exactly 2 of 5, matching
  the task's verified evidence.
- Git history shows *why*: the plan-level Status line in `plan-format.md` predates
  `update-plan-status.sh` by several commits (that doc line traces back to the `task 9` line of
  history; the script was created later, in the `task 104` line of history, and reused the
  task-level vocabulary from `status-markers.md` without reconciling the older doc).
- Live evidence corroborates that `[IN PROGRESS]` was never a real plan-level value: `grep` across
  every `specs/*/plans/*.md` in this repository shows the plan-level `- **Status**:` field has only
  ever taken the values `COMPLETED` (27) and `NOT STARTED` (5) — never `IN PROGRESS`, `IMPLEMENTING`,
  or `PARTIAL`. The literal string `[IN PROGRESS]` is written by exactly one script in this
  codebase, `update-phase-status.sh`, and only at the **phase** heading level, never at the plan
  top-level field. This confirms `[IN PROGRESS]` at plan level was copied from the phase-level
  vocabulary (or from a generic template) and never actually implemented as a plan-level write
  target.
- **Recommendation: resolution (b).** Extend `plan-format.md`'s plan-level vocabulary to
  `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}` — i.e., adopt the
  already-written `IMPLEMENTING`/`PARTIAL` verbs (lexically aligned with the task-level vocabulary
  in `status-markers.md`, which TODO.md/state.json already show) rather than rewriting the script
  to produce the never-implemented `IN PROGRESS`. `update-plan-status.sh`'s accept-set should be
  widened (case statement only; still "no new scripts") to also accept `BLOCKED` and `ABANDONED`
  so the accept-set is a superset match of the documented vocabulary; wiring new call sites that
  actually invoke it with those two values is left to the dependent hardening task, per the
  task's explicit out-of-scope note.
- **Phase-level vs plan-level asymmetry is intentional, not a bug**, and should be documented as
  such rather than unified: phase-level admits `PARTIAL` (a sub-unit can stall mid-execution) but
  not `ABANDONED` (abandonment is a whole-task/whole-plan decision, never a per-phase one — no
  script, skill, or command in this codebase ever marks an individual phase abandoned; abandoning
  the surrounding task is the only mechanism). Plan-level, after adopting (b), admits both
  `PARTIAL` and `ABANDONED` because the plan level spans the full lifecycle a phase does not: it
  can stall (`PARTIAL`, mid-implementation) or die entirely (`ABANDONED`, via `/task --abandon`,
  independent of how many phases were finished).

## Context & Scope

Scope was the vocabulary divergence between the plan-level `- **Status**:` field (top-of-file
metadata, one line) and the phase-level `### Phase N: {name} [STATUS]` heading marker (one per
phase). Both live inside the same plan `.md` files but are governed by different scripts and
different documentation sections. Per the task's explicit boundary, this research does not
address the fail-silent behavior of `update-plan-status.sh`'s callers, plan-file selection
(`ls -t ... | head -1`), or the phase-auto-advance logic in `update-task-status.sh` — those are
left for the dependent status-script-hardening task.

Files verified against the live repository (all line numbers below are current, re-checked
during this research, not merely quoted from the task description):

| File | Role |
|------|------|
| `.claude/scripts/update-plan-status.sh` | Writes the plan-level `- **Status**:` field |
| `.claude/scripts/update-phase-status.sh` | Writes individual `### Phase N: ... [STATUS]` headings |
| `.claude/scripts/update-task-status.sh` | Calls both of the above from `/implement` preflight/postflight |
| `.claude/context/formats/plan-format.md` | Documents plan-level Status vocabulary (line 6) and phase heading requirements |
| `.claude/context/standards/status-markers.md` | Documents task-level (TODO.md/state.json) vocabulary — the file the task description called `formats/status-markers.md`; it actually lives under `context/standards/`, not `context/formats/` (see Appendix note) |
| `.claude/rules/plan-format-enforcement.md` | Phase-heading checklist, restates valid phase markers |
| `.claude/rules/artifact-formats.md` | Restates phase-level marker list (lines 83-90) |
| `.claude/skills/skill-implementer/SKILL.md` | The one caller that explicitly writes `PARTIAL` to plan-level Status on interruption |

## Findings

### Codebase Patterns

**1. Script accept-sets, verified line-by-line:**

`update-plan-status.sh:21-27`:
```bash
case "$new_status" in
    IMPLEMENTING|implementing) new_status="IMPLEMENTING" ;;
    COMPLETED|completed) new_status="COMPLETED" ;;
    PARTIAL|partial) new_status="PARTIAL" ;;
    NOT_STARTED|not_started) new_status="NOT STARTED" ;;
    *) echo "Unknown status: $new_status" >&2; exit 1 ;;
esac
```
Accept-set: `{IMPLEMENTING, COMPLETED, PARTIAL, NOT STARTED}`. Confirmed matches the task's
verified evidence exactly.

`update-phase-status.sh:26-41` (the sibling script, for comparison): accept-set
`{IN_PROGRESS, NOT_STARTED, COMPLETED, PARTIAL, BLOCKED}` — this one is **already fully
consistent** with its own documentation (`plan-format-enforcement.md:13` and
`artifact-formats.md:83-90` both list exactly the same 5 markers for phase headings). The
phase-level script/doc pair has no divergence; only the plan-level pair does.

**2. Documented vocabularies, verified line-by-line:**

`plan-format.md:6`:
```
Use a single **Status** field with status markers (`[NOT STARTED]`, `[IN PROGRESS]`,
`[BLOCKED]`, `[ABANDONED]`, `[COMPLETED]`) per status-markers.md.
```
Documented plan-level set: `{NOT STARTED, IN PROGRESS, BLOCKED, ABANDONED, COMPLETED}`. Confirmed
matches the task's verified evidence exactly.

`plan-format-enforcement.md:13` and `artifact-formats.md:83-90` (phase-level, both consistent
with each other and with `update-phase-status.sh`):
`{NOT STARTED, IN PROGRESS, COMPLETED, PARTIAL, BLOCKED}` — 5 markers, no `ABANDONED`.

`status-markers.md` (task-level, `context/standards/status-markers.md`; the file the task
description labeled `formats/status-markers.md` does not exist — see Appendix): documents 12
task-level markers including `IMPLEMENTING`, `PARTIAL`, `BLOCKED`, `ABANDONED`, `NOT STARTED`,
`COMPLETED` — i.e., every plan-level marker this report recommends is already a task-level
marker with an identical spelling in this file. The plan-level vocabulary this report recommends
is a strict subset of the already-canonical task-level set.

**3. Only one call site ever produces the literal string `[IN PROGRESS]`, and it is not the
plan-level field:**

```
update-task-status.sh:249:  echo "[dry-run] Phase status: first [NOT STARTED] phase -> [IN PROGRESS] ..."
update-phase-status.sh:28:  new_status_display="IN PROGRESS" ;;
```

No script, skill, or command anywhere in `.claude/` writes `[IN PROGRESS]` to a plan's top-level
`- **Status**:` field. This is a strong signal that `plan-format.md:6`'s inclusion of
`[IN PROGRESS]` at plan level was either a copy from the phase-level vocabulary or aspirational
documentation that was never implemented, rather than a deliberate design choice later abandoned
by the script.

**4. Git history corroborates the "doc predates script" theory:**

- `plan-format.md`'s Status-field line (`... [IN PROGRESS] ... per status-markers.md`) already
  existed at the commit that introduced `copy-claude-directory.md` (an early, unrelated
  documentation commit), i.e., long before the plan-status script existed.
- `update-plan-status.sh` was created later by the commit
  `b835b815d "task 104 phase 1: create centralized plan status script"`, which introduced the
  script with its current `IMPLEMENTING/COMPLETED/PARTIAL/NOT_STARTED` accept-set from day one —
  evidently modeled on the task-level vocabulary in `status-markers.md` rather than on the
  older, unreconciled `plan-format.md` line.

No commit was found that reconciled the two afterward, so the divergence has persisted since
task 104 introduced the script.

**5. Live plan files on disk never show the disputed values, and never show `PARTIAL` either —
suggesting the wiring is not just undocumented but may already be silently failing (out of
scope, but relevant context):**

```
$ grep -h '^\- \*\*Status\*\*: \[' specs/*/plans/*.md | sed 's/.*\[\(.*\)\].*/\1/' | sort | uniq -c
     27 COMPLETED
      5 NOT STARTED
```

Across all 32 plan files with a top-level Status field currently in the repository, none show
`IN PROGRESS`, `IMPLEMENTING`, or `PARTIAL` — despite `update-task-status.sh` nominally invoking
`update-plan-status.sh IMPLEMENTING` at every `/implement` preflight, and
`skill-implementer/SKILL.md:572-575` nominally invoking it with `PARTIAL` on every interrupted
implementation. This is consistent with (but does not prove) the fail-silent behavior this task
explicitly defers to the dependent hardening task — `update-task-status.sh:256` calls the plan
script with `2>/dev/null || { warning-only }`, so a failure (e.g. from the plan-file-selection
`ls -t | head -1` picking the wrong file, or an idempotency short-circuit) would never surface.
This report does not attempt to diagnose or fix that; it is noted only as corroborating evidence
that the plan-level vocabulary has effectively never been exercised end-to-end, which lowers the
migration risk of resolution (b) — there is no accumulated corpus of `[IN PROGRESS]`-tagged plan
files that a vocabulary change would strand.

**6. `skill-implementer/SKILL.md:557-575` documents an explicit, deliberate design split between
task-level and plan-level status on interruption:**

```
**If status is "partial"**:
Keep status as "implementing" but update resume point. ...
TODO.md stays as `[IMPLEMENTING]`.
**Update plan file** (if exists): Update the Status field to `[PARTIAL]`:
    .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "PARTIAL"
```

This is a considered design, not an accident: the task-level marker (`TODO.md`/`state.json`)
intentionally stays at the coarser `[IMPLEMENTING]` across an interruption (the task as a whole is
still "being implemented" until it either completes or is explicitly abandoned), while the
plan-level marker is meant to carry the finer-grained "this specific plan document stalled and is
resumable" signal via `[PARTIAL]`. This is direct evidence that `PARTIAL` is not an accidental
plan-level write — it is the one piece of the intended design that the documentation simply never
caught up with.

### External Resources

Not applicable — this is a closed, self-contained internal-tooling question; no external
documentation or library informs the resolution.

### Recommendations

**Adopt resolution (b): extend the plan-level spec, do not rewrite the script to the
never-implemented `IN PROGRESS`.**

Target plan-level vocabulary (replaces `plan-format.md:6`'s current list):

| Marker | Currently accepted by script? | Currently documented? | Action |
|--------|-------------------------------|------------------------|--------|
| `[NOT STARTED]` | Yes | Yes | No change |
| `[IMPLEMENTING]` | Yes | **No** | Add to `plan-format.md:6` |
| `[PARTIAL]` | Yes | **No** | Add to `plan-format.md:6` |
| `[COMPLETED]` | Yes | Yes | No change |
| `[BLOCKED]` | **No** | Yes | Add to `update-plan-status.sh` case statement |
| `[ABANDONED]` | **No** | Yes | Add to `update-plan-status.sh` case statement |
| `[IN PROGRESS]` | No | Yes (to be removed) | Remove from `plan-format.md:6` — superseded by `[IMPLEMENTING]`, never a real write target |

Rationale for choosing (b) over (a):

1. **Lexical alignment with the task-level vocabulary the user already sees.** `status-markers.md`
   (the single source of truth for TODO.md/state.json) uses `IMPLEMENTING`/`PARTIAL` for exactly
   this concept. A user who sees `TODO.md: [IMPLEMENTING]` and opens the plan file would see
   `[IN PROGRESS]` under resolution (a) — two different words for the identical lifecycle stage,
   which is the confusion the task description itself flagged as (a)'s cost.
2. **The script is already the "real" implementation and has two live call sites** (preflight in
   `update-task-status.sh`, and the explicit `PARTIAL` write in `skill-implementer/SKILL.md`).
   Rewriting it to emit `IN PROGRESS` would touch working code paths to chase documentation that
   was never implemented, where extending the documentation touches only prose.
3. **No accumulated data to strand.** Section 5 above shows zero plan files currently carry
   `[IN PROGRESS]`, `[IMPLEMENTING]`, or `[PARTIAL]` — there is no migration cost either way, so
   the tie-breaker is which choice best serves future readers, and that is lexical consistency
   with the already-canonical task-level vocabulary.
4. **No collision with phase-level semantics.** Phase headings are a structurally distinct field
   (`### Phase N: ... [STATUS]` vs. the top `- **Status**:` line) with their own script
   (`update-phase-status.sh`) and their own, already-self-consistent vocabulary. Introducing
   `IMPLEMENTING`/`PARTIAL`/`BLOCKED`/`ABANDONED` at the plan level does not require touching
   `update-phase-status.sh` or its 5-marker phase vocabulary at all.

**Widening `update-plan-status.sh`'s accept-set to include `BLOCKED` and `ABANDONED`** is
recommended as part of settling the vocabulary (it is an edit to an existing script, not a new
one, honoring the no-new-scripts constraint) so the script's accept-set is a superset match for
the full documented plan-level vocabulary. Actually wiring new call sites that invoke the script
with those two values (e.g., having `/task --abandon` also stamp the plan file) is explicitly
deferred to the dependent status-script-hardening task per this task's own scope boundary — this
task settles what the vocabulary *is*, not which commands exercise every value of it.

### Plan-level vs. phase-level asymmetry: intentional, keep as-is, document the rationale

The task asked whether the asymmetry (plan-level has `ABANDONED` but historically lacked
`PARTIAL`; phase-level has `PARTIAL` but lacks `ABANDONED`) is intentional or should be unified.
Finding: **it is intentional and should not be unified toward symmetry** — but it should be
written down explicitly, because right now the asymmetry exists only implicitly (nothing states
the reasoning, which is exactly why the task treated it as suspicious).

- **Why phase-level has no `ABANDONED`**: abandonment is a whole-task decision made via
  `/task --abandon`, which updates `state.json`/`TODO.md` (task-level) only — it was not found to
  touch any per-phase heading. There is no command, script, or skill anywhere in `.claude/` that
  marks a single phase abandoned while leaving sibling phases active; the only way a phase stops
  being worked on permanently is that the whole task (and hence the whole plan) is abandoned. A
  phase that is deliberately never going to be done is handled by a different, already-existing
  mechanism (re-planning/`/revise`, or in `--hard` mode the "Planned Strategic Sorries" deferral
  table in `plan-format.md`), not by a phase-level `ABANDONED` marker. Adding one would create a
  second, redundant way to express "this part is dead" with no writer that would ever produce it
  — repeating exactly the `[IN PROGRESS]`-at-plan-level mistake this task is fixing.
- **Why plan-level should have `PARTIAL` (the fix in this report) but phase-level's `PARTIAL`
  remains distinct in meaning**: at the phase level, `PARTIAL` marks one specific phase as
  interrupted mid-execution. At the plan level (after adopting resolution (b)), `PARTIAL` marks
  the *document as a whole* as stalled/resumable — the aggregate signal that "this plan is not
  finished and not abandoned; the next `/implement` should pick it up." These are different
  grains of the same underlying concept (interrupted-but-resumable), not a collision: a plan can
  be plan-level `[PARTIAL]` while having phase 1 `[COMPLETED]`, phase 2 `[PARTIAL]`, and phase 3
  `[NOT STARTED]` — the plan-level marker aggregates, it does not duplicate, the phase-level ones.

Recommended documentation change to make this explicit (for the implementer to place in
`plan-format.md`, near the Status Marker Requirements section, and/or in `status-markers.md`):
a short note stating that `ABANDONED` is deliberately plan/task-level only (no phase-level
equivalent exists because abandonment always terminates the whole plan, never a single phase),
and that plan-level `PARTIAL` is an aggregate "this document is stalled" signal distinct from,
and compatible with, any individual phase already carrying its own `[PARTIAL]`.

## Decisions

- **Resolution chosen: (b)** — extend `plan-format.md`'s plan-level Status vocabulary to
  `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`, dropping the
  never-implemented `IN PROGRESS` in favor of `IMPLEMENTING` (matching `status-markers.md`'s
  task-level term for the identical concept).
- **`update-plan-status.sh`'s case statement (lines 21-27) should be widened** to also accept
  `BLOCKED` and `ABANDONED` (in addition to its current four), so the script's accept-set matches
  the full documented vocabulary. This is an edit to the existing script, not a new script.
- **Phase-level vocabulary is left untouched** — `{NOT STARTED, IN PROGRESS, PARTIAL, BLOCKED,
  COMPLETED}` stays exactly as documented in `plan-format-enforcement.md` and `artifact-formats.md`
  and exactly as `update-phase-status.sh` already accepts it. No changes needed there; it was
  already internally consistent.
- **The plan-level/phase-level asymmetry (ABANDONED only at plan level, PARTIAL at both but with
  different grain) is intentional and should be documented as such**, not unified toward a single
  shared vocabulary across both levels.
- Wiring new call sites that actually produce `BLOCKED`/`ABANDONED` at the plan level (e.g.,
  `/task --abandon` stamping the plan file) is explicitly deferred to the dependent
  status-script-hardening task, as is any fix to the fail-silent behavior noted in Finding 5.

## Risks & Mitigations

- **Risk**: Someone treats `[IN PROGRESS]` at plan level as intentional prior art and resists its
  removal. **Mitigation**: Finding 3/4/5 above (no writer ever produced it; zero live plan files
  carry it; the doc line predates the script by multiple commits) is decisive, reproducible
  evidence it was never implemented — cite these greps in the implementation plan.
- **Risk**: Widening `update-plan-status.sh`'s accept-set to include `BLOCKED`/`ABANDONED` without
  any caller ever using them looks like dead code. **Mitigation**: note in the plan (and possibly
  a short script comment) that these two values complete the documented vocabulary ahead of the
  dependent hardening task that will wire real call sites; this is standard "spec-then-wire"
  sequencing, not dead code — the same pattern the script already follows for `NOT_STARTED` today
  (also never observed live, per Finding 5's disk survey, since a plan is only created already at
  `[NOT STARTED]` by the planner and the script is never invoked to *set* it).
- **Risk**: A future reader still finds the plan-level/phase-level asymmetry suspicious.
  **Mitigation**: this task's Decisions section above supplies a citable rationale; the
  implementer should transcribe it into `plan-format.md` per the "Recommended documentation
  change" note in Findings.

## Context Extension Recommendations

- **Topic**: Plan-level status vocabulary rationale.
  **Gap**: `plan-format.md` currently only lists the vocabulary; it has no note explaining why
  the plan-level and phase-level vocabularies differ (the asymmetry this task investigated).
  **Recommendation**: the implementer add a short "Why plan-level and phase-level markers differ"
  callout adjacent to the Status Marker Requirements section (see Findings above for the exact
  content to transcribe), so future contributors do not re-open this question from scratch.
- **Topic**: `status-markers.md` file location.
  **Gap**: the task description (and, by inheritance, presumably some other in-repo reference)
  cites `.claude/context/formats/status-markers.md`; the file actually lives at
  `.claude/context/standards/status-markers.md`. No file exists at the `formats/` path. This is a
  minor path-hygiene gap worth a one-line fix wherever it is cited, but is not part of this task's
  file_scope and is noted here only as a drive-by observation for the implementer to fix
  opportunistically if touching a citing file anyway.

## Appendix

### Search queries / commands used

```bash
grep -rn "update-plan-status.sh" .claude --include="*.md" --include="*.sh" -l
grep -h '^\- \*\*Status\*\*: \[' specs/*/plans/*.md | sed 's/.*\[\(.*\)\].*/\1/' | sort | uniq -c
grep -rn '"IN PROGRESS"\|\[IN PROGRESS\]' .claude/scripts/*.sh .claude/skills/*/SKILL.md
git log --oneline -- .claude/scripts/update-plan-status.sh
git log -p --follow -- .claude/context/formats/plan-format.md | grep -n "Status.*IN PROGRESS"
git show --stat b835b815d
```

### File/line references verified during this research

- `.claude/scripts/update-plan-status.sh:21-27` (accept-set)
- `.claude/scripts/update-phase-status.sh:26-41` (phase accept-set, for contrast)
- `.claude/scripts/update-task-status.sh:217-288` (`update_plan_file()`, the caller)
- `.claude/context/formats/plan-format.md:6` (plan-level documented vocabulary)
- `.claude/context/standards/status-markers.md:86-146` (task-level vocabulary, canonical source)
- `.claude/rules/plan-format-enforcement.md:13` (phase-level documented vocabulary)
- `.claude/rules/artifact-formats.md:83-90` (phase-level documented vocabulary, restated)
- `.claude/skills/skill-implementer/SKILL.md:557-575` (explicit task-level/plan-level split on
  interruption; the origin of the plan-level `PARTIAL` write)

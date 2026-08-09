# Research Report: Task #961

**Task**: 961 - Add staleness detection to the orchestrator loop-guard resume path
**Started**: 2026-08-06T00:00:00Z
**Completed**: 2026-08-06T00:00:00Z
**Effort**: medium (single skill file + one doc file, but a schema addition and a new test harness)
**Dependencies**: 960 (edits the same `skill-orchestrate-hard/SKILL.md`; established the sentinel-region + fixture-test pattern this report recommends reusing)
**Sources/Inputs**: Codebase (skill-orchestrate-hard/SKILL.md, skill-orchestrate/SKILL.md, orchestrator-runtime-files.md, task-lock.sh, reap-session-runtime-files.sh, handoff-schema.md, test-resume-scan-nonconformance.sh)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The Stage 2 resume branch of `skill-orchestrate-hard/SKILL.md` (lines 234-273) trusts any
  syntactically-valid `.orchestrator-loop-guard` unconditionally — no signal is consulted before
  its `cycle_count`, `burnout_signals_this_session`, and `infra_failures` are adopted.
- `session_id` is correctly disqualified as the signal (it is regenerated on every
  `/orchestrate` invocation by design, so gating on it would break the guard's whole purpose:
  surviving across conversational turns). Two candidate signals clear that same bar cleanly and,
  in combination, cover the two mechanisms actually observed in the live failure (an old
  `max_cycles` constant *and* a superseded plan lineage):
  1. **Schema/version drift**: the guard's persisted `max_cycles` differs from the skill's
     current `MAX_CYCLES=13` constant. Zero-configuration, zero false-positive risk (the constant
     never changes mid-task under one deployed skill version), and directly reproduces the "guard
     carried a `max_cycles` from an older skill version" half of the observed defect.
  2. **Plan-lineage drift**: the guard's persisted `plan_version` (a new field, snapshotting the
     latest `plans/*.md` basename at write time) differs from the currently-latest plan file. This
     directly reproduces the "guard referenced an early plan version while the live plan was many
     versions later" half of the observed defect, and reuses the exact
     `ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1` idiom Stage 3/4/5 already use
     three times over.
  3. **mtime age** (recommended as a bounded backstop only, generous default, e.g. 7 days) catches
     a guard that is stale by neither signal above but has simply sat untouched far longer than
     any observed legitimate resume gap. This is the only one of the three signals whose default
     threshold is a judgment call rather than a hard fact, and should be called out to the
     implementer as a value the plan should pick deliberately (with rationale), not inherit
     silently from this report.
- The "preserve the evidence" archive-aside shape already exists verbatim in this same file (the
  stray-handoff sweep, lines 864-884): `mv` to a timestamped name inside `$TASK_DIR`, loud
  `ERROR:`-prefixed named notice, never delete. The staleness fix should reuse this exact idiom
  (`.stale-loop-guard-$(date -u +%s).json`), not invent a new archival convention.
- `.orchestrator-churn-state.json` does **not** need an independent staleness signal of its own.
  Per `orchestrator-runtime-files.md`'s Class Table, its writer/reader/cleanup lifecycle is
  already 1:1 coupled to the loop guard's (co-created in the same Stage 2 block, co-removed only
  at full-loop termination). The recommendation is to have the loop guard's staleness verdict
  also govern the churn-state file — archive it aside under the same verdict, without deriving a
  second independent signal — and document that coupling as the reason it "does not need" its
  own detector, satisfying WORK item (4) by extension rather than duplication.
- Sibling task 960 (a direct dependency, editing the same file) already established a precedent
  for testing SKILL.md-embedded bash: wrap the pure-bash logic in a
  `# --- <sentinel-name>:begin ---` / `:end` comment region, then extract and execute that region
  against constructed fixtures from a companion `scripts/tests/test-*.sh` script (structural model:
  `test-resume-scan-nonconformance.sh`). This is the strongly recommended way to satisfy the
  verification bar's "test it explicitly" requirement — see Recommendations below for why a
  purely narrative/manual verification would be weaker than the precedent already sitting in this
  exact file.

## Context & Scope

Task 961 asks for four things: (1) decide and document a staleness signal in
`orchestrator-runtime-files.md`, explicitly defending it against the `session_id` objection; (2)
implement detection on Stage 2's resume path in `skill-orchestrate-hard/SKILL.md`; (3) on
detection, archive-aside-and-reinitialize (never silently trust, never silently reset); (4) decide
whether `.orchestrator-churn-state.json` needs the same treatment. File scope is declared as
exactly two files: `skill-orchestrate-hard/SKILL.md` and `context/standards/orchestrator-runtime-
files.md`. Research below flags one likely necessary scope extension (a test script) for the
planner to weigh explicitly rather than silently assume out of scope.

Base-mode `skill-orchestrate/SKILL.md` has the byte-for-byte identical unconditional-trust shape
in its own Stage 2 (lines 87-158) and is explicitly out of scope for this task (not in file_scope,
and the task description scopes the defect to "the Stage 2 resume branch of
`skills/skill-orchestrate-hard/SKILL.md`" specifically). This asymmetry is worth flagging in the
plan/summary so a reader does not assume base-mode was silently fixed too.

## Findings

### Codebase Patterns

**Current Stage 2 unconditional-trust structure** (`skill-orchestrate-hard/SKILL.md:234-273`):
```bash
if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
  infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
  echo "[hard-orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES ..."
else
  # fresh init via task-lock.sh init-marker (atomic mkdir-gate + tmp-mv payload)
  ...
fi
```
The guard's full persisted schema at init time is: `session_id`, `cycle_count`, `max_cycles`,
`current_state`, `hard_mode`, `burnout_signals_this_session`, `infra_failures`,
`max_infra_failures`, `started`, `last_updated`. There is **no `plan_version` field today** — it
would need to be added, both at the two init-write sites (fresh-init at line ~247-263, and the
lost-init-race fallback) and refreshed at the per-cycle update site (Stage 3b, line 324-330,
`current_state`/`last_updated`/`cycle_count`).

**Churn state's existing (non-gating) `session_id` pattern** (lines 276-296) is the exact
precedent for "observe and log, never gate":
```bash
churn_session_id=$(jq -r '.session_id // ""' "$churn_file")
if [ -n "$churn_session_id" ] && [ "$churn_session_id" != "$session_id" ]; then
  echo "[hard-orchestrate] INFO: churn state was last written by a different session_id (...) — expected on conversational resume, not gated."
fi
```
Base-mode `skill-orchestrate/SKILL.md` (lines 117-125) carries the identical pattern for the loop
guard's own `session_id` field. This is the annotated rationale the task description explicitly
forbids re-deriving for the loop-guard fix: `session_id` changes on *every single invocation by
design*, so any signal used here must not share that property. Both of the recommended signals
(constant-vs-persisted-constant, and plan-file-basename-vs-persisted-basename) are invariant across
ordinary same-session-or-different-session resumes and only change when something real happened
(a skill upgrade changing `MAX_CYCLES`, or a new plan artifact actually being written) — this is
the crisp distinguishing property to write into the doc.

**The archive-aside "preserve the evidence" precedent** (lines 864-884, stray-handoff sweep):
```bash
if [ -e "$stray" ]; then
  echo "[hard-orchestrate] ERROR: STRAY HANDOFF at $stray — a writer produced the handoff outside its task directory." >&2
  echo "[hard-orchestrate] The correct destination is $handoff_file." >&2
  mv "$stray" "${TASK_DIR}/.stray-handoff-$(date -u +%s).json" 2>/dev/null \
    && echo "[hard-orchestrate] Stray moved into ${TASK_DIR}/ for inspection." >&2 \
    || echo "[hard-orchestrate] WARNING: could not move stray aside; remove it manually before the next cycle." >&2
fi
```
This is the shape the task description points at ("following the same 'preserve the evidence'
shape the existing stray-handoff sweep already uses"). The new logic should mirror it exactly:
timestamped `mv` into `$TASK_DIR`, an `ERROR:`-prefixed named notice (`STALE LOOP GUARD`, matching
the existing `STALE HANDOFF` / `STRAY HANDOFF` naming convention used at line 859), a stated
destination path, and a non-fatal fallback warning if the `mv` itself fails.

**Existing mtime-based freshness precedent** (multiple sites) all use the same idiom:
`stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0`, e.g. the handoff
staleness check at `skill-orchestrate-hard/SKILL.md:856` and `reap-session-runtime-files.sh`'s
age-threshold reap (`ORCHESTRATOR_SESSION_REAP_MIN`, default 240 minutes / 4 hours). That reap
threshold is **not** a usable default for the loop guard: it exists to reap genuinely-abandoned
*batch* state after a bounded single-invocation window, whereas the loop guard's entire purpose is
surviving multi-day conversational gaps. A loop-guard mtime threshold needs to sit well above any
plausible legitimate resume gap (the observed defect was 13 days) — this report recommends framing
it explicitly as a backstop with a generous default (days, not hours) rather than the primary
signal, precisely to avoid the false-positive risk the verification bar calls out ("an ordinary
cross-conversational-turn resume is NOT falsely flagged... test it explicitly").

**Plan-version resolution already exists per-cycle**, just not at Stage 2. `plan_path=$(ls -1
"${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)` appears three times in this file (lines
497, 951, 1022/1120) for exactly this "latest plan version" purpose, always via `sort -V`
(version-sort) over the plan directory. Line ~1055-1058 explicitly handles the "no plans/
directory yet" case as normal (post-research, pre-plan), which the staleness check must also
tolerate — a guard written during `researching`/`planning` status (before any plan file exists)
must not be falsely flagged just because both sides of the comparison are empty.

**`.orchestrator-churn-state.json`'s lifecycle coupling to the loop guard**, per
`orchestrator-runtime-files.md`'s Class Table (rows 1-2): both are written in the same Stage 2
block, both have "Cleanup site: `rm -f` only at full-loop termination... alongside the loop guard"
— i.e., they are already documented as a paired lifecycle, not independent files that happen to
share a directory. This is the load-bearing fact behind the WORK item (4) recommendation below.

**The two-class ephemeral/durable split's actual axis** (`orchestrator-runtime-files.md`'s
"Rationale: the freshness-gate asymmetry" section, lines 73-99) is about protection against a
**git-restored stale copy** — both files are gitignored specifically because nothing would catch a
committed-then-restored copy being silently trusted. This is a *different axis* from the
operational staleness this task adds (a genuinely-present, never-git-touched file that is simply
old/superseded on disk). The doc update must not conflate the two: the ephemeral/gitignored
classification stays correct and unchanged (git-restoration is still a live, ungated hazard for
these files, and gitignore is still the right mitigation for it); what changes is that Stage 2's
read site gains a *second, orthogonal* freshness gate — an operational one — that has nothing to
do with git history. Overwriting the existing "no freshness check on read" sentences without this
distinction would make the doc internally inconsistent (a reader would reasonably ask "so is it
gated or not?").

### Precedent for Testing Embedded SKILL.md Bash Logic

Sibling task 960 (a direct dependency) added a `resume-scan-conformance-gate:begin` /
`:end` sentinel region to this exact file (lines 532, 554) specifically so a companion test
script, `scripts/tests/test-resume-scan-nonconformance.sh`, could extract the pure-bash region via
`awk` and execute it against constructed markdown fixtures in a subshell, asserting on stdout/
stderr and the region's own result variables. That test file documents its own scope limit
explicitly: "the enclosing markdown fences ... contain `Agent tool:` / `EXIT (...)` pseudo-syntax
and are NOT valid bash ... This suite extracts and executes only the sentinel-delimited ...
regions." Structural shape: `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` counters, exit
0/1/2 (all-pass / any-fail / environment-error), deploy-tree-first-then-source-store-fallback
library resolution, and a `bash -n` syntax-clean assertion run against every extracted region
before any behavioral fixture is exercised.

This is directly relevant to task 961's verification bar ("test it explicitly," "`bash -n`
clean"): the new staleness-detection logic is exactly the same shape of problem (pure-bash logic
embedded in a markdown Stage description) that task 960 already solved for the same file. Reusing
the sentinel + fixture-test pattern is the load-bearing recommendation of this report for
satisfying the verification bar credibly, rather than by narrative claim alone.

## Recommendations

### 1. Documentation decision for `orchestrator-runtime-files.md`

Record, in a new subsection near the existing "Rationale: the freshness-gate asymmetry" section
(not replacing it — extending it, since the git-restoration axis stays correct):

- **Chosen signals** (both must trip independently; either one alone is sufficient to declare
  staleness — an OR, not an AND, since either is independent evidence the guard predates the live
  line of work):
  1. `guard.max_cycles != $MAX_CYCLES` (schema/version drift).
  2. `guard.plan_version != current latest plans/*.md basename`, gated to only apply when *both*
     sides are non-empty (i.e., skip the check entirely if either the guard predates any plan, or
     the task has not reached `plans/` yet — this is the normal researching/planning-status case,
     not evidence of staleness).
  3. (Backstop) `now - guard mtime > ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` (a new env var,
     documented default TBD by the planner/implementer — recommend a value comfortably longer
     than any realistic multi-day conversational gap and comfortably shorter than the observed
     13-day defect; this report deliberately does not prescribe an exact number since no
     documented data exists on real resume-gap distributions in this repo, but note that
     `ORCHESTRATOR_SESSION_REAP_MIN=240min` (4h) is not a usable anchor — it protects an
     unrelated, much-shorter-lived class of file).
- **Explicit anti-`session_id` defense** (required by the task): state plainly that `session_id`
  is disqualified because it is regenerated on *every* `/orchestrate` invocation regardless of
  whether real work progressed, so gating on it would flag literally every legitimate
  conversational resume — a 100% false-positive rate by construction. Both chosen signals are
  invariant across ordinary resumes: `MAX_CYCLES` is a compile-time constant that only changes
  when the skill file itself is edited (a rare, meaningful event), and the latest-plan-basename
  only changes when a new plan artifact is actually written (via `/plan` or `/revise` — again rare
  and meaningful, not a per-invocation churn). Neither shares `session_id`'s "changes every
  single time, regardless of progress" property.
- **Preserve, do not overwrite, the ephemeral/gitignored classification's git-restoration
  rationale.** Add a clarifying sentence distinguishing the two axes (git-restoration protection
  vs. this new live operational staleness gate) so the doc stays internally consistent — see
  Findings above for the exact distinction to draw.
- **`.orchestrator-churn-state.json` treatment**: document that it inherits the loop guard's
  staleness verdict rather than deriving its own (see item 4 below), citing the existing Class
  Table rows that already document its 1:1 lifecycle coupling to the loop guard.
- Update the Class Table's `.orchestrator-loop-guard` row's "Reader" cell (currently
  "unconditional trust, see Rationale") to reflect the new conditional trust, and update the
  "Rationale" section's sentence "with no `session_id` comparison and no mtime/staleness check" —
  it becomes false for the loop guard once this fix lands (still true for base-mode
  `skill-orchestrate/SKILL.md`, which is unchanged by this task — the doc should say so explicitly
  to avoid implying base mode was silently fixed too).

### 2. Stage 2 implementation shape (`skill-orchestrate-hard/SKILL.md`)

Restructure the existing `if [ -f "$loop_guard_file" ] && jq empty ... ]; then ... else ... fi` to
insert a staleness check as the *first* thing done inside the `if` (present-and-valid) branch,
before any counter is adopted:

1. Compute the two live reference values *before* the `if`/`else` (cheap, `2>/dev/null`-safe even
   when `plans/` does not exist yet): `current_plan_version=$(basename "$(ls -1
   "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1 || echo none)" 2>/dev/null || echo
   none)`.
2. Inside the present-and-valid branch, read `guard_max_cycles`, `guard_plan_version` (new field,
   `// "none"` default for guards written before this fix — i.e., a guard missing the field is
   *not* itself evidence of staleness, only a genuine mismatch is), and the guard's own mtime.
   Build a `stale_reason` string from whichever check(s) trip (useful for the notice — name the
   signal, not just "stale").
3. If `stale_reason` is non-empty: emit the loud `ERROR: STALE LOOP GUARD` notice (naming the
   tripped signal(s) and both compared values), `mv` the guard to
   `${TASK_DIR}/.stale-loop-guard-$(date -u +%s).json`, `mv` the co-located churn-state file to
   `${TASK_DIR}/.stale-churn-state-$(date -u +%s).json` under the same verdict (see item 4), then
   fall through to the *same* fresh-init logic the `else` branch already runs (recommend
   factoring the `jq -n ... | task-lock.sh init-marker` payload into a small bash function defined
   inside this same fenced code block — not a new script file — so the payload is written once and
   reused by both the "no guard existed" and "guard existed but was stale" paths, rather than
   duplicated a third time).
4. Otherwise (no `stale_reason`): proceed exactly as today.
5. Add `plan_version` to both init-write sites' JSON payload (seeded with
   `current_plan_version`), and refresh it at the Stage 3b per-cycle update (line ~324-330) so a
   plan revision that happens *mid-run* (the same continuous execution, not a resume gap) never
   produces a false staleness verdict on the *next* resume — the guard's persisted `plan_version`
   should always reflect the plan version that specific run last observed.
6. Wrap the new logic in a `# --- loop-guard-staleness:begin ---` / `# --- loop-guard-
   staleness:end ---` sentinel pair (following task 960's exact naming convention for the
   `resume-scan-conformance-gate` region), so a companion test script can extract and execute it
   in isolation — see item 5 below.

### 3. Archive-aside notice wording

Match the existing `[hard-orchestrate] ERROR: STALE HANDOFF` / `STRAY HANDOFF` naming convention
precisely: `[hard-orchestrate] ERROR: STALE LOOP GUARD — <reason>. Archived to <path> for
inspection; reinitializing fresh guard at cycle 0.` followed by a second line naming the
co-archived churn-state path. This keeps the vocabulary of "named, loud, `ERROR:`-prefixed
notices" consistent across all three archive-aside sites in this file.

### 4. `.orchestrator-churn-state.json` treatment

Recommend: **extend the fix by inheritance, not duplication.** Do not derive an independent
staleness signal for churn-state (it has no `max_cycles`-equivalent constant to compare, and
adding a second, differently-derived plan-lineage check purely for this file would be needless
surface area). Instead, since the Class Table already documents churn-state's cleanup lifecycle as
coupled 1:1 to the loop guard's ("alongside the loop guard"), have the *same* staleness verdict
computed for the loop guard also govern churn-state: when the loop guard is judged stale, archive
the churn-state file aside too (same timestamp suffix convention,
`.stale-churn-state-$(date -u +%s).json`) and reinitialize it fresh alongside the guard. Document
this reasoning explicitly in `orchestrator-runtime-files.md` — it directly answers WORK item (4)
("either extend the fix to it or record why it does not need it") with a positive answer that
avoids duplicated detection logic.

### 5. Testing (verification-bar risk)

The verification bar requires: `bash -n` clean, an explicit regression test proving a stale guard
is archived+reinitialized correctly, and an explicit test proving an ordinary resume is *not*
falsely flagged. Given task 960 already solved the identical "test pure-bash logic embedded in
this SKILL.md" problem for the same file via a sentinel-region + fixture-test-script pattern
(`test-resume-scan-nonconformance.sh`), this report recommends the planner adopt the same
approach: a new `scripts/tests/test-loop-guard-staleness.sh` (or similarly named) that extracts
the `loop-guard-staleness` sentinel region and drives it against constructed guard-file fixtures
(fresh/matching, version-drift, plan-lineage-drift, old-but-otherwise-fine, no-plan-yet) —
asserting archive-aside occurred, the notice was emitted and named the correct signal, and the
fresh guard starts at `cycle_count=0`.

**Scope flag**: this test script's path was not in the task's declared `FILE SCOPE`. Given the
directly-dependent sibling task needed the identical kind of file for the identical kind of
change to the identical SKILL.md, this report recommends the plan explicitly extend scope to
include it (with a clear one-line justification citing this precedent) rather than attempt to
satisfy "test it explicitly" through `bash -n` and narrative-only verification, which would be a
materially weaker bar than the one already met by task 960 in this same file.

## Decisions

- Chosen staleness signals: schema/version drift (`max_cycles` mismatch) OR plan-lineage drift
  (`plan_version` mismatch, new guard field) OR mtime age backstop (new env var, generous
  default). Any one signal tripping is sufficient (OR semantics), each independently immune to the
  `session_id` objection because none of them changes on every invocation by design.
- `.orchestrator-churn-state.json` is archived aside under the loop guard's verdict (inherited),
  not given an independent detector — justified by its already-documented 1:1 lifecycle coupling.
- The ephemeral/gitignored classification of both files is unchanged; only the read-time trust
  behavior changes. The doc update must state this as two orthogonal axes, not conflate them.
- Base-mode `skill-orchestrate/SKILL.md`'s identical Stage 2 shape is explicitly out of scope for
  this task and should be called out as such in the plan/summary, not silently left inconsistent
  without a note.

## Risks & Mitigations

- **False positive on legitimate long resume** (the verification bar's named regression risk):
  mitigated by using version/plan-lineage drift as the primary signals (both invariant under
  ordinary resume) and treating mtime age as a generous backstop only, not the primary gate.
- **`plan_version` field absent on guards written before this fix lands**: mitigated by treating a
  missing/`"none"` `plan_version` as "skip this specific check," never as itself evidence of
  staleness — an old-format guard without the field should not be spuriously flagged the very
  first time this code runs against it.
- **Test script outside declared file scope**: flagged explicitly above rather than silently
  assumed; the planner should make this an explicit scope decision, citing the task 960 precedent.
- **Duplicated fresh-init jq payload** (now needed at three call sites: no-guard, lost-init-race,
  and now stale-guard-reinit) risks drift between copies if not factored into a shared inline bash
  function within the same Stage 2 fenced block — flagged in Recommendation 2, step 3.

## Context Extension Recommendations

None beyond the `orchestrator-runtime-files.md` update this task itself performs — that update
*is* the context extension this defect calls for; no separate undocumented gap was found elsewhere
in the index.

## Appendix

Files reviewed:
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 2, Stage 3a/3b,
  Stage 4 planned/implementing per-phase dispatch, Stage 5 stray-handoff sweep and staleness gate,
  the `resume-scan-conformance-gate` sentinel region)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (base-mode Stage 2, for
  comparison/out-of-scope confirmation)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (full read)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (Handoff Writers section,
  confirming research agents never write `.orchestrator-handoff.json`)
- `agent-system/extensions/core/scripts/task-lock.sh` (`cmd_init_marker`, the atomic
  mkdir-gate + tmp-mv primitive both guard files use)
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` (mtime-threshold reap
  precedent and why its 4h default is not reusable here)
- `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` (sentinel-region
  extraction + fixture-execution test harness precedent, from the directly-dependent sibling task)
- `specs/961_add_freshness_detection_to_orchestrator_loop_guard/` state.json entry (task
  description, file scope, dependencies)

Search approach: codebase-only (Glob/Grep/Read); no web search was needed — this is a pure
in-repo agent-system design question with strong existing precedent for every sub-decision
(archive-aside shape, mtime idiom, sentinel-region test harness, non-gating session_id logging).

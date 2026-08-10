# Research Report: Task #936

**Task**: 936 - Stop Stage 8 postflight from clobbering .return-meta.json modified_files
**Started**: 2026-07-27
**Completed**: 2026-07-27
**Effort**: Small (single-file jq-merge fix + one warning block + one doc note)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 8, Stage MT-4 step 5.5)
- `agent-system/extensions/core/commands/orchestrate.md` (CHECKPOINT 3)
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `.claude/docs/architecture/handoff-schema.md`
**Artifacts**:
- This report (`specs/936_stage8_return_meta_clobbers_modified_files/reports/01_stage8-clobber-fix.md`)

## Executive Summary

- **Defect confirmed live, in the source store** (`agent-system/extensions/core/`, not the
  deployed `.claude/` copy). `skill-orchestrate/SKILL.md`'s "Stage 8: Postflight" writes
  `${TASK_DIR}/.return-meta.json` with `jq -n '{status, metadata}' > file` — a truncating
  redirect that produces an object with ONLY those two keys, on both the clean-exit and
  partial-exit paths.
- **Consequence confirmed**: `commands/orchestrate.md`'s CHECKPOINT 3 (single-task commit site)
  runs strictly after the skill returns and reads `modified_files` from that SAME, now-truncated
  file. Since Stage 8 always runs last in the single-task loop, `modified_files` is always absent
  by the time CHECKPOINT 3 reads it — the read is not merely fragile, it is unconditionally
  empty on every single-task run that reaches Stage 8. Source-file edits made by the
  implementation agent are silently never staged into the completion/pause commit.
- **Silent failure confirmed**: CHECKPOINT 3 has no `modified_count` accounting and never emits
  the canonical `context/standards/git-staging-scope.md` "Fail-Safe Direction" warning. The
  task-scoped variant of that warning DOES exist at the multi-task site (Stage MT-4 step 5.5,
  line ~1491), so the single-task site is the one gap.
- **Scope boundary confirmed, not merely assumed**:
  - Multi-task mode is unaffected: `Stage MT-5` writes a **different** file
    (`specs/.return-meta-multi.json`), and `Stage MT-4` step 5.5 commits **inside the per-task
    loop**, before MT-5 ever runs — there is no analogous "later stage clobbers an earlier
    writer's file" hazard in multi-task mode.
  - `skill-orchestrate-hard/SKILL.md` has **no truncating `.return-meta.json` write** at its own
    "Stage 8: Cleanup" (grep for `jq -n` + `.return-meta.json` near that stage returns nothing;
    Stage 8 there is `rm -f` on the loop guard and churn file only). Hard mode is unaffected.
- **Recommended fix** (Scope A, decision recorded): **merge, not a distinct path.** Read the
  existing file (if present; fall back to `{}`) and apply `. * {status: $status, metadata: {...}}`
  — jq's recursive merge operator — via a temp-file-then-`mv` (never redirecting into the same
  file being read). This preserves `modified_files`, `completion_data`, `memory_candidates`,
  `reflection`, and `artifacts` unconditionally, and additionally deep-merges the `metadata`
  sub-object so `agent_type`/`session_id`/`delegation_path` written by the implementation agent
  are not dropped either — Stage 8 only needs to *add* `cycles_used`/`final_state`, never *replace*
  the whole metadata object. Rejected alternative: writing to a distinct path, which would require
  updating both `commands/orchestrate.md` CHECKPOINT 3 and `orchestrate-recover-outcome.sh` (the
  documented single-reader contract) and gains nothing — the two writers already write
  sequentially, never concurrently, so there is no race to design around.
- **Scope B fix**: add `modified_count` accounting to CHECKPOINT 3's staging block and emit the
  exact, un-suffixed wording from `git-staging-scope.md`'s "Fail-Safe Direction" section when it
  is zero — no task-number suffix, since this is the single-task site (the suffixed form is
  reserved for the multi-task per-task site per that section's own text).
- **Scope C decision recorded**: yes, add a short section to `return-metadata-file.md` stating
  the multiple-sequential-writers invariant explicitly, since its absence is what let this defect
  ship. Placed near the top of "Field Specifications" or as a new subsection after "Schema", not
  buried in `modified_files`'s own subsection (the rule is general to the whole file, not specific
  to that one field).

## Context & Scope

The task is a bug-fix in the orchestrator's single-task lifecycle: an implementation agent
dispatched under `/orchestrate` (or `/orchestrate --hard` when it falls through to base
`skill-orchestrate`'s multi-task path — not relevant here since this is single-task) writes a
rich `.return-meta.json` including `modified_files`. `skill-orchestrate`'s own Stage 8 (run once,
at full-loop termination, whether clean or partial) then overwrites that same file with a
two-field object. `commands/orchestrate.md`'s CHECKPOINT 3 — which runs in the parent orchestrator
context, after the skill call returns — reads `modified_files` from the post-Stage-8 file, so it
always sees an empty list.

**Verified read order** (grep line numbers, subject to drift — anchor on stage names/symbols):
1. During the cycle loop, `orchestrate-recover-outcome.sh` is invoked multiple times (skill-orchestrate/SKILL.md calls it at several points inside the loop, e.g. near "Stage 5"/"Stage 6" equivalents) — these calls run BEFORE Stage 8 and correctly see the implementation agent's fresh `.return-meta.json`, including `completion_data`/`phases_completed` etc. This channel is unaffected by the Stage 8 defect because it runs earlier in the same cycle.
2. Stage 8 runs once, at the end of the whole single-task loop (after the last cycle, on either clean or partial exit), and unconditionally overwrites `.return-meta.json` with `{status, metadata}` only.
3. `commands/orchestrate.md`'s CHECKPOINT 3 runs after the skill call returns to the parent orchestrator turn — strictly after Stage 8 — and is the ONLY consumer of `.return-meta.json`'s `modified_files` field on the single-task path. By this point the field is gone.

This means the defect does not corrupt anything read *during* the loop (recovery reads all
precede Stage 8); it only guarantees CHECKPOINT 3's `modified_files` read comes up empty.

## Findings

### Codebase Patterns

**Stage 8 (`skill-orchestrate/SKILL.md`, "Stage 8: Postflight")** — both variants:

Clean exit:
```bash
mkdir -p "${TASK_DIR}/summaries"
jq -n \
  --arg status "implemented" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '{
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "${TASK_DIR}/.return-meta.json"
```

Partial exit: identical shape, `--arg status "partial"`.

Both use `jq -n` (no input) piped via `>` (truncating redirect) into the exact same path the
implementation agent already wrote its rich object to. Nothing reads the prior content first.

**CHECKPOINT 3 (`commands/orchestrate.md`)**:
```bash
task_dir="specs/${PADDED_NUM}_${PROJECT_NAME}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
metadata_file="${task_dir}/.return-meta.json"
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
```
No `modified_count` variable, no warning branch — silently zero results, silently zero-warning.

**Multi-task per-task site (`skill-orchestrate/SKILL.md`, Stage MT-4 step 5.5)** already has the
correct shape to imitate:
```bash
modified_count=0
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f") && modified_count=$((modified_count + 1))
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
...
if [ "$modified_count" -eq 0 ]; then
  echo "[postflight] WARNING: no modified_files reported for task #${task_num}; source-file changes NOT committed automatically. Review and commit manually." >&2
fi
```
This is the task-scoped variant (task-number-suffixed). The task's own scope note says the
single-task site should use the un-suffixed canonical wording instead.

**Canonical wording** (`context/standards/git-staging-scope.md`, "Fail-Safe Direction"):
```
[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually.
```
This is stated as "the only sanctioned wording; a second, differently-worded convention MUST NOT
be introduced" — reuse verbatim for the single-task site (no task-number suffix there, since
CHECKPOINT 3 is inherently single-task-scoped and unambiguous without one).

**`.return-meta.json` schema** (`context/formats/return-metadata-file.md`): `modified_files` is
documented as a top-level sibling of `memory_candidates`/`reflection`/`completion_data`, populated
only by implementation agents. Nowhere in this file is there a statement that the file may have
more than one writer within a single `/orchestrate` run, nor a rule that a later writer must
preserve fields it doesn't own. This is the gap Scope C addresses.

**Single-reader contract corroboration**: `orchestrate-recover-outcome.sh`'s header explicitly
frames itself as "the ONE place that reads a task's `.return-meta.json`" for outcome-recovery
purposes — but CHECKPOINT 3 in `commands/orchestrate.md` is a second, independent reader (for
`modified_files` specifically, not outcome status). Both readers depend on the file's shape being
additive across writers; a merge-based Stage 8 fix satisfies both without changing either reader.

### Scope Boundary Verification

- **Multi-task mode**: confirmed unaffected. `specs/.return-meta-multi.json` (Stage MT-5) is a
  distinct path from any per-task `.return-meta.json`. Stage MT-4 step 5.5's per-task commit runs
  inside the per-task loop, strictly before Stage MT-5 executes at all (Stage MT-5 is the
  batch-level closing stage, after every per-task iteration). No analogous clobber exists.
- **`skill-orchestrate-hard`**: confirmed unaffected by direct inspection. Its own "Stage 8:
  Cleanup" section contains only `rm -f "$loop_guard_file"` / `rm -f "$churn_file"` — no
  `.return-meta.json` write of any kind, truncating or otherwise. A grep for `jq -n` combined with
  `.return-meta.json` inside that file returns zero hits near Stage 8; the file's other
  `.return-meta.json` touchpoints are all reads (via `orchestrate-recover-outcome.sh` or direct
  `jq -c '.'` recovery reads), never writes.

### Recommendations

**A. Merge fix at Stage 8** (both clean-exit and partial-exit variants get the same shape):

```bash
mkdir -p "${TASK_DIR}/summaries"
meta_file="${TASK_DIR}/.return-meta.json"
existing_meta=$(cat "$meta_file" 2>/dev/null || echo '{}')
tmp_meta=$(mktemp)
echo "$existing_meta" | jq \
  --arg status "implemented" \
  --argjson cycles "$cycle_count" \
  --arg final_state "$current_status" \
  '. * {
    "status": $status,
    "metadata": {
      "cycles_used": $cycles,
      "final_state": $final_state
    }
  }' > "$tmp_meta" && mv "$tmp_meta" "$meta_file"
```
(partial exit: same shape with `--arg status "partial"`).

- `.` is the existing content (or `{}` if the file is absent — e.g. a task that reached Stage 8
  without ever dispatching an implement agent this invocation, which is possible on some
  blocked/failed short-circuit paths).
- `*` is jq's recursive merge: top-level keys not mentioned on the RHS (`modified_files`,
  `completion_data`, `memory_candidates`, `reflection`, `artifacts`, `next_steps`) pass through
  untouched; `metadata` merges recursively too, so `agent_type`/`session_id`/`delegation_path`
  the implementation agent wrote survive alongside the newly added `cycles_used`/`final_state`.
- Read-then-`mktemp`-then-`mv` avoids any same-file truncate-while-reading hazard a direct `>`
  redirect onto the file being read from would risk.
- The `status` value stays in the vocabulary from `return-metadata-file.md` (`"implemented"` /
  `"partial"`) — unchanged from today; the existing "do not correct this value back to
  `completed`" note in Stage 8's prose is untouched by this fix and should be left in place.

**B. CHECKPOINT 3 fail-safe warning** (`commands/orchestrate.md`), adding `modified_count`
accounting and the canonical un-suffixed warning:

```bash
task_dir="specs/${PADDED_NUM}_${PROJECT_NAME}"
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
metadata_file="${task_dir}/.return-meta.json"
modified_count=0
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f") && modified_count=$((modified_count + 1))
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
if [ "$modified_count" -eq 0 ]; then
  echo "[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually." >&2
fi
```
No task-number suffix (this is the single-task site; the suffixed variant belongs only to the
multi-task per-task site per `git-staging-scope.md`'s own text).

**C. `return-metadata-file.md` addition** (decision: yes, add). Suggested placement: a short
subsection immediately after "## Schema" / before "## Field Specifications", e.g.:

> ### Multiple Sequential Writers
>
> `.return-meta.json` may be written by more than one process within a single `/orchestrate`
> invocation — e.g. an implementation agent writes the rich object first, then
> `skill-orchestrate`'s own Stage 8 postflight writes again at full-loop termination to update
> `status`/`metadata`. Any writer that runs after an earlier writer in the same invocation MUST
> merge onto the existing file (read-modify-write) rather than overwrite wholesale, touching only
> the fields it owns. `modified_files`, `completion_data`, `memory_candidates`, `reflection`, and
> `artifacts` are producer-owned by the implementation agent and MUST survive a later writer's
> update untouched.

This is a documentation-only change; no script needs updating to support it since the merge
pattern in A already implements it.

## Decisions

- **Option (i) merge is correct**, not option (ii) distinct path — the merge preserves the
  existing single-reader contract (`commands/orchestrate.md` CHECKPOINT 3,
  `orchestrate-recover-outcome.sh`) and requires touching only Stage 8's own write, not every
  reader.
- **`metadata` sub-object is deep-merged, not replaced wholesale** — this is slightly more
  defensive than the task description's literal phrasing ("add/overwrite only status and
  metadata") but is a strict improvement and is fully consistent with "preserving...any other
  field": it additionally preserves sub-fields of `metadata` itself (`agent_type`, `session_id`,
  `delegation_path`) that the current wholesale-metadata-replace already discards today, which is
  the same class of defect one layer down. Using jq's `*` operator (rather than a two-line
  `.status = ... | .metadata.cycles_used = ...`) gets this for free.
- **Single-task CHECKPOINT 3 warning uses the un-suffixed canonical wording**, matching
  `git-staging-scope.md`'s own instruction that the suffixed form is reserved for multi-task.
- **Part C: add the multi-writer note to `return-metadata-file.md`.** Recorded as a "yes" decision
  per the task's Part C prompt — the absence of this rule is explicitly named as the root enabler
  of the defect, and the fix (Part A) already conforms to what the new rule would require, so
  documenting it costs nothing and prevents recurrence for any future third writer.

## Risks & Mitigations

- **Risk**: a future writer to `.return-meta.json` reintroduces a wholesale overwrite because the
  merge pattern isn't obvious from a naive `jq -n` snippet copied from elsewhere in the codebase.
  **Mitigation**: Part C's documentation note plus keeping Stage 8's own comment about the
  skill-status vocabulary intact serves as the load-bearing warning at the point of highest
  reuse risk.
- **Risk**: `mktemp` + `mv` fix must stay atomic and must not leave a stray tmp file on failure.
  **Mitigation**: standard `&&` chaining between the jq write and the `mv` (as shown above) means
  a jq failure never clobbers the real file; the tmp file is left for inspection rather than
  silently discarded, which is acceptable for a low-frequency postflight-only path.
- **Risk**: the existing file might be malformed/unparseable (e.g. an implementation agent crashed
  mid-write). **Mitigation**: `cat ... 2>/dev/null || echo '{}'` only guards against a missing
  file; a genuinely malformed-but-present file would make the `jq` merge fail. This is an
  acceptable edge case to leave as a non-blocking postflight failure (per
  `.claude/rules/error-handling.md`'s "Non-Blocking Errors" — git/postflight failures are logged,
  not fatal) and is out of scope for this task, which is specifically about the clobber, not about
  hardening against a separately-malformed file.

## Verification Bar (for the implementation phase)

Per the task's own verification bar: a single-task `/orchestrate` run over a task whose
implementation agent edits at least one source file outside `specs/` must produce a CHECKPOINT 3
commit that actually contains that source file (assert via `git show --name-only <sha>` on the
real commit produced, not merely that Stage 8 no longer truncates and not merely that the code
now reads `modified_files`). Also assert the negative case: a task whose agent reports no
`modified_files` must emit the canonical (un-suffixed) warning to stderr.

## Context Extension Recommendations

- **Topic**: Multi-writer invariant for shared per-task state files.
- **Gap**: `context/standards/git-staging-scope.md` documents the *reader* side of
- **Standards**: TBD
  `.return-meta.json` (staging contract) in detail but has no explicit *writer-ordering* rule; the
  `return-metadata-file.md` schema doc is the more natural home (per Part C decision above), but a
  cross-reference from `git-staging-scope.md`'s "Related Documentation" section back to the new
  subsection would close the loop for a reader who starts from the staging-contract side instead.
  Not required for this task's verification bar, but worth a one-line addition alongside the Part C
  edit if convenient.

## Appendix

- Search queries used: `grep -n "Stage 8"`, `grep -n "CHECKPOINT 3"`, `grep -n "modified_files"`,
  `grep -n "Fail-Safe Direction"`, `grep -n "step 5.5"`, `grep -n "return-meta.json"` across the
  four files in FILE SCOPE plus `skill-orchestrate-hard/SKILL.md` and
  `scripts/orchestrate-recover-outcome.sh` for scope-boundary verification.
- All findings anchored on symbol/stage names and quoted strings per the LINE-NUMBER CAVEAT; line
  numbers cited above are illustrative only and will drift.

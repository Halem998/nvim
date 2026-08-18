# Research Report: Task #17

**Task**: 17 - fix_return_meta_lifecycle_ordering
**Started**: 2026-08-18T01:30:00Z
**Completed**: 2026-08-18T01:36:00Z
**Effort**: Medium (single shared-function fix + coordinated edits across 5 command files, ~3-4 hours)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `scripts/skill-base.sh`, `scripts/command-gate-out.sh`, `scripts/command-gate-in.sh`,
  `scripts/orchestrator-postflight.sh`, `scripts/git-commit-scoped.sh`, `commands/{research,plan,
  implement,revise,orchestrate,spawn}.md`, `skills/{skill-researcher,skill-planner,
  skill-implementer,skill-reviser,skill-spawn,skill-team-research,skill-team-plan,
  skill-team-implement,skill-planner-hard,skill-implementer-hard}/SKILL.md`,
  `skills/skill-orchestrate/SKILL.md`, `context/patterns/skill-postflight-flow.md`,
  `context/standards/orchestrator-runtime-files.md`, `context/formats/return-metadata-file.md`,
  `context/standards/git-staging-scope.md`
- Empirical: local `git add` atomic-failure test (see Findings); `git log --grep="complete
  research"` survey of every historical commit of that message shape in this repository
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The described bug is real and confirmed exactly as stated: `skill_cleanup()`
  (`scripts/skill-base.sh:697`) unconditionally `rm -f`'s `.return-meta.json` as part of the
  skill's own postflight (Stage 9), which always runs and returns control to the command
  **before** the command's own `command-gate-out.sh` call (CHECKPOINT 2) ever reads that file.
  Every one of the five commands (`research.md`, `plan.md`, `implement.md`, `revise.md`,
  `orchestrate.md`) invokes DELEGATE (the skill) strictly before GATE OUT, so the file is already
  gone by the time `command-gate-out.sh` opens it, and the script always takes its "not found"
  branch and `exit 0`s at line 73 — never reaching the defensive status correction (lines
  76-129) or the `skill_validate_task_artifacts` directory sweep (line 133).
- **Correction to the task's own framing**: `/orchestrate` is architecturally different from the
  other four and is **not** actually broken by this mechanism today. `skill-orchestrate`
  (dispatched by `orchestrate.md`) never calls `skill_cleanup` and never imports
  `skill-postflight-flow.md` — its own Stage 8 postflight *merges onto* `.return-meta.json`
  (`skill_orchestrate_merge_return_meta`, `skill-base.sh:1042`) rather than deleting it, so the
  file is genuinely present when `orchestrate.md`'s own `command-gate-out.sh` call runs. The
  fix must not regress this already-working case.
- **Blast radius is larger than the task description states**, discovered while tracing what
  else in each command reads `.return-meta.json` after DELEGATE returns: `research.md`'s own
  CHECKPOINT 3 (`git add "reports/" ".return-meta.json" "TODO.md" "state.json"` then `git
  commit`) and `plan.md`'s CHECKPOINT 3 (`git add "${task_dir}/"` which recursively includes
  `.return-meta.json`) both run **after** GATE OUT and both expect `.return-meta.json` to still
  exist on disk — it is intentionally git-tracked "durable provenance"
  (`context/standards/orchestrator-runtime-files.md`), not a throwaway temp file. Empirically
  verified: `git add existing.txt missing.txt` fails atomically (exit 128, "did not match any
  files") and stages **nothing**, not even the paths that did exist. Since `skill-researcher`
  performs *no* commit of its own (`orchestrator-postflight.sh`'s header table documents "research
  -> git commit: NO"), `research.md`'s CHECKPOINT 3 is the *only* commit site for a standalone
  `/research` run, and today it is silently failing its `git add` entirely whenever
  `.return-meta.json` is already gone — which, per the mechanism above, is every time. A survey of
  every `"complete research"` commit in this repository's history (40+ checked) found `.return-
  meta.json` present in literally all of them, and every one traces to an `/orchestrate` or
  multi-task session-ID shape (`sess_..._<tasknum>` plus, mostly, a sibling
  `.orchestrator-handoff.json` in the same commit) — i.e., there is no evidence a standalone
  `/research` invocation has ever successfully committed via `research.md`'s own CHECKPOINT 3 in
  this repo's visible history. This is a strictly worse, previously-undiagnosed symptom of the
  same root cause and directly constrains the fix design (see Recommendation).
- **Recommended direction: (b), refined.** `skill_cleanup()` stops deleting
  `.return-meta.json` (uniform change, all 9 literal callers + the 2 skills that reach it via the
  `skill-postflight-flow.md` import). `command-gate-out.sh` keeps reading/correcting/validating
  but must **not** be the one to delete the file (deleting it there would newly regress
  `orchestrate.md`'s already-working CHECKPOINT 3 and would not fix `research.md`/`plan.md`'s
  CHECKPOINT 3, which run after gate-out and still need the file). Deletion instead becomes each
  **command's own** last action, positioned after whichever of its own steps still needs the file
  (its CHECKPOINT 3 commit, where one exists reading/adding the file; gate-out itself otherwise).
  `skill-spawn` (the one skill_cleanup caller whose command, `/spawn`, has no
  `command-gate-out.sh`-mediated consumer at all) keeps a dedicated inline `rm -f` immediately
  after its `skill_cleanup` call, mirroring the pattern it already uses for its own
  `.spawn-return.json`.
- **Defensive status correction: keep it, it is not dead weight.** Skill-internal Stage 7
  (`skill_postflight_update`) already calls `update-task-status.sh postflight` unconditionally on
  a success status, but that call is executed as one bash command among many inside an
  LLM-followed markdown procedure (not a `set -e` script) — if it silently fails (lock
  contention, a transient `state-write.sh` mutex timeout), nothing forces the postflight sequence
  to halt or retry. `command-gate-out.sh`'s correction is a genuinely independent second reader
  (fresh `jq` read of `state.json`, explicit comparison, retry via `update-task-status.sh` again)
  and is real defense-in-depth, not a redundant restatement — it has simply never been reachable.
  Recommend keeping it, not deleting it (rules out option (d) as the primary direction).
- **Artifact validation: also keep it, also not subsumed.** `skill_validate_task_artifacts` is a
  whole-`task_dir` sweep (`reports/*.md`, `plans/*.md`, `summaries/*.md`, each `--fix`'d) — a
  strictly broader check than each skill's own Stage 6a, which validates only the single
  `artifact_path` the metadata claims. `research.md`'s own CHECKPOINT 2 comment already describes
  these as "distinct from and complementary to" each other, confirming intentional, non-duplicate
  design. It is not subsumed and should not be deleted either.

## Context & Scope

Task 17 asks for a decision among four listed directions to fix `command-gate-out.sh`'s
structurally-unreachable post-metadata body (defensive status correction + artifact validation),
uniformly across all nine `skill_cleanup`-calling skills and all five `command-gate-out.sh`-calling
commands, plus a truthful warning message and an explicit decision on whether defensive
correction is still needed. This report traces the exact mechanism, verifies it empirically where
possible, extends the blast-radius analysis to command-level git-commit stages that read the same
file, and recommends one concrete direction with the precise per-file change list an
implementation pass should apply.

## Findings

### Confirmed mechanism (as described)

- `skill_cleanup()` (`agent-system/extensions/core/scripts/skill-base.sh:697-704`):
  ```bash
  skill_cleanup() {
    local padded_num="$1"
    local project_name="$2"
    local task_dir="specs/${padded_num}_${project_name}"
    rm -f "${task_dir}/.postflight-pending" \
          "${task_dir}/.postflight-loop-guard" \
          "${task_dir}/.return-meta.json" 2>/dev/null || true
  }
  ```
  This is Stage 9 of the shared `context/patterns/skill-postflight-flow.md` block, always run
  before a skill returns control to its calling command.
- `command-gate-out.sh:69-74`:
  ```bash
  meta_file="${task_dir}/.return-meta.json"
  if [ ! -f "$meta_file" ]; then
    echo "WARNING: .return-meta.json not found at $meta_file — skill may have failed silently" >&2
    exit 0
  fi
  ```
  This branch fires on **every normal successful run** of all five commands, because Stage 9 of
  the skill's own postflight has already deleted the file by the time this script opens it. The
  defensive correction (lines 76-129) and `skill_validate_task_artifacts "$task_dir"` (line 133,
  the script's last line) are consequently unreachable code on the success path — and on the
  failure path too, since a genuinely crashed skill also leaves no metadata file, producing the
  identical message. The warning currently carries zero diagnostic information.
- Verified DELEGATE-before-GATE-OUT ordering directly in each command file: `research.md:465`
  (STAGE 2 DELEGATE) precedes `research.md:542` (CHECKPOINT 2 GATE OUT); same pattern at
  `plan.md:465/544`, `implement.md:275/313`, `revise.md:44/74`, `orchestrate.md:617/649`.
- Literal `skill_cleanup` call sites (`grep -l` on `skills/*/SKILL.md`): `skill-implementer`,
  `skill-implementer-hard`, `skill-planner`, `skill-planner-hard`, `skill-reviser`, `skill-spawn`,
  `skill-team-implement`, `skill-team-plan`, `skill-team-research` — the nine named in the task.
  `skill-researcher` and `skill-researcher-hard` are **not** in this literal-grep list but reach
  the identical call indirectly: their own postflight sections say "Follow
  `@.claude/context/patterns/skill-postflight-flow.md` in full for Stage 7 ... Stage 9 (cleanup)"
  — the literal `skill_cleanup(...)` line lives in the imported pattern file, not repeated in
  their own body. Functionally these two also delete `.return-meta.json` before returning, so
  `/research` is affected identically to the other four base-mode-affected commands even though
  `skill-researcher` doesn't show up in a naive grep for the function name.

### Correction: `/orchestrate` is not actually broken by this mechanism

`skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` contain **zero** calls to
`skill_cleanup` and **zero** references to `skill-postflight-flow.md` — confirmed by grep across
both files. Every phase dispatch (`research_agent`, `planner_agent`, `implement_agent`) is
invoked directly via the Agent tool, bypassing `skill-researcher`/`skill-planner`/
`skill-implementer` entirely, so none of those skills' own Stage 9 cleanup ever runs inside an
`/orchestrate` loop. At full-loop termination, Stage 8 of `skill-orchestrate/SKILL.md` calls
`skill_orchestrate_merge_return_meta()` (`skill-base.sh:1042-1063`), which explicitly
**merges onto** the existing `.return-meta.json` (`. * {...}` jq merge, never a delete) — this is
by design, documented in the function's own header comment as necessary because "an earlier
writer (the implementation agent) already populated modified_files/completion_data/etc. on this
same path". `orchestrate.md`'s own `command-gate-out.sh` call (CHECKPOINT 2, line 652) therefore
finds a real file with a real `status` value (`"implemented"` or `"partial"`), and the defensive
correction's `case "orchestrate") expected_status="completed"; status_token="implement"` branch is
live and reachable today. A fix must preserve this, not accidentally break it by having
`command-gate-out.sh` itself delete the file (see Recommendation).

### Blast radius extends to command-level commit stages (new finding)

Every command's own postflight sequence continues past GATE OUT into a CHECKPOINT 3 (COMMIT)
stage, and four of the five read `.return-meta.json` there too — a second, previously
undiscussed consumer of the same file that a naive "gate-out deletes it when done" fix would
break or fail to fix:

| Command | CHECKPOINT 3 reads `.return-meta.json`? | Currently working? |
|---|---|---|
| `research.md` | Yes — explicit `git add ... ".return-meta.json" ...` (line ~578) | **No** (file already gone by CHECKPOINT 2; see atomic-failure finding below) |
| `plan.md` | Yes — `git add "${task_dir}/"` recursively includes it | Effectively moot: `skill-planner` already commits its own content inline (its own Stage 9, before its Stage 10 cleanup) — this command-level add is a currently-vestigial second attempt, harmless because the substantive content is already committed by the skill |
| `implement.md` | Yes — explicit `modified_files` read (lines 344-357) | Same as plan.md: `skill-implementer`'s own Stage 9 (inline `git-commit-scoped.sh` call, reading the *same* `modified_files` field) already runs *before* its own Stage 10 cleanup, so the substantive commit already happened; the command-level CHECKPOINT 3 read is currently vestigial/no-op, not load-bearing |
| `orchestrate.md` | Yes — explicit `modified_files` read (lines 679-683) | **Yes, already works** — because, per the correction above, nothing deletes `.return-meta.json` before this point in the orchestrate path |
| `revise.md` | No separate CHECKPOINT 3 | N/A — `skill-reviser` commits inline (its own Stage 9) before its own Stage 10 cleanup, same pattern as implementer/planner |

The `research.md` row is the one genuinely severe case, because (unlike plan/implement/reviser)
`skill-researcher` performs **no commit of its own** —
`orchestrator-postflight.sh`'s header comment documents this explicitly: `research -> ... git
commit: NO (matches existing researcher behavior)`. `research.md`'s own CHECKPOINT 3 is therefore
the *sole* commit site for a standalone `/research` run, not a redundant second one.

**Empirical verification of the failure mode**: `git add` with multiple pathspecs fails
atomically when any one path doesn't exist, staging *nothing at all*, not just the missing path:

```
$ git add exists.txt nonexistent.txt
fatal: pathspec 'nonexistent.txt' did not match any files
exit=128
$ git status --short
?? exists.txt          # nothing was staged, including the file that DID exist
```

Since `.return-meta.json` is always gone by the time `research.md`'s CHECKPOINT 3 runs (per the
confirmed mechanism above), its `git add "reports/" ".return-meta.json" "TODO.md" "state.json"`
call fails entirely and stages nothing — not the report, not `TODO.md`, not `state.json` — and
the failure is swallowed ("Commit failure is non-blocking (log and continue)"). A survey of every
historical `"complete research"` commit in this repository (`git log --grep`, 40+ commits
checked) found `.return-meta.json` present in 100% of them, and every session ID either carries a
task-number suffix (the `/orchestrate` MT-dispatch shape, `sess_..._<N>`) or is accompanied by a
sibling `.orchestrator-handoff.json` in the same commit (the single-task `/orchestrate` shape) —
i.e. there is no evidence in this repository's visible history of a standalone `/research`
invocation's CHECKPOINT 3 ever having successfully committed. This is a stronger, previously
undocumented consequence of the exact same root cause the task names, and it constrains which
refinement of direction (b) is correct (see below): the fix must ensure `.return-meta.json`
survives at least through `research.md`'s and `plan.md`'s own CHECKPOINT 3, not just through
`command-gate-out.sh`.

### Is the defensive correction actually needed? (explicit decision, as required)

**Yes, keep it.** `skill_postflight_update` (`skill-base.sh:493-527`, Stage 7, always runs before
Stage 9 cleanup inside the skill's own postflight) already does:
```bash
case "$status" in
  researched|planned|implemented)
    bash .claude/scripts/update-task-status.sh postflight "$task_number" "$operation" "$session_id" ...
    ;;
esac
```
unconditionally on a success status — so in the ordinary case `state.json` is already correct by
the time the skill returns, and gate-out's correction is a no-op (current_status already equals
expected_status). But this call is one bash invocation inside a markdown-described procedure that
an LLM agent executes turn by turn — it is not wrapped in `set -e`, has no retry, and (unlike
several sibling Stage 7a/8 calls in the same file) is not itself guarded with `|| echo
"WARNING..."`. A transient `state-write.sh` mutex/lock failure at this exact call would leave
`state.json` stale while the skill still finishes Stage 8/8a/9 and reports success. Gate-out's
correction is a structurally independent second reader (separate `jq` read of the *current*
`state.json`, explicit `[ "$current_status" != "$expected_status" ]` comparison, and its own retry
via `update-task-status.sh`) — genuine defense-in-depth against exactly that failure mode, not a
restatement of Stage 7. It has simply never been reachable. Recommend keeping it and fixing
reachability, not deleting it.

**Also keep artifact validation**, for the same reason: `skill_validate_task_artifacts` is a
whole-`task_dir` `--fix` sweep across `reports/`, `plans/`, and `summaries/`, strictly broader
than the single-artifact check each skill already runs at its own Stage 6a. `research.md`'s own
CHECKPOINT 2 text already documents these as deliberately complementary, not duplicate.

### `orchestrator-postflight.sh`: an orphaned precedent for the correct ordering

`agent-system/extensions/core/scripts/orchestrator-postflight.sh` is a fuller, self-contained
"shared postflight pipeline for research, plan, and implement operations" whose own documented
stage order is Stage 6 (read `.return-meta.json`) → ... → Stage 9 (git commit) → Stage 10
(cleanup, including `.return-meta.json`) — i.e. it already encodes read-before-commit-before-
delete as a single coherent sequence, which is exactly the ordering this task needs restored.
However, grepping every command and skill file in the repository for an actual invocation
(`bash .claude/scripts/orchestrator-postflight.sh`) finds **zero call sites** — the script is
orphaned, referenced only in comments/docs as a "precedent" by other scripts
(`command-gate-out.sh`'s own header comment cites it twice). This is useful corroborating
evidence for the correct ordering but is out of scope to revive; noted here as a possible
future cleanup, not part of this fix.

## Decisions

- **Recommended direction: (b), refined for the commit-stage blast radius.**
  1. `skill_cleanup()` (`scripts/skill-base.sh`) stops deleting `.return-meta.json`; it continues
     to remove only `.postflight-pending` and `.postflight-loop-guard`. This is the single shared
     edit that fixes reachability for all effective callers uniformly (the 9 literal callers plus
     `skill-researcher`/`skill-researcher-hard` via the `skill-postflight-flow.md` import).
  2. `skill-spawn` (the one caller whose command, `/spawn`, never calls `command-gate-out.sh` and
     has no other downstream consumer) adds one inline `rm -f
     "${task_dir}/.return-meta.json"` immediately after its `skill_cleanup` call — the same
     pattern it already uses for its own `.spawn-return.json`, so the file doesn't accumulate
     indefinitely for this one skill.
  3. `command-gate-out.sh` keeps its read, defensive correction, and
     `skill_validate_task_artifacts` call unchanged in substance, but:
     - rewrites the "not found" message to be truthful now that absence is a real signal, e.g.
       "ERROR: .return-meta.json not found at $meta_file — the skill completed without writing
       return metadata (crash before postflight, or a Stage 0/contract bug). Defensive status
       correction and artifact validation cannot run for this dispatch." (keep `exit 0`,
       non-blocking, matching the script's existing non-fatal posture toward its callers).
     - does **not** add a `rm -f` of `.return-meta.json` itself — deleting it here would newly
       regress `orchestrate.md`'s CHECKPOINT 3 (which currently works precisely because nothing
       deletes the file before it runs) and would not fix `research.md`/`plan.md`'s CHECKPOINT 3
       (which run after gate-out and still need the file present).
  4. Each command instead deletes `.return-meta.json` as the true last step of its **own** full
     postflight sequence, after whichever of its own later steps still consumes the file:
     - `research.md`, `plan.md`, `implement.md`, `orchestrate.md`: add `rm -f
       "${task_dir}/.return-meta.json"` as the final line of CHECKPOINT 3, after the
       `git commit`/`git-commit-scoped.sh` call succeeds (or is logged as failed —
       non-blocking either way, matching existing posture).
     - `revise.md`: add the same `rm -f` immediately after its `command-gate-out.sh` call (its
       own CHECKPOINT 3/GATE OUT), since it has no later stage needing the file.
  5. Update `context/patterns/skill-postflight-flow.md`'s Stage 9 description and
     `context/standards/orchestrator-runtime-files.md`'s existing `.return-meta.json` lifecycle
     row to state the new owner of the deletion (the calling command, not `skill_cleanup`) and
     point at the five per-command deletion sites.
- **Defensive status correction: retained**, with reasoning recorded above (independent
  second-layer check against a non-`set -e` Stage 7 call that can silently fail).
- **Artifact validation: retained**, with reasoning recorded above (broader whole-directory sweep,
  not subsumed by any skill's own single-artifact Stage 6a check).
- **Warning text: rewritten** to be an accurate failure signal rather than firing identically on
  every successful run (see item 3 above).
- Directions (a) and (c) were considered and folded into (b): (a)'s "run gate-out before skill
  cleanup" is not achievable as stated because skills run as an opaque Agent/Skill-tool dispatch
  that always completes its own full postflight (including cleanup) before returning control to
  the command — there is no seam for the command to intervene mid-skill. (c)'s "archive to a
  separate location" adds an extra file/rename with no benefit over simply deferring deletion of
  the existing file to the right point. (d) (delete the dead reads) is rejected because both
  reads are independently valuable and merely unreachable, not genuinely subsumed — see the two
  "keep it" findings above.

## Risks & Mitigations

- **Risk**: forgetting one of the five per-command deletion sites leaves `.return-meta.json`
  lingering on disk indefinitely for that command, eventually showing as an uncommitted
  "deleted"/"modified" diff on some later run. **Mitigation**: the per-file change list above is
  exhaustive (5 commands + skill-spawn's one-off); an implementer should grep every
  `command-gate-out.sh` call site and every remaining `skill_cleanup` call site to confirm none
  were missed, and confirm no other command reads `.return-meta.json` after its own last step.
- **Risk**: `implement.md`'s and `plan.md`'s CHECKPOINT 3 blocks, once genuinely reachable again
  (file no longer already gone), start doing real staging work they didn't do before, on top of
  what `skill-implementer`/`skill-planner` already committed inline. **Mitigation**: this should
  be idempotent/harmless (nothing new to stage the second time, `git-commit-scoped.sh` no-ops on
  an unchanged tree) but should be spot-checked by an implementer with a real `/implement` and
  `/plan` run rather than assumed.
- **Risk**: the `orchestrator-runtime-files.md` doc table and any other doc referencing
  `skill_cleanup`'s current three-file removal list will be stale after this change and should be
  updated in the same pass to avoid re-introducing the confusion this bug came from.

## Context Extension Recommendations

- **Topic**: Command-level consumers of `.return-meta.json` after DELEGATE returns.
  **Gap**: no single doc currently enumerates every place downstream of a skill dispatch that
  still reads `.return-meta.json` (gate-out's defensive correction/artifact-validation,
  research.md/plan.md/implement.md/orchestrate.md's CHECKPOINT 3 commit stages). This gap is what
  let the bug's blast radius go undiscovered beyond the two symptoms named in the task.
  **Recommendation**: add a short table to `context/patterns/skill-postflight-flow.md` (or a new
  file it points to) listing every reader of `.return-meta.json` per command, so a future change
  to the file's lifecycle can check all of them at once.

## Appendix

- Confirmed DELEGATE-before-GATE-OUT ordering: `research.md:465,542`; `plan.md:465,544`;
  `implement.md:275,313`; `revise.md:44,74`; `orchestrate.md:617,649`.
- `skill_cleanup()`: `scripts/skill-base.sh:694-704`.
- `command-gate-out.sh`: full file, `scripts/command-gate-out.sh:1-134`.
- `skill_orchestrate_merge_return_meta()`: `scripts/skill-base.sh:1024-1063`.
- `skill-orchestrate/SKILL.md` Stage 8 (postflight, merge not delete): lines ~1206-1272.
- `orchestrator-postflight.sh` header/stage table: lines 1-52; zero live call sites (grepped
  repo-wide).
- Empirical `git add` atomic-pathspec-failure test: run in a scratch repo
  (`/tmp/gitaddtest`), reproduced above verbatim.
- `git log --oneline --all --grep="complete research"` survey: 40+ commits checked via a loop
  counting `.return-meta.json` presence and extracting session IDs; 100% present, 100%
  orchestrate/MT-shaped session IDs.

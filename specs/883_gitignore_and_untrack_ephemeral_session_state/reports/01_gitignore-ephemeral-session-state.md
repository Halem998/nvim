# Research Report: Task #883

**Task**: 883 - gitignore_and_untrack_ephemeral_session_state
**Started**: 2026-07-15T22:52:27Z
**Completed**: 2026-07-15T23:15:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: - `git ls-files`, `git status`, `git show`/`git log`, live filesystem enumeration under `specs/`, `.gitignore`, `.claude/scripts/orchestrator-postflight.sh`, `.claude/scripts/task-lock.sh`, `.claude/scripts/events-append.sh`, `.claude/skills/skill-orchestrate{,-hard}/SKILL.md`, `.claude/docs/architecture/handoff-schema.md`, `.claude/context/formats/events-format.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All VERIFIED EVIDENCE claims in the task description check out against the live repo, with one
  update: `specs/.return-meta-multi.json` and `specs/.orchestrator-multi-state.json` were already
  untracked by the immediately-preceding commit (`git log -1` on HEAD, "orchestrate tasks 878-879:
  clean up multi-task state") — but the `.gitignore` gap that let them get committed in the first
  place (proven by `b42aa5aec`) is still open, so a future multi-task orchestrate run can
  re-commit them unless `.gitignore` is fixed now.
- `.orchestrator-handoff.json` is **ephemeral, not durable** — its own architecture doc
  (`.claude/docs/architecture/handoff-schema.md` line 5) states the file location is "runtime;
  not checked in" and that "each dispatch cycle overwrites the previous handoff." It should be
  gitignored. 186 instances are currently tracked in git (`git ls-files`).
- Beyond the four artifacts named in the task description, this research found three more
  actively-churning ephemeral patterns not yet covered by `.gitignore`:
  `.orchestrator-loop-guard` (4 tracked instances), `.continuation-loop-guard` (2 tracked
  instances), and the `.lock/` directory itself needs a directory-level pattern (3 tracked
  `holder.json` files, one of which — task 856's — is archived while still held and can never be
  released by normal means).
- Two additional patterns are recommended defensively even though nothing is currently tracked
  for them: `.orchestrator-churn-state.json` (hard-mode orchestrate churn counter, same lifecycle
  as the loop-guard) and `.postflight-loop-guard` (sibling of the already-ignored
  `.postflight-pending`, same cleanup-after-commit ordering bug). `.events.lock` (an flock mutex
  target for the event-store appender) is also recommended, on the same "pure concurrency
  machinery, zero data content" reasoning as `.lock/holder.json`.
- `specs/events.jsonl` (the unified event/reflection store) is explicitly documented as
  "Lazy Creation and Never-Gitignored" in `.claude/context/formats/events-format.md` — it is a
  deliberate, accumulating durable log, not session-scoped mutex state, and is out of scope here.
- Two legacy files at the `specs/` root — `.meta-return.json` and `.meta-builder-return.json` —
  are tracked but have no current producer anywhere in `.claude/` (verified via repo-wide grep).
  They are dead/orphaned artifacts, not actively-churning ephemeral state, so no gitignore or
  untracking action is recommended for them in this task's scope.

## Context & Scope

The task asks to (1) verify the task description's evidence claims against the live repo,
(2) enumerate the full set of ephemeral session artifacts under `specs/`, deciding for each
whether it is durable or ephemeral (with particular attention to `.orchestrator-handoff.json`),
and (3) recommend `.gitignore` additions plus `git rm --cached` targets, without writing any new
scripts.

The root cause identified in the task description is confirmed exactly: `orchestrator-postflight.sh`
stages the entire task directory wholesale before any per-file gitignore filtering can matter for
files that already have gitignore coverage — but for files with NO gitignore coverage at all
(the ones enumerated below), `git add "${task_dir}/"` tracks them unconditionally on the first
commit that touches that task directory while the file happens to exist on disk. Several of these
marker files are only `rm -f`'d in a "Stage 10: Cleanup marker files" step that runs **after** the
git commit step ("Stage 9") in `orchestrator-postflight.sh` (lines 429-491) — so the commit is
guaranteed to catch them mid-lifecycle, before their own script-authored cleanup ever removes
them from disk.

## Findings

### Evidence Verification (all claims checked against live repo)

| Claim | Verification | Result |
|---|---|---|
| `.gitignore` covers `**/.return-meta.json` (line 1) and `**/.git-snapshot-marker` (line 19), not `.lock/` or `.orchestrator-multi-state.json` | Read `.gitignore` directly (31 lines total) | Confirmed |
| `orchestrator-postflight.sh` stages the task dir wholesale via `"${task_dir}/"` | `grep -n 'stage_paths=' .claude/scripts/orchestrator-postflight.sh` → line 439: `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")`; `git add "${stage_paths[@]}"` at line 463, followed by `git commit` at line 464, with cleanup (`rm -f .postflight-pending .postflight-loop-guard .return-meta.json`) only at lines 483-486 (**after** the commit) | Confirmed, and root-caused further: this ordering (commit-then-cleanup) is exactly why every "cleaned up before the next commit" marker file still gets captured by the commit that precedes its own cleanup |
| `specs/860_enforce_plan_compliance_rule/.lock/holder.json` and `specs/archive/856_.../.lock/holder.json` are tracked right now | `git ls-files \| grep '.lock/'` | Confirmed, plus a third currently-tracked instance not named in the task description: `specs/876_wire_preflight_into_orchestrate_paths/.lock/holder.json` (shown as ` D` in `git status --porcelain` — deleted on disk, deletion not yet committed) |
| Task 856's archived lock was archived while still held | Read `specs/archive/856_scrub_task_number_leaks_from_wrapper_contracts/.lock/holder.json`: `{"session_id":"sess_1783970466_298292","task_number":856,"operation":"orchestrate","acquired_at":"2026-07-13T19:21:06Z","heartbeat_at":"2026-07-13T19:21:06Z", ...}`; `specs/state.json` has no `project_number == 856` entry (it now only exists in `specs/archive/state.json`) | Confirmed — this lock cannot be released through the normal `task-lock.sh release` path since the task directory is no longer in the active tree |
| `**/.return-meta.json` does not match `.return-meta-multi.json`; `specs/.return-meta-multi.json` is tracked today | Glob logic confirmed (no wildcard segment in the pattern). BUT: `git ls-files \| grep -i return-meta-multi` returns **nothing** — the file is no longer tracked | **Partially stale**: true when the task was authored, but the immediately-preceding commit on HEAD, `296c828af "orchestrate tasks 878-879: clean up multi-task state"`, already deleted both `specs/.return-meta-multi.json` and `specs/.orchestrator-multi-state.json` from tracking (`git show 296c828af --stat` shows both as pure deletions, no other content changes). The `.gitignore` gap that allowed them to be committed in the first place is still open, so this is not fixed at the root — a future multi-task `/orchestrate` run will recreate and re-commit them unless `.gitignore` is updated. |
| `b42aa5aec` ('orchestrate tasks 869-872') committed the deletion of 3 ephemeral lock files plus `.return-meta-multi.json` and `state.json` in one commit spanning 4 tasks | `git show --stat b42aa5aec` | Confirmed exactly: `specs/869_.../. lock/holder.json` (-8), `specs/871_.../.lock/holder.json` (-8), `specs/872_.../.lock/holder.json` (-8) all deleted; `specs/.return-meta-multi.json` modified; two new `.orchestrator-handoff.json` files added/modified in the same commit — this is live confirmation that `.orchestrator-handoff.json` churn rides along with the same commits as the lock-file churn |

### Full Enumeration of Ephemeral Session Artifacts Under `specs/`

Enumerated via `find specs -name '.*' -type f` / `-type d` (basenames deduped) plus targeted
`grep`/`git ls-files` cross-checks. Counts are live-filesystem counts (not all are tracked).

| Pattern | On-disk count | Currently tracked | Producer / consumer | Verdict |
|---|---|---|---|---|
| `**/.return-meta.json` | 271 | 1 (`specs/archive/025_migrate_git_repo_to_nvim_directory/.return-meta.json`, tracked *before* the existing gitignore rule) | Every research/plan/implement skill per `return-metadata-file.md`; deleted by `orchestrator-postflight.sh` Stage 10 | **Ephemeral, already gitignored.** One pre-existing tracked instance needs `git rm --cached`. |
| `**/.orchestrator-handoff.json` | 186 (all tracked) | **186** | Written only when `orchestrator_mode: true` (skills), read/overwritten every dispatch cycle by `skill-orchestrate`'s state machine loop | **Ephemeral — confirmed by its own architecture doc.** `handoff-schema.md` line 5: "File location: `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (runtime; not checked in)." Line 212: "The filename is static (not timestamped). Each dispatch cycle overwrites the previous handoff." Needs a new `.gitignore` entry and `git rm --cached` for all 186. |
| `.lock/` (dir, containing `holder.json`) | 6 dirs (3 active-tree, 1 archived, 2 for in-flight sibling tasks in the current multi-task orchestrate batch) | 3 (`860`, `876` [pending-delete], `archive/856`) | `task-lock.sh` (mkdir-atomic mutex; released via `rm -rf` on normal completion) | **Ephemeral session mutex — exactly the class named in the task title.** Needs a new `.gitignore` entry (directory pattern) and `git rm --cached` for the 3 tracked instances. |
| `.orchestrator-loop-guard` | 5 (1 active: `859`; 3 archived; 1 is the currently-running batch's own state, not yet materialized as this file for task 883) | 4 | `skill-orchestrate`/`skill-orchestrate-hard` cycle counter; `rm -f` only at terminal exit (several call sites in `SKILL.md`, e.g. lines 349, 566 in `skill-orchestrate`) | **Ephemeral.** Same commit-before-cleanup ordering bug. Needs a new `.gitignore` entry and `git rm --cached` for 4 tracked instances. `specs/859_fix_task_order_topic_case_indentation/.orchestrator-loop-guard` is a striking case: it is tracked, still present on disk, and `git status` shows it clean — i.e. permanently and silently committed forever in a completed task's directory. |
| `.continuation-loop-guard` | 2 (both archived) | 2 | `skill-implementer`/`skill-base.sh`; removed inline after implementer completes, and again by `orchestrator-postflight.sh` Stage 10 for `implement` operations | **Ephemeral.** Needs a new `.gitignore` entry and `git rm --cached` for 2 tracked instances. |
| `.orchestrator-churn-state.json` | 0 (none currently on disk) | 0 | `skill-orchestrate-hard` only (H5/H6 churn tracking); `rm -f "$churn_file"` at terminal exit | **Ephemeral by design (same family as loop-guard), not yet observed as tracked** because no `--hard` orchestrate run has recently coincided with a commit while it existed. Recommended defensively — same root-cause window applies. |
| `.postflight-loop-guard` | 0 | 0 | Cleaned up in the same `rm -f` line as `.postflight-pending` and `.return-meta.json` in `orchestrator-postflight.sh` (line 484-486) and `skill-base.sh` (line 467-468) | **Ephemeral, sibling of the already-ignored `.postflight-pending`.** The existing `**/.postflight-pending` gitignore entry does not cover this name. Recommended defensively for the same reason as above. |
| `.events.lock` | 1 (`specs/.events.lock`, live right now, part of the current orchestrate batch) | 0 | `events-append.sh`: `flock -x 200 ... 200> "$LOCK_FILE"` — a zero-byte flock target, created lazily on first append and never deleted (idiomatic flock reuse pattern) | **Ephemeral concurrency machinery, zero data content — same class as `.lock/holder.json`.** Recommended defensively. |
| `.return-meta-*.json` variants (`.return-meta-multi.json`, `.return-meta-02.json`, `.return-meta-orchestrate.json`) | 0 currently on disk for `-multi`; 2 tracked historical variants remain | 2 (`specs/archive/609_.../.return-meta-02.json`, `specs/archive/854_.../.return-meta-orchestrate.json`) plus the now-untracked-but-still-live-risk `specs/.return-meta-multi.json` pattern | `skill-team-research`/`skill-team-plan` write `-NN` suffixed variants per teammate; `skill-orchestrate` writes `specs/.return-meta-multi.json` at multi-task postflight (`skill-orchestrate/SKILL.md` line 814), removed only implicitly (not explicitly `rm -f`'d — see note below) | **Ephemeral — same family, not matched by the existing `**/.return-meta.json` pattern** (the hyphenated suffix breaks the exact-name match). Needs a new `.gitignore` entry (`**/.return-meta-*.json`) and `git rm --cached` for the 2 currently-tracked variants. |
| `specs/.orchestrator-multi-state.json` | 1 (live right now — this is the current multi-task batch's own state file, containing this very task's routing info) | 0 (untracked; deleted from tracking by `296c828af`, the commit immediately preceding HEAD) | `skill-orchestrate` Multi-Task Mode (Stage MT-1 initializes it, Stage MT-5 removes it only on `failed_count == 0`; **preserved on partial** "for diagnostics" per `SKILL.md`) | **Ephemeral runtime scratch state**, confirmed live by reading its current content (this task's own `sess_1784155855_f90cfe` batch: tasks 880-884). Not currently tracked, but the gap that let it get tracked before (proven by `b42aa5aec`) is still open. Needs a new `.gitignore` entry defensively; no `git rm --cached` needed right now since nothing is tracked. |
| `.gitkeep` | 8 | 8 | Manual placeholders for otherwise-empty directories | **Durable, intentional.** No action. |
| `.meta-return.json` / `.meta-builder-return.json` | 3 (2 at `specs/` root, 1 archived) | 3 | **No producer found anywhere in `.claude/`** (`grep -rln 'meta-return\.json\|meta-builder-return\.json' .claude/` returns nothing) | **Dead/orphaned legacy artifacts, not actively-churning ephemeral state.** These predate the current `.return-meta.json` naming convention (`return-metadata-file.md`) and are no longer written by anything live. Leaving them tracked causes no ongoing churn (nothing regenerates or modifies them). Out of scope for this task — recommend no gitignore/untracking action; a separate cleanup task could remove them as dead weight if desired. |
| `specs/events.jsonl` | 1 (live) | 0 (not yet committed, but see next row) | `events-append.sh`; append-only unified event/reflection store | **Explicitly durable by design**, per `.claude/context/formats/events-format.md` ("Lazy Creation and Never-Gitignored" — "Once created, it is a normal tracked file and is never gitignored. It accumulates for the [repository's] lifetime."). Out of scope: this is a deliberate data store, not session-scoped mutex state. No action recommended here. |
| `.baseline-fidelity-audit-dryrun.txt`, `.claude-backup-*.tar.gz` | 2 (both archived, one-off) | 2 | One-off task-specific deliverables (an audit dry-run capture and a config backup tarball), not regenerated on any recurring cycle | **Durable historical task artifacts, not part of the session-mutex churn pattern.** Out of scope. |
| `specs/literature/.literature.db{,.tmp}` | n/a (not found live, path-specific) | n/a | Literature SQLite index cache | Already gitignored (lines 24-27 of `.gitignore`). No action needed. |

### `.orchestrator-handoff.json`: The Task's Explicit Open Question, Resolved

The task description flags `.orchestrator-handoff.json` as "a candidate to evaluate (it may be a
deliberate durable handoff rather than ephemeral, so do not blanket-ignore it without deciding)."
This research resolves it decisively as **ephemeral**, on the strength of the file's own
architecture documentation, not inference:

- `.claude/docs/architecture/handoff-schema.md` line 5: *"File location:
  `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (runtime; not checked in)"* — this is the
  original design intent, stated plainly.
- Line 212: *"The filename is static (not timestamped). Each dispatch cycle overwrites the
  previous handoff."* — it holds only the state of the **most recent** dispatch cycle, so a
  historical git trail of it has no analytical value; each commit's version is superseded by the
  next dispatch's overwrite within the same task, often within seconds.
- Its content is explicitly the transient hand-off between two skill invocations within one
  `skill-orchestrate` state-machine run (see the doc's "Reading Contract" and "Relationship to
  Continuation Handoffs" sections) — it is read exactly once by the orchestrator's next cycle and
  then immediately overwritten again.
- This is architecturally distinct from the **continuation handoff**
  (`handoffs/phase-N-handoff-TIMESTAMP.md`), which the same doc explicitly designs as a
  timestamped, non-overwriting markdown artifact for a different consumer (a successor agent
  after context exhaustion). That continuation-handoff family is NOT in scope here — nothing in
  the evidence or the enumeration above suggests those markdown files are being wholesale-staged
  or accidentally committed, and they are intentionally durable audit trail material for
  human/agent post-mortem reading. Do not conflate the two when writing the `.gitignore` pattern:
  the new pattern must match only the bare `.orchestrator-handoff.json` filename, not the
  `handoffs/` directory.

189 tracked instances would have their live filesystem counterpart preserved by `git rm --cached`
(it only removes index tracking, not the working-tree file) — the orchestrator's read/write loop
for in-progress tasks is unaffected.

## Decisions

- **`.orchestrator-handoff.json` is ephemeral** and should be added to `.gitignore` and untracked.
  This resolves the task's explicit open question.
- **`.lock/` is the correct gitignore target, not `.lock/holder.json`** specifically — the
  directory-level pattern is simpler, matches the task-lock.sh's atomic-mkdir mutex-directory
  design, and there is no other file ever created under `.lock/` (verified: only `holder.json`
  exists under any `.lock/` directory found in the repo).
- **`specs/.return-meta-multi.json` and `specs/.orchestrator-multi-state.json` do not currently
  need `git rm --cached`** (already untracked by `296c828af`), but the `.gitignore` gap that let
  them be committed in the first place is unrelated to that one-off cleanup commit and must still
  be closed, or the same pollution recurs on the next multi-task `/orchestrate` run — including,
  potentially, the very batch (`sess_1784155855_f90cfe`, tasks 880-884) this research task is
  itself part of.
- **`.return-meta-*.json` (hyphen-suffixed variants) is the right pattern**, not a broadened
  `**/.return-meta*.json`, because the latter would also match legitimate report/plan artifact
  filenames that happen to start similarly in theory (none currently do, but the narrower,
  hyphen-anchored pattern is safer and matches the two live producers: team-mode `-NN` suffixes
  and orchestrate's `-multi`/`-orchestrate` suffixes).
- **`.meta-return.json`, `.meta-builder-return.json`, `specs/events.jsonl`, the audit/backup
  one-offs, and `.gitkeep` are explicitly excluded** from any `.gitignore` change — three of these
  are durable by design (`events.jsonl` has documented intent; `.gitkeep` is a universal
  convention; the audit/backup files are one-off deliverables) and the `.meta-return.json` pair
  is dead weight rather than actively-churning ephemeral state, so blanket-ignoring or untracking
  them is out of this task's scope and could destroy content with no compensating benefit.
- **Recommended full `.gitignore` addition set** (new entries, to be added near the existing
  `.return-meta.json`/`.postflight-pending`/`.git-snapshot-marker` block):
  - `**/.lock/`
  - `**/.orchestrator-handoff.json`
  - `**/.orchestrator-loop-guard`
  - `**/.continuation-loop-guard`
  - `**/.orchestrator-churn-state.json`
  - `**/.postflight-loop-guard`
  - `**/.orchestrator-multi-state.json`
  - `**/.return-meta-*.json`
  - `**/.events.lock`
- **Recommended `git rm --cached` targets** (index-only removal, working tree untouched):
  - `specs/860_enforce_plan_compliance_rule/.lock/holder.json`
  - `specs/876_wire_preflight_into_orchestrate_paths/.lock/holder.json` (note: already deleted on
    disk per `git status`; `git rm --cached` still applies cleanly against the index entry, or a
    plain `git add specs/876_.../` after the `.gitignore` change will register the on-disk
    deletion — either resolves the ` D` status)
  - `specs/archive/856_scrub_task_number_leaks_from_wrapper_contracts/.lock/holder.json`
  - `specs/archive/025_migrate_git_repo_to_nvim_directory/.return-meta.json`
  - `specs/archive/609_refactor_team_research_context_protection/.return-meta-02.json`
  - `specs/archive/854_diagnose_and_repair_xapian_directorybookkeeping_ghost_blocking_22_logos_inbox_files/.return-meta-orchestrate.json`
  - `specs/859_fix_task_order_topic_case_indentation/.orchestrator-loop-guard`
  - `specs/archive/625_orchestrate_single_agent_multi_task/.orchestrator-loop-guard`
  - `specs/archive/627_fix_task_order_regeneration/.orchestrator-loop-guard`
  - `specs/archive/739_zulip_fetch_skill/.orchestrator-loop-guard`
  - `specs/archive/543_convert_opencode_json_to_computed_artifact/.continuation-loop-guard`
  - `specs/archive/601_simplify_notification_pipeline_merge_vocabulary/.continuation-loop-guard`
  - All 186 tracked `**/.orchestrator-handoff.json` paths (full list obtainable via
    `git ls-files | grep -F '.orchestrator-handoff.json'` at implementation time — the list is
    large and volatile enough across archived tasks that re-deriving it live at implementation
    time is safer than hardcoding a snapshot here).

## Risks & Mitigations

- **Risk**: `git rm --cached` on ~200 files in one commit is a large diff. **Mitigation**: this is
  an intentional, mechanical, single-purpose cleanup commit (`.gitignore` change + matching
  `git rm --cached`), consistent with the git-workflow convention of atomic, single-concern
  commits; it does not touch any file content, only index membership.
- **Risk**: the current multi-task orchestrate batch (this very task, part of `sess_1784155855_f90cfe`,
  tasks 880-884) has a live `specs/.orchestrator-multi-state.json` and live `.lock/` directories
  for sibling tasks 880/882/884 — an implementation pass must not disturb those in-flight files'
  on-disk state, only their tracking status going forward. `git rm --cached` and `.gitignore`
  additions are index/future-tracking operations and never touch working-tree file contents, so
  this is safe by construction.
- **Risk**: task 856's orphaned lock (archived while held) cannot be released via
  `task-lock.sh release` since its task directory is no longer under `specs/` (it is under
  `specs/archive/`). Untracking it from git does not release the "lock" semantically (nothing
  reads `.lock/holder.json` from an archived directory for the active `active_projects` list
  anyway, since `task-lock.sh`'s `find_held_locks` scans `$PROJECT_ROOT/specs` at `-mindepth 2
  -maxdepth 2`, which does reach `specs/archive/*/.lock` too — worth flagging to the implementer,
  though deciding whether to also delete the stale lock directory outright is a judgment call for
  the implementation plan, not something this research report should force).

## Context Extension Recommendations

- none

## Appendix

### Search Queries / Commands Used

- `git ls-files | grep -F '.lock/'` / `.return-meta` / `orchestrator-multi-state` /
  `orchestrator-handoff` / `.postflight-pending` / `git-snapshot-marker`
- `find specs -name '.*' -type f 2>/dev/null | sed -E 's#.*/##' | sort | uniq -c | sort -rn`
- `find specs -name '.*' -type d 2>/dev/null | sed -E 's#.*/##' | sort | uniq -c | sort -rn`
- `git show --stat b42aa5aec`, `git show 296c828af --stat`, `git log --all --oneline -- '**return-meta-multi*'`
- `git status --porcelain` (repo-wide and path-scoped)
- `grep -n 'stage_paths=\|git add\|task_dir' .claude/scripts/orchestrator-postflight.sh`
- `grep -rln 'orchestrator-loop-guard\|continuation-loop-guard' .claude/scripts .claude/skills`
- `grep -n 'holder.json\|LOCK_FILE\|\.lock' .claude/scripts/task-lock.sh`
- `grep -n 'events.lock\|events.jsonl' .claude/scripts/events-append.sh`
- `grep -n -i 'git\|track\|commit\|ignore' .claude/context/formats/events-format.md`

### Key File References

- `/home/benjamin/.config/nvim/.gitignore`
- `/home/benjamin/.config/nvim/.claude/scripts/orchestrator-postflight.sh` (lines 429-491: Stage 9
  commit / Stage 10 cleanup ordering)
- `/home/benjamin/.config/nvim/.claude/scripts/task-lock.sh` (`.lock/holder.json` mutex mechanism)
- `/home/benjamin/.config/nvim/.claude/scripts/events-append.sh` (`.events.lock` flock target)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md` (line 5, line 212:
  ephemeral, overwrite-per-cycle design intent for `.orchestrator-handoff.json`)
- `/home/benjamin/.config/nvim/.claude/context/formats/events-format.md` (line 22-27: durable,
  never-gitignored design intent for `specs/events.jsonl`)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (Multi-Task Mode,
  Stages MT-1/MT-5: `.orchestrator-multi-state.json`/`.return-meta-multi.json` lifecycle)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate-hard/SKILL.md`
  (`.orchestrator-churn-state.json` lifecycle)

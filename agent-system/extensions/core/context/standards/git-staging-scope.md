# Git Staging Scope Contract

## Overview

This standard defines the operation-type commit-scope contract for the single-agent commit
pipeline (`/research`, `/plan`, `/implement`). It replaces repo-wide `git add -A` staging with
targeted, work-scoped staging so every commit contains only the files the operation actually
produced — never a concurrent session's stray edits.

This is the canonical authority referenced by `orchestrator-postflight.sh`, `skill-implementer`,
`general-implementation-agent`, `git-workflow.md`, and `skill-git-workflow`.

## Per-Operation Scope

### `research`

No commit is created. `do_git_commit=false` for the `research` operation type in
`orchestrator-postflight.sh`. This is unchanged by this contract — research was already safe.

### `plan`

Stage exactly:

```
specs/{padded}_{slug}/
specs/TODO.md
specs/state.json
```

No dependency on agent self-report — the plan operation only ever touches files under the task
directory plus the two shared index files.

### `implement`

Stage the `plan` scope above, PLUS:

```
{plan_path}                      # the plan file itself (may have phase status edits)
{each entry of modified_files}   # agent self-reported source files touched (see below)
```

`modified_files` is an optional `string[]` field in the agent's `.return-meta.json` (see
`.claude/context/formats/return-metadata-file.md`). It is populated by
`general-implementation-agent` (and other implementation agents) as they `Write`/`Edit` files
during execution — see `.claude/context/formats/progress-file.md`'s `files_touched` field for the
per-objective accumulation mechanism that feeds it.

## Fail-Safe Direction

**Under-stage, never over-stage.**

If `modified_files` is absent, empty, or the agent did not report it, the postflight pipeline
MUST fall back to staging only the fixed task-directory paths (`specs/{padded}_{slug}/`,
`specs/TODO.md`, `specs/state.json`, and the plan path for `implement`) and print a **loud,
non-silent warning**:

```
[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually.
```

It is always acceptable to leave source-file changes uncommitted for the user to review and
stage manually. It is never acceptable to reach for `git add -A` to "catch everything" — that
silently pulls in unrelated concurrent-session changes.

## Reference Template (proven, from `--team` skills)

This is the exact working pattern already used by `skill-team-research` and
`skill-team-implement` — reuse it verbatim rather than reinventing scoped staging:

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/reports/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete team research (${team_size} teammates)

Session: ${session_id}
"
```

For `implement`, extend the same pattern with the plan path and `modified_files`:

```bash
padded_num=$(printf "%03d" "$task_number")
stage_paths=(
  "specs/${padded_num}_${project_name}/"
  "specs/TODO.md"
  "specs/state.json"
  "$plan_path"
)
# Append each self-reported modified file
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file")

git add "${stage_paths[@]}"
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}
"
```

## Forbidden Operations

The following are forbidden in the commit pipeline and any agent/skill that stages files for a
task-scoped commit:

- `git add -A`
- `git add .`
- `git commit -am` (implicitly stages all tracked-file modifications)

These commands stage the entire working tree (or all tracked changes), which can silently
include a concurrent session's stray edits, unrelated in-progress work, or accidental file
changes that have nothing to do with the current operation.

## Required Review Flow

Before any commit in the pipeline, prefer to surface what is about to be committed:

```bash
git status --short
git diff --staged
```

After a targeted commit, the postflight pipeline runs `git status --porcelain` and logs a
warning if the working tree is still non-empty — this surfaces (rather than hides) any gap
between what was staged and what actually changed.

## State-Write Serialization and Honest Commit Messages

This scoped-staging rule governs WHAT gets staged for a commit; it does not, by itself, say
anything about ordering the underlying writes to the shared files it stages. `specs/state.json`
in particular is mutated by several independent read-modify-write round trips per postflight run
(status update, artifact-number increment, completion-data writes, memory-candidate propagation,
artifact linking), each of which reads the file, transforms it, and writes it back —  a shape
that is only ever safe against a SINGLE writer at a time. `orchestrator-postflight.sh` now
brackets that entire read-modify-write-plus-`TODO.md`-regen window (its Stages 7 through 8a) in
the `specs/.scope-lock/` mutex documented in `task-lock.md`'s "Scope-Mutex CLI" section, so two
concurrent postflight runs on DIFFERENT tasks can no longer interleave their state.json writes
and silently lose one session's update. This serialization is deliberately narrow: it protects
only the write window above, never `git add`/`git commit` themselves (Stage 9 and later remain
explicitly outside the mutex, matching the "targeted, work-scoped staging" contract this document
already describes — a slower git/TTS/cleanup tail carries no data-integrity risk worth
serializing).

Because the staging rule above still allows `specs/state.json` and `specs/TODO.md` to legitimately
carry OTHER tasks' current rows in a given commit (they are shared, wholesale-regenerated index
files — see Per-Operation Scope above), `orchestrator-postflight.sh`'s Stage 9 now also runs a
staged-diff scan immediately after `git add` and before `git commit`: it compares the just-staged
`specs/state.json` against `HEAD`'s, entry-by-entry on parsed `active_projects` records (never a
raw `+`/`-` line diff, which would miss a changed field sitting inside an unchanged
`project_number` context line), and appends a body line naming every OTHER task whose index rows
the commit carries — e.g. `Also carries current index rows for tasks: 42, 57`. This does not
change staging scope or serialization; it makes an already-legitimate outcome (a commit
mentioning one task while its diff includes other tasks' current index rows) honestly labeled
rather than silently attributed to the named task alone. The scan is entirely failure-tolerant:
any error (missing `HEAD` file on a first commit, unparseable JSON, no staged `state.json`) omits
the addendum and falls through to the plain commit message — it must never break a commit.

## Related Documentation

- `.claude/context/formats/return-metadata-file.md` — `modified_files` field schema
- `.claude/context/formats/progress-file.md` — `files_touched` per-objective field
- `.claude/scripts/orchestrator-postflight.sh` — Stage 9 execution site
- `.claude/rules/git-workflow.md` — Never Run list and Commit Scope section
- `.claude/skills/skill-git-workflow/SKILL.md` — canonical documentation front
- `.claude/context/patterns/task-lock.md` — the `specs/.scope-lock/` scope-mutex CLI
  (`scope-acquire`/`scope-release`) that now brackets the state.json read-modify-write window
  referenced above

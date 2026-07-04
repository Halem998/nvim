---
paths: ["specs/**/*", ".claude/**/*"]
---

# Git Workflow Rules

## Commit Conventions

### Task-Scoped Commits

All commits related to tasks use this format:
```
task {N}: {action} {description}
```

### Standard Actions

| Operation | Commit Message |
|-----------|----------------|
| Create task | `task {N}: create {title}` |
| Complete research | `task {N}: complete research` |
| Create plan | `task {N}: create implementation plan` |
| Complete phase | `task {N} phase {P}: {phase_name}` |
| Complete implementation | `task {N}: complete implementation` |
| Revise plan | `task {N}: revise plan (v{V})` |

### System Operations

| Operation | Commit Message |
|-----------|----------------|
| Archive tasks | `todo: archive {N} completed tasks` |
| Error fixes | `errors: create fix plan for {N} errors (task {M})` |
| Review | `review: {summary}` |
| State sync | `sync: reconcile TODO.md and state.json` |

## Commit Timing

### Create Commits After
- Task creation (includes TODO.md + state.json updates)
- Research completion (includes report file)
- Plan creation (includes plan file)
- Each implementation phase completion
- Final implementation completion (includes summary)
- Task archival operations

### Do Not Commit
- Partial/incomplete work
- Failed operations (rollback instead)
- Intermediate states during multi-phase operations

## Commit Scope

See `.claude/context/standards/git-staging-scope.md` for the authoritative per-operation
commit-scope contract (`research`/`plan`/`implement` staging rules, the proven `--team` staging
template, and the fail-safe under-stage-not-over-stage direction).

### Single-Task Operations
Include only files related to that task:
```
task 334: complete research

Modified:
  specs/TODO.md
  specs/state.json
  specs/334_task_slug/reports/01_research-findings.md
```

### Multi-Task Operations
Group related changes:
```
todo: archive 5 completed tasks

Modified:
  specs/TODO.md
  specs/state.json
  specs/archive/state.json
```

## Git Safety

### Never Run
- `git push --force` to main/master
- `git reset --hard` on uncommitted work without a snapshot first — see
  "No Destructive Git on Uncommitted Work" below for the full rule and exemptions
- `git rebase -i` (interactive mode not supported)
- Any destructive operations without user confirmation
- `git add -A` (or `git add .`) — stages the entire working tree, silently pulling in
  concurrent-session or unrelated stray edits; use targeted, work-scoped staging instead. See
  `.claude/context/standards/git-staging-scope.md` for the per-operation commit-scope contract.
- `git commit -am` — implicitly stages all tracked-file modifications, the same over-staging
  problem as `git add -A`

### No Destructive Git on Uncommitted Work

Agents MUST NOT run git operations that discard working-tree changes while
uncommitted changes exist, unless a snapshot was just taken. This is enforced by
the `guard-destructive-git.sh` PreToolUse Bash hook (registered in `settings.json`),
which blocks the commands below via `exit 2` + stderr guidance when the tree is
dirty and no fresh snapshot exists.

**Forbidden on a dirty tree** (discards uncommitted changes):
- `git reset --hard`
- `git checkout -- <path>` (pathspec discard form)
- `git restore <path>` (without `--staged`; `--staged` only unstages and is safe)
- `git clean -fd` (or any flag ordering/clustering that combines `-f` and `-d`)
- `git stash drop` / `git stash clear`
- Forced `git checkout` / `git switch` (`-f` / `--force`) — can silently overwrite
  local changes when switching branches

**Exemption — allowed when EITHER**:
1. The working tree is already clean (`git status --porcelain` is empty) — there is
   nothing to lose, so the hook exits 0 immediately. This is also how the sanctioned
   `/todo` safety-commit rollback flow (see `.claude/context/standards/git-safety.md`)
   stays exempt: the safety commit makes the tree clean *before* the
   `git reset --hard {sha}` / `git clean -fd` rollback runs, so it is never blocked.
2. A snapshot was just taken via `bash .claude/scripts/git-snapshot.sh` (the
   sanctioned way to snapshot). The helper writes a durable `.patch` under
   `specs/{NNN}_{SLUG}/` plus a belt-and-suspenders `git stash` (default mode) or a
   WIP commit on a scratch branch (`--branch` mode), then refreshes a short-lived,
   single-use freshness marker that the hook consumes on the next matching
   destructive command.

Before any intentional rollback that would otherwise be blocked, run
`bash .claude/scripts/git-snapshot.sh` first, then retry the destructive command.

**Not blocked** (do not discard uncommitted changes): `git stash` (push),
`git stash pop` / `git stash apply`, `git restore --staged <path>`, and non-forced
`git checkout` / `git switch` between branches.

### Always Check Before Commit
- `git status` to verify staged files
- `git diff --staged` to review changes
- Ensure no sensitive files (.env, credentials) are staged
- See `.claude/context/standards/git-staging-scope.md` for the required `git status --short` /
  `git diff --staged` review flow before any targeted commit

## Commit Message Format

```
{scope}: {action} {description}

Session: {session_id}
```

### Session ID

Session ID links commits to their originating command execution.

**Format**: `sess_{unix_timestamp}_{6_char_random}`
**Example**: `sess_1736700000_a1b2c3`

**Generation**:
```bash
# Portable command (works on NixOS, macOS, Linux - no xxd dependency)
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**Lifecycle**:
1. Generated at CHECKPOINT 1 (GATE IN)
2. Passed through delegation to skill/agent
3. Included in error logs for traceability
4. Included in final git commit

### Examples

```
task 334: create LaTeX documentation for Logos system

Session: sess_1736700000_a1b2c3
```

```
task 259 phase 2: implement modal semantics evaluator

Session: sess_1736701234_d4e5f6
```

```
todo: archive 3 completed tasks (336, 337, 338)

Session: sess_1736702000_789abc
```

## Branch Strategy

### Main Development
- Work on `main` or feature branches
- Commit frequently with descriptive messages
- Keep commits atomic (one logical change per commit)

### Task Branches (Optional)
For complex multi-phase implementations:
```
task-{N}-{slug}
```

## Error Handling

### On Commit Failure
1. Log the failure
2. Do not block the operation
3. Preserve changes for manual commit
4. Report to user that commit failed

### On Pre-Commit Hook Failure
1. Do not use --no-verify
2. Fix the issue
3. Create new commit (never amend failed commits)

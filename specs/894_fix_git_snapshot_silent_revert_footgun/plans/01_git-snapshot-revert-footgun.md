# Implementation Plan: Task #894

- **Task**: 894 - Fix git-snapshot.sh silent-revert footgun and unhelpful missing-argument failure
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/894_fix_git_snapshot_silent_revert_footgun/reports/01_git-snapshot-revert-footgun.md
- **Artifacts**: plans/01_git-snapshot-revert-footgun.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix two defects in `agent-system/extensions/core/scripts/git-snapshot.sh`: (a) a
resolution failure whose message does not say *why* task-directory inference failed, and
(b) a default mode whose `git stash push -u` silently reverts the working tree despite the
script's name implying a read-only operation. The fix is loud warnings plus a richer
failure message (primary), a new opt-in `--no-revert` mode that genuinely does not mutate
the tree (secondary, decided below), and call-site updates that pass the task number
explicitly and route each call site to the mode matching its semantic family. Definition
of done: all four modes behave as documented under a scratch-repo test matrix, the existing
`patch:`/`stash:`/`branch:`/`marker:` stdout lines are byte-unchanged, and every source-store
call site names its mode and its task number.

### BINDING CONSTRAINTS (carry into every phase)

1. **SOURCE-STORE RULE**: the source of truth is `agent-system/extensions/core/`.
   `.claude/` is a GITIGNORED, DISPOSABLE deploy artifact. Every edit in this plan targets
   `agent-system/extensions/core/**` (plus repo-root `.gitignore`). **Never edit `.claude/**`.**
   Path strings *inside* the edited content still read `.claude/scripts/git-snapshot.sh`
   because that is the runtime path agents invoke — that is correct and must not be changed
   to an `agent-system/` path.
2. **No task-number citations** in any file outside `specs/**` (see
   `.claude/rules/no-task-references-in-deliverables.md`). Where a phase edits a line that
   already carries one, the citation is removed as part of that edit. Pre-existing citations
   on lines this plan does not touch are out of scope.
3. **Re-verify every line anchor by quoted text** before editing. Line numbers in this plan
   are current as of planning but shift as earlier phases land — match on the quoted `old`
   text, never on the number.
4. **Write the script with Write/Edit tools, never via a `cat <<EOF` heredoc in Bash.** The
   new script text contains `!`-adjacent and `$`-heavy content; routing it through the Bash
   tool risks shell-escaping corruption (see the jq-escaping note in `.claude/CLAUDE.md` for
   the same class of hazard).

### Research Integration

The research report is load-bearing on three points that invert the task description's stated
premise, and this plan is built on the report, not the description:

- **`--branch` does NOT avoid the revert.** Verified by direct reproduction in an isolated
  scratch repo: after `git checkout -b` -> commit -> `git checkout <original>`, the tree is
  exactly as reverted as the stash path. `--branch` changes only the *recovery handle*
  (a branch vs. a stash entry), never the tree mutation. **This plan therefore never surfaces
  or defaults to `--branch` as "the non-destructive path."** Phases 1, 2 and 4 instead state
  plainly that default *and* `--branch` both revert.
- **The missing-argument failure is CONDITIONAL, not absolute.** `resolve_task_dir()` already
  infers the task from `specs/state.json`, but only when exactly one task has
  `status == "implementing"`. Concurrent non-terminal tasks are normal here, so the
  count-must-equal-1 heuristic breaks routinely. Phase 1's fix is therefore a message that
  names the *specific* resolution failure (no `jq` / no `state.json` / zero matches / N
  matches, listing them), not merely "you forgot an argument."
- **Two semantic families exist among call sites**, and they need opposite modes:
  a *rollback-ladder* family where the revert is intentional (snapshot immediately precedes an
  already-decided destructive command) and a *defensive-checkpoint* family
  (CHECKPOINT-BEFORE-OVERFLOW) where the revert is the actual footgun. This split is why the
  default must not change. Phase 4 handles family 1; Phase 5 handles family 2.

Also carried forward: keep the four existing stdout lines byte-compatible (three docs read
them), and route all new warning text to **stderr** so stdout stays untouched.

### Design Decision: `--no-revert` is IN SCOPE, as an opt-in third mode

The research explicitly left this as a design question for planning. **Decision: implement it,
in Phase 3, as an opt-in mode mutually exclusive with `--branch` — never as a default.**

Justification:

1. The task's own fallback test ("only if `--branch` proves insufficient should a `--no-revert`
   mode be added") is satisfied: the reproduction proved `--branch` insufficient. Without a
   third mode, the defensive-checkpoint family has *no* non-destructive option at all, and the
   warnings from Phases 1-2 would only tell an agent that its work is about to vanish without
   giving it any way to prevent that. That is a half-fix.
2. Not changing the default preserves the rollback-ladder family's currently-correct behavior
   and its working `guard-destructive-git.sh` exemption flow, exactly as the research advises.
3. The mechanism question the research flagged is resolvable and is resolved here:
   **`git stash create` + `git stash store`.** `git stash create` builds a stash *commit
   object* without touching the working tree or `refs/stash`; `git stash store` then records it
   so it appears in `git stash list` as an ordinary entry. Neither step reverts anything. Its
   one gap — `git stash create` cannot capture untracked files — is closed by copying
   `git ls-files --others --exclude-standard` output into a task-scoped
   `untracked-backup-{ts}/` directory. `--exclude-standard` matches `git stash -u`'s own
   ignored-file semantics, so coverage is at parity with default mode. Git 2.54.0 is present;
   both subcommands are long-stable.
4. The `cp`-based side channel was chosen over any `git stash -u`-derived approach for
   untracked files precisely because every `-u` form mutates the tree, which is the thing being
   eliminated.

`--no-revert` still writes the freshness marker. The snapshot it produces (patch + stored stash
+ untracked copy) is genuinely recoverable, so the marker is legitimately earned; the post-op
message notes that because the tree stays dirty, a following destructive command discards the
*live* edits and recovery must come from those artifacts.

### Decisions carried from research (explicitly NOT revisited)

- **Do not rename the script.** Optics-only; ~19 reference lines plus a marker-contract doc
  block cross-referenced by name from `guard-destructive-git.sh` and `task-lock.md`.
- **Do not change the default mode.** Would silently reinterpret every family-1 call site.
- **Do not present `--branch` as non-destructive** anywhere in prose, usage, or call sites.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases included.

## Goals & Non-Goals

**Goals**:
- Make it impossible to invoke the tree-reverting modes without a loud pre-op and post-op
  warning on stderr.
- Replace the generic resolution failure with a message that names the specific cause and shows
  both working invocation forms.
- Add `--help`/`-h` and reject unrecognized `-`-prefixed options instead of silently absorbing
  them into `TASK_ARG`.
- Add an opt-in `--no-revert` mode that leaves the working tree byte-identical.
- Update all 4 bare-invocation call sites to pass a task number and to name the mode
  appropriate to their semantic family.
- Route defensive-checkpoint call sites to `--no-revert`.

**Non-Goals**:
- Renaming the script.
- Changing the default mode.
- Any edit under `.claude/` (disposable deploy artifact).
- Removing pre-existing task-number citations on lines this plan does not otherwise edit.
- Deploying to `.claude/` — that is the Neovim-side picker's job, not this task's.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New warning text breaks doc-implied stdout parsing (`checkpoint-before-overflow.md:112` and two agent files read the reported references) | H | M | All new warnings go to **stderr**. The four existing stdout lines stay byte-identical. The single new stdout line (`untracked-backup:`) prints only when non-NONE. |
| `RESOLVE_REASON` set inside `resolve_task_dir` is lost because the function is called in a command substitution (subshell) | H | H (if naively written) | Phase 1 prints the reason to **stderr from inside the function** — stderr passes through `$( )` unchanged. Explicitly called out in Phase 1 tasks. |
| `--no-revert` untracked backup gets swept by a later `git stash -u`, or accidentally committed by task-scoped staging | M | M | Phase 3 adds `**/untracked-backup-*/` to repo-root `.gitignore`. Ignored files are excluded from `git stash -u`, from `git clean -fd` (no `-x`), and from `git ls-files --others --exclude-standard` (so backups never nest). |
| Rejecting unknown `-` options is a behavior change that breaks a caller | M | L | Research confirmed no call site passes an unrecognized flag or `--help`. Verified again in Phase 1 by re-grepping before the edit. |
| Line anchors drift between phases (Phases 1-3 all edit the same file) | M | H | Phases 1-3 are strictly sequential (waves 1, 2, 3). Every edit matches on quoted text, never line number. |
| Verification run against this repository's own working tree instead of a scratch repo | H | M | The research report records exactly this incident. Phase 6 mandates `set -e`-guarded absolute-path `cd` into a scratchpad repo with a verified `git rev-parse --show-toplevel` assertion before any script invocation. |
| Untracked filenames containing newlines break the `while read` copy loop | L | L | Accepted limitation; Phase 3 notes it in a code comment. No such filenames exist in this repo. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 1, 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 3 and 4 touch disjoint files
(Phase 3: `scripts/git-snapshot.sh` + `.gitignore`; Phase 4: hook, rules, agent, skill,
contract docs) and may run in parallel. Phase 5 must follow Phase 4 because both edit
`agents/general-implementation-hard-agent.md` (different regions).

---

### Phase 1: Usage block, `--help`, option rejection, and richer resolution diagnostics [COMPLETED]

**Goal**: The script documents the revert plainly in its own usage, accepts `--help`, rejects
unknown options, and explains exactly why task resolution failed.

**Territory**: `agent-system/extensions/core/scripts/git-snapshot.sh` only.

**Tasks**:
- [x] Re-grep the source store to reconfirm no call site passes `--help` or an unrecognized
      `-`-prefixed flag: `grep -rn "git-snapshot.sh" agent-system/extensions/core/` *(completed: confirmed no such call site)*
- [x] Edit 1.1 — marker contract: add the new marker key. Anchor on the quoted line
      `#               BRANCH_NAME=<wip-snapshot-{ts} branch name, or NONE>` and insert
      immediately after it:
      ```
      #               UNTRACKED_BACKUP=<untracked-backup-{ts} dir, or NONE>
      ```
      *(completed)*
- [x] Edit 1.2 — remove the task-number citation on the header line. Replace
      `# Sanctioned snapshot helper for task 780 (agent git-safety: preserve uncommitted work).`
      with
      `# Sanctioned snapshot helper for agent git-safety: preserve uncommitted work.`
      *(completed)*
- [x] Edit 1.3 — replace the entire `# --- Usage ---` block (from the line
      `# --- Usage ---` through the line
      `#   snapshot exists.`) with the exact text in "Replacement text 1.3" below. *(completed)*
- [x] Edit 1.4 — replace the arg-parsing block (from `MODE="default"` through the closing
      `done`) with the exact text in "Replacement text 1.4" below. Note this introduces
      `print_usage` (stdout; error paths redirect with `>&2`) and the mutual-exclusion check.
      *(completed)*
- [x] Edit 1.5 — replace `resolve_task_dir()` (from the comment line
      `# resolve_task_dir: turn a task number / path / empty arg into a specs/{NNN}_{SLUG} dir.`
      through its closing `}`) with "Replacement text 1.5" below. **Critical**: the reason is
      echoed to stderr *from inside the function*, because `TASK_DIR=$(resolve_task_dir ...)`
      runs the function in a subshell where a variable assignment would be discarded.
      *(completed)*
- [x] Edit 1.6 — replace the failure block (from `TASK_DIR=$(resolve_task_dir "$TASK_ARG")`
      through its `exit 1` / `fi`) with "Replacement text 1.6" below. *(completed)*
- [x] `bash -n agent-system/extensions/core/scripts/git-snapshot.sh` must pass. *(completed: verified)*

**Replacement text 1.3** (replaces the `# --- Usage ---` block):
```
# --- Usage ---
#   git-snapshot.sh [--branch | --no-revert] [TASK]
#     TASK          Task number (an integer), a specs/{NNN}_{SLUG} directory path, or
#                   omitted to infer the task from specs/state.json (see TASK inference).
#     --branch      Instead of the default stash-based snapshot, create a WIP commit
#                   on a scratch branch (wip-snapshot-{ts}) capturing the dirty tree,
#                   then return to the original branch.
#     --no-revert   Take the snapshot WITHOUT mutating the working tree (see modes).
#     --help, -h    Print the usage summary and exit 0.
#   The three modes are mutually exclusive; passing more than one is an error.
#
# --- WARNING: default and --branch modes REVERT the working tree ---
#   Despite the name, this script is NOT read-only in its default or --branch modes.
#   Both leave the working tree CLEAN at HEAD: uncommitted edits are removed from the
#   working directory (still recoverable, but no longer present).
#     default mode  runs `git stash push -u`, which reverts modified tracked files and
#                   removes untracked ones.
#     --branch mode commits the dirty tree onto a scratch branch and then checks out the
#                   original branch, which reverts the tree exactly as much as the stash
#                   path does. --branch changes only the RECOVERY HANDLE (a branch instead
#                   of a stash entry) -- it does NOT avoid the revert.
#   Use --no-revert when you want a durable backup and intend to KEEP WORKING. Use the
#   default (or --branch) when the snapshot is a precursor to an already-decided
#   destructive git command, where a clean tree is the intended handoff.
#
#   Default mode: writes specs/{NNN}_{SLUG}/working-progress-{ts}.patch (git diff HEAD)
#   AND runs `git stash push -u` (untracked-inclusive, without drop) as a
#   belt-and-suspenders in-repo copy. Both the patch and the marker are written before
#   the script exits successfully. THE WORKING TREE IS REVERTED.
#
#   --no-revert mode: writes the same working-progress-{ts}.patch, records a real stash
#   entry via `git stash create` + `git stash store` (which build and store a stash commit
#   object without ever touching the working tree), and copies untracked files to
#   specs/{NNN}_{SLUG}/untracked-backup-{ts}/ because a diff cannot represent them. The
#   working tree is left exactly as it was found. The freshness marker is still written:
#   the resulting snapshot is genuinely recoverable, but note that because the tree stays
#   dirty, a destructive command run afterwards discards the LIVE edits and recovery must
#   come from the patch / stash / untracked backup.
#
#   TASK inference: with no TASK argument, the script reads specs/state.json and uses the
#   single task whose status is "implementing". Inference FAILS whenever that is not
#   exactly one task -- zero matches, two or more concurrent "implementing" tasks, no jq,
#   or no specs/state.json. Several tasks being in flight at once is normal here, so
#   passing TASK explicitly is the reliable form.
#
#   On a clean working tree, this script is a no-op: it prints a message and exits 0
#   without writing a marker (there is nothing to protect).
#
#   On any failure, this script exits non-zero with a clear message so the caller
#   (an agent about to run a destructive git command) does NOT proceed believing a
#   snapshot exists.
```

**Replacement text 1.4** (replaces `MODE="default"` .. `done`):
```bash
MODE="default"
TASK_ARG=""
MODE_FLAG_COUNT=0

print_usage() {
  cat << 'USAGE'
Usage: git-snapshot.sh [--branch | --no-revert] [TASK]

  TASK          Task number (an integer), a specs/{NNN}_{SLUG} directory path, or
                omitted to infer the single "implementing" task from specs/state.json.
  --branch      Snapshot by committing the dirty tree to a scratch branch
                (wip-snapshot-{ts}), then returning to the original branch.
  --no-revert   Snapshot WITHOUT mutating the working tree.
  --help, -h    Print this usage and exit 0.

WARNING: the default and --branch modes BOTH revert the working tree.
  Default mode runs `git stash push -u`; --branch mode commits to a scratch branch and
  then checks out the original branch. Either way the tree ends up clean at HEAD and the
  uncommitted edits are no longer present in the working directory (they remain
  recoverable via the reported patch / stash / branch). --branch changes only the
  recovery handle -- it does NOT avoid the revert.
  Use --no-revert to take a durable backup and keep working.

The three modes are mutually exclusive.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --branch)
      MODE="branch"
      MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1))
      ;;
    --no-revert)
      MODE="no-revert"
      MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1))
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    -*)
      echo "git-snapshot.sh: unrecognized option '$arg'" >&2
      print_usage >&2
      exit 1
      ;;
    *)
      TASK_ARG="$arg"
      ;;
  esac
done

if [ "$MODE_FLAG_COUNT" -gt 1 ]; then
  echo "git-snapshot.sh: --branch and --no-revert are mutually exclusive" >&2
  print_usage >&2
  exit 1
fi
```

**Replacement text 1.5** (replaces `resolve_task_dir()`):
```bash
# resolve_task_dir: turn a task number / path / empty arg into a specs/{NNN}_{SLUG} dir.
# On failure it echoes a specific reason to stderr and returns 1. The reason is written to
# stderr rather than assigned to a variable on purpose: this function is invoked as
# TASK_DIR=$(resolve_task_dir ...), i.e. in a subshell, so any variable it set would be
# discarded -- stderr passes through the command substitution unchanged.
resolve_task_dir() {
  local arg="$1"

  if [ -n "$arg" ]; then
    if [ -d "$arg" ]; then
      echo "$arg"
      return 0
    fi
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      local padded dir
      padded=$(printf "%03d" "$arg")
      dir=$(find specs -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1)
      if [ -n "$dir" ]; then
        echo "$dir"
        return 0
      fi
      echo "git-snapshot.sh: could not resolve a task directory." >&2
      echo "  reason: '$arg' looks like a task number, but no specs/${padded}_* directory exists (cwd: $(pwd))" >&2
      return 1
    fi
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: '$arg' is neither an existing directory nor an integer task number (cwd: $(pwd))" >&2
    return 1
  fi

  # No TASK argument: infer the single task currently in status "implementing".
  if ! command -v jq >/dev/null 2>&1; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: no TASK argument was given and 'jq' is not installed, so specs/state.json could not be read" >&2
    return 1
  fi
  if [ ! -f specs/state.json ]; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: no TASK argument was given and specs/state.json does not exist (cwd: $(pwd)); inference requires it" >&2
    return 1
  fi

  local nums count
  nums=$(jq -r '.active_projects[] | select(.status=="implementing") | .project_number' specs/state.json 2>/dev/null)
  count=$(printf '%s\n' "$nums" | grep -c '^[0-9]\+$' || true)

  if [ "$count" = "0" ]; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: no TASK argument was given and no task in specs/state.json has status \"implementing\", so there is nothing to infer" >&2
    return 1
  fi
  if [ "$count" = "1" ]; then
    local padded dir
    padded=$(printf "%03d" "$nums")
    dir=$(find specs -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1)
    if [ -n "$dir" ]; then
      echo "$dir"
      return 0
    fi
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: inferred task $nums from specs/state.json, but no specs/${padded}_* directory exists" >&2
    return 1
  fi

  echo "git-snapshot.sh: could not resolve a task directory." >&2
  echo "  reason: no TASK argument was given and $count tasks are concurrently \"implementing\" ($(printf '%s' "$nums" | tr '\n' ' ' | sed 's/ *$//')), so inference is ambiguous" >&2
  return 1
}
```

**Replacement text 1.6** (replaces the `TASK_DIR=...` failure block):
```bash
TASK_DIR=$(resolve_task_dir "$TASK_ARG")
if [ -z "$TASK_DIR" ] || [ ! -d "$TASK_DIR" ]; then
  if [ -n "$TASK_DIR" ]; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: resolved to '$TASK_DIR', which is not a directory" >&2
  fi
  echo "  fix:    pass the task explicitly, in either form:" >&2
  echo "            bash .claude/scripts/git-snapshot.sh <task-number>" >&2
  echo "            bash .claude/scripts/git-snapshot.sh specs/<NNN>_<slug>" >&2
  echo "  note:   the no-argument form only resolves when EXACTLY ONE task in" >&2
  echo "          specs/state.json has status \"implementing\". Several tasks being in" >&2
  echo "          flight at once is normal here, so the explicit form is the reliable one." >&2
  echo "  modes:  the default and --branch modes REVERT the working tree; --no-revert does" >&2
  echo "          not. Run 'bash .claude/scripts/git-snapshot.sh --help' for details." >&2
  exit 1
fi
```

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` — marker contract key, header
  citation removal, usage block, arg parsing, `resolve_task_dir`, failure block

**Verification**:
- `bash -n agent-system/extensions/core/scripts/git-snapshot.sh` exits 0
- `bash agent-system/extensions/core/scripts/git-snapshot.sh --help` prints usage, exits 0
- `bash agent-system/extensions/core/scripts/git-snapshot.sh --branh` (typo) exits 1 with
  `unrecognized option`, rather than silently treating it as a task argument
- `bash agent-system/extensions/core/scripts/git-snapshot.sh --branch --no-revert` exits 1
  with the mutual-exclusion message
- Run from a directory with no `specs/` present: the output names `specs/state.json does not
  exist` as the reason

---

### Phase 2: Pre-op and post-op tree-reset warnings [COMPLETED]

**Goal**: Every tree-reverting invocation announces the revert before it happens and confirms
it afterwards with concrete recovery commands — all on stderr, leaving stdout byte-compatible.

**Territory**: `agent-system/extensions/core/scripts/git-snapshot.sh` only.

**Tasks**:
- [x] Edit 2.1 — insert the pre-op warning immediately **before** the mode dispatch. Anchor on
      the quoted line `if [ "$MODE" = "branch" ]; then` (the first occurrence, which follows
      `BRANCH_NAME="NONE"`) and insert "Replacement text 2.1" above it, separated by a blank
      line. *(completed)*
- [x] Edit 2.2 — append the post-op notice **after** the existing four `echo` output lines and
      **before** `exit 0`. Anchor on the quoted line
      `echo "  marker: ${MARKER_PATH}"` and insert "Replacement text 2.2" after it. *(completed)*
- [x] Do **not** modify, reorder, or reformat the four existing stdout lines
      (`snapshot complete`, `  patch:`, `  stash:`, `  branch:`, `  marker:`). Three doc files
      describe those references; they must stay byte-identical. *(completed: verified via
      1>/dev/null and 2>/dev/null split test)*
- [x] `bash -n` must pass. *(completed: verified)*

**Replacement text 2.1** (inserted before the mode dispatch):
```bash
# Pre-op warning. On stderr so the existing stdout report stays byte-compatible for the
# docs that describe it (checkpoint-before-overflow.md and the agent handoff steps).
if [ "$MODE" = "no-revert" ]; then
  echo "git-snapshot.sh: --no-revert mode -- the working tree will NOT be modified." >&2
else
  echo "git-snapshot.sh: WARNING -- ${MODE} mode REVERTS the working tree." >&2
  echo "  Your uncommitted changes are about to be removed from the working directory." >&2
  echo "  They stay recoverable via the patch / stash / branch reported on completion, but" >&2
  echo "  they will no longer be present as live edits. --branch does NOT avoid this; it" >&2
  echo "  only changes the recovery handle. If you intend to keep working, abort and re-run" >&2
  echo "  with --no-revert." >&2
fi
```

**Replacement text 2.2** (appended after the `marker:` line, before `exit 0`):
```bash
# Post-op notice, on stderr for the same stdout-compatibility reason as the pre-op warning.
if [ "$MODE" = "no-revert" ]; then
  echo "git-snapshot.sh: the working tree was left UNCHANGED -- your edits are still present." >&2
  echo "  Because the tree is still dirty, a destructive git command run after this will" >&2
  echo "  discard those live edits; recover them from the patch / stash / untracked backup." >&2
else
  echo "git-snapshot.sh: THE WORKING TREE WAS JUST RESET TO HEAD." >&2
  echo "  Your uncommitted changes are no longer in the working directory. Recover with:" >&2
  echo "    patch  -> git apply ${PATCH_PATH}" >&2
  [ "$STASH_REF" = "NONE" ] || echo "    stash  -> git stash pop ${STASH_REF}" >&2
  [ "$BRANCH_NAME" = "NONE" ] || echo "    branch -> git checkout ${BRANCH_NAME}" >&2
fi
```

Note: the `[ X = NONE ] || echo` form is used deliberately in place of `[ X != NONE ]` to keep
the script free of `!=`, which is prone to shell-escaping corruption when tooling rewrites
command strings.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` — pre-op warning block, post-op
  notice block

**Verification**:
- `bash -n` exits 0
- In the Phase 6 scratch repo, `git-snapshot.sh <task>` prints the WARNING block on stderr
  before the stash runs, and the RESET block after
- `git-snapshot.sh <task> 1>/dev/null` shows only warnings; `2>/dev/null` shows exactly the
  original five stdout lines and nothing else

---

### Phase 3: Implement `--no-revert` mode [COMPLETED]

**Goal**: `--no-revert` produces a snapshot with coverage at parity with default mode
(patch + real stash entry + untracked files) while leaving the working tree byte-identical.

**Territory**: `agent-system/extensions/core/scripts/git-snapshot.sh` and repo-root
`.gitignore`.

**Tasks**:
- [x] Edit 3.1 — replace the mode dispatch. Anchor on the quoted line `STASH_REF="NONE"` and
      replace from there through the closing `fi` of the `else` (default) branch with
      "Replacement text 3.1" below. The `--branch` and default branches are reproduced
      unchanged; only the new `elif` and the `UNTRACKED_BACKUP` initializer are added.
      *(completed: applied as two Edits — `UNTRACKED_BACKUP="NONE"` initializer plus the
      `elif`/no-revert branch — to preserve the Phase 2 pre-op warning block that now sits
      between the initializers and the dispatch `if`; net result is textually equivalent to
      Replacement text 3.1 with the Phase 2 warning retained in place)*
- [x] Edit 3.2 — add the marker key. Anchor on the quoted line
      `BRANCH_NAME=${BRANCH_NAME}` inside the `cat > "$MARKER_PATH"` heredoc and insert
      immediately after it:
      ```
      UNTRACKED_BACKUP=${UNTRACKED_BACKUP}
      ```
      (The guard hook reads only `^TIMESTAMP=`, so extra `KEY=VALUE` lines are contract-safe.)
      *(completed)*
- [x] Edit 3.3 — report the backup path on stdout only when it exists. Anchor on the quoted
      line `echo "  marker: ${MARKER_PATH}"` and insert **before** it:
      ```bash
      [ "$UNTRACKED_BACKUP" = "NONE" ] || echo "  untracked-backup: ${UNTRACKED_BACKUP}"
      ```
      *(completed)*
- [x] Edit 3.4 — repo-root `.gitignore`: anchor on the quoted line
      `**/.git-snapshot-marker` and insert immediately after it:
      ```
      **/untracked-backup-*/
      ```
      Rationale (worth a one-line comment above it in the file): ignoring the backup keeps a
      later `git stash -u` and a `git clean -fd` from removing it, keeps task-scoped staging
      from committing it, and keeps `git ls-files --others --exclude-standard` from nesting
      backups of backups on repeat runs. *(completed: comment added)*
- [x] `bash -n` must pass. *(completed: verified)*

**Replacement text 3.1** (replaces the whole mode dispatch):
```bash
STASH_REF="NONE"
BRANCH_NAME="NONE"
UNTRACKED_BACKUP="NONE"

if [ "$MODE" = "branch" ]; then
  ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  BRANCH_NAME="wip-snapshot-${TS}"

  if ! git checkout -b "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to create scratch branch $BRANCH_NAME" >&2
    exit 1
  fi
  if ! git add -A >/dev/null 2>&1 || ! git commit -m "wip snapshot ${TS}" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to create WIP commit on $BRANCH_NAME" >&2
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
    exit 1
  fi
  if ! git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to return to original branch $ORIGINAL_BRANCH after WIP commit on $BRANCH_NAME" >&2
    exit 1
  fi
elif [ "$MODE" = "no-revert" ]; then
  # Non-destructive mode. `git stash create` builds a stash COMMIT OBJECT and prints its
  # sha without touching the working tree or refs/stash; `git stash store` then records
  # that object so it appears in `git stash list` like any other entry. Neither step
  # reverts anything. `git stash create` prints nothing when there are no tracked-file
  # changes (e.g. an untracked-only dirty tree), which is handled below.
  STASH_SHA=$(git stash create "git-snapshot-${TS}" 2>/dev/null)
  if [ -n "$STASH_SHA" ]; then
    if ! git stash store -m "git-snapshot-${TS}" "$STASH_SHA" >/dev/null 2>&1; then
      echo "git-snapshot.sh: failed to store stash object $STASH_SHA (no-revert mode)" >&2
      rm -f "$PATCH_TMP"
      exit 1
    fi
    STASH_REF=$(git stash list | head -1 | cut -d: -f1)
  fi

  # `git stash create` cannot capture untracked files and the patch cannot represent them,
  # so copy them instead. --exclude-standard matches `git stash -u`'s own ignored-file
  # semantics, so coverage is at parity with default mode. Enumeration happens BEFORE the
  # backup directory is created, so a backup never contains itself. Untracked filenames
  # containing a newline are not supported (none exist in practice).
  UNTRACKED_LIST=$(git ls-files --others --exclude-standard 2>/dev/null)
  if [ -n "$UNTRACKED_LIST" ]; then
    UNTRACKED_BACKUP="${TASK_DIR}/untracked-backup-${TS}"
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      dest="${UNTRACKED_BACKUP}/${f}"
      if ! mkdir -p "$(dirname "$dest")" >/dev/null 2>&1 || ! cp -p "$f" "$dest" >/dev/null 2>&1; then
        echo "git-snapshot.sh: failed to back up untracked file '$f' to $dest (no-revert mode)" >&2
        rm -f "$PATCH_TMP"
        exit 1
      fi
    done <<< "$UNTRACKED_LIST"
  fi
else
  # Default mode: belt-and-suspenders in-repo stash copy (patch above is the primary
  # durable record; -u also captures untracked files the patch cannot represent).
  # NOTE: this REVERTS the working tree -- see the warning block above.
  if ! git stash push -u -m "git-snapshot-${TS}" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to stash changes (diff was computed but not yet written to $PATCH_PATH)" >&2
    rm -f "$PATCH_TMP"
    exit 1
  fi
  STASH_REF=$(git stash list | head -1 | cut -d: -f1)
fi
```

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` — mode dispatch, marker heredoc,
  stdout report line
- `.gitignore` (repo root) — add `**/untracked-backup-*/`

**Verification**:
- `bash -n` exits 0
- In the Phase 6 scratch repo: after `--no-revert`, `git status --porcelain` is byte-identical
  to its pre-run value, the modified tracked file still contains its modification, and the
  untracked file still exists at its original path
- `git stash list` shows one new `git-snapshot-{ts}` entry after `--no-revert`
- `${TASK_DIR}/untracked-backup-{ts}/` contains a copy of the untracked file
- The marker file contains an `UNTRACKED_BACKUP=` line and the guard hook still parses its
  `TIMESTAMP=` (spot-check with `grep -m1 '^TIMESTAMP=' <marker>`)

---

### Phase 4: Update rollback-ladder (family 1) call sites [COMPLETED]

**Goal**: The four bare-invocation sites pass a task number and state that the default mode
reverts — while keeping the default mode, which is correct for this family.

**Territory**: `hooks/guard-destructive-git.sh`, `rules/git-workflow.md`,
`agents/general-implementation-hard-agent.md` (the rung-(c) region near line 71 only),
`skills/skill-orchestrate-hard/SKILL.md`, `context/contracts/recovery.md`. All under
`agent-system/extensions/core/`.

**Tasks**:
- [x] Edit 4.1 — `hooks/guard-destructive-git.sh`. Replace the two quoted lines: *(completed)*
      ```
      echo "Run 'bash .claude/scripts/git-snapshot.sh' first to take a recoverable snapshot" >&2
      echo "(writes a .patch under the task directory + a stash backup), then retry the command." >&2
      ```
      with:
      ```
      echo "Run 'bash .claude/scripts/git-snapshot.sh <task-number>' first to take a recoverable" >&2
      echo "snapshot (writes a .patch under the task directory + a stash backup), then retry." >&2
      echo "Pass the task number explicitly: the no-argument form only resolves when exactly one" >&2
      echo "task in specs/state.json is 'implementing', which does not hold with several in flight." >&2
      echo "The default mode REVERTS the working tree -- intended here, immediately before a" >&2
      echo "destructive command. Use --no-revert only if you intend to keep working afterwards." >&2
      ```
- [x] Edit 4.2 — `rules/git-workflow.md`, exemption item 2. Replace the quoted lines: *(completed)*
      ```
      `specs/{NNN}_{SLUG}/` plus a belt-and-suspenders `git stash` (default mode) or a
      WIP commit on a scratch branch (`--branch` mode), then refreshes a short-lived,
      ```
      with:
      ```
      `specs/{NNN}_{SLUG}/` plus a belt-and-suspenders `git stash` (default mode), a
      WIP commit on a scratch branch (`--branch` mode), or a non-mutating stored stash plus
      an `untracked-backup-{ts}/` copy (`--no-revert` mode), then refreshes a short-lived,
      ```
- [x] Edit 4.3 — `rules/git-workflow.md`, the bare-invocation instruction. Replace the quoted
      lines: *(completed)*
      ```
      Before any intentional rollback that would otherwise be blocked, run
      `bash .claude/scripts/git-snapshot.sh` first, then retry the destructive command.
      ```
      with:
      ```
      Before any intentional rollback that would otherwise be blocked, run
      `bash .claude/scripts/git-snapshot.sh <task-number>` first, then retry the destructive
      command. Pass the task number explicitly — the no-argument form only resolves when
      exactly one task in `specs/state.json` has status `implementing`, which does not hold
      when several tasks are in flight at once.

      **The default and `--branch` modes both REVERT the working tree.** Both leave it clean
      at HEAD, with the uncommitted edits recoverable only from the reported patch, stash, or
      branch; `--branch` changes the recovery handle, not whether the revert happens. That is
      the intended behavior at this call site, because the snapshot sits immediately before an
      already-decided destructive command. For a purely defensive checkpoint where work
      continues afterwards, use `--no-revert`, which leaves the tree untouched.
      ```
- [x] Edit 4.4 — `agents/general-implementation-hard-agent.md`, rung (c). Replace the quoted
      lines: *(completed)*
      ```
      - **Rung (c) snapshot-then-smallest-scope-rollback** — only if rollback is truly required;
        snapshot first via `bash .claude/scripts/git-snapshot.sh` before any destructive git command.
      ```
      with:
      ```
      - **Rung (c) snapshot-then-smallest-scope-rollback** — only if rollback is truly required;
        snapshot first via `bash .claude/scripts/git-snapshot.sh {task_number}` before any
        destructive git command. Pass `{task_number}` explicitly — the no-argument form only
        resolves when exactly one task is `implementing`. The default mode REVERTS the working
        tree, which is correct here because a destructive command follows immediately.
      ```
- [x] Edit 4.5 — `skills/skill-orchestrate-hard/SKILL.md`, Recovery Discipline slot. Within *(completed)*
      the quoted contract-slot line beginning `5. Recovery Discipline:`, replace the substring:
      ```
      snapshot first via 'bash .claude/scripts/git-snapshot.sh', then use the smallest revert scope.
      ```
      with:
      ```
      snapshot first via 'bash .claude/scripts/git-snapshot.sh $task_number' (pass the task number explicitly; the default mode REVERTS the working tree, which is correct immediately before a rollback -- use --no-revert only when you intend to keep working), then use the smallest revert scope.
      ```
      `$task_number` is confirmed in scope: `build_hard_mode_prompt_context()` is an
      `echo "..."` double-quoted string that already interpolates `$next_phase` and
      `$phases_completed`, and `task_number` is assigned earlier in the same skill from
      `.task_context.task_number`. Verify this by quoted text before editing.
- [x] Edit 4.6 — `context/contracts/recovery.md`, rung (c) step 1. Replace the quoted line: *(completed)*
      ```
      1. **Snapshot first.** Run `bash .claude/scripts/git-snapshot.sh [--branch] [TASK]`
      ```
      with:
      ```
      1. **Snapshot first.** Run `bash .claude/scripts/git-snapshot.sh <TASK>` — pass TASK
         explicitly rather than relying on inference, which only resolves when exactly one task
         is `implementing`. The default mode reverts the working tree, which is the intended
         handoff here; `--branch` does NOT avoid that revert (it only changes the recovery
         handle from a stash entry to a branch), and `--no-revert` is for defensive checkpoints
         where work continues, not for this rung.
      ```
      Keep the following numbered-list lines (`(`.claude/scripts/git-snapshot.sh`) before any
      destructive git operation. ...`) intact, re-indenting only as needed so the list renders.
- [x] Confirm no new task-number citation was introduced in any edited file. *(completed:
      verified via `git diff | grep '^+' | grep -i "task [0-9]"` returning empty)*

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — blocked-command advice
- `agent-system/extensions/core/rules/git-workflow.md` — exemption item 2 and the rollback
  instruction
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — rung (c)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` — Recovery Discipline
  contract slot
- `agent-system/extensions/core/context/contracts/recovery.md` — rung (c) step 1

**Verification**:
- `bash -n agent-system/extensions/core/hooks/guard-destructive-git.sh` exits 0
- `grep -rn "git-snapshot.sh'" agent-system/extensions/core/` returns no bare-invocation form
  (no `git-snapshot.sh` immediately followed by a closing quote/backtick with no argument) in
  any of the five edited files
- `grep -rn "task [0-9]" ` over the five edited files introduces no new matches versus the
  pre-edit baseline

---

### Phase 5: Route defensive-checkpoint (family 2) call sites to `--no-revert` [NOT STARTED]

**Goal**: The CHECKPOINT-BEFORE-OVERFLOW family — where the agent snapshots, writes a handoff,
and stops, and where a successor needs the work still present — stops reverting the tree.

**Territory**: `context/patterns/checkpoint-before-overflow.md`,
`agents/general-research-agent.md`, `agents/general-research-hard-agent.md`,
`agents/general-implementation-agent.md`,
`agents/general-implementation-hard-agent.md` (the Stage 4C region near line 217 only — a
different region from Phase 4's rung (c) edit).

Scope note: the research report's family-2 list named `checkpoint-before-overflow.md` Stage 4C,
`general-implementation-agent.md`, and `general-implementation-hard-agent.md`. The two
research-agent sites are the *same* CHECKPOINT-BEFORE-OVERFLOW git-checkpoint step, verbatim
("If dirty and RED (or green cannot be confirmed), run ... instead"), so they belong to family 2
as well and are included here.

**Tasks**:
- [ ] Edit 5.1 — `context/patterns/checkpoint-before-overflow.md`, the code block. Replace the
      quoted line ```  bash .claude/scripts/git-snapshot.sh {task_number}``` (inside the fenced
      bash block) with:
      ```
        bash .claude/scripts/git-snapshot.sh --no-revert {task_number}
      ```
- [ ] Edit 5.2 — same file, the prose immediately after that block. Replace the quoted lines:
      ```
      This writes a durable `working-progress-{ts}.patch` under the task directory and (belt-and-
      suspenders) an in-repo `git stash push -u`, without dropping either. Capture whichever
      reference(s) the script reports — the patch path, the `stash@{N}` ref, and/or (with
      `--branch`) the `wip-snapshot-{ts}` branch name — for the handoff's Current State. On a clean
      tree the script itself is a no-op; this branch only runs it when the tree is dirty and RED, so
      that no-op case does not apply here.
      ```
      with:
      ```
      This writes a durable `working-progress-{ts}.patch` under the task directory, records a
      belt-and-suspenders stash entry, and copies untracked files to
      `untracked-backup-{ts}/`. Capture whichever reference(s) the script reports — the patch
      path, the `stash@{N}` ref, and the untracked-backup directory — for the handoff's Current
      State. On a clean tree the script itself is a no-op; this branch only runs it when the tree
      is dirty and RED, so that no-op case does not apply here.

      **`--no-revert` is required at this call site.** The script's default mode runs
      `git stash push -u`, which leaves the working tree clean at HEAD — the RED work this step
      exists to protect would disappear from the working directory, and the successor picking up
      the handoff would find nothing to resume from. `--branch` does not help: it commits the
      dirty tree to a scratch branch and then checks the original branch back out, which reverts
      the tree exactly as much as the stash path does. Only `--no-revert` leaves the tree intact.
      ```
- [ ] Edit 5.3 — same file, the decision table. Replace the quoted row:
      ```
      | Dirty | No / RED | `bash .claude/scripts/git-snapshot.sh {task_number}` |
      ```
      with:
      ```
      | Dirty | No / RED | `bash .claude/scripts/git-snapshot.sh --no-revert {task_number}` |
      ```
- [ ] Edit 5.4 — same file, the handoff reference string. Replace the quoted lines:
      ```
      - Snapshot path: `**Git checkpoint**: RED tree snapshotted via git-snapshot.sh — patch:
        {working-progress-{ts}.patch path}, stash: {stash@{N} or NONE}, branch: {wip-snapshot-{ts} or
        NONE}`
      ```
      with:
      ```
      - Snapshot path: `**Git checkpoint**: RED tree snapshotted via git-snapshot.sh --no-revert
        — patch: {working-progress-{ts}.patch path}, stash: {stash@{N} or NONE},
        untracked-backup: {untracked-backup-{ts} path or NONE}; working tree left intact`
      ```
- [ ] Edit 5.5 — `agents/general-research-agent.md`. Replace the quoted fragment
      ```
      `bash .claude/scripts/git-snapshot.sh {task_number}` instead. Record the resulting reference
      ```
      with
      ```
      `bash .claude/scripts/git-snapshot.sh --no-revert {task_number}` instead (`--no-revert`
      keeps the tree intact for the successor; the default and `--branch` modes both revert it).
      Record the resulting reference
      ```
- [ ] Edit 5.6 — `agents/general-research-hard-agent.md`. Apply the identical replacement as
      Edit 5.5 (the surrounding sentence is verbatim the same).
- [ ] Edit 5.7 — `agents/general-implementation-agent.md`, Stage 4C. Within the quoted
      single-line step beginning `1. **Git checkpoint** (CHECKPOINT-BEFORE-OVERFLOW`, replace
      the substring:
      ```
      run `bash .claude/scripts/git-snapshot.sh {task_number}` instead of committing broken state.
      ```
      with:
      ```
      run `bash .claude/scripts/git-snapshot.sh --no-revert {task_number}` instead of committing broken state (`--no-revert` is required here: the default and `--branch` modes both leave the tree clean at HEAD, erasing the very RED work this step protects).
      ```
- [ ] Edit 5.8 — `agents/general-implementation-hard-agent.md`, Stage 4C sub-section. Replace
      the quoted lines:
      ```
      After the base Stage 4C git-checkpoint step (commit if green,
      `bash .claude/scripts/git-snapshot.sh {task_number}` if RED — see
      ```
      with:
      ```
      After the base Stage 4C git-checkpoint step (commit if green,
      `bash .claude/scripts/git-snapshot.sh --no-revert {task_number}` if RED — see
      ```
      In the same sentence, replace the reference list
      ```
      `working-progress-*.patch` path, a `stash@{N}` ref, or a `wip-snapshot-{ts}` branch name)
      ```
      with
      ```
      `working-progress-*.patch` path, a `stash@{N}` ref, or an `untracked-backup-{ts}` path)
      ```
- [ ] Confirm the Phase 4 edit to `general-implementation-hard-agent.md` (rung (c), near the
      top of the file) is still intact and untouched by this phase's edits.

**Timing**: 1 hour

**Depends on**: 3, 4

**Files to modify**:
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md` — code block,
  prose, decision table, handoff reference string
- `agent-system/extensions/core/agents/general-research-agent.md` — Stage 4C checkpoint step
- `agent-system/extensions/core/agents/general-research-hard-agent.md` — same step
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Stage 4C step 1
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — Stage 4C
  git-checkpoint sub-section

**Verification**:
- `grep -rn "git-snapshot.sh {task_number}" agent-system/extensions/core/` returns zero
  matches without a preceding `--no-revert` (every family-2 site now names the mode)
- `grep -rn "no-revert" agent-system/extensions/core/` shows exactly the expected set of files
- The decision table row and the fenced code block in `checkpoint-before-overflow.md` agree on
  the same command string

---

### Phase 6: Scratch-repo verification matrix [NOT STARTED]

**Goal**: Prove all four modes and the failure paths behave as documented, without ever
touching this repository's working tree.

**SAFETY CONTRACT — read before any command.** The research report records an incident where a
reproduction attempt fell through to this repository because a `cd` silently failed. Every
verification command in this phase MUST:
- run inside a scratch git repo created under the scratchpad directory, using absolute paths;
- be preceded, in the same shell invocation, by an assertion that aborts if the working
  directory is not the scratch repo, e.g.
  `cd /abs/scratch/repo || exit 1; case "$(git rev-parse --show-toplevel)" in /abs/scratch/repo) ;; *) echo ABORT >&2; exit 1;; esac`
- never invoke `git-snapshot.sh` with this repository as the working directory.

Run the **source-store** script directly
(`bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/git-snapshot.sh`).
Do **not** copy it into `.claude/` — that directory is a disposable deploy artifact regenerated
by the Neovim-side extension picker, and syncing it is not part of this task.

**Tasks**:
- [ ] Build the harness: scratch repo with an initial commit, `specs/001_scratch/` directory,
      a `specs/state.json` fixture, one modified tracked file, and one untracked file.
- [ ] Case A (default mode): dirty tree -> run with an explicit task number. Assert: pre-op
      WARNING and post-op RESET blocks on stderr; the five original stdout lines byte-identical
      to the pre-change script's format; `git status --porcelain` now empty; `stash@{0}` exists;
      patch and marker written.
- [ ] Case B (`--branch`): reset the fixture, run with `--branch`. Assert: tree also ends clean
      (this is the research finding, re-confirmed as a regression guard); branch
      `wip-snapshot-*` exists; the pre-op WARNING fired for branch mode too.
- [ ] Case C (`--no-revert`): reset the fixture, capture `git status --porcelain` and the
      tracked file's content beforehand. Run with `--no-revert`. Assert: `git status
      --porcelain` byte-identical to the captured value; the modification still present in the
      tracked file; the untracked file still at its original path; a new `git-snapshot-*` stash
      entry exists; `untracked-backup-*/` contains the untracked file; marker contains both
      `TIMESTAMP=` and `UNTRACKED_BACKUP=`.
- [ ] Case D (`--no-revert` with untracked-only dirt): assert `git stash create` printing
      nothing is handled — `STASH_REF` is `NONE`, the run still exits 0, and the untracked
      backup is still made.
- [ ] Case E (failure paths): `--help` exits 0 with usage; `--branh` exits 1 with
      `unrecognized option`; `--branch --no-revert` exits 1 with the mutual-exclusion message;
      no-arg with zero `implementing` tasks in the fixture names the zero-match reason; no-arg
      with two `implementing` tasks names the ambiguity and lists both numbers; a nonexistent
      task number names the missing-directory reason.
- [ ] Case F (clean tree): assert the no-op path still exits 0, prints the original message,
      and writes no marker — in all three modes.
- [ ] Case G (marker contract): assert the guard hook's parse expression
      `grep -m1 '^TIMESTAMP=' <marker> | cut -d= -f2` still yields an integer for markers from
      all three modes.
- [ ] Delete the scratch repo. Assert this repository's `git status --porcelain` is unchanged
      from its pre-phase value and that no `wip-snapshot-*` branch and no new stash entry exist
      here.

**Timing**: 1 hour

**Depends on**: 3, 4, 5

**Files to modify**:
- None in the repository. Harness scripts live in the scratchpad directory only.

**Verification**:
- All seven cases pass
- This repository's `git status --porcelain`, `git branch --list 'wip-snapshot-*'`, and
  `git stash list` are unchanged from their pre-phase values

---

## Testing & Validation

- [ ] `bash -n` passes on `git-snapshot.sh` and `guard-destructive-git.sh`
- [ ] Default-mode stdout is byte-identical in format to the pre-change script (five lines,
      same labels, same order); all new messaging is on stderr
- [ ] `--no-revert` leaves `git status --porcelain` byte-identical
- [ ] `--no-revert` coverage is at parity with default mode: tracked changes in a real stash
      entry, untracked files in `untracked-backup-{ts}/`, both plus the patch
- [ ] Every resolution-failure path names a specific reason, and the two-concurrent-tasks case
      lists the candidate task numbers
- [ ] No bare `git-snapshot.sh` invocation remains anywhere in
      `agent-system/extensions/core/`
- [ ] Every family-2 call site specifies `--no-revert`; no family-1 call site does
- [ ] No file outside `specs/**` was edited under `.claude/`
- [ ] No new task-number citations introduced outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-snapshot.sh` (rewritten usage, arg parsing,
  diagnostics, warnings, `--no-revert` mode, marker key)
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (blocked-command advice)
- `agent-system/extensions/core/rules/git-workflow.md`
- `agent-system/extensions/core/context/contracts/recovery.md`
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/agents/general-research-hard-agent.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- `.gitignore` (repo root, one added pattern)
- `specs/894_fix_git_snapshot_silent_revert_footgun/summaries/01_git-snapshot-revert-footgun-summary.md`

## Rollback/Contingency

Every change is additive text in tracked files; nothing is deleted or migrated, and no
existing mode's behavior changes. Each phase is committed separately per the
commit-per-green-substep mandate, so any phase can be reverted with a targeted
`git revert <sha>` without disturbing the others.

Ordered fallbacks if a phase cannot land:

1. **Phase 3 (`--no-revert`) fails or proves unreliable**: drop Phase 3 and Phase 5, keep
   Phases 1, 2, 4, and 6. Phases 1-2 alone deliver the research report's stated *primary*
   fix (loud warnings plus a richer failure message) and are independently valuable. Remove
   the `--no-revert` references from the Phase 1 usage text and the Phase 4 doc edits before
   committing, so the docs never advertise a mode that does not exist.
2. **`git stash create` + `store` behaves unexpectedly on this git version**: fall back within
   Phase 3 to patch-plus-untracked-copy only, setting `STASH_REF=NONE` in `--no-revert` mode.
   Coverage is then patch + untracked copy, which is still strictly better than losing the
   tree; document the reduced coverage in the usage block.
3. **A call-site edit breaks a consumer**: revert only that phase's commit. Phases 4 and 5 are
   pure documentation/prompt text and carry no runtime dependency on Phases 1-3.

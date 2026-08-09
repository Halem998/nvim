# Research Report: Task #894

**Task**: 894 - Fix git-snapshot.sh silent-revert footgun and unhelpful missing-argument failure
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: medium (doc/message-only fix; optional new flag is a separate, bounded follow-on)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` (source-store script, read in full)
- All 12 source-store files that reference `git-snapshot.sh` (grep + read of surrounding context)
- `agent-system/extensions/core/hooks/guard-destructive-git.sh`
- `specs/state.json` (live evidence of concurrent multi-task "researching"/"implementing" status)
- Controlled git experiment reproducing `--branch` mode's tree effect (see Findings)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md (honored: no task-number citations below)

## Executive Summary

- **`--branch` mode does NOT avoid the revert.** A controlled reproduction (see Findings)
  confirms that after `--branch` mode's own documented sequence — commit dirty changes to a
  scratch branch, then `git checkout` back to the original branch — the working tree ends up
  exactly as clean/reverted as the default stash mode. The task's premise that `--branch`
  "already avoids the revert" does not hold; only the *recovery mechanism* differs (a
  checkout-able branch vs. a stash entry), not the tree-mutation outcome. Surfacing/defaulting to
  `--branch` as "the non-destructive path" would therefore be recommending something that does
  not solve the underlying problem, and risks papering over it.
- **The missing-argument failure is not an unconditional requirement** — `resolve_task_dir()`
  already infers the task from `specs/state.json` when no argument is given, succeeding whenever
  exactly one task has `status == "implementing"`. It fails (falling through to the generic
  "could not resolve a task directory" message) whenever that invariant doesn't hold: zero
  matches, 2+ concurrent "implementing" tasks, no `jq`, or a missing `specs/state.json`. Live
  `specs/state.json` at research time shows 3 tasks (892, 893, 894) simultaneously
  `"status": "researching"` under the SAME orchestrator's multi-task/parallel operation model —
  concrete evidence that multiple tasks in `"implementing"` at once is a realistic, not
  hypothetical, occurrence in this repo, which is exactly the condition that breaks the
  count-must-equal-1 heuristic.
- Of the 12 source-store files that reference the script, **4 contain literal bare-invocation
  instruction text** (no task-number argument shown): `general-implementation-hard-agent.md:71`,
  `git-workflow.md:154`, `guard-destructive-git.sh:216`, and
  `skill-orchestrate-hard/SKILL.md:546`. The latter two are the most likely root causes of "two
  different phase agents hit this in one session": `guard-destructive-git.sh:216` is the hook's
  own auto-emitted stderr advice on every blocked destructive command, and
  `skill-orchestrate-hard/SKILL.md:546` is baked verbatim into the Recovery Discipline slot of
  every hard-mode phase-dispatch prompt.
- Recommended fix is additive and low-risk: (1) loud pre-op and post-op warnings plus an
  expanded usage block documenting the revert; (2) a richer missing-argument message that states
  *why* resolution failed and shows both invocation forms; (3) do NOT change the default mode or
  rename the script now. A genuinely non-destructive `--no-revert` flag is justified (per the
  task's own "only if `--branch` proves insufficient" test, which it does) but should land as a
  new opt-in flag, not a default change, because the 12 existing call sites split into two
  semantically different families — see Findings and Recommendations.

## Context & Scope

Researched the two-part defect in `agent-system/extensions/core/scripts/git-snapshot.sh` (the
SOURCE STORE — all line numbers below are re-derived against this file, not the gitignored
`.claude/` deploy copy, which was confirmed byte-identical via `diff -q`):

(a) unhelpful failure when invoked with no task argument, and
(b) the default mode's `git stash push -u` silently resetting the working tree, with the name
    "snapshot" implying non-destructive, read-only behavior.

Per the task's explicit instruction, `--branch` mode (already present) was evaluated as a
possible existing fix before considering any new flag, and every call site across the source
store was enumerated so any behavior/default change can be checked against real callers.

## Findings

### The script, verified against the source store

`agent-system/extensions/core/scripts/git-snapshot.sh` — all cited line numbers current as read:

- Usage/header comment block: lines 33–52. `--branch` documented at lines 34/38–40; default mode
  documented at lines 42–45, including the literal sentence "runs `git stash push -u`
  (untracked-inclusive, without drop) as a belt-and-suspenders in-repo copy" at line 43.
- Arg parsing loop (only `--branch` is recognized as a flag; anything else, including a typo like
  `--branh`, silently falls into `TASK_ARG`): lines 56–68.
- `resolve_task_dir()`: lines 71–108. Empty-arg branch (lines 91–105) queries
  `jq -r '.active_projects[] | select(.status=="implementing") | .project_number' specs/state.json`
  and only succeeds when exactly one match exists (`count == 1` at line 96).
- Unresolved-task-dir failure: lines 111–115 (`exit 1` at :114). Current message:
  ```
  git-snapshot.sh: could not resolve a task directory.
    Pass it explicitly: git-snapshot.sh [--branch] <task-number-or-specs-dir>
  ```
  This already prints *a* one-line usage hint, but not *why* resolution failed (no `jq`? no
  `specs/state.json`? zero matches? multiple matches, and if so which task numbers?) — matching
  the task's "fails unhelpfully" characterization even though it is not a bare `exit 1` with no
  guidance at all.
- Clean-tree no-op: lines 118–121 (`exit 0` at :120, by design — nothing to protect).
- Diff computed to a scratch tmpfile *before* the stash/branch step, specifically to avoid the
  patch file itself being swept up by `git stash push -u`: lines 128–137 (`exit 1` at :136).
- `--branch` mode: lines 142–158 (`exit 1` at :148, :153, :157) — creates
  `wip-snapshot-{ts}`, commits with `git add -A` + `git commit`, then checks out the original
  branch.
- Default mode: lines 159–168 — `git stash push -u -m "git-snapshot-${TS}"` at line 162;
  `STASH_REF` captured via `git stash list | head -1 | cut -d: -f1` at line 167.
- Patch moved into place + marker written: lines 170–185.
- Success output: lines 187–192, echoing patch/stash/branch/marker paths (`STASH_REF` echoed at
  :189) — but nothing in this output states in plain language that the working tree was just
  reset.

All five task-cited exit points (`:114, :136, :148, :153, :157`) and the header/stash/STASH_REF
line numbers (`:43, :162, :167, :189`) are confirmed exact against the current source-store file.

### `--branch` mode does not avoid the revert (verified by direct reproduction)

The task description explicitly warned against prejudging a new flag and asked to evaluate
`--branch` as a possible complete fix first. It was evaluated concretely, not assumed. A minimal
git repo was built and both the default sequence and the `--branch` sequence were run by hand,
mirroring the script's own logic (`git checkout -b <branch>` → stage+commit the dirty files →
`git checkout <original>`):

```
=== status BEFORE branch-mode snapshot ===
 M tracked.txt
?? new_untracked.txt
Switched to a new branch 'wip-snapshot-test'
Switched to branch 'master'
=== status AFTER returning to original branch ===
(empty — tree is clean)
=== tracked.txt contents on original branch ===
line1                      <- the "MODIFIED" line is gone
=== does new_untracked.txt exist on original branch? ===
ls: cannot access 'new_untracked.txt': No such file or directory
GONE - reverted, same as stash mode
```

This is expected git behavior, not a bug in the reproduction: once the dirty changes are
committed onto the scratch branch, `git checkout <original branch>` updates the working tree to
match the original branch's tip — which lacks those changes — so modified files revert and newly
added files disappear from the working directory. The *recovery path* differs from stash mode
(a named, `git branch`-visible commit vs. a `stash@{N}` entry, which arguably is more durable and
discoverable — stashes can be silently pruned by `git gc` in ways branches generally are not, and
`--branch` is immune to being confused with unrelated stash activity elsewhere in the same
session), but the caller-visible symptom the task is about — the working tree changes vanish
without warning — is identical in both modes.

**Consequence**: recommending `--branch` as "the non-destructive path" (per the task's outcome
(3) framing) would be inaccurate and should not be done. The task's own fallback condition —
"only if `--branch` proves insufficient should a `--no-revert` mode be added" — is satisfied:
`--branch` is insufficient, so a real non-destructive mode is the only way to eliminate the tree
mutation itself.

### Call-site enumeration (all references to `git-snapshot.sh` in the source store)

12 files reference the script. Grouped by how they invoke/describe it:

**Invocation shown WITH a task-number placeholder (6 sites — safe today, no change needed):**
| File:line | Context |
|---|---|
| `agents/general-research-agent.md:164` | CHECKPOINT-BEFORE-OVERFLOW git-checkpoint step |
| `agents/general-research-hard-agent.md:177` | Same, hard-mode research |
| `agents/general-implementation-agent.md:321` | Stage 4C context-pressure handoff, "if dirty and RED" |
| `agents/general-implementation-hard-agent.md:217` | Same handoff step, hard-mode, cross-referenced into `.orchestrator-handoff.json`'s `git_checkpoint` field |
| `context/patterns/checkpoint-before-overflow.md:85` | Code block in the "Dirty tree, RED" branch |
| `context/patterns/checkpoint-before-overflow.md:100` | Decision table row |

**Bare invocation, no argument shown (4 sites — the concrete risk vectors for defect (a)):**
| File:line | Context |
|---|---|
| `agents/general-implementation-hard-agent.md:71` | Prose: "snapshot first via `bash .claude/scripts/git-snapshot.sh` before any destructive git command" (Recovery ladder rung c) |
| `rules/git-workflow.md:154` | "Before any intentional rollback that would otherwise be blocked, run `bash .claude/scripts/git-snapshot.sh` first, then retry the destructive command." |
| `hooks/guard-destructive-git.sh:216` | The guard hook's own `stderr` advice, auto-emitted on EVERY blocked destructive command: `echo "Run 'bash .claude/scripts/git-snapshot.sh' first to take a recoverable snapshot"` |
| `skills/skill-orchestrate-hard/SKILL.md:546` | Literal text inside `build_hard_mode_prompt_context()`'s "Recovery Discipline" contract slot — injected verbatim into every hard-mode phase-dispatch prompt |

The last two are the strongest candidates for the observed "two different phase agents hit this
in one session": `guard-destructive-git.sh:216` fires automatically and unconditionally whenever
any agent trips the destructive-git guard on a dirty tree (no task-number context available to
the hook to include), and `skill-orchestrate-hard/SKILL.md:546` is copied into every hard-mode
phase agent's dispatch prompt, so any two phases that each hit a RED/rollback situation would
each see and could each literally type the same bare command.

**Documents `TASK` as explicitly optional (1 site):**
| File:line | Context |
|---|---|
| `context/contracts/recovery.md:63` | `` bash .claude/scripts/git-snapshot.sh [--branch] [TASK] `` — the bracketed `[TASK]` sanctions omission, relying on the same state.json inference |

**Descriptive mention, not an instruction to type a command (1 site):**
| File:line | Context |
|---|---|
| `rules/git-workflow.md:146` | Explains what satisfies the guard hook's snapshot exemption; not phrased as "run this" |

**Non-invocation cross-references (not call sites; found but out of scope for behavior change):**
`manifest.json:109` (script listing), `context/patterns/task-lock.md:73`,
`context/patterns/checkpoint-before-overflow.md:11,126,129,132,169`,
`scripts/task-lock.sh:45`, `hooks/guard-destructive-git.sh:24,41,44,194`.

**No call site invokes the script with an unrecognized flag or `--help`** — there is no `--help`
handling at all; an unrecognized token is silently absorbed into `TASK_ARG` and, if it doesn't
match a directory or a bare integer, falls through to the same "could not resolve a task
directory" message. Worth a minor, low-cost fix alongside the others.

### Two distinct call-site *semantic families* — relevant to whether the default should change

Reading the surrounding context of all 12 references reveals two genuinely different intended
uses, which matters for any default-behavior recommendation:

1. **Rollback-ladder / pre-destructive-op family** (`recovery.md` rung (c),
   `guard-destructive-git.sh`'s own advice, `git-workflow.md:154`,
   `general-implementation-hard-agent.md:71`, `skill-orchestrate-hard/SKILL.md:546`'s Recovery
   Discipline slot): the snapshot is explicitly a *precursor* to an already-decided, imminent
   destructive git command (`git reset --hard`, forced checkout, etc.). For this family, the
   tree ending up clean/reverted is not a surprise — it's the intended handoff into the
   destructive step that follows immediately after. Today's default behavior is *correct* for
   this family.
2. **Defensive-checkpoint family** (`checkpoint-before-overflow.md` Stage 4C "Dirty tree, RED",
   `general-implementation-agent.md:321`, `general-implementation-hard-agent.md:217`): the
   snapshot is taken because context pressure was detected and the agent is about to write a
   handoff and stop — there is no guaranteed subsequent destructive command. The caller's intent
   here is closer to "just make sure my work is durably backed up" while possibly still wanting
   the tree left as-is for a successor to inspect or resume. This is the family where the
   observed damage occurred (a phase-4 agent's own partial edits vanishing), and it is exactly
   the family for which today's stash-based revert is semantically wrong, not merely
   under-documented.

This split is the key argument against a blanket default change: flipping the default to
non-destructive would be *correct* for family 2 but would silently change behavior relied upon
(even if only implicitly) by family 1's already-working exemption flow with
`guard-destructive-git.sh`.

## Decisions

- **Do not recommend surfacing/defaulting to `--branch` as a fix for the revert.** It was
  evaluated as instructed and does not solve the stated problem (verified by reproduction above).
  It may still be worth documenting as the more durable *recovery* mechanism for the
  rollback-ladder family, but that is a separate, smaller point from "avoids the revert."
- **Do not rename the script now.** The name mismatch is real ("snapshot" implies non-destructive
  in most technical usage, e.g. filesystem/LVM/ZFS snapshots), but a rename only fixes optics: it
  does nothing for the two concrete, cheap-to-fix defects (unhelpful failure message, absence of
  loud warnings), and it carries a real migration cost — 12 files, ~19 distinct
  reference/invocation lines, plus the marker-contract doc comment block in the script's own
  header (lines 11–31) which is cross-referenced by name from `guard-destructive-git.sh` and
  `task-lock.md`. Revisit renaming only if/when a real behavior change (e.g. a new non-destructive
  default) makes the current name newly and additionally misleading in a way documentation can't
  cover — bundling a rename with a pure behavior/messaging fix is not justified by the evidence
  gathered here.
- **Do not change the default mode.** The two-family split above means a default flip would fix
  family 2's footgun while quietly changing the meaning of a `git-snapshot.sh` call for family 1
  call sites that currently pair it with an immediately-following destructive command. This is
  exactly the kind of "default change that breaks existing callers is worse than the footgun"
  risk the task asked to guard against.
- **Do recommend, as the safe/primary fix**: (1) an expanded usage block that states the revert
  plainly, printed on the missing-argument failure path; (2) a pre-op warning line printed
  immediately before the `git stash push -u` / branch-checkout step in default and `--branch`
  modes alike, since both mutate the tree; (3) a post-op line in the success output that says in
  plain language "the working tree was just reset to HEAD; your changes are recoverable via
  STASH_REF / BRANCH_NAME / PATCH_PATH above," not just an unlabeled dump of those values; (4) a
  richer missing-argument message that names the specific resolution failure (no `state.json`,
  no `jq`, zero `"implementing"` tasks, or N candidates found — listing their numbers) instead of
  a single generic line.
- **Do recommend, as a secondary/optional follow-on**: a new opt-in `--no-revert` flag (not
  default) that skips the stash/branch-checkout step entirely, backing up untracked files via a
  plain copy alongside the existing `git diff HEAD` patch instead of relying on `git stash -u`.
  This is a real design/implementation question (exact untracked-file backup mechanism, whether
  `git stash create`+`store` — which does not mutate the tree — can be extended to cover
  untracked files, or whether a manual `cp`-based side-channel is simpler and more robust) that
  belongs in `/plan`, not resolved here. If implemented, the defensive-checkpoint family call
  sites (`checkpoint-before-overflow.md` Stage 4C row, `general-implementation-agent.md:321`,
  `general-implementation-hard-agent.md:217`) are the natural candidates to switch to it; the
  rollback-ladder family should stay on the current default.

## Risks & Mitigations

- **Risk**: adding pre-op/post-op warning text changes the script's stdout/stderr shape, which
  three doc files (`checkpoint-before-overflow.md:112`, and the two agent files that tell an
  agent to "capture whichever reference(s) the script reports") implicitly rely on for parsing
  guidance. **Mitigation**: keep the existing `patch:`/`stash:`/`branch:`/`marker:` line format
  unchanged and byte-compatible; add the plain-language warning as new, additional lines rather
  than rewriting the existing ones, so nothing that currently greps/reads those specific lines
  breaks.
- **Risk**: a richer missing-argument message that enumerates candidate task numbers could leak
  cross-task information into an agent's context inappropriately. **Mitigation**: this is
  low-severity — task numbers and statuses in `specs/state.json` are not sensitive, and the
  `git-snapshot.sh` header already documents the multi-task inference contract; surfacing the
  same information on failure is a diagnostic improvement, not a new exposure.
- **Risk**: if a future `--no-revert` mode is added, callers that continue to invoke the script
  bare from the rollback-ladder family must not accidentally pick up the new flag by mistake
  (e.g., via a global default toggle). **Mitigation**: keep it strictly opt-in (`--no-revert` as
  an explicit third mode alongside `--branch`, mutually exclusive), never a config/env default.

## Appendix

### Search / verification steps performed
- `grep -rn "git-snapshot\.sh"` across `agent-system/` (all extensions, not just core) to find
  every reference; cross-checked against `grep -rn "git-snapshot"` (without `.sh`) to catch
  non-script-path mentions.
- Read the full `git-snapshot.sh` source (193 lines) and confirmed all line numbers cited in the
  task description against the current source-store file (all matched exactly).
- Confirmed `.claude/scripts/git-snapshot.sh` (deployed copy) is byte-identical to the
  source-store file via `diff -q` — the source-store rule holds and there is no drift to reconcile.
- Confirmed `.claude/` is gitignored (`/.claude/` in `.gitignore`, explicit comment "disposable
  build artifact regenerated from" the source store).
- Read `specs/state.json` to confirm multiple tasks can be concurrently non-terminal
  ("researching"/"implementing") in normal operation.
- Reproduced `--branch` mode's tree-mutation behavior in an isolated scratch git repository
  (outside the working tree) to verify, rather than assume, whether it avoids the revert.
- Read the CHECKPOINT-BEFORE-OVERFLOW pattern (`checkpoint-before-overflow.md`) and the recovery
  ladder (`recovery.md`) in full to classify call sites into the two semantic families above.

### One-time incident during research (self-correction, no lasting effect)

While reproducing `--branch` mode, an initial reproduction attempt was mistakenly run against
this repository's own working tree (a scratchpad `cd` silently failed and the command fell
through to the current directory) — a `wip-snapshot-test2` branch was briefly created here. No
commit was made on it (the `git add`/`git commit` steps in that attempt failed before creating
any commit; `git rev-parse` confirmed the branch and `master` pointed to the identical SHA), and
the stray branch was deleted immediately upon discovery. The repository's pre-existing
uncommitted changes (`.claude-extensions.json`, `which-key.lua`, `cli.lua` — present before this
research began) were untouched throughout. Noted here for transparency, not as a task finding.

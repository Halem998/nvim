# Implementation Plan: Task #780

- **Task**: 780 - Agent git-safety: preserve uncommitted work, guard destructive git ops
- **Status**: [NOT STARTED]
- **Effort**: 5-6 hours
- **Dependencies**: None (pairs with 779, 782; blocks 782, 785)
- **Research Inputs**: reports/01_git-safety-preserve-uncommitted-work.md
- **Artifacts**: plans/01_guard-destructive-git-hook.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 780 prevents agents from irreversibly destroying uncommitted work through
destructive git commands (`git reset --hard`, `git checkout -- <path>`, `git restore <path>`,
`git clean -fd`, `git stash drop/clear`, forced `checkout`/`switch`). It adds three coordinated
pieces: (1) a behavioral **rule** in `git-workflow.md`; (2) an enforced **PreToolUse Bash hook**
(`guard-destructive-git.sh`) that blocks destructive commands via `exit 2` + stderr unless the
working tree is clean or a fresh snapshot marker exists; and (3) a lightweight **snapshot helper**
(`git-snapshot.sh`) that writes a recoverable `.patch` under the task directory and refreshes the
marker the hook checks. Definition of done: a dirty-tree `git reset --hard` is blocked, the same
command is allowed after running the helper and on a clean tree, the existing `/todo`
safety-commit + `git reset --hard` flow is NOT broken, and every changed file is updated in
**both** its deployed and extension-source copies so the wiring cannot be silently reverted by a
future sync.

### Research Integration

The research report (`reports/01_git-safety-preserve-uncommitted-work.md`) established the
concrete contracts this plan follows:
- **Hook model**: `.claude/hooks/block-pr-submission.sh` is the exact precedent — PreToolUse
  matcher `"Bash"`, reads `tool_input.command` from stdin JSON, blocks via **`exit 2` + stderr**
  (NOT `permissionDecision: deny`, which is documented-buggy for allow-listed `Bash(git:*)` —
  GH issues #4669/#13214/#18312), early `exit 0` on empty/non-Bash input, anchored `grep -qE`
  patterns `(^|[;&|] *)`.
- **Marker model**: `subagent-postflight.sh`'s `.postflight-pending` (task-scoped, gitignored,
  discovered via `find specs -maxdepth 3`). The snapshot marker adds freshness (timestamp window)
  + delete-on-use semantics.
- **Critical dual-copy hazard (verified live)**: `block-pr-submission.sh` was registered in
  `.claude/settings.json` only (task 696), then silently reverted when task 710 regenerated
  `settings.json` from the un-updated `.claude/extensions/core/root-files/settings.json`. It is
  still unregistered today and absent from `.claude/extensions/core/hooks/` and
  `manifest.json` `provides.hooks`. Every file this task touches exists in a deployed copy AND an
  extension-source copy; both must be updated.
- **Exemption hazard**: `.claude/context/standards/git-safety.md` already sanctions
  `git reset --hard {sha}` + `git clean -fd` after a same-branch safety commit (used by `/todo`).
  The hook's exemption logic must recognize this pattern (clean-tree-first check handles it,
  since the safety commit makes the tree clean before the reset) so `/todo` is not broken.

Verified during planning: `.claude/scripts/` is ALSO dual-sourced (deployed `.claude/scripts/` +
`.claude/extensions/core/scripts/` + `manifest.json` `provides.scripts`), so the helper script
needs the same dual-copy treatment as the hook. `settings.json` PreToolUse currently contains
only a `Write` matcher entry — a new `Bash` matcher entry must be appended, not replaced.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (meta task, no roadmap_flag set).

## Goals & Non-Goals

**Goals**:
- Add a "no destructive git on uncommitted work" section to `git-workflow.md` (both copies) that
  enumerates the forbidden commands and the snapshot-first exemption.
- Create `guard-destructive-git.sh` PreToolUse Bash hook that blocks destructive git patterns on a
  dirty tree unless a fresh snapshot marker exists, allows everything on a clean tree, and never
  blocks non-Bash / malformed input.
- Create `git-snapshot.sh` helper that writes a durable `.patch` under `specs/{NNN}_{SLUG}/`,
  optionally stashes / WIP-commits, and writes/refreshes the gitignored freshness marker.
- Wire all three into BOTH deployed and extension-source locations (hook script x2 + manifest
  `provides.hooks`; helper script x2 + manifest `provides.scripts`; rule x2; `settings.json` x2),
  and gitignore the marker.
- Verify the hook blocks a dirty-tree `reset --hard`, allows it post-snapshot and on a clean tree,
  and does not break the `/todo` safety-commit rollback flow.

**Non-Goals**:
- Restoring `block-pr-submission.sh`'s own broken wiring — research flags this as an adjacent but
  out-of-scope follow-up (may be folded in as a drive-by only if the implementer judges it
  trivial; not required for this task's completion).
- Creating a consolidated `.claude/docs/reference/hooks-contract.md` — flagged by research as an
  optional future context extension, out of scope here.
- Guarding non-git destructive commands (`rm -rf`, etc.) — this task is scoped to git operations.
- Changing the tasks 779/782 workflows (fix-forward, targeted staging) that build on this.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New hook/rule/script registered in only one of the two copies, silently reverted by next sync (the exact `block-pr-submission.sh` failure) | H | M | Phase 4 is a dedicated dual-copy wiring phase with an explicit checklist; Phase 5 verifies with `diff` on every pair and `jq` on manifest lists |
| Overly broad patterns false-block legitimate clean-tree ops or benign quoted substrings | H | M | Run `git status --porcelain` clean-tree check FIRST and `exit 0` immediately if clean; reuse anchored `(^|[;&|] *)` pattern style from `block-pr-submission.sh` |
| Hook breaks `/todo`'s sanctioned safety-commit + `git reset --hard`/`git clean -fd` flow | H | M | Safety commit makes tree clean before the reset, so clean-tree-first check exempts it automatically; Phase 5 explicitly tests this flow |
| Stale marker silently authorizes a later unrelated destructive command | M | M | Freshness window (e.g. 120s) + delete-on-use (single-shot) marker semantics |
| Parse failure or non-Bash input accidentally blocks a tool call | H | L | Early `exit 0` guard when `tool_input.command` is empty, mirroring `block-pr-submission.sh` |
| Marker file accidentally committed as an artifact | L | L | Add marker pattern to `.gitignore` (mirrors `**/.postflight-pending`); keep durable `.patch` separate (tracked, under task dir) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Snapshot marker contract + helper script [COMPLETED]

**Goal**: Define the snapshot-marker format and implement the `git-snapshot.sh` helper that
produces a recoverable snapshot and writes the marker the hook will check.

**Tasks**:
- [x] Define the marker contract (documented as a comment block in the helper): filename
      `.git-snapshot-marker`, task-scoped under `specs/{NNN}_{SLUG}/`, content = ISO/epoch
      timestamp + `HEAD` sha + patch path; freshness window (recommend 120s); delete-on-use.
      *(completed: contract documented at top of git-snapshot.sh, freshness window 120s specified
      for the hook to enforce in Phase 2)*
- [x] Create `.claude/scripts/git-snapshot.sh` (executable, `chmod +x`) that:
  - [x] Runs `git status --porcelain`; if clean, prints "nothing to snapshot" and exits 0 (no marker written).
  - [x] Default mode: `git diff HEAD > specs/{NNN}_{SLUG}/working-progress-{ts}.patch` (task dir
        inferred from active task or passed as `$1`) AND `git stash push` (without drop) as a
        belt-and-suspenders in-repo copy. *(altered: diff is captured to a scratch mktemp file
        first, then moved into the task dir AFTER the stash step — writing the patch into
        $TASK_DIR before `git stash push -u` would make the patch itself an untracked file that
        the stash immediately sweeps away, and can delete $TASK_DIR if it had no other tracked
        contents; verified via temp-repo smoke test. Also added `-u` to include untracked files
        in the stash, since the goal is preserving all uncommitted work, not just tracked diffs.)*
  - [x] `--branch` mode: create a WIP commit on a scratch branch (`wip-snapshot-{ts}`) and return
        to the original branch.
  - [x] Write/refresh the freshness marker (epoch timestamp + HEAD sha + patch path).
  - [x] Print the patch path / stash ref / branch name for the caller.
  - [x] Exit non-zero with a clear message on any failure so the caller does not proceed to the
        destructive step believing it is safe.
- [x] Add unit-style smoke check: run helper on a dirty scratch tree, confirm patch + marker exist.
      *(completed: verified in a disposable /tmp git repo — clean-tree no-op, dirty-tree default
      stash mode, and --branch mode all produce a non-empty patch + parseable marker and leave
      the working tree clean; this repo's own working tree was never touched)*

**Timing**: ~1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/git-snapshot.sh` - new helper script (deployed copy; extension-source copy and
  manifest registration handled in Phase 4)

**Verification**:
- Running the helper on a dirty tree writes a non-empty `.patch` under the task dir and a marker file.
- Running the helper on a clean tree is a no-op (exit 0, no marker written).
- Marker content includes a parseable timestamp and the current HEAD sha.

---

### Phase 2: Guard hook script (guard-destructive-git.sh) [COMPLETED]

**Goal**: Implement the PreToolUse Bash hook that blocks destructive git commands on a dirty tree
unless a fresh snapshot marker (per Phase 1 contract) exists.

**Tasks**:
- [x] Create `.claude/scripts/../hooks/guard-destructive-git.sh` at `.claude/hooks/guard-destructive-git.sh`
      (executable), modeled line-for-line on `.claude/hooks/block-pr-submission.sh`:
  - [x] `INPUT=$(cat)`; `COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')`.
  - [x] Early `exit 0` if `COMMAND` empty (non-Bash / parse failure — never block).
  - [x] Run `git status --porcelain`; if clean, `exit 0` immediately (clean tree = nothing to lose;
        this also auto-exempts `/todo`'s post-safety-commit reset).
  - [x] Match destructive patterns with anchored `grep -qE '(^|[;&|] *)...'` (from the research
        pattern table): `git reset ... --hard`; `git checkout -- ` / `git checkout ... --\s`;
        `git restore` without `--staged`; `git clean` with flag-order-agnostic `-f`+`-d`;
        `git stash (drop|clear)`; forced `checkout`/`switch` (`-f`/`--force`). Do NOT match
        `git stash` (push), `git stash pop`/`apply`, or `git restore --staged`.
  - [x] If a destructive pattern matches AND tree is dirty: check for a fresh snapshot marker
        (`find specs -maxdepth 3 -name .git-snapshot-marker`, timestamp within freshness window);
        if fresh, consume (delete) it and `exit 0`; otherwise print a corrective message to
        **stderr** naming `git-snapshot.sh` as the remedy and `exit 2`.
  - [x] Final `exit 0` for the allow-through path.
- [x] Confirm the corrective stderr message tells the agent exactly how to proceed (run the helper
      then retry). *(completed: stderr names git-snapshot.sh explicitly and describes what it
      writes, then says "retry the command")*

**Timing**: ~1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/hooks/guard-destructive-git.sh` - new hook (deployed copy; extension-source copy,
  manifest, and settings.json registration handled in Phase 4)

**Verification**:
- Piping `{"tool_input":{"command":"git reset --hard"}}` on a dirty tree returns exit 2 with a
  stderr message.
- Same input on a clean tree returns exit 0.
- Piping a non-Bash / empty command returns exit 0.
- `git stash` (push) and `git restore --staged` inputs return exit 0 on a dirty tree.

---

### Phase 3: Extend git-workflow.md rule [COMPLETED]

**Goal**: Add the "no destructive git on uncommitted work" section to the `git-workflow.md` rule
(deployed copy), replacing/extending the current blanket `git reset --hard` prohibition.

**Tasks**:
- [x] In `.claude/rules/git-workflow.md`, add a section that:
  - [x] Lists the forbidden destructive commands (`git reset --hard`, `git checkout -- <path>`,
        `git restore <path>`, `git clean -fd`, `git stash drop/clear`, forced `checkout`/`switch`).
  - [x] States the exemption: allowed only when the tree is clean OR a snapshot was just taken
        (WIP commit on scratch branch, `.patch` under `specs/{NNN}_{SLUG}/`, or `git stash` without drop).
  - [x] Names `git-snapshot.sh` as the sanctioned way to take the snapshot.
  - [x] Cross-references that this is enforced by the `guard-destructive-git.sh` PreToolUse hook.
  - [x] Reconciles with the existing blanket `Never Run: git reset --hard` line (replace it with the
        nuanced clean-or-snapshotted rule).
  - [x] Notes the `/todo` / `git-safety.md` safety-commit exemption so it is not read as contradictory.

**Timing**: ~0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/rules/git-workflow.md` - new rule section (deployed copy; extension-source copy synced in Phase 4)

**Verification**:
- The new section enumerates all six destructive-command classes and the three snapshot forms.
- The section does not contradict `.claude/context/standards/git-safety.md`.

---

### Phase 4: Dual-copy deployment + wiring [COMPLETED]

**Goal**: Propagate all three artifacts to their extension-source copies and register them so the
change survives a future sync/regen. This is the phase that prevents repeating the
`block-pr-submission.sh` silent-revert failure.

**Tasks**:
- [x] **Hook script**: copy `.claude/hooks/guard-destructive-git.sh` ->
      `.claude/extensions/core/hooks/guard-destructive-git.sh` (identical, executable); add
      `"guard-destructive-git.sh"` to `.claude/extensions/core/manifest.json` `provides.hooks`.
- [x] **Helper script**: copy `.claude/scripts/git-snapshot.sh` ->
      `.claude/extensions/core/scripts/git-snapshot.sh` (identical, executable); add
      `"git-snapshot.sh"` to `manifest.json` `provides.scripts`.
- [x] **Rule**: sync the Phase 3 section into `.claude/extensions/core/rules/git-workflow.md` so
      both copies are byte-identical.
- [x] **settings.json (both copies)**: append a new PreToolUse `"matcher": "Bash"` entry invoking
      `bash .claude/hooks/guard-destructive-git.sh 2>/dev/null || echo '{}'` to BOTH
      `.claude/settings.json` AND `.claude/extensions/core/root-files/settings.json`. Preserve the
      existing `Write` matcher entry (append, do not replace the PreToolUse array).
      *(deviation: altered — registered as plain `bash .claude/hooks/guard-destructive-git.sh`,
      WITHOUT the `2>/dev/null || echo '{}'` suffix. That suffix is the correct convention for
      advisory hooks that emit `permissionDecision` JSON, but for an exit-code+stderr blocking
      hook it is actively harmful: `cmd 2>/dev/null || echo '{}'` swallows stderr (the corrective
      message the hook is required to show) AND replaces any nonzero exit code — including the
      deliberate `exit 2` block signal — with the fallback `echo`'s exit 0, silently turning the
      hook into a permanent no-op. Verified by tracing bash `||` semantics: since `echo '{}'`
      always succeeds, the composite command's exit code is always 0 regardless of the script's
      real exit code, which is unacceptable for a hook whose entire purpose is to block via a
      nonzero exit code. This mirrors the correct, unwrapped invocation shape implied by
      block-pr-submission.sh's own header comment ("Blocking mechanism: exit code 2 ... Does NOT
      use permissionDecision: deny").*
- [x] **.gitignore**: add `**/.git-snapshot-marker` (mirroring `**/.postflight-pending`) so the
      ephemeral marker is never committed. Keep the durable `working-progress-*.patch` tracked.

**Timing**: ~1 hour

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/extensions/core/hooks/guard-destructive-git.sh` - source copy of hook
- `.claude/extensions/core/scripts/git-snapshot.sh` - source copy of helper
- `.claude/extensions/core/rules/git-workflow.md` - source copy of rule
- `.claude/extensions/core/manifest.json` - add both scripts to `provides.hooks` / `provides.scripts`
- `.claude/settings.json` - append Bash PreToolUse matcher
- `.claude/extensions/core/root-files/settings.json` - append Bash PreToolUse matcher (sync source)
- `.gitignore` - add `**/.git-snapshot-marker`

**Verification**:
- `diff .claude/hooks/guard-destructive-git.sh .claude/extensions/core/hooks/guard-destructive-git.sh` is empty.
- `diff .claude/scripts/git-snapshot.sh .claude/extensions/core/scripts/git-snapshot.sh` is empty.
- `diff .claude/rules/git-workflow.md .claude/extensions/core/rules/git-workflow.md` is empty.
- Both settings.json copies contain a Bash PreToolUse matcher for the hook (compare with `jq`).
- `jq '.provides.hooks | index("guard-destructive-git.sh")'` and
  `jq '.provides.scripts | index("git-snapshot.sh")'` are both non-null.

---

### Phase 5: Verification & scenario testing [NOT STARTED]

**Goal**: Prove the end-to-end behavior and confirm no regression to sanctioned rollback flows.

**Tasks**:
- [ ] **Blocks dirty-tree reset**: on a scratch dirty tree, pipe
      `{"tool_name":"Bash","tool_input":{"command":"git reset --hard"}}` to the hook; assert exit 2
      + stderr message.
- [ ] **Allows post-snapshot**: run `git-snapshot.sh`, then pipe the same input; assert exit 0 and
      that the marker was consumed (deleted).
- [ ] **Allows clean tree**: on a clean tree, pipe the same input; assert exit 0.
- [ ] **Does not over-block**: pipe `git stash`, `git stash pop`, `git restore --staged`, and a
      benign command containing "reset --hard" inside a quoted commit message; assert exit 0 for all.
- [ ] **/todo flow intact**: simulate the `git-safety.md` pattern (safety commit -> tree clean ->
      `git reset --hard {sha}` + `git clean -fd`); assert the hook allows it (clean-tree exemption).
- [ ] **Dual-copy integrity**: run all Phase 4 `diff`/`jq` checks; assert every pair matches and
      both manifest lists contain the new entries.
- [ ] **Registration sanity**: confirm the hook is invoked by Claude Code for a Bash call (or, if
      not testable in-session, confirm the settings.json entry matches the working
      `block-pr-submission.sh`-style registration shape).

**Timing**: ~1 hour

**Depends on**: 4

**Files to modify**:
- None (verification only; may write a throwaway test script under the scratchpad, not committed)

**Verification**:
- All six scenario checks pass.
- All dual-copy integrity checks pass.

---

## Testing & Validation

- [ ] Hook blocks dirty-tree `git reset --hard` (exit 2 + stderr).
- [ ] Hook allows the same command immediately after `git-snapshot.sh` (marker consumed).
- [ ] Hook allows the same command on a clean tree.
- [ ] Hook does NOT block `git stash` (push), `git stash pop/apply`, `git restore --staged`, or
      benign quoted substrings.
- [ ] `/todo`-style safety-commit + `git reset --hard`/`git clean -fd` flow still works.
- [ ] Non-Bash / empty command input never blocks (exit 0).
- [ ] `git-snapshot.sh` writes a recoverable `.patch` under the task dir and a fresh marker.
- [ ] Both deployed and extension-source copies of hook, helper, and rule are byte-identical.
- [ ] `manifest.json` `provides.hooks` and `provides.scripts` include the new scripts.
- [ ] Both `settings.json` copies register the Bash PreToolUse hook.
- [ ] `.gitignore` ignores `**/.git-snapshot-marker`.

## Artifacts & Outputs

- `.claude/hooks/guard-destructive-git.sh` (+ `.claude/extensions/core/hooks/` copy)
- `.claude/scripts/git-snapshot.sh` (+ `.claude/extensions/core/scripts/` copy)
- `.claude/rules/git-workflow.md` updated (+ `.claude/extensions/core/rules/` copy)
- `.claude/extensions/core/manifest.json` updated (`provides.hooks`, `provides.scripts`)
- `.claude/settings.json` updated (+ `.claude/extensions/core/root-files/settings.json` copy)
- `.gitignore` updated (`**/.git-snapshot-marker`)
- `specs/780_agent_git_safety_preserve_uncommitted_work/summaries/NN_guard-destructive-git-hook-summary.md` (on /implement)

## Rollback/Contingency

- All changes are additive files or appended sections; revert via `git checkout` of the changed
  files (a clean-tree op — not blocked by the new hook).
- If the hook proves too aggressive in practice, disable it by removing the Bash PreToolUse matcher
  from both `settings.json` copies (leaving the script and rule in place), then iterate on patterns.
- If the extension-source copies drift from deployed, re-run the Phase 4 `diff` checks and re-sync;
  the manifest entries ensure a future "Load Core" restores the deployed copies rather than dropping them.

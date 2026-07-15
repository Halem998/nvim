# Implementation Plan: Task #884

- **Task**: 884 - extend_git_guard_hook_to_block_overstaging
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None (see Territory note re: task 882 running in parallel)
- **Research Inputs**: `specs/884_extend_git_guard_hook_to_block_overstaging/reports/01_extend-git-guard-overstaging.md`
- **Artifacts**: plans/01_extend-git-guard-overstaging.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the existing `guard-destructive-git.sh` PreToolUse Bash hook with three new detectors
that block over-staging commands (`git add -A`/`--all`, `git add .`, `git commit -a`/`-am`/`--all`)
at the tool boundary, and fix two prose locations that currently instruct agents to run commands
the extended hook will block. No new hook file, no `settings.json` change, and — critically — no
exemption mechanism for `git-snapshot.sh`.

Definition of done: the three prohibited forms are blocked on a dirty tree with actionable
remediation text; the verified false-positive set (`--amend`, `--author=`, `.env`, `.gitignore`,
quoted commit-message text, and the opaque `bash .claude/scripts/git-snapshot.sh --branch` call)
all pass through; and no deliverable outside `specs/**` cites a task number.

### Research Integration

The research report is accurate and its two central conclusions are confirmed independently:

1. **No exemption mechanism is needed for `git-snapshot.sh`.** Its sanctioned `git add -A`
   (`scripts/git-snapshot.sh:150`, `--branch` mode only) runs as a subprocess inside the script.
   Every call site invokes the opaque command `bash .claude/scripts/git-snapshot.sh [--branch] [TASK]`,
   which contains none of the literal substrings the hook scans for. **Empirically verified**: both
   proposed segment-extraction patterns return no match against that literal string. The hook
   structurally cannot observe the internal command. Do not build a marker, allowlist, or
   caller-identification mechanism.
2. **Source of truth is `agent-system/extensions/core/`, not `.claude/`.** Confirmed
   `.gitignore:7` ignores `/.claude/`; confirmed all three target files are byte-identical between
   the two trees today.

Two findings **extend** the research, both discovered by empirically executing the proposed
regexes rather than tracing them by hand. Both are load-bearing and are folded into the phases
below:

- **A real false positive the manual trace missed** (see Phase 1, Task 3): the segment-wide `-a`
  scan matches flag-like text inside a quoted commit message. `git commit -m "fix -a regression"`
  and `git commit -m "add -a flag support"` both **blocked** under the research's proposed pattern.
  This is a new exposure created by applying the existing `clean -f -d` flag-scan idiom to
  `commit`: `git clean` takes no message argument, so the idiom never had to survive arbitrary
  quoted text before. Mitigation (quote-stripping) is specified and verified below.
- **A design fork the research left implicit** (see Phase 1, Task 2): whether the new detectors
  join the existing `MATCHED` chain (which would let a fresh snapshot marker *exempt* over-staging)
  or block independently. Research's prose says "no interaction with the marker mechanism", but the
  naive implementation — appending to the `MATCHED` chain — silently produces the opposite. This
  plan makes the placement explicit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Block `git add -A`, `git add --all`, `git add .`, `git commit -a`, `git commit -am`, and
  `git commit --all` at the PreToolUse boundary on a dirty tree.
- Preserve the sanctioned `git-snapshot.sh --branch` flow with zero special-casing.
- Keep the verified false-positive set passing through untouched.
- Fix the two prose locations that teach commands the hook will now block.
- Land every edit in the tracked source tree so it survives regeneration.

**Non-Goals**:
- Creating a second hook file (hard constraint: extend the existing one).
- Changing `settings.json` (registration already exists — see Phase 0).
- Rewriting `context/standards/git-staging-scope.md` (policy is already correct; **owned by task
  882 in parallel — do not touch**).
- Editing anything under `scripts/` (**owned by task 882 in parallel**).
- Building a durable automated test harness for the hook. None exists (`hooks/` has no `tests/`
  subdirectory), and research scoped this as a follow-up. Phase 3 verifies concretely against the
  real hook without adding a permanent harness.

## Territory / Ownership

Task 882 is running in parallel and owns `context/standards/git-staging-scope.md` and everything
under `scripts/`. This task's file set is disjoint from that:

| Owned by this task (all under `agent-system/extensions/core/`) | Change |
|---|---|
| `hooks/guard-destructive-git.sh` | three new detectors + header comment |
| `context/orchestration/postflight-pattern.md` | 2 prose lines (228, 247) |
| `skills/skill-project-overview/SKILL.md` | 1 prose line (435) |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edits land in `.claude/` (gitignored) and are wiped on regeneration | H | M | Phase 0 gate: confirm the source path before any edit; Phase 3 re-verifies via `git status` that changes are tracked |
| New detectors join the `MATCHED` chain, letting a snapshot marker exempt over-staging | M | H (naive impl does this) | Phase 1 Task 2 specifies placement explicitly: independent block, own `exit 2`, own message, before the marker logic |
| False positive on quoted commit-message text (`-m "fix -a bug"`) | M | M | Quote-stripping before the flag scan; verified 13/13 in Phase 3 |
| Remediation text tells the user to run `git-snapshot.sh` (wrong advice for over-staging) | L | H (if message is reused) | Over-staging block emits its own remediation pointing at scoped staging, never the snapshot script |
| Task-number citation leaks into a deliverable outside `specs/**` | L | M | Explicit MUST NOT in Phases 1-2; Phase 3 greps the three touched files |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 0 | -- |
| 2 | 1, 2 | 0 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files.

---

### Phase 0: Confirm Source Tree and Registration [COMPLETED]

**Goal**: Gate the work on the two facts that make it correct, so no edit lands in the wrong tree.

**Tasks**:
- [ ] Confirm `.claude/` is gitignored: `git check-ignore -v .claude/hooks/guard-destructive-git.sh`
- [ ] Confirm the tracked source and deploy copies are currently identical for all three target files
- [ ] Confirm no `settings.json` change is needed: `guard-destructive-git.sh` is **already**
      registered as a PreToolUse/Bash hook in the assembled `.claude/settings.json` AND in the
      tracked source `agent-system/extensions/core/root-files/settings.json:52`. Since this task
      *extends* an already-registered hook, registration already covers it. **Conclusion: no
      settings change.**

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**: none (verification gate only)

**Verification**:
- `git check-ignore` confirms `/.claude/` is ignored
- The three source/deploy pairs report identical
- `grep -n "guard-destructive-git" agent-system/extensions/core/root-files/settings.json` returns
  the existing registration

**Note for the implementer**: the delegation context suggested `settings.json` is assembled from
`templates/settings.json`. The registration actually lives in
`agent-system/extensions/core/root-files/settings.json`. This does not change the conclusion (no
edit needed) but corrects the path if you go looking. Do **not** edit the assembled
`.claude/settings.json` under any circumstance.

---

### Phase 1: Extend the Hook with Over-Staging Detectors [COMPLETED]

**Goal**: Add three detectors to the existing hook that block over-staging independently of the
destructive-command chain.

**Tasks**:
- [x] **Task 1 — Header comment.** Extend the file header (lines 11-27 style) with a
      "Over-staging patterns (blocked independently of the snapshot-marker exemption)" section
      listing the three forms. State explicitly that the guard has **no exemption mechanism** for
      over-staging, that `git-snapshot.sh`'s internal `git add -A` is invisible to this hook
      because the hook only ever sees the literal top-level `tool_input.command`, and that any
      future legitimate need must be wrapped in a script rather than special-cased here. This
      comment is the artifact that stops a future maintainer from building an exemption for a
      problem that does not exist at this observation boundary.
- [x] **Task 2 — Placement (design-critical).** Insert the over-staging logic **after** the
      clean-tree gate (line 43-45) and **before** the `MATCHED=0` destructive chain (line 47).
      It must be a self-contained block that emits its own `BLOCKED:` message and calls `exit 2`
      directly. It MUST NOT set `MATCHED`/`REASON` and fall through to the shared marker check.
      Rationale: a snapshot makes a *destructive* command recoverable, so the marker exemption is
      coherent there. Over-staging is a scope-pollution problem, not a data-loss problem — a
      snapshot does not make it acceptable, so the marker must never exempt it. The shared
      remediation text ("run git-snapshot.sh first, then retry") is also actively wrong advice
      for over-staging.
      Keeping the clean-tree gate ahead of the new block is correct and intentional: on a clean
      tree `git add -A` stages nothing and `git commit -am` has nothing to commit, so both are
      true no-ops.
- [x] **Task 3 — Quote-stripping helper.** Before flag-scanning any segment, strip quoted spans:
      `seg_scan=$(echo "$seg" | sed -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g")`. Scan `seg_scan`,
      not the raw segment. This is required — without it, `git commit -m "fix -a regression"`
      false-positives (empirically confirmed). Apply to both the add and commit detectors for
      consistency.
- [x] **Task 4 — `git add` detector.** Extract segments with the existing idiom
      `(^|[;&|][[:space:]]*)git[[:space:]]+add[^;&|]*`, loop with the existing
      `while IFS= read -r seg` shape, and on the quote-stripped segment check:
      - `-A`/`--all`: `(^|[^-])-[a-zA-Z]*A[a-zA-Z]*([[:space:]]|$)|--all([[:space:]]|$)`
      - bare `.` pathspec: `(^|[[:space:]])\.([[:space:]]|$)`
- [x] **Task 5 — `git commit` detector.** Same idiom with verb `commit`; on the quote-stripped
      segment check `(^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)|--all([[:space:]]|$)`.
      Catch bare `-a` as well as `-am` — the hazard (implicit staging of all tracked
      modifications) is identical with or without `-m`, per `git-staging-scope.md`.
- [x] **Task 6 — Remediation messages.** Each block prints `BLOCKED: <reason>` plus guidance
      pointing at scoped staging per `git-staging-scope.md`. Never reference `git-snapshot.sh`
      here. Suggested reasons:
      - `git add -A (or --all) stages the entire working tree; stage explicit task-scoped paths instead`
      - `git add . stages the entire current directory tree; stage explicit task-scoped paths instead`
      - `git commit -a/-am (or --all) implicitly stages all tracked-file modifications; stage explicit paths and commit without -a`

**Timing**: 1 hour

**Depends on**: 0

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - header comment + three
  detectors as one independent pre-`MATCHED` block

**Verification**:
- `bash -n agent-system/extensions/core/hooks/guard-destructive-git.sh` parses clean
- The new block appears after the clean-tree gate and before `MATCHED=0`
- No occurrence of `MATCHED=1` inside the new block
- No `git-snapshot.sh` reference in the new block's remediation text
- No task-number citation anywhere in the file (deliverable rule)

**Note on `--all` boundary**: use `--all([[:space:]]|$)` rather than research's `--all\b`. Both
correctly reject `--allow-empty` (verified), but the explicit whitespace/EOL boundary matches the
file's existing `([[:space:]]|$)` idiom and avoids `\b`'s edge behavior on a trailing hyphen.

---

### Phase 2: Reconcile Contradicting Prose [NOT STARTED]

**Goal**: Remove the two documented instructions that teach commands the extended hook blocks, and
fix one over-broad (and now actively broken) staging prescription.

**Tasks**:
- [ ] **`context/orchestration/postflight-pattern.md:228` and `:247`** — both currently read
      `echo "Manual fix: git add . && git commit -m 'task $task_number: ${command} completed'"`.
      Both are inside `skill-git-workflow`'s validate-return fallback (the `jq`-parse-failure
      branch and the `status == "failed"` branch). Replace both with guidance pointing at scoped
      staging, e.g. `Manual fix: stage the task-scoped files per git-staging-scope.md and commit
      manually (do not use git add -A / git add . / git commit -am)`. These are the only two
      literal blocked-command instructions in the file; fix both identically.
- [ ] **`skills/skill-project-overview/SKILL.md:435`** — currently `git add specs/ .claude/`.
      Narrow to the canonical template from `git-staging-scope.md`, matching the surrounding step's
      existing variables:
      ```
      padded_num=$(printf "%03d" "$next_num")
      git add "specs/${padded_num}_${slug}/" specs/TODO.md specs/state.json
      ```
      **Scope honesty (do not overclaim)**: this line is **not** one of the three forms the hook
      blocks — it has no `-A`, no bare `.`, and no `-a`. The hook will not reject it. Justify the
      fix on its own merits, of which there are two:
      1. It contradicts `git-staging-scope.md`'s narrow per-operation contract (staging *all* of
         `specs/` rather than the one task directory plus the two index files).
      2. **It is now actively broken**: `/.claude/` is gitignored, so `git add .claude/` stages
         nothing and emits `The following paths are ignored by one of your .gitignore files`.
         The `.claude/` argument is dead weight and must be dropped regardless.
- [ ] Confirm the surrounding variable names (`next_num`, slug variable) match what that SKILL.md
      step already defines before substituting; adjust to fit rather than introducing new names.

**Timing**: 30 minutes

**Depends on**: 0

**Files to modify**:
- `agent-system/extensions/core/context/orchestration/postflight-pattern.md` - lines 228, 247
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md` - line 435

**Verification**:
- `grep -n "git add \." agent-system/extensions/core/context/orchestration/postflight-pattern.md`
  returns nothing
- `grep -n "git add specs/ \.claude/" agent-system/extensions/core/skills/skill-project-overview/SKILL.md`
  returns nothing
- Neither file gains a task-number citation (both are outside `specs/**` — deliverable rule applies)

---

### Phase 3: Verify Against the Real Hook [NOT STARTED]

**Goal**: Prove the three prohibited forms block and the full false-positive set passes, by piping
real payloads through the actual hook.

**Critical precondition**: the hook exits 0 immediately on a clean tree (line 43-45). **Every
must-block case will silently pass if the tree is clean.** Confirm `git status --porcelain` is
non-empty before trusting any BLOCK result, or the entire verification is vacuous.

**Tasks**:
- [ ] Drive cases through the hook as it will really be called:
      `echo '{"tool_input":{"command":"git add -A"}}' | bash agent-system/extensions/core/hooks/guard-destructive-git.sh; echo $?`
      Exit 2 = blocked, exit 0 = allowed.
- [ ] **MUST BLOCK (expect exit 2)** — the three prohibited forms and their variants:

      | Command | Why |
      |---|---|
      | `git add -A` | short flag |
      | `git add --all` | long flag |
      | `git add .` | bare dot pathspec |
      | `git add -A .` | both |
      | `git commit -am "msg"` | clustered |
      | `git commit -a -m "msg"` | split flags |
      | `git commit -a` | bare `-a`, no `-m` |
      | `git commit --all -m "x"` | long flag |
      | `git commit -m "x" -a` | flag after message |

- [ ] **MUST NOT BLOCK (expect exit 0)** — the required false-negative set:

      | Command | Why it must pass |
      |---|---|
      | `bash .claude/scripts/git-snapshot.sh --branch 884` | the sanctioned opaque call — the whole point |
      | `git commit --amend` | not `-a` |
      | `git commit --author="A U" -m "x"` | not `-a` |
      | `git commit --allow-empty -m "x"` | not `--all` |
      | `git add .env` | dot-prefixed path, not bare dot |
      | `git add .gitignore` | dot-prefixed path, not bare dot |
      | `git add ./lua/foo.lua` | relative path, not bare dot |
      | `git add specs/TODO.md specs/state.json` | canonical scoped staging |
      | `git add specs/884_x/` | canonical scoped staging |
      | `git commit -m "msg"` | plain commit |
      | `git commit -m "fix -a regression"` | **quoted-text false positive found in this task's analysis** |
      | `git commit -m "add -a flag support"` | same class |
      | `git commit -m 'fix -a in single quotes'` | single-quote variant |
      | `git commit -m "add all the things"` | `all` as prose, not a flag |

- [ ] Confirm the existing destructive detectors still behave: `git reset --hard` still blocks;
      `git stash pop` and `git restore --staged x` still pass. The new block must not disturb them.
- [ ] Confirm marker independence: take a fresh snapshot marker, then verify `git add -A` **still
      blocks** (the marker must not exempt over-staging) while `git reset --hard` is exempted as
      before. This is the check that catches the Phase 1 Task 2 placement error.
- [ ] Confirm the edits are tracked: `git status --short` shows the three
      `agent-system/extensions/core/...` files as modified, and **no** `.claude/...` path appears.
- [ ] Deliverable rule sweep: `grep -rniE "task [0-9]+" ` over the three touched files returns
      nothing.

**Timing**: 1 hour

**Depends on**: 1, 2

**Files to modify**: none (verification only)

**Verification**:
- All 9 must-block cases exit 2
- All 14 must-not-block cases exit 0
- Marker-independence check passes
- No `.claude/` path in `git status --short`

---

## Testing & Validation

- [ ] `bash -n` parses the modified hook clean
- [ ] 9/9 must-block cases return exit 2 (on a confirmed-dirty tree)
- [ ] 14/14 must-not-block cases return exit 0, including the opaque `git-snapshot.sh --branch`
      call and the quoted-message cases
- [ ] Pre-existing destructive detectors unchanged in behavior
- [ ] A fresh snapshot marker does **not** exempt `git add -A`
- [ ] All modifications are in the tracked source tree; none in `.claude/`
- [ ] No task-number citations in any file outside `specs/**`

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (extended)
- `agent-system/extensions/core/context/orchestration/postflight-pattern.md` (2 lines fixed)
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md` (1 line fixed)
- `specs/884_extend_git_guard_hook_to_block_overstaging/summaries/01_extend-git-guard-overstaging-summary.md`

## Follow-Up (out of scope, recommended)

Research flagged that no automated test harness exists for this hook, and `hooks/` has no `tests/`
subdirectory. Hook regexes verified only by ad-hoc invocation are exactly the kind of thing that
regresses silently. A follow-up task should add a durable harness covering both the existing
destructive cases and the over-staging cases (including the quoted-message false-positive class
identified here). Not created by this task.

## Rollback/Contingency

All three changes are small, independent, and confined to the tracked source tree. To revert:
`git checkout -- agent-system/extensions/core/hooks/guard-destructive-git.sh` (and likewise the two
prose files), then re-sync to `.claude/`. If only the hook proves problematic (e.g. an unforeseen
false positive blocks legitimate work), reverting the hook alone is safe — the two prose fixes are
independently correct and should be kept regardless, since the `skill-project-overview` line is
broken on its own terms (gitignored `.claude/` argument) and the postflight guidance is wrong
independent of whether the hook enforces it.

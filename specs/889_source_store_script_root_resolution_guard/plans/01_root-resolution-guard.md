# Implementation Plan: Task #889

- **Task**: 889 - Source store script root resolution guard
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/889_source_store_script_root_resolution_guard/reports/01_root_resolution_guard.md
- **Artifacts**: plans/01_root-resolution-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

24 scripts under `agent-system/extensions/core/scripts/` compute their repo root as
`"$(cd "${SCRIPT_DIR}/../.." && pwd)"`. That depth is correct only in a deploy tree
(`.claude/scripts/` or `.opencode/scripts/`, two levels under the repo root). Run from the
source store the same expression resolves to `agent-system/extensions/` and the script proceeds
against a bogus root — creating stray artifacts (`agent-system/extensions/.agent-logs/`) before
failing on a missing `state.json`. This plan adds one sourced guard helper that fails loudly
before any bogus-root path is consumed, wires it into all 24 scripts with a single line each,
and de-anchors the `.agent-logs/` gitignore entry so nested log dirs are ignored wherever they
appear.

Definition of done: a source-store invocation of any of the 24 exits non-zero with an
actionable message and creates zero files; a deploy-tree invocation is byte-for-byte unaffected.

### Research Integration

Honored from the research report:
- Guard accepts **both** `.claude` and `.opencode` as valid deploy-tree grandparents (the deploy
  tree is not singular). Never hardcode `.claude`.
- Guard is a **structural path check** — no filesystem I/O, no false negatives on a fresh repo
  with no `specs/` yet.
- `git rev-parse --show-toplevel` is **rejected**: it would silently succeed by finding the true
  repo root, masking the invocation-context error this task exists to surface.
- Guard is placed **before** any log-dir `mkdir` or state-file read. `generate-todo.sh` (line 93
  `mkdir -p` vs line 106 state check) and `update-phase-status.sh` both materialize
  `.agent-logs/` before validating inputs; placing the guard at the root computation makes that
  internal ordering irrelevant.
- `.gitignore` line 10 `/.agent-logs/` -> `**/.agent-logs/`, matching the `**/` convention at
  lines 27-35.
- `check-extension-docs.sh` carries a "known latent bug, flagged not fixed" comment (lines
  76-80) describing this exact defect; this task closes it, so the comment is reconciled.

Two findings from plan-stage verification **override** the research's recommendation; see
"Decisions" below:
- The research recommended 24 self-contained inline guard blocks and advised against a shared
  helper. Plan-stage measurement (~37 lines vs ~120) and the user's "minimal code" focus reverse
  this. The research's stated objection (no sourced-file convention in this directory) is
  accurate as to these 24 scripts but `skill-base.sh` is already a sourced library declared in
  the same `provides.scripts` list, so the convention is not new to the manifest.
- The research did not surface that 4 of the 24 lack `set -e`, which is decisive for how the
  source line must be written (see Risks).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task.

## Goals & Non-Goals

**Goals**:
- A source-store invocation of any of the 24 scripts fails loudly and actionably, before writing
  anything.
- A deploy-tree invocation (`.claude/scripts/` or `.opencode/scripts/`) is behaviorally
  unchanged.
- Nested `.agent-logs/` directories are gitignored wherever they appear.
- The guard lives in exactly one place, so a future third deploy-tree name is a one-line edit.
- `check-extension-docs.sh`'s stale "flagged not fixed" comment reflects reality.

**Non-Goals**:
- Porting the guard to `.opencode/scripts/` (git-tracked, independently maintained, partially
  divergent, and explicitly out of scope per the task description). The guard *accepts*
  `.opencode` as valid; mirroring the fix into that tree is a separate follow-up.
- Fixing the mkdir-before-validate ordering *inside* `generate-todo.sh` /
  `update-phase-status.sh`. The guard makes it moot for the source-store case; reordering their
  internals is unrelated scope.
- Hand-editing the `.claude/` deploy tree. It is a disposable, gitignored build artifact
  regenerated only via `<leader>al`; see Phase 6 and Risks.
- Converting the 4 non-`set -e` scripts to `set -e`. Out of scope and behavior-changing; the
  guard is made robust without it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Bootstrap: helper missing at runtime bricks all 24.** If the manifest entry is omitted or a sync is partial, every deployed core script (incl. `update-task-status.sh`, `generate-todo.sh`) fails to source it. | H | L | Source line is `\|\| exit 1`, so failure is immediate and names the missing path. Manifest registration is Phase 1, verified by `check_manifest_entries`/Rule E and by the Phase 5 smoke test before any wiring lands. |
| **4 of 24 lack `set -e`** (`reconcile-artifacts.sh`, `task-lock.sh`, `check-extension-docs.sh` = `set -uo pipefail`; `validate-wiring.sh` = no `set` at all). A bare `source` of a missing helper would print an error and **continue with an unvalidated root** — silently reintroducing this exact bug class. | H | M (certain if unhandled) | Write the source line as `. "${SCRIPT_DIR}/deploy-root-guard.sh" \|\| exit 1` — correct under any `set` configuration. Do **not** rely on `set -e`. `exit 1` *inside* the sourced helper correctly exits the caller (sourcing runs in the same shell), so the guard itself works in all 24 regardless. |
| **Doc-lint gate goes red until the user syncs.** All 24 are currently deployed byte-identical and `check-extension-docs.sh` is currently **PASS**; editing source makes Rule F (`check_deployed_script_drift`, a hard `fail()`) report 24 drift failures. | M | H (certain) | Expected and unavoidable for any source-store edit to a deployed script. Do not treat as a defect. Phase 5 verifies via source-store + simulated-deploy-tree smoke tests, **not** via the doc-lint gate. Phase 6 surfaces the required `<leader>al` sync prominently in the summary and handoff. |
| Copy-paste drift across 24 edits. | M | M | Only one line is copied, and Phase 5 greps that all 24 contain it modulo the root-var name. The guard body itself exists once. |
| `check-extension-docs.sh`'s `REPO_ROOT` env override breaks. Verification callers pass `REPO_ROOT=$(pwd)` to run it from the source store *on purpose*. | M | M | Gate that file's guard on `REPO_ROOT` being unset, so the guard fires only on the computed default. Phase 4 + Phase 5 assert the override still works. |
| Future third deploy-tree name false-positives the guard. | L | L | Single `case` in one file; a one-line edit. This is the main payoff of the helper over 24 copies. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. Phases 3 and 4 touch disjoint files
(23 scripts vs. `check-extension-docs.sh` alone).

---

### Phase 1: Create the guard helper and register it [COMPLETED]

**Goal**: One self-locating, dependency-free guard file, deployable via the core manifest.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/deploy-root-guard.sh` with the canonical
      body below. It validates **its own** location via `BASH_SOURCE[0]` — it is always
      co-located with its caller in the same `scripts/` dir, so it needs no arguments and reads
      none of the caller's variables. *(completed)*
- [x] Add `"deploy-root-guard.sh"` to `.provides.scripts` in
      `agent-system/extensions/core/manifest.json`. *(completed)*
- [x] Verify the manifest stays valid JSON (`jq empty`) and the new entry references an existing
      file. *(completed)*

**Canonical guard body** (the single source of truth; do not duplicate it elsewhere):

```bash
#!/usr/bin/env bash
# Sourced by core scripts immediately after their SCRIPT_DIR / root computation.
#
# Those scripts resolve their repo root as "${SCRIPT_DIR}/../..", a depth that is correct ONLY
# in a deploy tree (.claude/scripts/ or .opencode/scripts/, two levels under the repo root). Run
# from the agent-system source store the same expression silently resolves to
# agent-system/extensions/ instead of failing, and the script then writes stray artifacts under
# a bogus root. This guard makes that invocation fail loudly instead.
#
# Structural check only: no filesystem I/O, so it cannot false-negative on a fresh repo that has
# no specs/ yet or has loaded no extensions. Deliberately NOT `git rev-parse --show-toplevel`,
# which would silently succeed by finding the true repo root and mask the invocation error.
#
# Callers MUST use `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` — several callers do not
# set -e, so the `|| exit 1` is what makes a missing helper fail closed rather than continue.

__guard_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${__guard_dir%/*}" in
  */.claude | */.opencode)
    unset __guard_dir
    ;;
  *)
    echo "ERROR: ${0##*/} must run from a deployed scripts/ tree (.claude/scripts/ or" >&2
    echo "       .opencode/scripts/), not '${__guard_dir}'." >&2
    echo "       This looks like the agent-system source store, where '../..' resolves to a" >&2
    echo "       bogus repo root. Deploy first via <leader>al ('Load Core' / 'Sync all'), then" >&2
    echo "       run the deployed copy." >&2
    exit 1
    ;;
esac
```

Notes for the implementer:
- `${__guard_dir%/*}` strips the trailing `/scripts` using parameter expansion — no `dirname`
  fork, no subshell. `basename(SCRIPT_DIR)` is always literally `scripts` in every tree and
  carries no discriminating power; the grandparent name is the only signal.
- `unset __guard_dir` keeps the caller's namespace clean and is safe under `set -u`.
- `exit 1` in a sourced file exits the calling script — intended.
- Do **not** reference task numbers in this file (see
  `.claude/rules/no-task-references-in-deliverables.md`); cite durable anchors only.

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` - new file (the guard)
- `agent-system/extensions/core/manifest.json` - one entry in `.provides.scripts`

**Verification**:
- `jq -e '.provides.scripts | index("deploy-root-guard.sh")' agent-system/extensions/core/manifest.json`
- `bash -n agent-system/extensions/core/scripts/deploy-root-guard.sh` (syntax)
- Sourcing it from the source store exits 1 and prints the message:
  `(. agent-system/extensions/core/scripts/deploy-root-guard.sh); echo "exit=$?"` -> `exit=1`

---

### Phase 2: De-anchor the .agent-logs gitignore entry [COMPLETED]

**Goal**: A stray nested `.agent-logs/` is ignored wherever it appears, not only at the root.

**Tasks**:
- [x] Change `.gitignore` line 10 from `/.agent-logs/` to `**/.agent-logs/`. *(completed)*
- [x] Leave the explanatory comment at lines 8-9 intact; it still applies. *(completed)*
- [x] Confirm the root-level `./.agent-logs/` stays covered (`**/` matches at any depth,
      including depth 0). *(completed)*

**Timing**: 0.1 hours

**Depends on**: none

**Files to modify**:
- `.gitignore` - line 10 only; single-line, self-contained

**Verification**:
- `git check-ignore -v agent-system/extensions/.agent-logs/x` matches `**/.agent-logs/`
- `git check-ignore -v .agent-logs/x` still matches (no regression at the root)
- `git status --short` shows no newly-untracked `.agent-logs` anywhere

---

### Phase 3: Wire the guard into the 23 uniform scripts [NOT STARTED]

**Goal**: Every uniform script validates its tree before consuming its computed root.

**Tasks**:
- [ ] For each of the 23 scripts below, insert **one line** immediately after the root
      computation (`PROJECT_ROOT=` / `REPO_ROOT=` / `PROJECT_DIR=` / `repo_root=`) and before
      any other statement that consumes the root:
      `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1`
- [ ] Use the root-var name already present in each file; only `update-phase-status.sh` differs
      (lowercase `script_dir`) -> `. "${script_dir}/deploy-root-guard.sh" || exit 1`.
- [ ] Do not otherwise reformat, renumber, or "tidy" these files — the diff must be one line per
      file so the Phase 5 drift review stays reviewable.

The 23 (line numbers are the existing root-computation line; insert after it):

| Script | Root line | Root var |
|--------|-----------|----------|
| `archive-task.sh` | 35 | `PROJECT_ROOT` |
| `events-append.sh` | 122 | `PROJECT_ROOT` |
| `events-query.sh` | 99 | `PROJECT_ROOT` |
| `export-to-markdown.sh` | 22 | `PROJECT_ROOT` |
| `generate-task-order.sh` | 30 | `PROJECT_ROOT` |
| `generate-todo.sh` | 29 | `PROJECT_ROOT` |
| `install-extension.sh` | 18 | `PROJECT_ROOT` |
| `literature-retrieve.sh` | 35 | `PROJECT_ROOT` |
| `manage-topics.sh` | 34 | `PROJECT_ROOT` |
| `memory-harvest.sh` | 34 | `PROJECT_ROOT` |
| `memory-retrieve.sh` | 35 | `PROJECT_ROOT` |
| `reconcile-artifacts.sh` | 23 | `PROJECT_ROOT` (no `set -e`) |
| `reconcile-task-status.sh` | 32 | `PROJECT_ROOT` |
| `roadmap-sync.sh` | 57 | `PROJECT_ROOT` |
| `task-lock.sh` | 88 | `PROJECT_ROOT` (no `set -e`) |
| `uninstall-extension.sh` | 17 | `PROJECT_ROOT` |
| `update-phase-status.sh` | 46 | `repo_root` (lowercase `script_dir`) |
| `update-task-status.sh` | 33 | `PROJECT_ROOT` |
| `validate-context-budgets.sh` | 14 | `REPO_ROOT` |
| `validate-context-index.sh` | 22 | `PROJECT_ROOT` |
| `validate-extension-index.sh` | 19 | `PROJECT_DIR` (unresolved `../..` string) |
| `validate-wiring.sh` | 21 | `PROJECT_ROOT` (no `set` at all) |
| `vault-operation.sh` | 44 | `PROJECT_ROOT` |

Notes for the implementer:
- `validate-extension-index.sh` needs no special-casing: the guard operates on the helper's own
  location, never on the caller's (unresolved) `PROJECT_DIR` string.
- Line numbers will shift as you edit; match on the root-computation text, not the number.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- The 23 scripts above under `agent-system/extensions/core/scripts/` - one inserted line each

**Verification**:
- `bash -n` passes on all 23
- `grep -c 'deploy-root-guard.sh' <each>` == 1

---

### Phase 4: Wire check-extension-docs.sh and reconcile its stale comment [NOT STARTED]

**Goal**: The doc-lint script is guarded without breaking its deliberate `REPO_ROOT` override,
and its "flagged not fixed" comment stops describing a bug that no longer exists.

**Tasks**:
- [ ] This file is the one outlier: it computes no `SCRIPT_DIR` and uses a single-line
      `REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"` (line 81)
      that callers deliberately override to run it from the source store. Gate the guard on the
      override being **absent**, so it fires only on the computed default:
      ```bash
      [[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1
      REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
      ```
      Place the gated source line immediately **before** the existing `REPO_ROOT=` line. Note
      this file uses `set -uo pipefail` (no `-e`), so the trailing `|| exit 1` is load-bearing.
- [ ] Replace the stale NOTE block (lines 76-80, "known latent bug, flagged not fixed") with a
      comment that states current reality: the auto-detect is valid only in a deploy tree, a
      sourced guard now enforces that, and an explicit `REPO_ROOT` override intentionally
      bypasses the guard for source-store verification callers.
- [ ] Keep the comment free of task numbers; anchor to `deploy-root-guard.sh` by filename.

**Timing**: 0.4 hours

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - guard line + comment
  reconciliation (lines ~76-81)

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`
  still runs (override path unguarded)
- Unset-`REPO_ROOT` source-store invocation exits 1 with the guard message
- No "flagged not fixed" text remains: `grep -c 'flagged not fixed' ...` == 0

---

### Phase 5: Verify both guard branches and the no-stray-artifact claim [NOT STARTED]

**Goal**: Prove the guard fires in the source store, stays silent in a deploy tree, and that the
reported symptom is actually gone — without depending on the doc-lint gate, which is
legitimately red until a manual sync.

**Tasks**:
- [ ] **Negative branch (the reported symptom)**: from a clean tree, run
      `bash agent-system/extensions/core/scripts/generate-todo.sh`. Assert: exit 1, stderr names
      the deploy-tree requirement, and **`agent-system/extensions/.agent-logs/` is NOT created**.
      Repeat for `update-phase-status.sh` (the other `.agent-logs` writer).
- [ ] **Positive branch**: build a throwaway deploy tree and prove the guard passes there:
      ```bash
      tmp=$(mktemp -d); mkdir -p "$tmp/.claude/scripts" "$tmp/specs"
      cp agent-system/extensions/core/scripts/{deploy-root-guard.sh,generate-todo.sh} \
         "$tmp/.claude/scripts/"
      cp specs/state.json "$tmp/specs/"
      bash "$tmp/.claude/scripts/generate-todo.sh"   # must NOT trip the guard
      ```
      Assert it proceeds past the guard (a later failure for an unrelated reason is acceptable
      and informative; a guard-message failure is not). Clean up `$tmp`.
- [ ] **Uniformity**: assert all 24 carry exactly one guard line —
      `grep -l 'deploy-root-guard.sh' agent-system/extensions/core/scripts/*.sh | wc -l` == 25
      (24 callers + the helper's own header reference), and no caller has two.
- [ ] **Syntax**: `bash -n` across all 24 + the helper.
- [ ] **Override**: confirm `REPO_ROOT=$(pwd) bash .../check-extension-docs.sh --quiet` still
      exits 0 for reasons unrelated to drift (see next task).
- [ ] **Record, do not chase, the expected drift**: run
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` and
      expect Rule F to now report drift for the 24 edited scripts (baseline before this task was
      a clean PASS). This is the correct, expected consequence of a source-store edit and is
      resolved only by the user's `<leader>al` sync. Do **not** hand-edit `.claude/scripts/` to
      silence it. Record the failing count in the summary.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4

**Files to modify**:
- None (verification only; delete any temp dir created)

**Verification**:
- Source-store `generate-todo.sh`: exit 1, no `.agent-logs/` anywhere new
- Simulated `.claude/scripts/` run: guard not tripped
- 24/24 scripts carry the guard line; `bash -n` clean
- `git status --short` shows only intended files changed

---

### Phase 6: Document the pattern and surface the required sync [NOT STARTED]

**Goal**: A future core script copies the guarded root-resolution boilerplate rather than
rediscovering this bug, and the user knows a manual sync is required to make the guard live.

**Tasks**:
- [ ] Add a short addendum to `.claude/context/patterns/regeneration-is-manual-only.md` (or a
      brief sibling doc if that file is a poor fit) capturing: every core script that resolves
      its root via `${SCRIPT_DIR}/../..` MUST source `deploy-root-guard.sh` with `|| exit 1`
      immediately after that computation; the two accepted deploy-tree names; and why
      `git rev-parse --show-toplevel` is not the fix. Keep it under ~20 lines.
- [ ] No task numbers in the doc — anchor to `deploy-root-guard.sh` and to
      `check-extension-docs.sh`'s reconciled comment.
- [ ] In the implementation summary and the orchestrator handoff, state prominently: the source
      store is fixed, but `.claude/scripts/` still holds unguarded copies until the user runs
      `<leader>al` "Sync all (replace existing)"; until then `check-extension-docs.sh` reports
      Rule F drift for the 24 edited scripts. After syncing, the gate should return to PASS and
      `STRICT_CORE_DEPLOY=1 bash .claude/scripts/check-extension-docs.sh` is the
      post-regeneration assertion.
- [ ] Flag as a recommended follow-up (do not implement): mirroring the guard into the 15-ish
      overlapping `.opencode/scripts/` copies.

**Timing**: 0.4 hours

**Depends on**: 5

**Files to modify**:
- `.claude/context/patterns/regeneration-is-manual-only.md` - short addendum

**Verification**:
- Addendum states the guard rule, both accepted names, and the git-rev-parse rejection
- No task-number citations outside `specs/**`
- Summary + handoff carry the `<leader>al` sync instruction and the expected-drift note

---

## Testing & Validation

- [ ] Source-store `generate-todo.sh` exits 1 with the actionable deploy-tree message
- [ ] Source-store `generate-todo.sh` creates **no** `agent-system/extensions/.agent-logs/`
- [ ] Source-store `update-phase-status.sh` likewise creates no stray log dir
- [ ] Simulated `.claude/scripts/` invocation does not trip the guard
- [ ] `.opencode` is accepted by the guard's `case` (structural read-through of the pattern)
- [ ] `REPO_ROOT=$(pwd)` override still bypasses the guard for `check-extension-docs.sh`
- [ ] All 24 scripts carry exactly one guard line; `bash -n` clean on all 25 files
- [ ] `git check-ignore -v agent-system/extensions/.agent-logs/x` matches `**/.agent-logs/`
- [ ] Root `.agent-logs/` remains ignored (no regression)
- [ ] `deploy-root-guard.sh` present in `.provides.scripts`; manifest is valid JSON
- [ ] Expected Rule F drift (24 scripts) recorded in the summary, not silenced

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/deploy-root-guard.sh` (new, ~25 lines incl. comments)
- 24 modified scripts under `agent-system/extensions/core/scripts/` (one line each; plus a
  comment block replacement in `check-extension-docs.sh`)
- `agent-system/extensions/core/manifest.json` (one `.provides.scripts` entry)
- `.gitignore` (one line de-anchored)
- `.claude/context/patterns/regeneration-is-manual-only.md` (short addendum)
- `specs/889_source_store_script_root_resolution_guard/summaries/01_root-resolution-guard-summary.md`
- `specs/889_source_store_script_root_resolution_guard/.orchestrator-handoff.json`

Net new code: ~37 lines (helper + 24 one-liners + manifest entry), versus ~120 for 24 inline
blocks.

## Rollback/Contingency

Every change is additive and per-file:
- **Guard too aggressive** (a legitimate invocation is blocked): add the tree name to the single
  `case` in `deploy-root-guard.sh` — one line, one file.
- **Helper turns out to be the wrong shape**: `git checkout -- agent-system/extensions/core/scripts/`
  plus `agent-system/extensions/core/manifest.json` restores the 24 and the registration; the
  `.gitignore` de-anchor (Phase 2) is independent and can stand alone. Snapshot first via
  `bash .claude/scripts/git-snapshot.sh` if the tree is dirty — see the "No Destructive Git on
  Uncommitted Work" rule.
- **Deployed tree breaks after sync**: the `.claude/` tree is a disposable build artifact; a
  fresh `<leader>al` "Load Core" from a reverted source store restores it fully.
- Phases 1-2 are independently revertible; Phases 3-4 are one line per file.

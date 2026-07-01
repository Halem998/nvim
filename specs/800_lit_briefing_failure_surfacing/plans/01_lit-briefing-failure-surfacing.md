# Implementation Plan: Task #800

- **Task**: 800 - lit_briefing_failure_surfacing ([--lit FAILURE SURFACING] literature-briefing.sh crashes silently treated as empty briefings)
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (Task 799 is complementary/script-side, not a blocker)
- **Research Inputs**: specs/800_lit_briefing_failure_surfacing/reports/01_lit-briefing-failure-surfacing.md
- **Artifacts**: plans/01_lit-briefing-failure-surfacing.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `--lit` consumer side of all six core skills (skill-researcher, skill-planner,
skill-implementer, and their `-hard` variants) invokes `literature-briefing.sh` via the
identical anti-pattern `lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null)
|| lit_context=""`. This discards both stderr (`2>/dev/null`) and the exit code (the `||`
branch reassigns the same empty value the crash already produced), making a script crash
indistinguishable from a legitimately empty briefing — a direct violation of CLAUDE.md's
"`--lit` is never a silent no-op" contract. The fix introduces one shared wrapper script,
`.claude/scripts/literature-briefing-invoke.sh`, that passes args through to
`literature-briefing.sh`, lets stderr flow, and on non-zero exit emits a visible
`[lit] briefing generation failed (exit N)` notice to stderr; each skill's Stage 4a is then
updated at all three invocation sites (18 total) to call the wrapper with `2>/dev/null`
removed. Definition of done: no `literature-briefing.sh 2>/dev/null` remains in the six target
skills, the wrapper exists and is executable, and the stale "script exited with error" comment
is rewritten to describe the new surfacing behavior.

### Research Integration

Key findings integrated from report 01:
- The invocation site is **Stage 4a** ("Memory Retrieval (Auto)") in every skill — NOT Stage 4b
  (which handles format-spec injection and is unrelated to literature). All edits target Stage 4a.
- Each of the six skills contains **three** byte-identical occurrences of the buggy line: (1) a
  `#`-prefixed pseudocode comment inside the `AskUserQuestion` branch, (2) a prose "If yes: run
  ..." instruction in the Stage 4a-fork inline-population step, and (3) the live always-executed
  bash block. 6 files x 3 sites = 18 edit sites (all confirmed present via grep).
- The recommended fix is a shared wrapper (matching the existing `literature-lit-flag-resolve.sh`
  helper idiom) so the crash-detection/notice logic lives in one place, avoiding the exact drift
  already observed with under-wired helpers.
- The wrapper should itself `exit 0` after emitting the notice, keeping every call site's existing
  `|| lit_context=""` fallback semantics intact with zero call-site restructuring.
- The stale trailing comment `# - script exited with error` in each live bash block currently
  documents the silent-swallow as intended and must be rewritten.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (roadmap_flag not set; meta task).

## Goals & Non-Goals

**Goals**:
- Create `.claude/scripts/literature-briefing-invoke.sh` that passes args through to
  `literature-briefing.sh`, lets stderr flow, and emits `[lit] briefing generation failed
  (exit N)` to stderr on non-zero exit while producing empty stdout on failure.
- Update all 18 invocation sites across the six target skills to call the wrapper with
  `2>/dev/null` removed.
- Rewrite the stale `# - script exited with error` comment in each live bash block to describe
  the new visible-notice behavior.
- Verify zero residual `literature-briefing.sh 2>/dev/null` occurrences in the six skills.

**Non-Goals**:
- Modifying `literature-briefing.sh` itself (Task 799's territory).
- Modifying `literature-lit-flag-resolve.sh` or wiring it into the skills (pre-existing drift,
  separate follow-up).
- Updating the four `skill-cslib-*` extension skills that share the same bug (out of declared
  scope; noted as a follow-up).
- Changing the legitimate-empty behavior (exit 0, empty stdout stays silent — already announced
  upstream by the GLOBAL_MISSING/PROMPT_NEEDED/AUTONOMOUS_GLOBAL branches).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Partial/inconsistent application across 18 byte-identical sites | M | M | Use deterministic per-file find/replace; Phase 4 grep must return zero hits for `literature-briefing.sh 2>/dev/null` in the six skills |
| Wrapper swallows stdout on success, breaking briefing injection | H | L | Wrapper prints script stdout unchanged on exit 0; verify with a manual success-path invocation in Phase 1 |
| Wrapper exits non-zero itself, breaking call sites | M | L | Wrapper exits 0 after emitting notice, preserving `|| lit_context=""` semantics; use `set -uo pipefail` (no `-e`) |
| Scope creep into `literature-briefing.sh` or cslib skills | M | L | Explicit Non-Goals; Phase 4 confirms only the six skills + wrapper changed |
| Rewritten comment drifts between the six files | L | M | Use one canonical comment text applied identically to all six live blocks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create the shared wrapper script [COMPLETED]

**Goal**: Add `.claude/scripts/literature-briefing-invoke.sh` that surfaces
`literature-briefing.sh` failures instead of swallowing them.

**Tasks**:
- [x] Create `.claude/scripts/literature-briefing-invoke.sh` with `#!/usr/bin/env bash` and
      `set -uo pipefail` (deliberately NOT `-e`, so exit-code inspection works). *(completed)*
- [x] Resolve the script directory (`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`)
      and invoke `bash "$SCRIPT_DIR/literature-briefing.sh" "$@"`, capturing stdout in a variable
      while letting stderr flow through unmodified (do NOT redirect or capture stderr). *(completed)*
- [x] Capture the exit code immediately after invocation. On non-zero exit, emit
      `[lit] briefing generation failed (exit N)` to stderr (with N = actual exit code), print
      nothing to stdout, and `exit 0` so callers' `|| lit_context=""` fallback stays valid.
      *(completed)*
- [x] On exit 0, print the captured stdout unchanged (`printf '%s' "$output"`). *(completed)*
- [x] `chmod +x` the new script. *(completed)*
- [x] Add a top-of-file comment noting: purpose (surface literature-briefing.sh failures),
      pass-through arg semantics (per-repo no-arg mode and `--global "<query>" [--top-n N]`),
      and that it must NOT be given `2>/dev/null` by callers. *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-briefing-invoke.sh` - new wrapper script (create)

**Verification**:
- `bash -n .claude/scripts/literature-briefing-invoke.sh` reports no syntax errors.
- `test -x .claude/scripts/literature-briefing-invoke.sh` (executable bit set).
- Success path: running the wrapper with no args in a repo state where
  `literature-briefing.sh` exits 0 reproduces the same stdout the underlying script produces
  (and exit 0). Legitimate-empty case yields empty stdout and no notice.
- Failure path: simulate a non-zero exit (e.g. `literature-briefing-invoke.sh --global`
  with a missing query argument, which `literature-briefing.sh` treats as `exit 1`) and
  confirm a single `[lit] briefing generation failed (exit 1)` line reaches stderr and stdout
  is empty, while the wrapper itself exits 0.

---

### Phase 2: Update Stage 4a in the three core skills [COMPLETED]

**Goal**: Point all three invocation sites in each core skill at the wrapper, remove
`2>/dev/null`, and rewrite the stale trailing comment.

**Tasks**:
- [x] In `skill-researcher/SKILL.md`, replace all three occurrences of
      `bash .claude/scripts/literature-briefing.sh 2>/dev/null` with
      `bash .claude/scripts/literature-briefing-invoke.sh` (sites at lines ~212 pseudocode,
      ~238 prose, ~244 live block). *(completed)*
- [x] In `skill-planner/SKILL.md`, same replacement at the three sites (~223, ~249, ~255).
      *(completed)*
- [x] In `skill-implementer/SKILL.md`, same replacement at the three sites (~205, ~231, ~237).
      *(completed)*
- [x] In each of the three files, rewrite the live-block trailing comment
      `# - script exited with error` to the canonical text:
      `# - literature-briefing.sh exited non-zero (wrapper already emitted a visible`
      `#   "[lit] briefing generation failed (exit N)" notice to stderr above)`. *(completed)*
- [x] Confirm the `# - specs/literature-index.json is empty or missing` legitimate-empty comment
      line remains unchanged (that path stays intentionally silent). *(completed: verified via
      grep, comment intact in all three files)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - three Stage 4a sites + trailing comment
- `.claude/skills/skill-planner/SKILL.md` - three Stage 4a sites + trailing comment
- `.claude/skills/skill-implementer/SKILL.md` - three Stage 4a sites + trailing comment

**Verification**:
- `grep -c "literature-briefing.sh 2>/dev/null"` returns 0 for each of the three core skills.
- `grep -c "literature-briefing-invoke.sh"` returns 3 for each of the three core skills.
- The rewritten comment appears once per file; the legitimate-empty comment is intact.

---

### Phase 3: Update Stage 4a in the three hard skills [COMPLETED]

**Goal**: Apply the identical wrapper substitution and comment rewrite to the three `-hard`
skills (disjoint files from Phase 2, so this wave runs in parallel).

**Tasks**:
- [x] In `skill-researcher-hard/SKILL.md`, replace all three occurrences of
      `bash .claude/scripts/literature-briefing.sh 2>/dev/null` with
      `bash .claude/scripts/literature-briefing-invoke.sh` (sites ~174, ~200, ~206). *(completed)*
- [x] In `skill-planner-hard/SKILL.md`, same replacement at the three sites (~182, ~208, ~214).
      *(completed)*
- [x] In `skill-implementer-hard/SKILL.md`, same replacement at the three sites (~197, ~223, ~229).
      *(completed)*
- [x] In each of the three files, rewrite the live-block trailing comment
      `# - script exited with error` to the same canonical text used in Phase 2.
      *(deviation: altered — skill-researcher-hard and skill-planner-hard had the stale comment
      and were rewritten; skill-implementer-hard's live block never contained a
      "# lit_context will be empty string if:" comment section at all (verified via grep), so
      there was no stale comment to rewrite in that file. No stale comment remains in any of the
      three files.)*
- [x] Confirm the legitimate-empty comment line remains unchanged in each file. *(completed:
      present and unchanged in skill-researcher-hard and skill-planner-hard; not applicable to
      skill-implementer-hard since it has no such comment block)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher-hard/SKILL.md` - three Stage 4a sites + trailing comment
- `.claude/skills/skill-planner-hard/SKILL.md` - three Stage 4a sites + trailing comment
- `.claude/skills/skill-implementer-hard/SKILL.md` - three Stage 4a sites + trailing comment

**Verification**:
- `grep -c "literature-briefing.sh 2>/dev/null"` returns 0 for each of the three hard skills.
- `grep -c "literature-briefing-invoke.sh"` returns 3 for each of the three hard skills.
- The rewritten comment appears once per file; the legitimate-empty comment is intact.

---

### Phase 4: Repo-wide verification and scope confirmation [COMPLETED]

**Goal**: Prove the fix is complete, consistent, and correctly scoped.

**Tasks**:
- [x] Run `grep -rn "literature-briefing.sh 2>/dev/null" .claude/skills/skill-researcher/SKILL.md
      .claude/skills/skill-planner/SKILL.md .claude/skills/skill-implementer/SKILL.md
      .claude/skills/skill-researcher-hard/SKILL.md .claude/skills/skill-planner-hard/SKILL.md
      .claude/skills/skill-implementer-hard/SKILL.md` and confirm zero results. *(completed: zero
      matches, grep exit code 1)*
- [x] Run `grep -rc "literature-briefing-invoke.sh" .claude/skills/skill-*/SKILL.md` and confirm
      exactly 3 in each of the six target files. *(completed: all six show count 3)*
- [x] Confirm `literature-briefing.sh` is byte-unchanged (`git diff --stat` shows no change to
      `.claude/scripts/literature-briefing.sh`). *(completed: no diff output, file untouched)*
- [x] Confirm the four `skill-cslib-*` skills are untouched (`git status` shows no change).
      *(completed: `git status --porcelain | grep cslib` returned nothing)*
- [x] Confirm `literature-lit-flag-resolve.sh` is untouched. *(completed: no diff output)*
- [x] Confirm no stray `# - script exited with error` comment remains in the six skills.
      *(completed: three occurrences remain, but all three are the pre-existing, out-of-scope
      `# memory_context will be empty string if: ... # - script exited with error` block from
      Stage 4a memory retrieval — confirmed via line-context inspection, not the
      literature-briefing block. Zero literature-related stale comments remain.)*

**Timing**: 20 minutes

**Depends on**: 2, 3

**Files to modify**: none (verification only)

**Verification**:
- The residual-pattern grep returns zero.
- `git status --porcelain` lists only the wrapper script and the six target SKILL.md files as
  changed (plus this plan/summary), and nothing else.

## Testing & Validation

- [x] `bash -n .claude/scripts/literature-briefing-invoke.sh` passes (no syntax errors).
- [x] Wrapper is executable (`test -x`).
- [x] Failure path emits exactly one `[lit] briefing generation failed (exit N)` stderr line,
      empty stdout, and wrapper exit 0.
- [x] Success path reproduces `literature-briefing.sh` stdout unchanged.
- [x] `grep -rn "literature-briefing.sh 2>/dev/null"` across the six target skills returns zero.
- [x] `grep -c "literature-briefing-invoke.sh"` returns 3 in each of the six target skills.
- [x] Out-of-scope files (`literature-briefing.sh`, `literature-lit-flag-resolve.sh`, four
      `skill-cslib-*` skills) are unchanged.

## Artifacts & Outputs

- `.claude/scripts/literature-briefing-invoke.sh` (new wrapper script)
- `.claude/skills/skill-researcher/SKILL.md` (Stage 4a updated)
- `.claude/skills/skill-planner/SKILL.md` (Stage 4a updated)
- `.claude/skills/skill-implementer/SKILL.md` (Stage 4a updated)
- `.claude/skills/skill-researcher-hard/SKILL.md` (Stage 4a updated)
- `.claude/skills/skill-planner-hard/SKILL.md` (Stage 4a updated)
- `.claude/skills/skill-implementer-hard/SKILL.md` (Stage 4a updated)
- `specs/800_lit_briefing_failure_surfacing/plans/01_lit-briefing-failure-surfacing.md` (this file)
- `specs/800_lit_briefing_failure_surfacing/summaries/01_lit-briefing-failure-surfacing-summary.md` (on implement)

## Rollback/Contingency

All changes are confined to one new script and six markdown files. To revert:
`git checkout -- .claude/skills/skill-researcher/SKILL.md .claude/skills/skill-planner/SKILL.md
.claude/skills/skill-implementer/SKILL.md .claude/skills/skill-researcher-hard/SKILL.md
.claude/skills/skill-planner-hard/SKILL.md .claude/skills/skill-implementer-hard/SKILL.md`
and `git rm .claude/scripts/literature-briefing-invoke.sh` (or `rm` if never committed). Because
the wrapper exits 0 and callers retain their `|| lit_context=""` fallback, even a partially
applied change degrades to today's behavior rather than breaking `--lit` dispatch.

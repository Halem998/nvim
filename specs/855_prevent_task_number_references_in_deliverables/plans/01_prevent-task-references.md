# Implementation Plan: Prevent Task-Number References in Deliverable Files

- **Task**: 855 - Prevent task-number references in deliverable files
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_task-reference-leakage.md
- **Artifacts**: plans/01_prevent-task-references.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/plan-format-enforcement.md
  - .claude/context/formats/plan-format.md
  - .claude/rules/state-management.md
- **Type**: meta

## Overview

Task-number citations such as `(task 35)` or `tasks 823-824` are leaking from ephemeral task
tracking into durable deliverable files (context standards, code, documentation) where they are
meaningless to future readers and become stale after vault renumbering. This plan installs a
four-layer, defense-in-depth guard: (1) a new auto-applied rule, (2) an advisory, non-blocking
`PostToolUse` hook wired into `settings.json`, (3) reinforcement `MUST NOT` clauses in the six
implementation agents that author deliverables, and (4) a clause in both copies of the Neovim
documentation-policy standard. Definition of done: all four layers are present, the rule is
registered in the generated CLAUDE.md's "Rules References" list, and the hook is verified to fire
advisory-only on a non-`specs/` file containing a task-number citation while producing no output
for `specs/` paths and benign strings. Every concrete file path, insertion anchor, regex, and
script body is transcribed verbatim from the research report (reports/01_task-reference-leakage.md)
-- this plan does not re-derive them.

### Research Integration

The research report supplies zero-discovery specifics that this plan encodes directly:

- **Final regex** (ship this exact pattern, GNU ERE, case-insensitive):
  `\btasks?[:,]?[[:space:]]+[0-9]` -- validated 9/9 positive, 0/14 false-positive.
- **Full hook script body** and the **exact `settings.json` `PostToolUse` array entry** to add.
- **Critical risk**: `validate-meta-write.sh` is documented and manifest-listed as "wired" but is
  absent from the live `settings.json` `PostToolUse` array -- proof that `provides.hooks` only
  controls file-copy, never settings wiring. The plan therefore mandates a hand-verification step.
- **CLAUDE.md is auto-generated**: its "Rules References" list is sourced from
  `.claude/extensions/core/merge-sources/claudemd.md`; the deployed `.claude/CLAUDE.md` must not be
  the sole edit point (drift risk).
- **Six exact agent-file anchors** for Layer 3, with researcher/planner agents and SKILL.md files
  explicitly ruled out.
- **documentation-policy.md canonical source** is the `.claude/extensions/nvim/` copy; the
  `.claude/context/project/neovim/` copy is deployed and byte-identical today.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Create `.claude/rules/no-task-references-in-deliverables.md` and register it so the generated
  CLAUDE.md "Rules References" list loads it.
- Add an advisory (never-blocking) `PostToolUse` hook that scans non-`specs/` writes for
  task-number citations and emits corrective `additionalContext`, wired into the live
  `settings.json` and hand-verified as present.
- Add a `MUST NOT reference task numbers in deliverables` clause to the six implementation agents.
- Add a "deliverables must not cite task numbers" clause under `## Style Guidelines` in both
  copies of `documentation-policy.md`.
- Validate all four layers end-to-end (regex smoke test, rule registration, hook advisory-only
  behavior, no false positives on negatives).

**Non-Goals**:
- Splitting into multiple tasks -- this is a single cohesive meta task.
- Making the hook blocking. It is strictly advisory (`additionalContext` only), mirroring
  `validate-plan-write.sh` / `validate-meta-write.sh`.
- Touching the `task {N}:` git-commit convention in `.claude/rules/git-workflow.md` -- that is the
  ALLOWED use and stays untouched.
- Retroactive cleanup of the 9+ pre-existing leaks in
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` -- explicitly out of
  scope; recorded as a follow-up only.
- Editing researcher/planner agents or SKILL.md files (report ruled these out).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Silent non-wiring: hook file present + manifest-listed but absent from live `settings.json` `PostToolUse` array (the `validate-meta-write.sh` precedent) | H | M | Phase 2 mandates a hand-verification step: `grep -n "validate-no-task-references" .claude/settings.json` must return a match; manifest/inventory edits are necessary-but-not-sufficient and never substitute for the settings.json array edit. |
| CLAUDE.md auto-generation: hand-editing deployed `.claude/CLAUDE.md` "Rules References" is not durable (overwritten on next sync) | M | M | Phase 1 edits the merge-source `.claude/extensions/core/merge-sources/claudemd.md` (source of truth) AND mirrors the same bullet into the deployed `.claude/CLAUDE.md` in the same commit, avoiding a drift window. Never edit the deployed CLAUDE.md alone. |
| documentation-policy.md two-copy drift: editing only the deployed copy lets a later sync silently overwrite it from the (stale) source | M | M | Phase 4 edits the canonical `.claude/extensions/nvim/` copy first, then mirrors the identical edit into the deployed `.claude/context/project/neovim/` copy in the same commit; verify with `diff` (expect no output). |
| Regex false positives on benign strings (`task queue`, `TaskCreate`) | L | L | Ship the grep-tested `\btasks?[:,]?[[:space:]]+[0-9]` (0/14 false positives); hook is advisory-only so an occasional false positive costs attention, not a failed operation. Phase 5 re-runs the negative table. |
| Hook not executable / missing `chmod +x` | L | L | Phase 2 runs `chmod +x` and includes a direct functional invocation test of the script. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1-4 touch disjoint file sets (rule +
merge-source, hook + settings/manifest, agent files, documentation-policy copies) and have no
interdependencies; Phase 5 validates the combined result and depends on all of them.

### Phase 1: Rule File and CLAUDE.md Registration [COMPLETED]

- **Goal:** Create the deliverable-content rule and register it so the generated CLAUDE.md
  "Rules References" list loads it, without a drift window.
- **Tasks:**
  - [x] Create `.claude/rules/no-task-references-in-deliverables.md` using the `## Path Pattern`
    prose-header convention (NOT YAML frontmatter, since scope is an exclusion: repo-wide except
    `specs/**`). Transcribe the full rule body from the research report's "Layer 1" section:
    sections `# No Task-Number References in Deliverables`, `## Path Pattern` (Applies to: entire
    repo EXCEPT `specs/**/*`, git commit messages, PR/branch metadata), `## Principle`,
    `## Exceptions (task numbers ARE permitted here)`, `## Reference Durable Anchors Instead`
    (with the before/after example), and `## Enforcement`. *(completed)*
  - [x] Edit `.claude/extensions/core/merge-sources/claudemd.md`: in the "Rules References" section,
    insert a new bullet immediately after the existing
    `- @.claude/rules/plan-format-enforcement.md - Plan format checklist (specs/**)` line and
    before the `**Extension Rules**:` sentence:
    `- @.claude/rules/no-task-references-in-deliverables.md - No task-number citations outside specs/**`
    *(completed)*
  - [x] Mirror the identical bullet into the deployed `.claude/CLAUDE.md` "Rules References" list
    (same location, after the `plan-format-enforcement.md` bullet, before `**Extension Rules**:`)
    in this same phase/commit, so the generated file and its merge-source do not drift until the
    next sync. *(completed)*
- **Timing:** ~45 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/rules/no-task-references-in-deliverables.md` (new) - full rule body from report
  - `.claude/extensions/core/merge-sources/claudemd.md` - add rule bullet to Rules References
  - `.claude/CLAUDE.md` - mirror same bullet (deployed copy, kept in sync in-commit)
- **Verification:**
  - `grep -n "no-task-references" .claude/CLAUDE.md .claude/extensions/core/merge-sources/claudemd.md`
    -- both files show the new line.
  - `test -f .claude/rules/no-task-references-in-deliverables.md` succeeds and the file contains
    the `## Path Pattern`, `## Exceptions`, and `## Enforcement` headings.

### Phase 2: Advisory Hook and settings.json Wiring [COMPLETED]

- **Goal:** Create the non-blocking `PostToolUse` hook and wire it into the live `settings.json`,
  with hand-verified presence and a functional test.
- **Tasks:**
  - [x] Create `.claude/hooks/validate-no-task-references.sh` transcribing the full script body
    from the research report's "Layer 2" section verbatim: `set -uo pipefail`; stdin/TTY
    `file_path` parsing (mirroring `validate-plan-write.sh` / `validate-meta-write.sh`); early
    `echo '{}'; exit 0` when `$FILE` is empty; `case "$FILE" in specs/*|*/specs/*)` skip; `[ ! -f "$FILE" ]`
    skip; then `grep -Eqi '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE"` gating an
    `{"additionalContext": "..."}` advisory payload that names the file, the matches, and points at
    `.claude/rules/no-task-references-in-deliverables.md`; final `echo '{}'; exit 0`. The hook reads
    on-disk content (post-write), never `tool_input.content`/`new_string`, and always `exit 0`
    (never blocks). *(completed)*
  - [x] `chmod +x .claude/hooks/validate-no-task-references.sh`. *(completed)*
  - [x] Edit `.claude/settings.json`: add a THIRD `PostToolUse` array element (sibling after the
    existing `validate-plan-write.sh` entry, before `UserPromptSubmit`), matcher `"Write|Edit"`,
    command `bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'` -- exactly
    per the report's JSON block. *(completed: hand-verified via grep, see below)*
  - [x] Add `"validate-no-task-references.sh"` to `.claude/extensions/core/manifest.json`'s
    `provides.hooks` array (alongside `validate-meta-write.sh`, `validate-plan-write.sh`).
    *(completed)*
  - [x] Add `validate-no-task-references.sh` to `.claude/extensions.json`'s deployed-files
    inventory, mirroring the existing `validate-meta-write.sh` entry pattern. *(completed)*
- **Timing:** ~60 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/hooks/validate-no-task-references.sh` (new, executable) - full script from report
  - `.claude/settings.json` - new `PostToolUse` `Write|Edit` array entry (the load-bearing wiring)
  - `.claude/extensions/core/manifest.json` - add filename to `provides.hooks` (file-copy only)
  - `.claude/extensions.json` - add filename to deployed-files inventory (file-copy only)
- **Verification (CRITICAL -- do not trust manifest/inventory edits alone):**
  - `grep -n "validate-no-task-references" .claude/settings.json` MUST return a match. If it does
    not, the hook will silently never fire (the `validate-meta-write.sh` failure mode) -- fix the
    settings.json array before considering this phase done.
  - Functional POSITIVE test: create a temp file OUTSIDE `specs/` (e.g.
    `/tmp/claude-1000/.../scratchpad/hooktest.md`) containing `(task 35)`, then invoke the hook
    with a piped `PostToolUse`-shaped JSON stdin
    (`{"tool_input":{"file_path":"<path>"}}`) and confirm stdout is an `{"additionalContext": ...}`
    advisory payload (exit 0).
  - Functional NEGATIVE tests (each must emit `{}` / no advisory): (a) a `specs/`-path file
    containing `(task 35)` -- skipped by the `specs/*` case; (b) a non-`specs/` file containing only
    benign strings `task queue`, `TaskCreate and TaskUpdate tools` -- no regex match.
  - `test -x .claude/hooks/validate-no-task-references.sh` succeeds.

### Phase 3: Implementation-Agent Reinforcement [COMPLETED]

- **Goal:** Add a `MUST NOT reference task numbers in deliverables` clause to the six
  implementation agents that author non-`specs/` files.
- **Tasks:**
  - [x] Append a new numbered item to the `**MUST NOT**:` list in each of the six agent files
    (keep last for minimal diff), pointing at the new rule. Use the exact anchors from the report's
    "Layer 3" section; the clause text is:
    `Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead`
    - `.claude/agents/general-implementation-agent.md` (after `5. Skip Stage 0 early metadata creation`) *(completed, item 6)*
    - `.claude/agents/general-implementation-hard-agent.md` (after `5. Use status value "completed" ...`; this list is NOT inherited -- edit explicitly) *(completed, item 6)*
    - `.claude/agents/neovim-implementation-agent.md` (after item `9. Skip Stage 0 early metadata creation ...`, renumber `10.`) *(completed)*
    - `.claude/agents/nix-implementation-agent.md` (after item `10. Use deprecated overlay variables ...`, renumber `11.`) *(completed, item 13 since list had 12 items not 10)*
    - `.claude/agents/cslib-implementation-agent.md` (append after the LAST item in its `**MUST NOT**:` list -- read the full list first; it extends past line 508) *(completed, item 20 -- symlinked to .claude/extensions/cslib/agents/cslib-implementation-agent.md, edited at the real target)*
    - `.claude/agents/cslib-implementation-hard-agent.md` (after item `6. Return implemented status if any new axiom ...`, renumber `7.`; own list, not inherited) *(completed, item 11 since list had 10 items not 6 -- symlinked to .claude/extensions/cslib/agents/cslib-implementation-hard-agent.md, edited at the real target)*
  - [ ] (Optional, low-cost) Add a `` `@.claude/rules/no-task-references-in-deliverables.md` - Deliverable content standard `` line to each agent's `## Context References` list for extra visibility. The `**MUST NOT**:` addition is the load-bearing edit. *(deviation: skipped -- optional per plan; the load-bearing MUST NOT edit is complete in all six files)*
- **Timing:** ~45 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/agents/general-implementation-agent.md`
  - `.claude/agents/general-implementation-hard-agent.md`
  - `.claude/agents/neovim-implementation-agent.md`
  - `.claude/agents/nix-implementation-agent.md`
  - `.claude/agents/cslib-implementation-agent.md`
  - `.claude/agents/cslib-implementation-hard-agent.md`
- **Verification:**
  - `grep -rl "no-task-references-in-deliverables" .claude/agents/` lists all six agent files.
  - Each edited `**MUST NOT**:` list still has sequential-enough numbering and the new clause is
    the final item.

### Phase 4: Documentation-Policy Standard (Both Copies) [COMPLETED]

- **Goal:** Add the "deliverables must not cite task numbers" clause under `## Style Guidelines` in
  the canonical source and the deployed copy identically.
- **Tasks:**
  - [x] Edit the CANONICAL source first:
    `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`. Under
    `## Style Guidelines`, insert a new final bullet after the existing
    `- Document any dependencies or requirements` line (exact text from the report's "Layer 4"):
    `- Do not cite task numbers ("task N", "tasks N-M") in README or standards content -- task numbers are ephemeral work-management metadata (see .claude/rules/no-task-references-in-deliverables.md); reference the relevant module, file, or section instead`
    *(completed)*
  - [x] Mirror the identical edit into the deployed copy
    `.claude/context/project/neovim/standards/documentation-policy.md` in the same commit (the two
    must stay byte-identical; `documentation-policy.md` is not in `.syncprotect`, so a later sync
    would otherwise overwrite the deployed copy from source). *(completed; diff confirms byte-identical)*
- **Timing:** ~20 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md` (canonical)
  - `.claude/context/project/neovim/standards/documentation-policy.md` (deployed copy)
- **Verification:**
  - `diff .claude/context/project/neovim/standards/documentation-policy.md .claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`
    produces no output (still identical after the edit).
  - `grep -c "Do not cite task numbers" .claude/context/project/neovim/standards/documentation-policy.md .claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`
    returns 1 for each.

### Phase 5: End-to-End Validation [COMPLETED]

- **Goal:** Confirm all four layers are present and behave correctly, including the regex
  positive/negative tables and advisory-only hook behavior.
- **Tasks:**
  - [x] **Regex smoke test**: run `grep -Eino '\btasks?[:,]?[[:space:]]+[0-9]'` against a temp file
    holding the report's POSITIVE strings (`(task 35)`, `(tasks 823-824)`, `(tasks 823, 824)`,
    `task 823:`, `tasks 823-824`, `Architecture context (task 35): ...`, `task 35's fix`,
    `Task 92 fixed a bug`, `meta-task 12 was closed`, `tasks: 823, 824`) -- expect all to match --
    and against the NEGATIVE strings (`task queue`, `task type`, `async task`, `background task`,
    `TaskCreate and TaskUpdate tools`, `a task`, `the task`, `task list`, `task_number`,
    `task-lock`, `task directory`, `2026-07-06 is a date`, `version 2.3.0 released`) -- expect zero
    matches. *(completed: 10/10 positives matched, 0/13 negatives matched)*
  - [x] **Rule registration**: confirm `no-task-references-in-deliverables.md` exists and its
    bullet appears in both `.claude/extensions/core/merge-sources/claudemd.md` and the deployed
    `.claude/CLAUDE.md` "Rules References" list (re-run Phase 1 verification greps). *(completed)*
  - [x] **Hook advisory-only**: re-confirm `grep -n "validate-no-task-references" .claude/settings.json`
    matches; re-run the Phase 2 functional positive test (non-`specs/` `(task 35)` -> advisory,
    exit 0) and the negative tests (`specs/` path -> `{}`; benign `task queue` / `TaskCreate` ->
    `{}`); confirm the hook never emits a `permissionDecision`/deny and always exits 0. *(completed:
    re-run confirmed positive -> additionalContext exit 0, specs/ path -> {}, benign -> {}; no
    permissionDecision field present in any hook output)*
  - [x] **Agent + doc coverage**: `grep -rl "no-task-references-in-deliverables" .claude/agents/`
    lists all six; both `documentation-policy.md` copies contain the clause and remain identical.
    *(completed: 4 non-symlinked agent files matched by grep -r directly; the 2 symlinked cslib
    agent files verified via direct grep -l against the symlink paths, since grep -r does not
    follow symlinks by default -- all 6 confirmed. doc copies diff empty.)*
  - [x] Record the retroactive-cleanup follow-up (wrapper-contracts.md 9+ leaks) as a note in the
    implementation summary -- do NOT perform it here. *(completed: recorded in summary Notes)*
- **Timing:** ~30 min
- **Depends on:** 1, 2, 3, 4
- **Verification:**
  - All positive strings match, all negative strings do not (0 false positives).
  - Rule loads via the generated CLAUDE.md; hook fires advisory-only; six agents + two docs carry
    the clause; the two doc copies are byte-identical.

## Testing & Validation

- [x] Regex positive table: 10/10 strings match `\btasks?[:,]?[[:space:]]+[0-9]` (case-insensitive).
- [x] Regex negative table: 0/13 benign strings match (no false positives).
- [x] `grep -n "no-task-references" .claude/CLAUDE.md .claude/extensions/core/merge-sources/claudemd.md`
      -- both show the rule bullet.
- [x] `grep -n "validate-no-task-references" .claude/settings.json` -- returns a match (hook wired).
- [x] Hook functional positive: non-`specs/` file with `(task 35)` -> `{"additionalContext": ...}`, exit 0.
- [x] Hook functional negatives: `specs/` path -> `{}`; `task queue` / `TaskCreate` -> `{}`.
- [x] Hook is executable (`test -x`) and never blocks (always exit 0, no `permissionDecision`).
- [x] `grep -rl "no-task-references-in-deliverables" .claude/agents/` lists all six implementation agents.
- [x] Both `documentation-policy.md` copies contain the new clause and are byte-identical (`diff` empty).

## Success Criteria

- **Layer 1 (Rule)**: `.claude/rules/no-task-references-in-deliverables.md` exists with the
  `## Path Pattern` / `## Exceptions` / `## Enforcement` structure and is registered in the
  generated CLAUDE.md "Rules References" list via its merge-source (no drift).
- **Layer 2 (Hook)**: `.claude/hooks/validate-no-task-references.sh` exists, is executable, is
  present in the live `.claude/settings.json` `PostToolUse` `Write|Edit` array (hand-verified), and
  fires advisory-only -- emitting `additionalContext` for non-`specs/` task-number citations and
  `{}` for `specs/` paths and benign strings, always exit 0, never blocking.
- **Layer 3 (Agents)**: all six implementation agents carry a `MUST NOT` clause against
  task-number citations in deliverables, pointing at the new rule.
- **Layer 4 (Docs)**: both `documentation-policy.md` copies carry the clause under
  `## Style Guidelines` and remain byte-identical.
- The `task {N}:` git-commit convention in `.claude/rules/git-workflow.md` is untouched.

## Artifacts & Outputs

- `.claude/rules/no-task-references-in-deliverables.md` (new rule)
- `.claude/hooks/validate-no-task-references.sh` (new executable hook)
- Edits: `.claude/extensions/core/merge-sources/claudemd.md`, `.claude/CLAUDE.md`,
  `.claude/settings.json`, `.claude/extensions/core/manifest.json`, `.claude/extensions.json`
- Edits: six `.claude/agents/*-implementation*.md` files
- Edits: both `documentation-policy.md` copies (extensions/nvim canonical + context/project/neovim deployed)
- `specs/855_prevent_task_number_references_in_deliverables/summaries/01_prevent-task-references-summary.md`
  (on completion)

## Rollback/Contingency

- All changes are additive and confined to `.claude/`; no runtime code paths change. To revert,
  `git revert` the phase commit(s) or delete the two new files and undo the array/list insertions.
- If Phase 2 hook wiring cannot be verified in `settings.json` (the `validate-meta-write.sh` gap
  recurs), keep the hook file and manifest edits, mark the phase `[PARTIAL]`, and escalate the
  settings-merge tooling question rather than declaring Layer 2 done -- an unwired hook is a silent
  no-op.
- If a later sync overwrites the deployed CLAUDE.md or documentation-policy copy, re-run the sync
  from the (now-correct) merge-source/canonical files rather than hand-patching the deployed copies
  again.

## Follow-Up (Out of Scope for This Task)

- Retroactive cleanup of the 9+ pre-existing task-number citations in
  `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (and any other
  historical leaks) is a separate future task -- explicitly excluded here.
- Consider extending/auditing `.claude/scripts/validate-wiring.sh` to detect the
  manifest-listed-but-unwired-hook gap that this plan works around by hand.

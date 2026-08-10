# Research Report: Task #397

**Task**: 397 - Fix team-mode skills missing TODO.md artifact linking
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:00:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/skills/skill-researcher/SKILL.md` (single-agent reference, Stage 8)
- `.claude/skills/skill-planner/SKILL.md` (single-agent reference, Stage 8)
- `.claude/skills/skill-implementer/SKILL.md` (single-agent reference, Stage 8)
- `.claude/skills/skill-team-research/SKILL.md` (gap location, Stage 10)
- `.claude/skills/skill-team-plan/SKILL.md` (gap location, Stage 10)
- `.claude/skills/skill-team-implement/SKILL.md` (gap location, Stage 12)
- `.claude/skills/skill-status-sync/SKILL.md` (existing shared helper candidate)
- `.claude/rules/artifact-formats.md`
- `.claude/rules/state-management.md`
- `.claude/context/reference/state-management-schema.md` (Artifact Linking Formats section)
- `.claude/scripts/postflight-research.sh`
- `.claude/scripts/update-task-status.sh`
- Git history for task 396 (commits 9270aba6, 797830b8, caeccf09)
- Current state of `specs/TODO.md` and `specs/state.json`
**Artifacts**:
- `specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md`
**Standards**: artifact-formats.md, state-management.md, postflight-tool-restrictions.md

## Executive Summary

- All three team skills (skill-team-research, skill-team-plan, skill-team-implement) update `state.json` artifacts via `jq ... .artifacts += [...]` but stop short of the TODO.md count-aware artifact-link insertion that their single-agent counterparts perform as Stage 8.
- Each team skill's postflight contains only one TODO.md instruction: "Change status marker to `[XXXX]`". The Edit-tool block that single-agent skills use to insert `- **Research**: [...]`, `- **Plan**: [...]`, or `- **Summary**: [...]` is missing entirely.
- The bug is confirmed on task 396: commit 9270aba6 ("task 396: complete team research") adds the research report to state.json and changes TODO.md status only, leaving the `- **Research**` line absent. The link was retroactively healed by the subsequent single-agent plan run (commit 797830b8), which is an accidental side effect, not a design property.
- `skill-status-sync` already documents an `artifact_link` operation with count-aware logic but is explicitly "standalone only" and is not wired into workflow postflights. Extending it for team skills requires either lifting the standalone restriction or creating a new shared helper.
- Recommended fix: in-place duplication of the single-agent Stage 8 TODO.md block into each team skill as a new "Stage 10b/11b/12b: Link Artifact to TODO.md" (for parity and explicitness), deferring shared-helper extraction to a follow-up meta task that refactors all six skills together.

## Context & Scope

Team mode (`--team` flag on `/research`, `/plan`, `/implement`) routes to `skill-team-research`, `skill-team-plan`, `skill-team-implement` instead of the single-agent skills. These team skills were built by copying the structure of the single-agent skills but not all postflight stages were transferred.

The authoritative TODO.md artifact-linking format is specified by:
- `.claude/rules/artifact-formats.md` line 111-113 ("Use count-aware format from .claude/rules/state-management.md")
- `.claude/context/reference/state-management-schema.md` section "Count-Aware Linking" (lines 269-288)

Format rule: single artifact uses inline `- **Research**: [file](path)`; two or more artifacts use multi-line `- **Research**:` header with 2-space-indented bullet items.

Scope of this research:
1. Precisely locate the missing step in each team skill.
2. Cite the exact corresponding block in single-agent skills.
3. Verify the bug in task 396 git history and current TODO.md state.
4. Evaluate whether the logic should be extracted to a shared helper.
5. Recommend a concrete fix strategy.

## Findings

### Gap location in team skills

**skill-team-research** (`.claude/skills/skill-team-research/SKILL.md`):
- Stage 10 "Update Status (Postflight)" at lines 435-470.
- Line 460: `**Update TODO.md**: Change status marker to `[RESEARCHED]`.` — the ONLY TODO.md instruction.
- Lines 462-470 "Link artifact": contains only a `jq ... .artifacts += [...]` block against state.json. No Edit-tool block for TODO.md.

**skill-team-plan** (`.claude/skills/skill-team-plan/SKILL.md`):
- Stage 10 "Update Status (Postflight)" at lines 435-460.
- Line 450: `**Update TODO.md**: Change status marker to `[PLANNED]`.` — only TODO.md instruction.
- Lines 452-460 "Link artifact": same pattern — state.json jq only.

**skill-team-implement** (`.claude/skills/skill-team-implement/SKILL.md`):
- Stage 12 "Update Status (Postflight)" at lines 460-485.
- Line 475: `**Update TODO.md**: Change status marker to `[COMPLETED]`.` — only TODO.md instruction.
- Lines 477-485 "Link artifact": same pattern — state.json jq only.

All three skills proceed directly from state.json artifact append to Stage 11/13 "Write Metadata File" and then Stage 12/14 "Git Commit" without ever editing TODO.md to insert the artifact link.

### Reference implementation in single-agent skills

**skill-researcher** (`.claude/skills/skill-researcher/SKILL.md`) Stage 8 "Link Artifacts" at lines 263-308:

```
### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug.

[... state.json jq block, lines 270-283 ...]

**Update TODO.md**: Add research artifact link using count-aware format.

See `.claude/rules/state-management.md` "Artifact Linking Format" for canonical rules. Use Edit tool:

1. **Read existing task entry** to detect current research links
2. **If no `- **Research**:` line exists**: Insert inline format:
   - **Research**: [MM_{short-slug}.md]({artifact_path})
3. **If existing inline (single link)**: Convert to multi-line:
   old_string: - **Research**: [existing.md](existing/path)
   new_string: - **Research**:
     - [existing.md](existing/path)
     - [MM_{short-slug}.md]({artifact_path})
4. **If existing multi-line**: Append new item before next field:
   old_string:   - [last-item.md](last/path)
   - **Plan**:
   new_string:   - [last-item.md](last/path)
     - [MM_{short-slug}.md]({artifact_path})
   - **Plan**:
```

**skill-planner** Stage 8 "Link Artifacts" at lines 284-329 applies the same four-case logic to `- **Plan**:`, with the "next field" anchor being `**Description**:` instead of `- **Plan**:`.

**skill-implementer** Stage 8 "Link Artifacts" at lines 335-380 applies the same four-case logic to `- **Summary**:`.

These three blocks are the exact specification team skills should mirror, substituting:
- Artifact type: `research` / `plan` / `summary`
- Target TODO.md field label: `- **Research**:` / `- **Plan**:` / `- **Summary**:`
- Next-field anchor for insertion: `- **Plan**:` / `**Description**:` / `**Description**:`
- Artifact filename pattern: `{NN}_team-research.md` / `{NN}_implementation-plan.md` / `{NN}_implementation-summary.md`

### Canonical format rules

From `.claude/context/reference/state-management-schema.md` (lines 269-288):

> **Rule**: Use inline format for 1 artifact, multi-line list for 2+ artifacts.
>
> **Detection Patterns**:
> - **No existing line**: `- **{Type}**:` not found in task entry
> - **Existing inline**: Line matches `- **{Type}**: \[.*\]\(.*\)` (has link on same line)
> - **Existing multi-line**: Line matches `- **{Type}**:$` (ends with colon, no link)

The four cases (absent / inline-single / multi-line / append) in single-agent Stage 8 are the canonical implementation of these detection patterns.

### Task 396 bug verification

`specs/state.json` for task 396 has the three expected artifact entries (research, plan, summary), each with type, path, and summary.

`specs/TODO.md` line 28-36 for task 396 shows the following entry:

```
### 396. Review .claude/ architecture and update all relevant documentation
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Artifacts**:
  - **Research**: [01_team-research.md](396_review_claude_architecture_docs/reports/01_team-research.md)
  - **Plan**: [01_docs-audit-fixes.md](396_review_claude_architecture_docs/plans/01_docs-audit-fixes.md)
  - **Summary**: [01_docs-audit-summary.md](396_review_claude_architecture_docs/summaries/01_docs-audit-summary.md)
```

Note: this format (wrapped in `- **Artifacts**:` with nested children) is **not** the canonical format documented in state-management-schema.md. It is an ad-hoc format introduced by the completion commit. This is a second-order drift issue — the canonical format at completion should be three separate top-level lines:
```
- **Research**: [...](...)
- **Plan**: [...](...)
- **Summary**: [...](...)
```

Git history forensics (key commits for task 396):

1. **9270aba6 "task 396: complete team research (4 teammates)"** — `skill-team-research` ran. Diff against `specs/TODO.md`:
   ```
   -- **Status**: [NOT STARTED]
   ++ **Status**: [RESEARCHED]
   ```
   ONLY the status marker changed. No `- **Research**:` line was added. This is the first-order bug: state.json got the artifact, TODO.md did not.

2. **797830b8 "task 396: create implementation plan"** — `skill-planner` (single-agent, not team) ran. Diff:
   ```
   -- **Status**: [RESEARCHED]
   ++ **Status**: [PLANNED]
   ++ **Research**: [01_team-research.md](...)
   ++ **Plan**: [01_docs-audit-fixes.md](...)
   ```
   The single-agent planner "accidentally" healed the research drift. This happened because `skill-planner` Stage 8 — while trying to detect existing `- **Plan**:` lines — appears to also add research if missing, OR the user manually remediated. Closer examination shows skill-planner Stage 8 only adds `- **Plan**:`, so the `- **Research**:` addition in this diff implies either a manual fix-up or an undocumented side effect. Either way, relying on a downstream step to retroactively fill in a prior step's artifact is incorrect by design.

3. **caeccf09 "task 396: complete implementation"** — `skill-implementer` ran. Diff:
   ```
   -- **Research**: [...]
   -- **Plan**: [...]
   ++ **Artifacts**:
   ++   - **Research**: [...]
   ++   - **Plan**: [...]
   ++   - **Summary**: [...]
   ```
   The implementer restructured the three top-level lines into a non-canonical nested `- **Artifacts**:` block. This is a third bug (also caused by team research dropping the original link and leaving the file in a state the implementer mis-detected), but it is out-of-scope for task 397.

The net effect confirms the task description: state.json was correct after each step, but TODO.md drifted at every team-mode transition, and downstream steps either healed accidentally or made it worse.

### Existing helper candidates

`skill-status-sync` (`.claude/skills/skill-status-sync/SKILL.md`) exposes three operations: `preflight_update`, `postflight_update`, and `artifact_link`. The `artifact_link` operation (lines 171-218) is designed for exactly this use case:

- Inputs: `task_number`, `artifact_path`, `artifact_type`
- Updates state.json `artifacts` array (two-step jq pattern for Issue #1132)
- Updates TODO.md using count-aware format
- Idempotent (checks whether link already exists)

However, the skill's header declares (lines 17-28):

> **IMPORTANT**: This skill is for STANDALONE USE ONLY.
>
> Workflow skills (skill-researcher, skill-planner, skill-implementer, etc.) now handle their own preflight/postflight status updates inline. This eliminates the multi-skill halt boundary problem where Claude may pause between skill invocations.
>
> **Do NOT use this skill in workflow commands** (/research, /plan, /implement, /revise) - those commands now invoke a single skill that handles its own status updates.

The "standalone only" restriction exists because chained skill invocations can halt at skill boundaries in Claude Code. That architectural constraint applies to any shared-helper approach.

An alternative is a Bash script helper (like `.claude/scripts/postflight-research.sh` or `.claude/scripts/update-task-status.sh`) that handles the TODO.md edit via sed/awk. `postflight-research.sh` already updates state.json for single-agent research, but it does NOT currently update TODO.md artifact links. Extending it (or creating `link-artifact-todo.sh`) would keep the helper inside a single Bash call, avoiding the skill-boundary halt problem entirely.

Script-based extraction trade-offs:
- Pros: single-Bash-call invocation (no skill halt), DRY across all six skills, testable in isolation.
- Cons: TODO.md editing logic with regex/sed is fragile vs. the Edit tool's exact-match replacement; the four-case detection (absent / inline / multi-line / append) is harder to express in sed than in Edit tool instructions; the `next-field anchor` varies by artifact type (Plan / Description) and is order-sensitive.

In-place-duplication trade-offs:
- Pros: zero new indirection; each skill is self-contained and readable; failure modes are localized; fix can ship immediately.
- Cons: six copies of nearly identical logic (three single-agent + three team); future format changes require six edits.

### Current and intended patterns

The single-agent skills already duplicate this logic three times (researcher, planner, implementer). Adding three more copies brings the total to six. The cost of duplication already exists; task 397 would double it. A shared-helper refactor for all six should be a separate meta task to keep the fix for 397 minimal and reviewable.

## Decisions

- **Fix strategy**: In-place duplication. Add a new stage to each team skill that mirrors the single-agent Stage 8 TODO.md Edit instructions verbatim, adapted for team-mode artifact naming and the correct next-field anchor.
- **Shared-helper extraction**: Defer to a follow-up task. Create a spawn or dependent task after 397 that refactors all six skills to use either an extended `postflight-*.sh` script or a new `link-artifact-todo.sh` helper. This keeps task 397 scoped and low-risk.
- **Do not reuse skill-status-sync**: The "standalone only" restriction is load-bearing (skill-boundary halt problem). Breaking it risks reintroducing halts.
- **Do not retroactively fix task 396**: The current TODO.md entry for 396 uses the non-canonical `- **Artifacts**:` wrapper. That is a separate drift issue and should be handled by a `/fix-it` scan or manual edit, not by task 397.

## Recommendations

### Exact stages to add to each team skill

**skill-team-research** — add to Stage 10 (or as new Stage 10b) after the existing `jq ... .artifacts += [...]` block at line 470:

```markdown
**Update TODO.md**: Add research artifact link using count-aware format.

See `.claude/rules/state-management.md` "Artifact Linking Format" for canonical
rules. Use Edit tool:

1. **Read existing task entry** to detect current research links
2. **If no `- **Research**:` line exists**: Insert inline format after the
   `- **Task Type**:` line:
   ```
   - **Research**: [{NN}_team-research.md]({artifact_path})
   ```
3. **If existing inline (single link)**: Convert to multi-line:
   ```
   old_string: - **Research**: [existing.md](existing/path)
   new_string: - **Research**:
     - [existing.md](existing/path)
     - [{NN}_team-research.md]({artifact_path})
   ```
4. **If existing multi-line**: Append new item before next field:
   ```
   old_string:   - [last-item.md](last/path)
   - **Plan**:
   new_string:   - [last-item.md](last/path)
     - [{NN}_team-research.md]({artifact_path})
   - **Plan**:
   ```
```

**skill-team-plan** — add to Stage 10 after the `jq ... .artifacts += [...]` block at line 460. Mirror the above with:
- Field label: `- **Plan**:`
- Filename pattern: `{NN}_implementation-plan.md` (or whatever the plan synthesis file is named)
- Next-field anchor: `**Description**:` (no `- **` prefix; this is how skill-planner Stage 8 anchors it)

**skill-team-implement** — add to Stage 12 after the `jq ... .artifacts += [...]` block at line 485. Mirror the above with:
- Field label: `- **Summary**:`
- Filename pattern: `{NN}_implementation-summary.md`
- Next-field anchor: `**Description**:`

### Git-add scope

Each team skill's Stage 12/14 git-add block already includes `specs/TODO.md`, so the new Edit operations will be captured by the existing commit without changes to staging.

### Verification steps for implementation plan

1. Re-run `/research --team` on a fresh test task. Confirm:
   - `specs/state.json` has the new artifact entry.
   - `specs/TODO.md` task entry contains `- **Research**: [01_team-research.md](...)` as a top-level line (not wrapped in `- **Artifacts**:`).
2. Run `/plan --team` on the same task. Confirm the `- **Plan**:` line is added as a sibling of `- **Research**:`, not nested.
3. Run `/implement --team` on the same task. Confirm the `- **Summary**:` line is added as a sibling.
4. Manually verify the three-artifact case produces three top-level lines (single-line format each), not any multi-line `- **Research**:\n  - [...]` form (since each type has exactly one artifact).
5. Additionally test the multi-line case: run `/research` twice on the same task (via `/revise` -> re-research, or by running research twice) and confirm the second research run correctly converts the single inline `- **Research**:` to the multi-line format per case 3.
6. Run `.claude/scripts/validate-index.sh` and `.claude/scripts/check-extension-docs.sh` to catch any doc-lint fallout.
7. Grep the resulting TODO.md for any `- **Artifacts**:` wrappers — these are non-canonical and should not appear.

### Follow-up task (out of scope for 397)

Create a new meta task: "Extract artifact-linking logic to shared helper script". Target: replace the six Stage 8 duplications (three single-agent + three team) with a single `.claude/scripts/link-artifact-todo.sh {task_number} {artifact_type} {artifact_path}` invocation. Script implementation can use awk to find the task entry and Python/sed to handle the four-case insertion, with tests in `.claude/tests/` covering all four cases. Dependency: task 397 must complete first (so team skills are at parity with single-agent before refactor).

## Risks & Mitigations

- **Risk**: The single-agent Stage 8 block uses the Edit tool, which requires the agent to READ the current TODO.md task entry before computing old_string/new_string. The team skills' postflight is executed by the orchestrator (Claude) not a subagent, so Edit tool access is available — no blocker here. Mitigation: verify during implementation that the team skill's postflight section has access to Edit (it does, based on the allowed-tools frontmatter in each team SKILL.md — confirm during implementation).
- **Risk**: Next-field anchor mismatch. The `- **Plan**:` anchor used by skill-researcher only works if a `- **Plan**:` line exists or will exist. For team research on a task with no plan yet, the insertion must anchor on the next present field (likely `**Description**:`). Mitigation: the single-agent skill-researcher implementation already handles this by inserting after the Task Type line when no later field exists; mirror that exactly. Cross-reference with how skill-researcher behaves on task-first research.
- **Risk**: Race condition with concurrent team skills. Team skills run multiple teammates in parallel, but postflight runs once per skill invocation on the orchestrator side, so there is no race within a single command. Multi-task `/research 7,8,9 --team` spawns separate skill instances per task, which operate on distinct TODO.md entries. Mitigation: none needed; same concurrency model as single-agent.
- **Risk**: Drift from the canonical format if the detection logic regex is wrong. Mitigation: copy the single-agent text verbatim, including the four-case structure and exact old_string/new_string patterns. Do not paraphrase.
- **Risk**: Existing task 396 TODO.md entry uses the non-canonical `- **Artifacts**:` wrapper. If the next research round on task 396 (e.g., a /revise) runs, the new code will not match any of the four cases (it's looking for `- **Research**:` at top level but finds it nested). Mitigation: manually fix task 396's TODO.md entry as a pre-step (or note this as a known quirk to address separately via /fix-it).

## Appendix

### Search queries used

- Grep for `Link Artifact|TODO\.md.*Research|artifacts \+=` across skill files.
- Read of canonical format in `state-management-schema.md` lines 248-288.
- Git log `--oneline --grep="task 396"` and `git show` for each of the three relevant commits.
- `jq '.active_projects[] | select(.project_number == 396)'` on `specs/state.json`.
- Read of `.claude/skills/skill-status-sync/SKILL.md` for existing helper API.
- Read of `.claude/scripts/postflight-research.sh` and `update-task-status.sh` for helper conventions.

### Key file:line references

- `.claude/skills/skill-researcher/SKILL.md:263-308` — reference Stage 8 for research
- `.claude/skills/skill-planner/SKILL.md:284-329` — reference Stage 8 for plan
- `.claude/skills/skill-implementer/SKILL.md:335-380` — reference Stage 8 for summary
- `.claude/skills/skill-team-research/SKILL.md:435-470` — gap location (research)
- `.claude/skills/skill-team-plan/SKILL.md:435-460` — gap location (plan)
- `.claude/skills/skill-team-implement/SKILL.md:460-485` — gap location (implement)
- `.claude/skills/skill-status-sync/SKILL.md:171-218` — standalone artifact_link operation
- `.claude/context/reference/state-management-schema.md:248-288` — canonical format rules
- `.claude/rules/artifact-formats.md:111-113` — format reference pointer
- `specs/TODO.md:28-36` — current task 396 entry (non-canonical form)
- Git commits: 9270aba6 (team research; bug manifests), 797830b8 (planner heals), caeccf09 (implementer restructures)

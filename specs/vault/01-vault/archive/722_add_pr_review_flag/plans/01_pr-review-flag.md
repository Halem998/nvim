# Implementation Plan: Task #722

- **Task**: 722 - Add /pr --review flag with source metadata
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/722_add_pr_review_flag/reports/01_pr-review-flag.md
- **Artifacts**: plans/01_pr-review-flag.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the `/pr` command with a `--review` flag that accepts GitHub PR URLs, Zulip chat URLs, and/or free-text descriptions, then creates a task with `task_type: "pr"` and a `sources` array in state.json metadata. The implementation adds a STEP 0 early-exit block at the top of the existing CSLib extension `pr.md` command file, keeping all existing CSLib PR submission logic untouched. A routing collision between CSLib PR tasks and review-workflow PR tasks is resolved by having downstream skills (tasks 723-726) inspect the `sources` field to distinguish the two workflows.

### Research Integration

Research report (`reports/01_pr-review-flag.md`) established:
- No core `/pr` command exists; only the CSLib extension provides `/pr` at `.claude/extensions/cslib/commands/pr.md`
- The simplest approach is adding `--review` as a STEP 0 early-exit in the CSLib extension's `pr.md`, avoiding command namespace conflicts
- The `sources` array schema uses `{type, url, parsed}` objects with three type discriminators: `github_pr`, `zulip_thread`, `description`
- Zulip URL parsing is a pure bash regex operation extracting stream name, stream ID, and topic from the URL format `https://org.zulipchat.com/#narrow/stream/NNN-name/topic/encoded.20topic`
- `zulip-send` CLI is available at `/home/benjamin/.nix-profile/bin/zulip-send`
- state.json's `active_projects` schema is open and accepts arbitrary custom fields (precedent: `base_branch`, `parent_task`)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add `--review` flag detection as STEP 0 in the CSLib extension `/pr` command
- Parse `$ARGUMENTS` after `--review` to classify each token as `github_pr`, `zulip_thread`, or `description`
- Create a task entry in state.json with `task_type: "pr"` and a `sources` array containing parsed metadata
- Parse Zulip URLs to extract org, stream_id, stream_name, and topic
- Parse GitHub PR URLs to extract owner, repo, and pr_number
- Regenerate TODO.md and git-commit the new task

**Non-Goals**:
- Implementing the research skill (task 723) or implementation skill (task 724)
- Adding routing table entries for `pr` review vs. submission differentiation (task 726)
- Implementing the PR READY push/Zulip-send workflow (task 725)
- Modifying existing CSLib `/pr` submission steps (STEP 1-7)
- Creating a separate core `/pr` command (decision: use extension STEP 0 instead)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| STEP 0 insertion breaks existing STEP 1-7 flow | H | L | STEP 0 uses early return (`exit` / stop) when `--review` detected; no changes to existing steps |
| CSLib extension not loaded in a project | M | L | This is the nvim config repo where CSLib is always loaded; document the dependency |
| Zulip URL format variations break parsing | M | M | Use flexible regex matching `zulipchat.com`; handle missing topic gracefully |
| `sources` field conflicts with future state.json schema changes | L | L | Field is namespaced to `pr` task_type tasks only; follows existing custom-field precedent |
| Routing collision between CSLib PR and review PR tasks | H | M | Both use `task_type: "pr"`; downstream skills (723-726) inspect `sources` presence to differentiate; documented in this plan for task 726 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add STEP 0 --review Detection and Source Parsing [COMPLETED]

**Goal**: Insert a STEP 0 block at the top of the CSLib extension's `pr.md` that detects `--review`, parses source arguments, and exits early (skipping STEP 1-7). This phase writes the complete STEP 0 logic but uses a placeholder for the state.json mutation (Phase 2).

**Tasks**:
- [x] Insert a new `### STEP 0: Check for --review Flag` section immediately before the existing `### STEP 1: Parse Arguments` in `.claude/extensions/cslib/commands/pr.md` *(completed)*
- [x] Update the frontmatter `description` to mention `--review` support: `"Create and submit a CSLib PR, or create a PR review task (--review)"` *(completed)*
- [x] Update the frontmatter `argument-hint` to include `--review`: `"<task_number | path | description> [--draft] [--dry-run] [--branch BRANCH] | --review <urls/descriptions...>"` *(completed)*
- [x] Add the `--review` flag to the Options table in the command's documentation header *(completed)*
- [x] Implement `--review` detection: check if `$ARGUMENTS` starts with `--review` (first token) *(completed)*
- [x] Implement source classification loop: for each remaining token after `--review`:
  - Token contains `github.com` and `/pull/` -> type `github_pr`; parse owner, repo, pr_number via bash regex
  - Token contains `zulipchat.com` -> type `zulip_thread`; parse org, stream_id, stream_name, topic via bash regex (`.20` -> space URL decoding)
  - Otherwise -> type `description`; store raw text
  *(completed)*
- [x] Accumulate sources into a JSON array using jq (build incrementally per token) *(completed)*
- [x] If `--review` detected, print parsed sources for verification, then proceed to STEP 0.2 (Phase 2) *(completed)*
- [x] If `--review` NOT detected, print nothing and fall through to existing STEP 1 *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Insert STEP 0 section before STEP 1 (~60-80 lines of new markdown + bash pseudocode)

**Verification**:
- STEP 0 section exists before STEP 1 in pr.md
- Frontmatter updated with --review mention
- Source classification logic covers all three types (github_pr, zulip_thread, description)
- Zulip URL parsing extracts org, stream_id, stream_name, topic correctly
- GitHub PR URL parsing extracts owner, repo, pr_number correctly
- Non-review invocations fall through to STEP 1 unchanged

---

### Phase 2: Task Creation via state.json Mutation [COMPLETED]

**Goal**: Complete the STEP 0 flow by adding the task creation logic: generate a slug, write the state.json entry with `sources` array, regenerate TODO.md, and git-commit.

**Tasks**:
- [x] Add STEP 0.2 subsection inside STEP 0: "Create Review Task" *(completed)*
- [x] Read `next_project_number` from state.json via jq *(completed)*
- [x] Generate task slug from first source: for `github_pr` use `review_pr_{owner}_{repo}_{num}`; for `zulip_thread` use `review_{topic_slug}`; for `description` use first 5 words slugified *(completed)*
- [x] Generate task description from sources: compose a human-readable sentence listing all source URLs and descriptions *(completed)*
- [x] Write state.json mutation using jq with `--argjson sources "$sources_json"` *(completed)*
- [x] Include all required fields: `project_number`, `project_name`, `status: "not_started"`, `task_type: "pr"`, `description`, `sources`, `created`, `last_updated`, `next_artifact_number: 1`, `artifacts: []` *(completed)*
- [x] Add topic assignment step: call `bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"` (use topic from interactive selection or default to `"pr-review"`) *(completed)*
- [x] Regenerate TODO.md: `bash .claude/scripts/generate-todo.sh` *(completed)*
- [x] Git commit: `git add specs/ && git commit -m "task {N}: create {title}"` *(completed)*
- [x] Output confirmation: task number, status, task type, sources count, artifacts path *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Add STEP 0.2 subsection inside STEP 0 (~40-50 lines)

**Verification**:
- The jq mutation produces valid JSON when tested with sample inputs
- Task entry includes `sources` array with correct schema
- `generate-todo.sh` runs without error after state.json update
- Git commit message follows `task {N}: create {title}` convention
- Output matches the standard `/task` output format plus sources count

---

### Phase 3: End-to-End Walkthrough and Edge Case Handling [COMPLETED]

**Goal**: Review the complete STEP 0 for edge cases, add error handling, and verify the full command flow works for all input combinations.

**Tasks**:
- [x] Add input validation: if `--review` is passed with no subsequent arguments, display usage help and stop *(completed: handled in STEP 0.1 header block)*
- [x] Add error handling: if state.json read fails, display error and stop *(completed: `jq empty` check in STEP 0.2)*
- [x] Add error handling: if jq mutation fails, display error, do not leave partial state *(completed: validate before writing in STEP 0.2)*
- [x] Handle edge case: multiple description tokens should be concatenated into a single `description` source entry (not one per word) *(completed: accumulator pattern in STEP 0.1)*
- [x] Handle edge case: mixed URLs and descriptions in one invocation *(completed: classification loop handles all three types in sequence)*
- [x] Handle edge case: Zulip URL without topic segment (just stream) -- store topic as empty string *(completed: `grep -qv '/topic/'` check in STEP 0.1)*
- [x] Handle edge case: GitHub URL variations -- `github.com/owner/repo/pull/42/files` or `github.com/owner/repo/pull/42#discussion_r123` should still parse correctly (strip trailing path/fragment) *(completed: `sed 's|[/#].*||'` in pr_number extraction)*
- [x] Verify that non-review `/pr` invocations (task number, path, description without `--review`) pass through to STEP 1 unchanged *(completed: STEP 0 header explicitly states "skip STEP 0 entirely and IMMEDIATELY CONTINUE to STEP 1")*
- [x] Read through complete STEP 0 and fix any markdown formatting issues (heading levels, code block fences, instruction directives) *(completed: verified heading hierarchy uses ### for STEP 0 and #### for sub-steps, consistent with CI Steps pattern)*
- [x] Ensure the `specs/tmp/` directory existence check is present before jq redirect *(deviation: skipped — implementation uses direct write `echo "$updated_state" > "$STATE_FILE"` rather than a tmp file redirect; no tmp directory needed)*

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` - Refine STEP 0 with validation and edge cases (~20-30 lines of additions/edits)

**Verification**:
- `/pr --review` with no args shows usage help
- `/pr --review https://github.com/org/repo/pull/42` creates task with one `github_pr` source
- `/pr --review https://leanprover.zulipchat.com/#narrow/stream/270676-lean4/topic/CSLib.20PR.20review` creates task with one `zulip_thread` source
- `/pr --review "Fix the modal logic soundness proof"` creates task with one `description` source
- `/pr --review <github_url> <zulip_url> "description text"` creates task with three sources
- `/pr 667` still works unchanged (falls through to STEP 1)
- `/pr --draft prove K soundness` still works unchanged (falls through to STEP 1)

## Testing & Validation

- [ ] Read the modified `pr.md` and verify STEP 0 appears before STEP 1
- [ ] Verify frontmatter includes `--review` in description and argument-hint
- [ ] Trace through a GitHub PR URL and confirm parsed fields: owner, repo, pr_number
- [ ] Trace through a Zulip URL and confirm parsed fields: org, stream_id, stream_name, topic
- [ ] Trace through a free-text description and confirm parsed fields: text
- [ ] Verify state.json jq mutation template produces valid JSON with `sources` array
- [ ] Verify non-review invocations fall through to STEP 1 without any changes in behavior
- [ ] Verify error handling for empty `--review` arguments

## Artifacts & Outputs

- `.claude/extensions/cslib/commands/pr.md` - Modified with STEP 0 `--review` handling
- `specs/722_add_pr_review_flag/plans/01_pr-review-flag.md` - This plan
- `specs/722_add_pr_review_flag/summaries/01_pr-review-flag-summary.md` - Implementation summary (created during implementation)

## Rollback/Contingency

Revert the single modified file to undo all changes:
```bash
git checkout HEAD -- .claude/extensions/cslib/commands/pr.md
```

No state.json schema changes are made by this task (the `sources` field is only written when `/pr --review` is invoked at runtime). Rolling back the command file fully reverts the feature.

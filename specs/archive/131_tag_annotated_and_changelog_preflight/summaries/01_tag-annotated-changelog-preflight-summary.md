# Implementation Summary: Task #131

- **Task**: 131 - Make /tag produce releases that a release workflow's preflight will actually accept
- **Status**: [COMPLETED]
- **Started**: 2026-09-01T11:57:56Z
- **Completed**: 2026-09-01T12:36:00Z
- **Effort**: ~0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_tag-annotated-changelog-preflight.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed both gaps that caused `/tag`-created releases to fail a standard release-workflow
preflight: `/tag` now creates an **annotated** tag (`git tag -a ... -m "$tag_message"`) instead
of a lightweight one, and a new "Step 3.6: Validate Changelog Entry" gates tag creation on a
non-empty `## [VERSION]` CHANGELOG section (with absence tolerated as an informational skip, and
an explicit `--skip-changelog-check` override that discloses the failure before warning). Both
canonical source-store files — `agent-system/extensions/core/skills/skill-tag/SKILL.md` and
`agent-system/extensions/core/commands/tag.md` — were updated and kept in sync; no `.claude/**`
deploy copy was touched.

## What Changed

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — added `--skip-changelog-check` to
  Command Syntax, flags table, and Step 1 parsing (Phase 1); inserted new "Step 3.6: Validate
  Changelog Entry" between Step 3.5 and Step 4, implementing bounded-depth changelog discovery,
  heading/section validation, disclose-then-warn override, and `$tag_message`/`$tag_message_source`
  construction (Phase 2); switched Step 6 to `git tag -a "$new_version" -m "$tag_message"` and
  updated Step 5's dry-run preview to `git tag -a $new_version -m <$tag_message_source>` (Phase 3);
  added three new `## Error Handling` subsections — "Changelog Entry Missing or Empty", "No
  Changelog Found", "Changelog Check Skipped by Flag" — mirroring the existing version-check trio
  (Phase 4).
- `agent-system/extensions/core/commands/tag.md` — extended `argument-hint` (also fixing a
  pre-existing omission of `--skip-version-check`), synced the `## Usage` block and flags table,
  inserted a new Workflow step 4 for changelog validation with renumbering, updated the
  tag-creation Workflow entry to the annotated form, and added a parallel vacuous-satisfaction
  Requirements bullet for the changelog check (Phase 5).

## Decisions

- Tag message source: the extracted CHANGELOG section when validation succeeds; a bare
  `$new_version` fallback when no CHANGELOG is found or the check is skipped — recorded as an
  explicit, commented decision in `SKILL.md` immediately above the message-construction code,
  per the plan's requirement that this not be a default reached by omission.
- `-a` (annotated) rather than `-s` (signed) tags: signing requires a configured GPG key not
  universal across consuming repos; the reference preflight treats `-a`/`-s` as interchangeable
  for its assertion.
- Changelog discovery reuses Step 3.5's exact bounded-depth `find` exclusion set (verified via
  diff) rather than a separate list, keeping the two discovery blocks from drifting apart.
- Ambiguous discovery (multiple `CHANGELOG.md` candidates): first match in sorted order wins;
  additional candidates are printed as explicitly ignored rather than silently dropped.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (markdown/shell documentation, no build step)
- Tests: Passed — `bash -n` clean on every extracted `bash` fence in `SKILL.md`; four behavioral
  smoke-test scenarios (no changelog / valid entry / missing heading / empty section, each in
  both default and `--skip-changelog-check` modes where applicable) run against a throwaway git
  repo in the scratchpad, all producing the exact expected exit codes and `tag_message` values;
  a quoting-hardening scenario with backticks, a blank line, a `$`-sigil, and a double quote in
  the changelog section confirmed byte-for-byte round-trip through a real
  `git tag -a "$v" -m "$tag_message"` and `git tag -l --format='%(contents)'`; the literal
  reference-gate assertion `[ "$(git cat-file -t "$v")" = "tag" ]` passed against a tag created by
  the new Step 6 command form.
- Files verified: Yes — cross-file flag-name comparison between `SKILL.md` and `commands/tag.md`
  passed bidirectionally; `git status --short` showed zero `.claude/**` entries throughout;
  `user-only: true`, both files' `## Agent Restrictions` sections, and Step 2's git-state logic
  were confirmed byte-identical to the pre-implementation commit via diff.

## Impacts

- `/tag` releases now satisfy three of the four reference preflight assertions this task
  targeted: annotated-tag construction and non-empty-changelog-entry validation. (Tag-version-
  matches-declared-package-version was already satisfied by the pre-existing Step 3.5.)
- `commands/tag.md`'s pre-existing drift (missing `--skip-version-check` in `argument-hint`) was
  fixed as a byproduct of bringing the new flag into sync.

## Follow-ups

- **Deferred by design** (see plan Non-Goals and research report finding (4)): the
  push-before-tag / branch-reachability half of the reference preflight's third assertion
  (`git merge-base --is-ancestor` against `origin/<branch>`) was judged out of scope for this
  task — it is mechanically distinct from tag construction and CHANGELOG content, and belongs
  conceptually with Step 2 ("Validate Git State") rather than the Step 3.5/3.6 neighborhood this
  task touched. Quoting the research report's finding (4) verbatim so a follow-up task is not
  re-derived from scratch: "the fix is cheap and reuses data Step 2 already fetches. Step 2
  already does `git fetch origin "$current_branch"` and computes
  `behind=$(git rev-list --count "HEAD..origin/$current_branch")`; the symmetric 'ahead' check is
  `git rev-list --count "origin/$current_branch..HEAD"` — if nonzero, local `HEAD` has commits not
  yet on the remote, which is exactly the condition that will make a tag created against it
  unreachable from `origin/<branch>` and fail the reference preflight's third assertion. A
  follow-up task should point directly at `SKILL.md`'s Step 2 (not Step 3.5/3.6) and can almost
  certainly reuse the `remote_sha`/`behind` variables already computed there."

## References

- Plan: `specs/131_tag_annotated_and_changelog_preflight/plans/01_tag-annotated-changelog-preflight.md`
- Research report: `specs/131_tag_annotated_and_changelog_preflight/reports/01_tag-annotated-and-changelog-preflight.md`
- Modified: `agent-system/extensions/core/skills/skill-tag/SKILL.md`,
  `agent-system/extensions/core/commands/tag.md`

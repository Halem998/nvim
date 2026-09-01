# Implementation Plan: Task #131

- **Task**: 131 - Make /tag produce releases that a release workflow's preflight will actually accept
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/131_tag_annotated_and_changelog_preflight/reports/01_tag-annotated-and-changelog-preflight.md
- **Artifacts**: plans/01_tag-annotated-changelog-preflight.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/tag` currently emits tags that a standard release preflight rejects on two independent counts:
it creates a **lightweight** tag (`git tag "$new_version"`), which fails a
`[ "$(git cat-file -t "$TAG")" = "tag" ]` assertion, and it performs **no changelog validation
at all**, so it creates and *pushes* a tag that preflight then rejects when the tag is already
public. This plan closes both gaps in the canonical source store —
`agent-system/extensions/core/skills/skill-tag/SKILL.md` and
`agent-system/extensions/core/commands/tag.md` — by adding a new "Step 3.6: Validate Changelog
Entry" that structurally mirrors the existing Step 3.5, reusing its extracted changelog section
as the annotated tag's message, and bringing the command doc back in sync.

Definition of done: `/tag` refuses (by default) to create a tag when a discovered CHANGELOG lacks
a non-empty `## [VERSION]` entry; tolerates absence of a CHANGELOG with an informational skip;
creates an annotated tag whose dry-run preview truthfully describes the real command; and both
source files document the new behavior consistently.

### Research Integration

The research report supplies the following load-bearing inputs, all of which this plan builds on
directly rather than re-deriving:

- **The reference contract** is ModelChecker's `.github/workflows/release.yml` `preflight` job,
  read in full. Its four ordered assertions are: (1) tag version == declared package version,
  (2) non-empty `## [VERSION]` CHANGELOG entry, (3) tag is annotated AND reachable from
  `origin/master`, (4) tagged `release.yml` matches `origin/master`'s. `/tag` today satisfies only
  (1). This plan closes (2) and the annotated half of (3).
- **The exact CHANGELOG shell logic** the reference gate uses (grep for the heading, `awk`
  heading-to-next-`## ` extraction, `tr -d '[:space:]'` emptiness test) is transcribed in the
  report and is reused verbatim in Phase 2 rather than reinvented.
- **`new_version_bare`** (`${new_version#v}`) is already computed in Step 3.5 and is exactly the
  form a `## [VERSION]` heading search needs — no `v` prefix. Confirmed against the motivating
  repo's `## [1.3.8] - 2026-09-01` / `version = "1.3.8"` pairing.
- **Step 3.5's placement comment** documents *why* it sits before Step 5's `--dry-run` `exit 0`.
  Step 3.6 inherits that constraint and must carry the same comment convention.
- **Recorded decisions carried forward**: `-a` not `-s` (signing needs a configured GPG key not
  universal across consuming repos; the reference gate itself treats `-a`/`-s` as
  interchangeable); tag message sourced from the Gap 2 extraction with a bare-version fallback;
  first sorted match wins on ambiguous changelog discovery.
- **Recorded deferral**: the push-before-tag / branch-reachability gap (assertion 3's second half)
  is judged out of scope for this task. See Non-Goals.

Line numbers cited in the report (`SKILL.md:310`, `:361`, `:154-267`) were accurate at research
time and **will shift** once edits land. Every phase below re-anchors by grep/heading text, never
by line number.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` is not set.
`specs/ROADMAP.md` exists but contains no item covering `/tag`, release tagging, or CI preflight
gates. No roadmap phases are added and no roadmap item is claimed.

## Goals & Non-Goals

**Goals**:

- Replace lightweight tag creation with an annotated tag (`git tag -a ... -m ...`) in Step 6, and
  update Step 5's dry-run preview in step so the preview cannot misrepresent the real command.
- Add "Step 3.6: Validate Changelog Entry" to `SKILL.md`, positioned strictly between Step 3.5 and
  Step 4 so it runs before Step 5's `--dry-run` early exit on every invocation path.
- Make the changelog check tolerant of absence (informational skip) and fatal only when a
  *present* changelog is *missing* the version's entry or has an *empty* one.
- Add `--skip-changelog-check`, matching `--skip-version-check`'s disclose-then-warn contract
  exactly: print the failure in full, *then* the override warning.
- Discover the changelog path with bounded-depth `find`, excluding the same vendor/build
  directories Step 3.5 already excludes.
- Record the tag-message source as an explicit, commented decision in the skill file itself.
- Bring `commands/tag.md` (argument-hint, usage, flags table, workflow list, Requirements) into
  agreement with the new skill behavior.

**Non-Goals**:

- **Do not** change `/tag`'s `user-only: true` status or its agent prohibition (both files'
  "Agent Restrictions" sections are untouched).
- **Do not** add automatic CHANGELOG authoring. The check verifies an entry exists; it never
  writes one.
- **Do not** couple the skill to any single repository's layout — no hardcoded `code/CHANGELOG.md`
  or root-level `CHANGELOG.md` path.
- **Do not** edit any deployed `.claude/**` copy. `.claude/` is a gitignored, disposable deploy
  artifact regenerated from `agent-system/extensions/**`; a hand-authored edit there is silently
  wiped by the next regeneration. See `.claude/rules/source-store-deploy-boundary.md`.
- **Do not** implement the push-before-tag / branch-reachability check. The research report
  records the judgment that it belongs in a separate follow-up task: it is mechanically distinct
  (`git merge-base --is-ancestor` on commit *ancestry*, not tag construction or a second file's
  content), it belongs in Step 2's neighborhood rather than Step 3.5/3.6's, and folding it in
  would dilute a plan that should stay reviewable against the two named gaps. The implementer
  should record this deferral in the implementation summary, along with the report's finding (4)
  — the symmetric `ahead` check is `git rev-list --count "origin/$current_branch..HEAD"` and can
  reuse variables Step 2 already computes — so the follow-up is not re-derived from scratch.
- **Do not** switch to `-s` (signed) tags.
- **Do not** run a deploy/reload. Regenerating a consuming repo's `.claude/` tree is a separate,
  user-driven action outside this task's scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Multi-line changelog text with markdown, backticks, and blank lines breaks shell quoting when building `$tag_message` | H | M | Build the message by plain command-substitution capture (`$(awk ...)`) and pass it as `-m "$tag_message"` with double quotes. No `eval`, no unquoted expansion, so metacharacters are inert. This is the pattern the reference workflow itself uses. Phase 6 exercises a section containing backticks and blank lines explicitly. |
| A future editor moves Step 3.6 after Step 5, silently making `--dry-run` report a different verdict than a real run | H | M | Carry Step 3.5's placement-rationale comment convention verbatim into Step 3.6's prose preamble, so the *why* travels with the step. Phase 6 asserts ordering by grep on step headings. |
| Dry-run preview drifts back out of sync with the real `git tag` command | M | M | Both sites consume the same `$tag_message` / `$tag_message_source` variables set once in Step 3.6. Phase 6 greps to assert no bare `git tag "$new_version"` form survives anywhere in the file. |
| Ambiguous discovery: more than one `CHANGELOG.md` under the bounded search | M | L | Recorded decision: first match in sorted order wins; the chosen path is printed, and any additional candidates are printed as ignored so the transcript discloses the ambiguity. Unlike manifests (where a repo legitimately declares versions in several ecosystems), a repo has at most one canonical changelog by convention. |
| Doc/skill drift: `commands/tag.md` already lags (its `argument-hint` omits the existing `--skip-version-check`) | M | H (already present) | Phase 5 fixes the pre-existing drift alongside the new flag, and Phase 6 cross-greps both files for every flag name. |
| Unbounded `find` in a large repo | L | L | Reuse Step 3.5's exact `-maxdepth 3` plus the same seven `-not -path` exclusions. |
| Editing a deployed `.claude/` copy by reflex | H | L | Every phase names absolute source-store paths; Phase 6 asserts `git status` shows no `.claude/**` modification. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Phases 4 and 5 are genuinely parallel:
Phase 4 touches only `SKILL.md`, Phase 5 only `commands/tag.md`. Phases 1-4 are serialized on
`SKILL.md` file territory even where their logical dependencies would permit otherwise.

---

### Phase 1: Declare `--skip-changelog-check` [COMPLETED]

**Goal**: Introduce the new override flag in `SKILL.md`'s syntax block, flags table, and Step 1
argument parsing, so later phases have a `$skip_changelog_check` variable to branch on.

**Tasks**:

- [x] In `agent-system/extensions/core/skills/skill-tag/SKILL.md`, extend the `## Command Syntax`
      fenced block to `/tag [--patch|--minor|--major] [--force] [--dry-run] [--skip-version-check] [--skip-changelog-check]`. *(completed)*
- [x] Add a flags-table row immediately after the `--skip-version-check` row:
      `| \`--skip-changelog-check\` | Bypass a missing or empty CHANGELOG entry (still prints the full failure detail first) |`. *(completed)*
- [x] In Step 1's bash block, add `skip_changelog_check=false` to the initializer group and a
      matching parse branch after the `--skip-version-check` branch:
      ```bash
      if [[ "$*" == *"--skip-changelog-check"* ]]; then
        skip_changelog_check=true
      fi
      ```
      *(completed)*
- [x] Verify the substring-match parse order is safe: `--skip-changelog-check` and
      `--skip-version-check` share no common prefix that would cause one to match the other under
      `[[ "$*" == *"..."* ]]`. Confirm by inspection and record the confirmation. *(completed: confirmed neither flag is a substring of the other via `grep -qF` cross-check; no cross-match)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — Command Syntax block, flags table,
  Step 1 bash block.

**Verification**:

- `grep -c 'skip-changelog-check' agent-system/extensions/core/skills/skill-tag/SKILL.md`
  returns at least 3 (syntax block, flags table, parse branch).
- Extract Step 1's bash fence and run `bash -n` on it — must exit 0.
- `grep -n 'skip_changelog_check=false'` confirms the initializer exists and sits with the other
  flag initializers, not inside a conditional.

---

### Phase 2: Add Step 3.6 "Validate Changelog Entry" [COMPLETED]

**Goal**: Insert the changelog gate between Step 3.5 and Step 4, implementing discover ->
require-heading -> extract-section -> require-non-empty -> disclose-then-optionally-override, and
setting the `$tag_message` / `$tag_message_source` variables Phase 3 consumes.

**Tasks**:

- [x] Insert a new `### Step 3.6: Validate Changelog Entry` heading between the end of Step 3.5's
      fenced block and the `### Step 4: Display Summary` heading. *(completed)*
- [x] Write a prose preamble mirroring Step 3.5's, carrying the same placement rationale
      explicitly — that this step runs on every invocation path (default, `--force`, `--dry-run`)
      **because it sits strictly before Step 5's `--dry-run` `exit 0`**. This sentence is the
      guard against a future editor relocating the step; do not paraphrase it away. *(completed)*
- [x] Implement bounded-depth discovery reusing Step 3.5's exclusion set verbatim:
      ```bash
      changelog_candidates=$(find "$repo_root" -maxdepth 3 -type f \
        -not -path '*/node_modules/*' \
        -not -path '*/.git/*' \
        -not -path '*/dist/*' \
        -not -path '*/build/*' \
        -not -path '*/target/*' \
        -not -path '*/__pycache__/*' \
        -not -path '*/.venv/*' \
        -not -path '*/venv/*' \
        -iname 'CHANGELOG.md' \
        2>/dev/null | sort)
      changelog_file=$(printf '%s\n' "$changelog_candidates" | head -1)
      ```
      `$repo_root` and `$new_version_bare` are already in scope from Step 3.5 — reuse them, do not
      recompute. *(completed)*
- [x] Print any candidates beyond the first as explicitly ignored, so the transcript discloses the
      ambiguity rather than silently picking. *(completed)*
- [x] Absence branch (informational, proceeds normally, phrased to parallel Step 3.5's "No
      declared package version found ... Skipping version-consistency check."):
      ```
      No CHANGELOG.md found near repo root (bounded-depth search, vendor/build dirs excluded).
      Skipping changelog check.
      ```
      In this branch set `tag_message="$new_version"` and
      `tag_message_source="bare version string (no CHANGELOG found)"`. *(completed)*
- [x] Presence branch: require `grep -q "^## \[${new_version_bare}\]" "$changelog_file"`, then
      extract the section with the reference gate's `awk` (heading exclusive, up to but not
      including the next `^## ` heading), then require non-emptiness after whitespace stripping:
      ```bash
      changelog_section=$(awk -v ver="$new_version_bare" '
        $0 ~ "^## \\[" ver "\\]" { found=1; next }
        found && /^## / { exit }
        found { print }
      ' "$changelog_file")
      if [ -z "$(printf '%s' "$changelog_section" | tr -d '[:space:]')" ]; then ...
      ```
      *(completed)*
- [x] Failure disclosure: on missing heading OR empty section, print the changelog path and the
      specific failure state in full **before** branching on the flag. Then either
      `exit 1` with a resolution hint ("Add a non-empty `## [$new_version_bare]` section to
      $changelog_file, commit, then re-run /tag. Or pass --skip-changelog-check to proceed anyway
      (not recommended).") or, when `skip_changelog_check=true`, print
      `WARNING: --skip-changelog-check is set. Proceeding despite the above.` and fall back to
      `tag_message="$new_version"` / `tag_message_source="bare version string (changelog check skipped)"`.
      *(completed)*
- [x] Success branch: print `Changelog entry: OK -- $changelog_file has a non-empty '## [$new_version_bare]' section.`
      and build the tag message:
      ```bash
      tag_message=$(printf '%s\n\n%s\n' "$new_version" "$changelog_section")
      tag_message_source="CHANGELOG section for $new_version_bare ($changelog_file)"
      ```
      *(completed)*
- [x] Add a comment block immediately above the message construction recording the **decision**:
      the annotated tag's subject line is `$new_version` and its body is the extracted CHANGELOG
      section, because that section is already validated non-empty by this step and is the same
      content the release preflight reads; the bare `$new_version` message is a deliberate
      *fallback* used only when no section is available (no changelog, or check skipped), not a
      default reached by omission. Also record that `-a` is used rather than `-s` because signing
      requires a configured GPG key that is not universal across consuming repos. *(completed)*
- [x] Confirm `$tag_message` and `$tag_message_source` are assigned on **every** reachable path
      out of this step (absence, skip-override, success). A path that leaves them unset would make
      Phase 3's `git tag -a -m ""` silently produce an empty message. *(completed: verified 3
      reachable exits, each assigns tag_message; grep -c 'tag_message=' within the block equals 3)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts (a) exactly one new `###` step heading is added, (b)
`$repo_root` and `$new_version_bare` are already in scope from Step 3.5 and need no
recomputation, and (c) there are exactly three reachable exits from the step, each of which must
set `$tag_message`. Confirm (a) by `grep -c '^### Step' SKILL.md` before and after (must increase
by exactly 1); confirm (b) by grepping Step 3.5's block for both assignments before writing
Step 3.6; confirm (c) by tracing each branch of the finished block and counting `tag_message=`
assignments — if the count is not 3, the branch analysis is wrong and must be redone before
proceeding to Phase 3.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — new Step 3.6 section inserted between
  Step 3.5 and Step 4.

**Verification**:

- Step ordering: `grep -n '^### Step' SKILL.md` shows `Step 3.5` < `Step 3.6` < `Step 4` <
  `Step 5`, and Step 5 is where `dry_run` / `exit 0` appears.
- `bash -n` on the extracted Step 3.6 fence exits 0.
- `grep -c 'tag_message=' SKILL.md` within the Step 3.6 block equals 3.
- The step's prose preamble contains the phrase `--dry-run` and an explicit statement that the
  step precedes Step 5's early exit.
- Exclusion set matches Step 3.5's exactly: diff the two `-not -path` lists.

---

### Phase 3: Annotated tag creation and truthful dry-run preview [COMPLETED]

**Goal**: Close Gap 1 — replace lightweight tag creation with `git tag -a`, and update the
dry-run preview in the same phase so the two can never be out of step.

**Tasks**:

- [x] In Step 6 ("Create and Push Tag"), replace
      `if ! git tag "$new_version"; then` with
      `if ! git tag -a "$new_version" -m "$tag_message"; then`. *(completed)*
- [x] Update the adjacent success line to state the tag kind:
      `echo "Created annotated tag: $new_version"`. *(completed)*
- [x] In Step 5's dry-run block, replace `echo "  git tag $new_version"` with a form that names
      the message source without dumping the full message body:
      ```bash
      echo "  git tag -a $new_version -m <$tag_message_source>"
      ```
      *(completed)*
- [x] Sweep the whole file for any other tag-creating invocation. The push command
      (`git push origin "$new_version"`), the existence probe (`git rev-parse "$new_version"`),
      the listing (`git tag -l 'v*'`), and the recovery hint (`git tag -d $new_version`) are all
      correct as-is and must NOT be changed — only tag *creation* sites change. *(completed:
      grep -n 'git tag' confirmed exactly 2 creation sites, both now use -a; list/delete sites
      unchanged)*
- [x] Confirm the Step 6 error-recovery hint block still reads correctly for an annotated tag
      (`git tag -d $new_version` deletes annotated tags identically — no change needed, but
      confirm rather than assume). *(completed: confirmed by inspection, no change needed)*

**Timing**: 0.4 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts there are exactly **two** tag-creating call sites in
`SKILL.md` — the dry-run preview and Step 6's real command — as reported by research. Confirm at
implementation time with `grep -n 'git tag' agent-system/extensions/core/skills/skill-tag/SKILL.md`
and classify every hit as create / delete / list / other before editing. If the count of creation
sites is not 2, stop and reconcile against the file rather than editing the two the report named.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — Step 5 dry-run block, Step 6 creation
  block.

**Verification**:

- `grep -n 'git tag' SKILL.md` shows no remaining bare-creation form (`git tag "$new_version"` or
  `git tag $new_version` with no `-a`/`-d`/`-l`).
- Both the dry-run preview line and the Step 6 command contain `-a`.
- `bash -n` on the extracted Step 5 and Step 6 fences exits 0.
- The dry-run preview references `$tag_message_source`, not `$tag_message` — the preview must
  describe the message, not print it.

---

### Phase 4: SKILL.md Error Handling subsections [COMPLETED]

**Goal**: Document the three new changelog outcomes in `SKILL.md`'s `## Error Handling` section,
mirroring the existing Version Mismatch / No Declared Version Found / Version Check Skipped by
Flag trio one-for-one.

**Tasks**:

- [x] Add `### Changelog Entry Missing or Empty` — the fatal-by-default outcome. Show both
      variants (heading absent; heading present but section empty) as transcript examples, using
      the exact strings Phase 2 emits. *(completed)*
- [x] Add `### No Changelog Found` — explicitly labelled an **informational** outcome, not a
      failure, with the sentence pattern the existing "No Declared Version Found" subsection uses:
      `/tag` proceeds normally after printing it, in every invocation mode including `--dry-run`.
      *(completed)*
- [x] Add `### Changelog Check Skipped by Flag` — carrying the same "suppresses the *block*, not
      the *disclosure*" sentence the `--skip-version-check` subsection uses, with a transcript
      showing the full failure detail printed *before* the WARNING line. *(completed)*
- [x] Place the three subsections immediately after the existing `### Version Check Skipped by
      Flag` subsection so the version trio and the changelog trio read as parallel groups.
      *(completed)*
- [x] Cross-check every transcript line against the literal `echo` strings written in Phase 2.
      A documented transcript that does not match the code is worse than no transcript.
      *(completed: verified every transcript line grep-matches Step 3.6's echo statements
      verbatim)*

**Timing**: 0.3 hours

**Depends on**: 2, 3

Phase 4's logical dependency is on Phase 2 (whose emitted strings it documents); the additional
dependency on Phase 3 is file-territory serialization on `SKILL.md`, not a semantic requirement.

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly **three** new `###` subsections under
`## Error Handling`, mirroring the existing three version-check subsections. Confirm by
`grep -c '^### ' ` within the Error Handling section before and after — the count must increase
by exactly 3 — and by confirming the existing version trio is exactly three subsections, so the
mirroring claim holds.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — `## Error Handling` section.

**Verification**:

- Every quoted transcript string appears verbatim in an `echo` in Step 3.6. Spot-check by
  extracting each transcript line and grepping the Step 3.6 block for it.
- The "No Changelog Found" subsection contains the word `informational`.
- The "Changelog Check Skipped by Flag" subsection shows the failure detail above the WARNING
  line, not below it.

---

### Phase 5: Update commands/tag.md [COMPLETED]

**Goal**: Bring the command doc into agreement with the skill, so the numbered workflow and the
Requirements section no longer silently contradict it. Also fix the pre-existing drift where the
frontmatter `argument-hint` omits `--skip-version-check`.

**Tasks**:

- [x] Frontmatter `argument-hint`: extend to
      `"[--patch|--minor|--major] [--force] [--dry-run] [--skip-version-check] [--skip-changelog-check]"`.
      Note this fixes an existing omission (`--skip-version-check` was already missing) as well as
      adding the new flag. *(completed)*
- [x] `## Usage` fenced block: match the skill's Command Syntax line exactly. *(completed)*
- [x] Flags table: add a `--skip-changelog-check` row after the `--skip-version-check` row, phrased
      in the same register ("Explicit override for a missing or empty changelog entry; still
      reports the failure"). *(completed)*
- [x] `## Workflow` numbered list: insert changelog validation as a new step 4 —
      `4. **Validate Changelog Entry**: Require a non-empty \`## [VERSION]\` section in a discovered CHANGELOG; fail if present-but-missing` —
      and renumber the following entries. Change the tag-creation entry from
      `**Create Tag**: \`git tag vX.Y.Z\`` to
      `**Create Tag**: \`git tag -a vX.Y.Z -m "<version + CHANGELOG section>"\` (annotated, not lightweight)`.
      *(completed)*
- [x] `## Requirements` section: add a bullet phrased to parallel the existing version-consistency
      bullet's vacuous-satisfaction construction —
      "A discovered CHANGELOG (if any) has a non-empty `## [VERSION]` section for the computed
      version — a repo with no CHANGELOG satisfies this requirement vacuously". *(completed)*
- [x] Leave the `## Warning` and `## Agent Restrictions` sections untouched. *(completed: confirmed
      byte-unchanged)*

**Timing**: 0.4 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts **five** edit sites in `commands/tag.md`: frontmatter
`argument-hint`, `## Usage` block, flags table, `## Workflow` numbered list, `## Requirements`
section. Confirm by reading the whole file (it is under 80 lines) and enumerating every place a
flag name, the tag-creation command, or a validation step appears, before making any edit. If a
sixth site exists, cover it; if one of the five does not, record which and why.

**Files to modify**:

- `agent-system/extensions/core/commands/tag.md` — frontmatter, Usage, flags table, Workflow,
  Requirements.

**Verification**:

- Flag-name cross-check: every flag appearing in `SKILL.md`'s flags table also appears in
  `tag.md`'s flags table, in `tag.md`'s `argument-hint`, and in `tag.md`'s Usage block. Run the
  comparison in both directions.
- `grep -n 'git tag' commands/tag.md` shows only the annotated form.
- The Workflow list is contiguously numbered with no duplicate or skipped number.
- `grep -i 'vacuously' commands/tag.md` returns two hits (version bullet, changelog bullet).

---

### Phase 6: End-to-end verification [NOT STARTED]

**Goal**: Run the complete gate set — shell syntax, behavioral smoke tests against a throwaway
repo, cross-file consistency, and the source-store boundary check — and confirm no `.claude/**`
file was touched.

**Tasks**:

- [ ] **Shell syntax**: extract every `bash` fence from `SKILL.md` and run `bash -n` on each
      individually. Each block in this file is self-contained, so a combined extraction is also a
      valid check:
      ```bash
      awk '/^```bash$/{f=1;next} /^```$/{f=0} f' \
        agent-system/extensions/core/skills/skill-tag/SKILL.md > "$SCRATCH/tag-blocks.sh"
      bash -n "$SCRATCH/tag-blocks.sh"
      ```
      Any syntax error must be traced back to its originating fence and fixed there.
- [ ] **Behavioral smoke test**: build a throwaway git repo in the scratchpad and exercise the
      Step 3.6 block directly with `new_version`, `new_version_bare`, `repo_root`, and
      `skip_changelog_check` preset. Cover four scenarios and confirm each verdict:
      1. No changelog anywhere -> informational skip, exit 0, `tag_message` == `$new_version`.
      2. `code/CHANGELOG.md` (nested, **not** root-level — this is the motivating repo's layout)
         with a non-empty `## [X.Y.Z]` section -> OK, `tag_message` == version + section body.
      3. `code/CHANGELOG.md` present but with **no** `## [X.Y.Z]` heading -> exit 1 by default;
         with `skip_changelog_check=true` -> exit 0 with the failure printed *above* the WARNING.
      4. `## [X.Y.Z]` heading present but the section body is whitespace-only -> same as (3).
- [ ] **Quoting hardening check**: in scenario 2, use a changelog section containing backticks, a
      blank line, a `$`-sigil, and a double quote. Confirm `tag_message` captures them literally
      and that a real `git tag -a "$v" -m "$tag_message"` in the throwaway repo produces a tag
      where `git cat-file -t "$v"` reports `tag` and `git tag -l --format='%(contents)' "$v"`
      round-trips the body intact.
- [ ] **Annotated-tag assertion**: in the throwaway repo, run the exact reference-gate assertion
      `[ "$(git cat-file -t "$v")" = "tag" ]` against a tag created by the new Step 6 command form.
      This is the literal contract the task exists to satisfy — verify it directly, not by
      inference.
- [ ] **Ordering invariant**: confirm by grep that Step 3.6 precedes Step 5's `exit 0` in file
      order, and that no `exit 0`/`exit 1` between Step 3.5 and Step 4 can be reached before the
      changelog check runs.
- [ ] **Cross-file consistency**: run the bidirectional flag-name comparison between `SKILL.md`
      and `commands/tag.md` described in Phase 5.
- [ ] **Source-store boundary**: `git status --short` must show modifications only under
      `agent-system/extensions/core/` and `specs/131_*`. Zero `.claude/**` entries. If any appear,
      revert them — the edit belongs in the source store.
- [ ] **Non-goal audit**: confirm `user-only: true`, the Agent Restrictions sections in both files,
      and Step 2's git-state logic are byte-unchanged, and that no `git merge-base` /
      `rev-list ... origin/...HEAD` ancestry check was added.
- [ ] Record the push-before-tag deferral in the implementation summary, quoting the research
      report's finding (4) so the follow-up task is not re-derived.

**Timing**: 0.5 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:

- None (verification only). Any defect found is fixed in the phase that introduced it.

**Verification**:

- All four smoke-test scenarios produce the expected exit code and expected `tag_message`.
- `git cat-file -t` reports `tag` for a tag created by the new command form.
- `bash -n` clean across all extracted fences.
- `git status --short` shows no `.claude/**` paths.

---

## Testing & Validation

- [ ] Every `bash` fence in `SKILL.md` passes `bash -n`.
- [ ] Scenario: repo with no CHANGELOG -> informational skip, `/tag` proceeds, `--dry-run` reports
      the same verdict a real run would.
- [ ] Scenario: repo with `code/CHANGELOG.md` and a valid entry -> OK, annotated tag message is
      version + section body.
- [ ] Scenario: repo with `code/CHANGELOG.md` missing the version heading -> exit 1 by default.
- [ ] Scenario: repo with an empty `## [VERSION]` section -> exit 1 by default.
- [ ] Scenario: each failing case with `--skip-changelog-check` -> proceeds, with the failure
      detail printed in full above the WARNING line.
- [ ] `git cat-file -t "$new_version"` returns `tag` (not `commit`) for a tag created by the new
      Step 6 command.
- [ ] Dry-run preview names `git tag -a` and describes the message source; it does not print the
      full message body.
- [ ] Step 3.6 appears strictly between Step 3.5 and Step 4 in file order.
- [ ] Flag names agree bidirectionally between `SKILL.md` and `commands/tag.md`.
- [ ] `git status --short` shows no modification under any `.claude/` path.
- [ ] `user-only: true` and both Agent Restrictions sections are unchanged.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — new `--skip-changelog-check` flag,
  new Step 3.6, annotated tag creation in Step 6, corrected dry-run preview in Step 5, three new
  Error Handling subsections.
- `agent-system/extensions/core/commands/tag.md` — updated argument-hint, Usage, flags table,
  Workflow list, and Requirements.
- `specs/131_tag_annotated_and_changelog_preflight/summaries/01_tag-annotated-changelog-preflight-summary.md`
  — implementation summary, including the recorded push-before-tag deferral.

## Rollback/Contingency

Both edited files are tracked in git and this task touches no generated or deployed artifact, so
rollback is a plain revert of the two source-store files:

```bash
git checkout HEAD -- \
  agent-system/extensions/core/skills/skill-tag/SKILL.md \
  agent-system/extensions/core/commands/tag.md
```

(Only safe on a clean tree, or after `bash .claude/scripts/git-snapshot.sh 131` — see
`.claude/rules/git-workflow.md`'s destructive-git guard.)

Per-phase contingencies:

- If Phase 2's changelog discovery proves too broad or too narrow in a real repo, the fallback is
  to narrow `-iname 'CHANGELOG.md'` to an exact `-name` match while keeping the discover-not-
  hardcode principle. Do **not** fall back to a hardcoded path — that violates a stated non-goal.
- If multi-line `-m` quoting proves problematic in practice despite Phase 6's hardening check, the
  recorded fallback is the bare `-m "$new_version"` message form for all paths. That still closes
  Gap 1 (the annotated-tag assertion) fully, and leaves Gap 2's gate intact. Record the downgrade
  as a decision in the summary rather than applying it silently.
- Because `.claude/` is regenerated from the source store, no deploy-side cleanup is ever needed
  after a revert.

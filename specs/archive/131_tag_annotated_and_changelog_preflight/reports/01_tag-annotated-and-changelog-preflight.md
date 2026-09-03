# Research Report: Task #131

- **Task**: 131 - Make /tag produce releases that a release workflow's preflight will actually accept
- **Started**: 2026-09-01T04:47:00Z
- **Completed**: 2026-09-01T05:10:00Z
- **Effort**: ~1 hour (research)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-tag/SKILL.md` (canonical source)
  - `agent-system/extensions/core/commands/tag.md` (canonical source)
  - `/home/benjamin/Projects/ModelChecker/.github/workflows/release.yml` (motivating reference contract, live on disk)
  - `/home/benjamin/Projects/ModelChecker/.github/RELEASE_SETUP.md` (release process narrative for the same repo)
  - `/home/benjamin/Projects/ModelChecker/code/CHANGELOG.md`, `code/pyproject.toml` (concrete changelog/version format in use)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed both gaps exactly as described against the live source files: `SKILL.md:361`
  creates a lightweight tag (`git tag "$new_version"`), and `SKILL.md` has zero occurrences of
  "changelog" anywhere in the file.
- Located and read the actual motivating CI gate — `ModelChecker/.github/workflows/release.yml`'s
  `preflight` job — which is the concrete reference contract to satisfy. It asserts, in this
  order: (1) tag version == `code/pyproject.toml` version, (2) `code/CHANGELOG.md` has a
  non-empty `## [VERSION]` entry (bare version, no `v` prefix — matches the skill's existing
  `new_version_bare` convention), (3) the tag is annotated (`git cat-file -t` == `tag`) AND
  reachable from `origin/master` via `git merge-base --is-ancestor`, (4) the tagged commit's
  `release.yml` matches `origin/master`'s copy.
- Recommend: Gap 1 fix is `git tag -a "$new_version" -m "$tag_message"`, with `$tag_message`
  built from the CHANGELOG section extracted for Gap 2 (falling back to a bare `-m "$new_version"`
  when no changelog is found or the version's section can't be extracted). Do not default to
  `-s` (signing) — record this as a deliberate scope decision, not an omission.
- Recommend: Gap 2 fix is a new step immediately after "Step 3.5: Validate Version Consistency"
  (call it "Step 3.6: Validate Changelog Entry"), structurally mirroring 3.5's discover ->
  check -> disclose-then-optionally-skip pattern, with a new `--skip-changelog-check` flag.
- The "third gap" the task asks to assess (push-before-tag / branch-reachability) is real and
  independently confirmed in the reference workflow and its `RELEASE_SETUP.md` narrative, but my
  judgment (recorded in Decisions below) is to treat it as a **separate, out-of-scope follow-up
  task** rather than fold it into this one — reasons given below.

## Context & Scope

Task 131 asks for two specific, independent fixes to `skill-tag` (the `/tag` user-only command)
so that tags it creates and pushes are accepted by a standard release-workflow preflight gate,
plus documentation updates to `commands/tag.md` reflecting the new behavior, plus an explicit,
recorded judgment on whether a third related gap (push-before-tag ordering) belongs in this task
or a separate one. No implementation was performed — this is the research phase; findings below
are intended to ground a subsequent `/plan 131`.

## Findings

### Codebase Patterns

**Gap 1 — lightweight tag creation** (`SKILL.md`):
- Line 310 (dry-run preview): `echo "  git tag $new_version"`
- Line 361 (real execution, Step 6): `if ! git tag "$new_version"; then`
- Both must change together (the task description explicitly calls out that the dry-run preview
  must not misrepresent what a real run does).

**Gap 2 — no changelog occurrence at all**: confirmed via `grep -i changelog SKILL.md` (0 hits).

**Existing pattern to mirror — Step 3.5 "Validate Version Consistency"** (`SKILL.md:154-267`):
This is the load-bearing template for the new check. Its shape:
1. Bounded-depth discovery (`find "$repo_root" -maxdepth 3 -not -path '*/node_modules/*' ...`)
   excluding `.git`, `dist`, `build`, `target`, `__pycache__`, `.venv`, `venv`.
2. Per-file extraction function keyed on `basename`.
3. Absence is informational, not fatal: "No declared package version found ... Skipping
   version-consistency check." — proceeds normally.
4. Presence + mismatch is fatal by default, with a full disclosure block ("Declared in: ...")
   printed **before** either the `exit 1` or (if `--skip-version-check` is set) the override
   warning. The comment at `SKILL.md:156-158` is explicit that this step "runs for every
   invocation path — default, `--force`, and `--dry-run` alike — because it sits strictly before
   Step 5's `--dry-run` `exit 0`". This is the exact placement constraint the task repeats for
   the new changelog check.
5. `commands/tag.md`'s "Requirements" section states the version-consistency rule in one line:
   "Declared package version (if any manifest declares one) matches the computed tag version — a
   repo with no manifest satisfies this requirement vacuously." The changelog rule needs the
   same one-line treatment, phrased the same way (vacuous satisfaction when absent).

**Step ordering constraint**: Step 4 ("Display Summary") and Step 5 ("Execute Based on Mode",
which contains the `--dry-run` `exit 0`) both come after Step 3.5. A new "Step 3.6" inserted
between 3.5 and 4 preserves the "runs before dry-run's early exit" invariant without renumbering
Steps 4-8.

**`new_version_bare`** (`SKILL.md:165`, `${new_version#v}`) is already computed in Step 3.5 and
is exactly what a `## [VERSION]` changelog heading search needs (no `v` prefix) — the ModelChecker
CHANGELOG confirms this format: `## [1.3.8] - 2026-09-01`, matching `pyproject.toml`'s
`version = "1.3.8"` (no `v`).

### External Resources — the reference contract

Read in full: `/home/benjamin/Projects/ModelChecker/.github/workflows/release.yml`'s `preflight`
job (job name: "Preflight (tag/version/CHANGELOG checks)"). Four steps, in order:

1. **Tag vs. pyproject.toml version** — `TAG_VERSION="${GITHUB_REF_NAME#v}"` compared against
   `grep -m1 '^version = ' code/pyproject.toml`. `/tag` already satisfies the equivalent of this
   (Step 3.5).
2. **CHANGELOG non-empty entry** — exact shell logic worth transcribing since it is the direct
   model for the new Step 3.6:
   ```bash
   VERSION="${GITHUB_REF_NAME#v}"
   CHANGELOG=code/CHANGELOG.md
   if ! grep -q "^## \[${VERSION}\]" "${CHANGELOG}"; then
     echo "ERROR: ${CHANGELOG} has no '## [${VERSION}]' heading. ..."
     exit 1
   fi
   SECTION=$(awk -v ver="${VERSION}" '
     $0 ~ "^## \\[" ver "\\]" { found=1; next }
     found && /^## / { exit }
     found { print }
   ' "${CHANGELOG}")
   if [ -z "$(printf '%s' "${SECTION}" | tr -d '[:space:]')" ]; then
     echo "ERROR: ${CHANGELOG}'s '## [${VERSION}]' entry is empty. ..."
     exit 1
   fi
   ```
   This `awk` extraction (heading -> next `## ` heading, exclusive) is exactly "the version
   heading plus the CHANGELOG section for that version" the task names as the sensible tag-message
   default for Gap 1 — i.e. Gap 2's own extraction is directly reusable as Gap 1's message source.
3. **Annotated + reachable from origin/master**:
   ```bash
   git fetch origin --force "+refs/tags/${GITHUB_REF_NAME}:refs/tags/${GITHUB_REF_NAME}"
   TAG_TYPE=$(git cat-file -t "refs/tags/${GITHUB_REF_NAME}")
   if [ "${TAG_TYPE}" != "tag" ]; then
     echo "ERROR: ${GITHUB_REF_NAME} is a ${TAG_TYPE}, not an annotated tag. Create it with 'git tag -a' (or -s), not 'git tag'."
     exit 1
   fi
   if ! git merge-base --is-ancestor "${GITHUB_REF_NAME}" origin/master; then
     echo "ERROR: ${GITHUB_REF_NAME} is not reachable from origin/master. Push (or /merge) the branch BEFORE creating and pushing the tag ..."
     exit 1
   fi
   ```
   Confirms the task description's framing precisely: the annotated-tag assertion and the
   push-before-tag/ancestry assertion are bundled in **one** preflight step in the reference
   workflow, but they are mechanically two different checks (`git cat-file -t` vs.
   `git merge-base --is-ancestor`), and `/tag`'s existing Step 2 only covers the "not behind"
   half of the second one, never the "reachable"/"not-ahead-of-remote" half.
4. **Tagged `release.yml` matches `origin/master`'s copy** — a workflow-specific backstop for
   the same push-ordering hazard, not something `/tag` (a generic, repo-agnostic skill) could
   meaningfully check; this is out of scope by construction (it is specific to workflow-file
   content, not tag/changelog mechanics).

`RELEASE_SETUP.md`'s "Release Process" section (`/home/benjamin/Projects/ModelChecker/.github/RELEASE_SETUP.md:101-151`)
independently narrates the same push-before-tag requirement as "required, not just
conventional," citing a real incident (the 1.3.0 release) where an unpushed workflow-file fix
only happened to work by accident of push ordering. This is corroborating evidence, not just a
CI assertion — the ordering hazard is real and has bitten this repo before, separately from the
two gaps this task targets.

### Recommendations

**Gap 1 (annotated tag)**:
- Change `SKILL.md:361` from `git tag "$new_version"` to
  `git tag -a "$new_version" -m "$tag_message"`.
- Change `SKILL.md:310` (dry-run) to print the annotated form, e.g.
  `echo "  git tag -a $new_version -m <changelog section for $new_version_bare, or bare version if none>"`
  — the exact wording should describe the message source without dumping the full message text
  into the dry-run preview.
- Build `$tag_message` once, in the new Step 3.6 (so it is available to both the dry-run preview
  in Step 5 and the real tag creation in Step 6), as: the extracted `$SECTION` from the
  changelog check (heading line + section body) when a changelog entry was found; otherwise a
  bare `"$new_version"`.
- Use `-a`, not `-s`. Recorded decision: signing requires a configured GPG key that is not
  universal across the repos this shared skill runs in, and the reference preflight's own
  comment treats `-a`/`-s` as interchangeable ("Create it with 'git tag -a' (or -s)") — `-a` is
  sufficient to satisfy `git cat-file -t == tag`. Adding a signing requirement would introduce a
  new failure mode (missing/unconfigured key) this task's motivating evidence does not call for.

**Gap 2 (changelog gate)**:
- New "Step 3.6: Validate Changelog Entry" in `SKILL.md`, placed after Step 3.5 and before
  Step 4, mirroring Step 3.5's structure:
  - Discovery: bounded-depth `find "$repo_root" -maxdepth 3` for a file named `CHANGELOG.md`
    (case-insensitive, `-iname`), excluding the same vendor/build directories Step 3.5 already
    excludes. Record as a decision: if multiple candidates are found, use the first in sorted
    order and do not attempt multi-file union/intersection semantics — unlike manifests (where
    a repo can legitimately declare version in `package.json` *and* `Cargo.toml`), a repo has at
    most one canonical changelog by convention, so ambiguity here is a genuine edge case, not the
    normal multi-ecosystem case Step 3.5 handles.
  - Absence: "No CHANGELOG file found ... Skipping changelog check." — informational, proceeds
    normally, in every invocation mode (mirrors Step 3.5's "No declared package version found").
  - Presence: require a `^## \[${new_version_bare}\]` heading (grep), then extract the section
    up to (not including) the next `^## ` heading (awk, exactly as the reference workflow does),
    then require that section to be non-empty after whitespace-stripping
    (`tr -d '[:space:]'`).
  - Missing heading or empty section: full disclosure (path, missing/empty state), then either
    `exit 1` or — if `--skip-changelog-check` is set — the same "suppresses the block, not the
    disclosure" pattern as `--skip-version-check`: print the failure detail in full, then a
    `WARNING: --skip-changelog-check is set. Proceeding despite the above.` line.
- New flag `--skip-changelog-check`, parsed in Step 1 alongside `--skip-version-check`.
- `commands/tag.md` updates needed:
  - Flags table: add `--skip-changelog-check` row.
  - Usage/argument-hint line: add the flag.
  - Workflow numbered list: Step 6 changes to `git tag -a vX.Y.Z -m "..."`; insert a changelog
    validation step between the existing steps 3 and 4 (renumbering the rest).
  - Requirements section: add a changelog line matching the version-consistency line's phrasing
    ("... a repo with no CHANGELOG satisfies this requirement vacuously").
- `SKILL.md`'s "Error Handling" section should gain three new subsections mirroring the existing
  "Version Mismatch" / "No Declared Version Found" / "Version Check Skipped by Flag" trio:
  "No Changelog Found" (informational), "Changelog Entry Missing or Empty" (fatal by default),
  "Changelog Check Skipped by Flag" (disclose-then-warn).

## Decisions

- **Message source for the annotated tag**: the CHANGELOG section extracted by Gap 2's own
  check, falling back to a bare `-m "$new_version"` when no changelog entry is available (no
  changelog file, or the check was skipped via `--skip-changelog-check`). This was an explicit
  choice point the task description flagged ("a bare `-m "$new_version"` is acceptable but
  should be a recorded choice, not a default reached by omission") — recording it here as the
  recommended choice for the planner to carry forward, not a default reached silently.
- **`-a` over `-s`**: annotated, unsigned tags only. See Recommendations above for rationale.
- **Third gap (push-before-tag / branch-reachability) — treat as a separate follow-up task, not
  folded into this one.** Rationale:
  1. It is a mechanically distinct check (`git merge-base --is-ancestor` against
     `origin/<branch>`, on the *ancestry* of the tagged commit) from both named gaps, which are
     about tag *construction* (annotated vs. lightweight) and a *separate file's* content
     (CHANGELOG). It belongs conceptually with Step 2 ("Validate Git State"), not the Step
     3.5/3.6 neighborhood this task is scoped to.
  2. The task's own two numbered gaps ("GAP 1", "GAP 2") do not include it as a third gap; the
     task explicitly separates "assess ... and record the judgment" from the two mandated fixes,
     signaling the author left it deliberately open rather than in-scope by default.
  3. Task title and NON-GOALS both scope this task to "tag annotated and changelog preflight" —
     a third, unrelated check risks diluting a plan that should stay tightly reviewable against
     the two named gaps.
  4. Countervailing point, worth carrying into the follow-up task: the fix is cheap and reuses
     data Step 2 already fetches. Step 2 already does `git fetch origin "$current_branch"` and
     computes `behind=$(git rev-list --count "HEAD..origin/$current_branch")`; the symmetric
     "ahead" check is `git rev-list --count "origin/$current_branch..HEAD"` — if nonzero, local
     `HEAD` has commits not yet on the remote, which is exactly the condition that will make a
     tag created against it unreachable from `origin/<branch>` and fail the reference
     preflight's third assertion. A follow-up task should point directly at `SKILL.md`'s Step 2
     (not Step 3.5/3.6) and can almost certainly reuse the `remote_sha`/`behind` variables already
     computed there.
  5. Net judgment: **spawn or file a new task** for the push-before-tag check rather than
     expanding this one's scope, but the follow-up task description should quote finding (4)
     above so the fix isn't re-derived from scratch.

## Risks & Mitigations

- **Multi-line `-m` content and shell quoting**: the changelog section can contain markdown
  markup, backticks, and blank lines. Risk: shell metacharacter mishandling when building
  `$tag_message`. Mitigation: build the message via plain variable capture (`$(awk ...)`,
  already how Step 3.5/reference workflow do it) and pass it through `-m "$tag_message"` with
  double-quoting — no `eval`, no unquoted expansion, so shell metacharacters in the changelog
  text are inert. Confirmed this is exactly the pattern the reference workflow itself uses.
- **Ambiguous changelog discovery** (multiple `CHANGELOG.md` files under the bounded-depth
  search): addressed above as a recorded decision (first match, sorted) rather than left
  unspecified.
- **Regression of the "dry-run must sit before other invariant" contract**: Step 3.5's own
  comment already documents *why* it sits where it does; the new Step 3.6 must carry the same
  comment convention so a future editor does not accidentally move it after Step 5.
- **Doc/skill drift**: `commands/tag.md` and `SKILL.md` already had one point of drift before
  this task (the flags table in `tag.md` already includes `--skip-version-check`, so that
  precedent shows the two files are usually kept in sync — the new flag and behavior should
  follow the same dual-file update discipline this task's "ALSO UPDATE" section calls for).

## Context Extension Recommendations

- **Topic**: Reference CI/CD preflight gate patterns for `/tag`-adjacent work.
- **Gap**: There is no `.claude/context/` file capturing the ModelChecker `release.yml`
  preflight job as a concrete, load-bearing reference contract for `/tag` design decisions. It
  currently exists only as a file on disk in a sibling project, discovered ad hoc during this
  research.
- **Recommendation**: Once this task's implementation lands, consider adding a short pointer
  (not a full copy — the source of truth should stay `release.yml` itself) under
  `agent-system/extensions/core/context/` noting that `/tag`'s Step 3.5/3.6 checks are modeled on
  ModelChecker's `preflight` job, with a repo-relative path to it, so future changes to either
  side can be cross-checked deliberately rather than drifting apart unnoticed.

## Appendix

- Search queries / commands used: `find agent-system/extensions/core -iname '*tag*'`; `cat -n`
  on `SKILL.md` and `tag.md`; `jq`/`grep` against `specs/state.json` and `specs/TODO.md` to
  confirm task framing; `find / -iname 'ModelChecker*'` and `find ~ -maxdepth 4 -iname
  '*modelchecker*'` to locate the motivating repo; direct reads of
  `ModelChecker/.github/workflows/release.yml`, `ModelChecker/.github/RELEASE_SETUP.md`,
  `ModelChecker/code/CHANGELOG.md`, `ModelChecker/code/pyproject.toml`.
- Referenced line numbers are as of this research pass and will shift once Gap 1/Gap 2 fixes are
  implemented — the planner should re-anchor against the checked-out file rather than trusting
  these numbers verbatim after any edit.

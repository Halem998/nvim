# Implementation Plan: Mode-Gated Section Loading Convention

- **Task**: 87 - Mode gated section loading convention
- **Status**: [IMPLEMENTING]
- **Effort**: 7.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/087_mode_gated_section_loading_convention/reports/01_mode-gated-section-convention.md
- **Artifacts**: plans/01_mode-gated-section-convention.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A skill's `SKILL.md` body and a command's `.md` body are loaded in full on every invocation —
`install-extension.sh` has no include/partial/fragment mechanism and deploy is a byte-for-byte
copy — so a large section entered on exactly one branch is paid for on every invocation that
skips it. This plan formalizes the extraction mechanism that already exists informally in this
repo (prose section moved to a `context/` file behind an imperative "READ ... now" pointer),
adds the one missing piece (a machine-detectable paired section marker), lands a regression lint
wired as `verify-deploy.sh` Gate 19, and proves the whole convention end-to-end with a single
independent pilot. Definition of done: convention documented and registered, lint plus its
fixture test green, Gate 19 wired, and one measured extraction landed on
`skill-email-cleanup/SKILL.md`'s `` `--all` Mode `` section.

**Territory constraint (hard boundary):** this plan MUST NOT modify
`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
`agent-system/extensions/memory/skills/skill-distill/SKILL.md`,
`agent-system/extensions/literature/skills/skill-literature/SKILL.md`, or
`agent-system/extensions/core/commands/task.md`. All four are owned by sibling tasks. The pilot
is `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md` and nothing else.

### Research Integration

The research report's five decisions are adopted wholesale and are not re-litigated here:

1. **Mechanism**: prose/decision-logic branch section -> `context/**/*.md` + imperative
   "READ ... now" pointer. Bash-to-`scripts/*.sh` is a pre-existing, complementary, *separate*
   lever — documented as an adjacent option in the convention file, explicitly outside this
   convention's mechanism and outside the lint's detection model.
2. **Marker**: paired `<!-- branch-gated:begin condition="..." -->` /
   `<!-- branch-gated:end -->`, modeled on the informal `# --- name:begin/end ---` bash comment
   style already used inside `skill-orchestrate/SKILL.md`. Paired (not single) because it removes
   the `^## ` boundary scan entirely — the exact operation the fence-interior heading trap
   corrupts, and the reason both prior extractions needed a manual boundary map.
3. **Lint**: structural-plus-reasoned-allowlist shape, built on
   `scripts/lint/lint-task-lookup-adoption.sh` (dual-mode root resolution, scope by construction,
   fixture-driven regression test). See "Convention-selection check" in Phase 2 for the one place
   this plan deliberately departs from the research report's framing.
4. **Threshold**: 8,000 B aggregate marked-but-unextracted bytes per file, to be confirmed at
   implementation time.
5. **Pilot**: `skill-email-cleanup/SKILL.md`'s `` `--all` Mode `` section, independent of all
   sibling-task territory.

Facts re-verified against the live tree during planning (do not re-derive, but do re-confirm the
two marked as hypotheses in their phases):

- `verify-deploy.sh`'s last gate today is Gate 18 (task-lookup adoption lint); Gate 19 is free.
- `core/manifest.json`'s `provides.context` lists `patterns` **wholesale** -> the convention doc
  needs **no** manifest edit.
- `core/manifest.json`'s `provides.scripts` enumerates scripts **individually**, including each
  `lint/lint-*.sh` and `tests/test-lint-*.sh` -> the new lint **and** its test **do** need
  manifest entries. This is a divergence from the research report, which only discussed the
  no-manifest-edit case for context files.
- `email/manifest.json`'s `provides.context` lists `project/email` wholesale -> the pilot's
  extracted file needs no manifest edit, only an `index-entries.json` entry.
- `lint-task-lookup-adoption.sh` uses `set -euo pipefail` (Class A), not the `set -uo pipefail`
  the research report attributed to it. Its fixture test uses `set -uo pipefail`. Match each
  sibling's actual posture, not the report's description.
- `skill-email-cleanup/SKILL.md` is 47,832 B; its `` `--all` Mode `` section spans lines 281-534
  = 17,309 B, and contains ten `#`/`###`-prefixed lines, several of them bash comments *inside
  fenced blocks* — a live instance of the fence-interior trap the marker exists to defeat.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap consultation was
requested; `specs/ROADMAP.md` was not read and is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- Publish `context/patterns/mode-gated-section-loading.md` as the named, general convention:
  marker syntax, the imperative/passive pointer test, destination-file framing requirements,
  registration mechanics, path-selection rule (core vs. extension-owned surface), and the
  whole-section-vs-reference-appendix risk distinction.
- Land `scripts/lint/lint-branch-gated-sections.sh` detecting marked-but-unextracted branch
  sections above a byte threshold on runtime-loaded executable `.md` surfaces.
- Land a fixture-driven regression test for that lint.
- Wire the lint as `verify-deploy.sh` Gate 19, following Gate 18's call shape exactly.
- Land one pilot extraction with a measured before/after byte delta.

**Non-Goals**:
- Migrating any of the four headline instances (skill-orchestrate, skill-distill,
  skill-literature, `commands/task.md`). Owned by sibling tasks; touching them here is
  prohibited.
- Adopting bash-to-`scripts/*.sh` extraction as part of this convention or lint.
- Detecting *unmarked* branch-gated sections. The lint is a regression guard on the marked class,
  not a completeness proof — stated plainly in the convention doc and the lint header rather than
  papered over.
- Any change to `install-extension.sh` or the deploy mechanism (no include/partial mechanism is
  being introduced).
- A `condition="..."` cross-check against real dispatch logic (documented as a future
  enhancement; the attribute is recorded for humans and future tooling only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Whole-section extraction leaves the pointer target as the section's ONLY specification; a skipped READ yields unspecified (not degraded) execution | H | M | Unsoftened framing at both ends: pointer says "READ ... now and follow it exactly"; destination file's opening line states it is the complete and only specification for the section and MUST be followed exactly. Never "see also"/"for more detail". Phase 5 verifies both ends by direct read-back. |
| Fence-interior heading trap: a naive `^## ` scan matches a decoy heading inside a fenced example and truncates the wrong range | H | M | Mark boundaries with the paired marker BEFORE cutting; re-locate both boundaries by literal marker text immediately before the deletion; the pilot section is a live instance (ten `#`-prefixed lines, several inside fences) so this is exercised, not assumed. |
| Lint threshold mis-calibrated (8,000 B is a recommendation, not derived from an existing budget constant) | M | M | Phase 2 confirms it against all five known section sizes (17,309 / 25,883 / 43,254 / 65,772 / 103,462 B) and records the calibration reasoning in the lint header; a wrong-but-documented number is re-tunable, an undocumented one is not. |
| Convention-selection rule (`adoption-lint-conventions.md`) nominally selects zero-tolerance because the live *marked* count is zero at landing | M | H | Phase 2 runs the honest live-count check and records the deliberate outcome: allowlist mechanism present, starting empty, because known debt arrives the moment a sibling task marks a section mid-migration. Zero-tolerance would block those tasks' intermediate states. Stated in the lint header, not left implicit. |
| New lint/test files silently not deployed because `core/manifest.json` enumerates scripts individually | M | M | Phase 2 and Phase 3 each add their own manifest entry as part of the phase; Phase 6's full `verify-deploy.sh` run over a fresh deploy is the catch-all. |
| Pilot file concurrently modified by other in-flight email work | L | L | `skill-email-cleanup/SKILL.md`'s `--all` section is not the subject of any open task found during planning (the one open email task concerns safety-context loading, not this section). Phase 5 re-checks `git status` and re-locates boundaries by text before cutting. |
| Marker-adoption blind spot: an unmarked new large branch section evades the lint entirely | M | H | Accepted and documented, matching this repo's existing adoption-lint precedent. Convention doc instructs authors to mark any `##` section entered via an explicit conditional-dispatch statement; the lint header states the limitation plainly. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author and register the convention document [COMPLETED]

**Goal**: `context/patterns/mode-gated-section-loading.md` exists as the named, citable
convention, registered in the core context index, so every later phase (and every sibling
migration task) has one authority to point at.

**Tasks**:
- [x] Write `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` covering: *(completed)*
  - **The problem**, stated once and concretely: skill/command bodies load in full on every
    invocation; `install-extension.sh` has no include/partial/fragment mechanism; deploy is a
    byte-for-byte copy. A mutually-exclusive branch section is therefore paid for on every
    invocation that skips it.
  - **Marker syntax**: `<!-- branch-gated:begin condition="..." -->` ... `<!-- branch-gated:end -->`,
    placed immediately outside the section's `##` heading and immediately after its last line.
    Document the `condition` attribute's vocabulary by example (`multi_task_mode=true`, `--auto`,
    `mode=all`) and state that it is human/future-tooling documentation, not currently
    cross-checked against dispatch logic.
  - **Why paired, not single**: a single marker still requires a same-or-higher-heading scan to
    find the end — the exact operation the fence-interior heading trap corrupts. Cite the trap by
    name with the concrete decoy class (a `##`- or `#`-prefixed line inside a fenced example).
  - **Naming precedent**: the informal `# --- name:begin ---` / `# --- name:end ---` bash comment
    style already present in `skill-orchestrate/SKILL.md` Stage 2. This is a formalization of an
    existing house style, not new syntax.
  - **The extraction procedure**, as an ordered checklist: mark -> re-locate boundaries by literal
    marker text -> create destination file -> replace the marked span (markers included) with the
    pointer -> register in `index-entries.json` -> re-check inbound cross-references -> measure.
    Include the bottom-up (last-section-first) ordering rule for multi-section files so untouched
    sections keep their line numbers.
  - **The imperative/passive pointer test**, stated as a test an author applies: "would an agent
    reading only the body know it is REQUIRED to open the referenced file at this moment?" Give
    the two working precedent pointers verbatim as templates and name the banned forms
    ("see also", "for more detail", "additional context").
  - **Whole-section vs. reference-appendix risk**: extracting a whole mode makes the destination
    the section's ONLY specification, so a skipped READ produces unspecified execution rather
    than degraded execution. Requirement: the destination file's opening line must state it is
    the complete and only specification for the section and MUST be followed exactly.
  - **Path selection rule**: a core-owned surface extracts into
    `core/context/patterns/<name>.md`; an extension-owned surface extracts into that extension's
    own provided context subtree (e.g. `email/context/project/email/patterns/<name>.md`).
    Pointers always use the DEPLOYED path form (`.claude/context/...`), never the source-store
    form, because that is the path an executing agent can open.
  - **Registration mechanics**: add an `index-entries.json` entry with the appropriate
    `load_when` keys. Whether `manifest.json` also needs an edit depends on whether that
    extension's `provides.context` lists the directory wholesale or enumerates files — check,
    do not assume (core lists `patterns` wholesale; core's `provides.scripts` enumerates
    individually).
  - **When NOT to extract**: sections below the lint threshold, sections that are the default/
    most-frequently-taken branch, and composable modifiers (which are not exclusive branches at
    all — name `skill-email-cleanup`'s `Archive Scope` as the worked counter-example).
  - **Adjacent, separate lever**: procedural bash -> `scripts/*.sh` removes tokens on *every*
    invocation, branch-gated or not; already established via the existing `orchestrate-*.sh`
    script family. Explicitly outside this convention's mechanism and outside the lint's
    detection model; a per-file application task may reach for it independently.
  - **Enforcement pointer**: names `scripts/lint/lint-branch-gated-sections.sh` and
    `verify-deploy.sh` Gate 19, and states the marker-adoption blind spot plainly.
  - **See Also**: `context/patterns/adoption-lint-conventions.md`.
- [x] Add the `index-entries.json` entry for `patterns/mode-gated-section-loading.md` in
  `agent-system/extensions/core/index-entries.json`, matching the shape of the existing
  `patterns/todo-archival-reference.md` entry (`path`, `domain`, `subdomain`, `summary`,
  `line_count`, `keywords`, `load_when`). Set `line_count` to the file's actual final line count.
  *(completed: line_count 207, modeled on adoption-lint-conventions.md's on_demand:true shape)*
- [x] Confirm no `manifest.json` edit is required (core `provides.context` lists `patterns`). *(completed: confirmed)*
- [x] Verify the file contains no task-number references (`.claude/rules/no-task-references-in-deliverables.md`);
  refer to sibling work by file name only, never by task number. *(completed: check-task-references.sh PASS, 0 occurrences)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` - new; the convention
- `agent-system/extensions/core/index-entries.json` - one new entry

**Verification**:
- `python3 -c "import json; json.load(open('agent-system/extensions/core/index-entries.json'))"` parses.
- The new entry's `path` and `line_count` match the file on disk (`wc -l`).
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo's equivalent
  invocation) reports no new findings for the new file.
- Read-back check: every marker example in the doc uses the exact literal strings
  `branch-gated:begin` and `branch-gated:end` that Phase 2's lint will grep for.

---

### Phase 2: Implement the branch-gated section lint [COMPLETED]

**Goal**: `scripts/lint/lint-branch-gated-sections.sh` exists, resolves its scan root correctly in
both source-store and deployed layouts, and fails loudly and namedly when a runtime-loaded `.md`
surface carries marked-but-unextracted branch sections summing above the threshold.

**Tasks**:
- [x] Read `scripts/lint/lint-task-lookup-adoption.sh` in full first and copy its structure: *(completed)*
  argument parsing (`--verbose`, `--quiet`, optional `path...`), the dual-mode root-resolution
  probe (`core/manifest.json` one level under a candidate root distinguishes source-store from
  deployed), the `[VIOLATION]`-tagged output line format that `verify-deploy.sh` greps, and the
  three-value exit-code contract (0 clean / 1 violations / 2 script error).
- [x] **Strict-mode posture**: default to Class A (`set -euo pipefail`), matching the sibling *(completed: Class A, no counter idiom)*
  lint's actual posture. Only choose Class B (`set -uo pipefail`) if the counter/report-everything
  admission test in `context/standards/shell-strict-mode.md` genuinely applies to the
  implementation as written, and say which was chosen and why in the header.
- [x] **Scope by construction, never by exclusion list**: `commands/*.md` and `skills/*/SKILL.md` *(completed)*
  across each extension. `docs/`, `context/`, `rules/`, `agents/` are out of scope because the
  scan never visits them.
- [x] **Layer 1 (structural)**: for each in-scope file, pair every `<!-- branch-gated:begin ... -->` *(completed)*
  with the next `<!-- branch-gated:end -->` and sum the byte spans. Report a violation when a
  file's sum exceeds the threshold. Handle and report, as a distinct named diagnostic (not a
  silent skip), the three malformed cases: an unmatched `begin`, an unmatched `end`, and a
  nested/overlapping pair.
- [x] **Layer 2 (file-level allowlist)**: an `EXCLUDED_FILES`-style block in the same shape as the *(completed: starts empty)*
  sibling lint's. Every entry carries an inline reason; bare paths are prohibited by construction.
- [x] **Convention-selection check (do this, do not skip it)**: run the honest live count of *(completed: live count is 0)*
  marked-but-unextracted files across the tree before finalizing. Expect zero (no markers exist
  yet outside the pilot). Record in the lint header the deliberate decision that the allowlist
  mechanism is present but **starts empty** — chosen over zero-tolerance because per-file
  migration work will legitimately produce a marked-but-unextracted intermediate state, which a
  zero-tolerance assertion would block outright. If the live count comes back non-zero, that is
  new information: record what was found and populate the allowlist with reasoned entries.
- [x] **Threshold**: implement as a single named constant at the top of the script (e.g. *(completed: THRESHOLD_BYTES=8000)*
  `THRESHOLD_BYTES=8000`) with a header comment giving the calibration: below every known
  instance (17,309 / 25,883 / 43,254 / 65,772 / 103,462 B) by a wide margin so it needs no
  re-tuning as those land, and above small legitimately-inline branch content whose extraction
  overhead (new file, pointer, index entry) would exceed the win.
- [x] **Known-limitation block** in the header, in the sibling lint's plain-spoken style: this is *(completed)*
  a marker-keyed lint; an unmarked new offender evades it entirely; a clean run means "no marked
  section exceeds the threshold", never "no branch-gated section is inline anywhere".
- [x] Add `"lint/lint-branch-gated-sections.sh"` to `provides.scripts` in *(completed)*
  `agent-system/extensions/core/manifest.json` (that list enumerates files individually; without
  this entry the script is never deployed).
- [x] Run the lint against the live source store and confirm it exits 0. *(completed: 133 files checked, exit 0; deployed-mode .claude scan also exercised, 50 files, exit 0)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The threshold is asserted as 8,000 B and the known-instance sizes as
17,309 / 25,883 / 43,254 / 65,772 / 103,462 B. Confirm at implementation time by re-measuring the
pilot section directly (`awk` over the marker-delimited span) and by sanity-checking the four
headline figures against the research report before writing them into the header; if any figure
does not reproduce, record the measured value rather than the reported one. Also asserted: the
in-scope file set is `commands/*.md` plus `skills/*/SKILL.md` across all extensions — confirm the
glob actually enumerates a non-empty set in BOTH root-resolution modes before trusting a clean
run (an empty scan that exits 0 is the precise defect that made an earlier gate worthless).

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh` - new; the lint
- `agent-system/extensions/core/manifest.json` - one new `provides.scripts` entry

**Verification**:
- `bash -n` on the script passes.
- `shellcheck` (if available in this environment) reports no errors.
- The lint run against the source store exits 0 and its `--verbose` output names a non-empty
  in-scope file list (proving the scan root resolved and the glob matched).
- The same run invoked from the deployed `.claude/` copy path also enumerates a non-empty file
  list (dual-mode root resolution actually works, not just in the invocation that was convenient).
- `python3 -c "import json; json.load(open('agent-system/extensions/core/manifest.json'))"` parses
  and the new entry is present.

---

### Phase 3: Fixture-driven regression test for the lint [COMPLETED]

**Goal**: `scripts/tests/test-lint-branch-gated-sections.sh` pins the lint's behavior against
synthetic fixtures, never depending on the live tree being clean.

**Tasks**:
- [x] Model the file structurally on `scripts/tests/test-lint-task-lookup-adoption.sh`: `set -uo *(completed)*
  pipefail`, `mktemp -d` workdir with an `EXIT` trap, deploy-tree-first / source-store-fallback
  candidate resolution for locating the lint under test, `pass()`/`fail()`/`info()` counters, and
  the "exit code reports test success, not lint success" header note.
- [x] Cases to cover, each with its own synthetic fixture tree: *(completed: all 9 cases, 16 PASS assertions)*
  1. **Acceptance criterion**: a `skills/x/SKILL.md` fixture carrying a marked section above the
     threshold -> lint exits 1 and names that file.
  2. A marked section *below* the threshold -> lint exits 0 (the "don't extract trivia" boundary).
  3. Two marked sections in one file each below threshold but summing above it -> lint exits 1
     (the sum, not the max, is the trigger).
  4. An extracted file (pointer present, no markers) -> lint exits 0.
  5. A marked, over-threshold section in an OUT-OF-SCOPE location (`context/`, `docs/`) -> lint
     exits 0 (scope is by construction).
  6. A file on the allowlist with an over-threshold marked section -> lint exits 0.
  7. Malformed markers (unmatched `begin`; unmatched `end`) -> reported as the named diagnostic,
     not silently treated as clean.
  8. **Fence-interior decoy**: a fixture whose marked section contains `##`- and `#`-prefixed
     lines inside fenced code blocks -> boundaries still resolve exactly to the markers. This is
     the case that proves the marker design's whole reason for existing.
  9. **Both root-resolution modes** exercised (source-store-shaped fixture root and
     deployed-shaped fixture root), each producing a non-empty scan.
- [x] Add `"tests/test-lint-branch-gated-sections.sh"` to `provides.scripts` in *(completed)*
  `agent-system/extensions/core/manifest.json`.
- [x] Confirm no separate `run-all.sh` registration is needed (it discovers `scripts/tests/test-*.sh` *(completed: verified via run-all.sh source read)*
  automatically) by inspecting `run-all.sh`'s discovery logic, not by assuming it.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Nine test cases are asserted. Confirm each is actually implemented and
actually exercises a distinct code path — a case that passes because the fixture never reached
the relevant branch is worse than no case. Report the real case count and each case's PASS/FAIL
line in the phase's completion note. Also asserted: `run-all.sh` auto-discovers
`scripts/tests/test-*.sh` — confirm by reading its discovery logic before relying on it.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` - new
- `agent-system/extensions/core/manifest.json` - one new `provides.scripts` entry

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` exits 0 with
  every case PASS and a non-zero case count.
- Deliberately break one fixture (flip case 1's section below threshold) and confirm the suite
  FAILS — a suite that cannot fail proves nothing. Restore afterwards.
- The suite leaves no files behind outside its `mktemp -d` workdir and does not mutate the
  repository (`git status --short` unchanged after a run).

---

### Phase 4: Wire the lint as verify-deploy Gate 19 [COMPLETED]

**Goal**: `verify-deploy.sh` runs the new lint as Gate 19, following Gate 18's call shape exactly,
so the convention is enforced on every deploy verification.

**Tasks**:
- [x] Re-confirm Gate 18 is still the last gate in `scripts/verify-deploy.sh` before appending *(completed: confirmed via grep)*
  Gate 19 (another in-flight change may have claimed the number).
- [x] Copy Gate 18's block structure verbatim, substituting the new script: the *(completed)*
  `[ ! -d "$TARGET/agent-system/extensions" ]` deploy-consumer `[SKIP]` branch, the
  script-existence `fail`, the `cd "$TARGET" && REPO_ROOT="$TARGET" bash ... --verbose` invocation,
  the pass/fail messages, `CURRENT_GATE="gate19"`, and the `FINDINGS_LIST+=("FINDING gate19 ...")`
  loop keyed on `[VIOLATION]` lines.
- [x] Update the gate count/summary text in `verify-deploy.sh` and any place that names the *(completed: no such place found)*
  highest gate number, if such a place exists (grep for `gate18` and for the gate total before
  assuming there is none).
- [x] Run `verify-deploy.sh` end to end against the source store and confirm Gate 19 appears, *(completed: Gate 19 PASS; 2 pre-existing failures on specs/state.json unrelated to this change, from concurrent sibling-task edits)*
  runs, and passes.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: "Gate 18 is currently the last gate, so Gate 19 is free" is a hypothesis
from a planning-time read. Confirm by grepping `verify-deploy.sh` for `Gate 1[0-9]`/`gate1[0-9]`
immediately before editing; if a Gate 19 already exists, take the next free number and say so.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - one new gate block appended

**Verification**:
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` passes.
- A full `verify-deploy.sh` run prints the Gate 19 header, reports PASS, and the run's overall
  failure count is unchanged from before the edit.
- Temporarily point the gate at a nonexistent script path and confirm it produces a `fail`, not a
  silent pass. Restore afterwards.

---

### Phase 5: Pilot extraction — skill-email-cleanup `--all` Mode [NOT STARTED]

**Goal**: The convention is demonstrated end to end on one independent file: marker applied, lint
detection observed firing, section extracted behind an imperative pointer, destination registered,
byte delta measured.

**Tasks**:
- [ ] `git status --short` on `agent-system/extensions/email/` first; abort and report if the
  pilot file has uncommitted concurrent edits.
- [ ] Re-locate the section boundaries by heading text, not by the line numbers in this plan:
  the `` ## `--all` Mode (`mode=all`): ... `` heading, and the line immediately before
  `## Archive Scope (`scope=archive`): ...`. Inspect the span for fence-interior `#`/`##` lines
  and confirm by direct reading that the chosen end boundary is the real next `##` heading and not
  a decoy.
- [ ] Insert `<!-- branch-gated:begin condition="mode=all" -->` immediately above the heading and
  `<!-- branch-gated:end -->` immediately after the section's last line.
- [ ] **Run the lint now and record its output.** It MUST report a violation naming
  `skill-email-cleanup/SKILL.md`. This is the proof that detection works on a real file, not only
  on a fixture; capture the exact line for the summary. (This intermediate state is expected red —
  see Commit Mode.)
- [ ] Create `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md`
  containing the section's content verbatim, preceded by an opening line stating it is the
  complete and only specification for `/email --all` mode's execution and MUST be followed
  exactly. Demote the section's internal headings by one level if needed so the destination file
  has a single top-level heading.
- [ ] Replace the entire marked span in `SKILL.md` (markers included) with an imperative pointer
  in the Execution Flow / mode-dispatch position, using the deployed path form:
  `.claude/context/project/email/patterns/email-cleanup-all-mode.md`, phrased "READ ... now and
  follow it exactly". Apply the imperative/passive test to the wording before accepting it.
- [ ] Grep the email extension (and `commands/email.md` specifically) for inbound references into
  the extracted region and repoint any that would now dangle. Record the result of the check even
  if nothing needed repointing — the check is required every time, never assumed clean.
- [ ] Add the `index-entries.json` entry in `agent-system/extensions/email/index-entries.json`
  with `load_when.commands: ["/email"]` (plus `skills`/`task_types` keys matching the shape of the
  existing entries in that file), correct `line_count`, and a one-line `summary`.
- [ ] Confirm no `email/manifest.json` edit is needed (`provides.context` lists `project/email`
  wholesale) — verify rather than assume.
- [ ] Measure and record: `SKILL.md` bytes before, bytes after, delta and percentage; extracted
  file bytes; approximate token saving per non-`--all` `/email` invocation. Put this table in the
  task summary and add a one-line worked reference to it in the convention doc's "measured
  example" slot.
- [ ] Re-run the lint: it MUST now exit 0 for that file.

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The section is asserted to span lines 281-534 = 17,309 B of a 47,832 B file,
and to be genuinely mutually exclusive with `Default Mode`. Confirm all three at implementation
time: re-measure the marker-delimited span with `wc -c` after marking (do not reuse this plan's
number), and re-read `commands/email.md`'s mode-dispatch block to confirm exactly one of
`mode=default` / `mode=all` fires per invocation. Report the measured figures; if they differ from
these, the measured ones are correct.

**Files to modify**:
- `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md` - section replaced by pointer
- `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md` - new
- `agent-system/extensions/email/index-entries.json` - one new entry
- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` - measured-example line

**Verification**:
- Content-preservation check: the extracted file's body is byte-identical to the removed span
  apart from the added opening framing line and any deliberate heading-level demotion. Diff the
  two explicitly; do not eyeball it.
- `python3 -c "import json; json.load(open('agent-system/extensions/email/index-entries.json'))"` parses.
- `bash agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh --verbose` exits 0.
- The pointer text passes the imperative test: an agent reading only `SKILL.md` is told it is
  REQUIRED to open the file at that moment. No "see also"/"for more detail" phrasing anywhere.
- The recorded before/after byte figures are real command output, not estimates.

---

### Phase 6: Full gate run, deploy verification, and measurement write-up [NOT STARTED]

**Goal**: Every gate is green over a fresh deploy, the new files actually deploy, and the measured
result is recorded.

**Tasks**:
- [ ] Run the full test suite (`scripts/tests/run-all.sh`, or the repo's standard invocation) and
  confirm the new lint test is discovered and passes alongside the existing suite with no
  regressions.
- [ ] Run `verify-deploy.sh` end to end; all gates including the new one must pass.
- [ ] Deploy (or dry-run deploy) and confirm all four new/changed artifacts land in `.claude/`:
  the lint script, the lint test, the convention doc, and the pilot's extracted pattern file.
  A missing file here means a `manifest.json` entry was skipped in Phase 2, 3, or 5.
- [ ] Confirm the deployed pointer path
  (`.claude/context/project/email/patterns/email-cleanup-all-mode.md`) resolves to a real file
  after deploy — the pointer is worthless if the path is wrong in the deployed tree.
- [ ] Run the repo's context-budget validation (`scripts/validate-context-budgets.sh`) and confirm
  the two new context entries do not breach any tier cap.
- [ ] Run the task-reference lint over the changed files and confirm no task-number references
  leaked into any deliverable outside `specs/**`.
- [ ] Write the task summary with the measurement table and the exact acceptance evidence:
  convention path, lint path, gate number, pilot before/after bytes.

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `specs/087_mode_gated_section_loading_convention/summaries/01_mode-gated-section-convention-summary.md` - new

**Verification**:
- Full test suite green; new lint test present in its output by name.
- `verify-deploy.sh` reports 0 failures with the new gate listed.
- All four artifacts present under `.claude/` after deploy.
- `validate-context-budgets.sh` green.
- No task-number references reported outside `specs/**`.

---

## Testing & Validation

- [ ] `bash -n` and (where available) `shellcheck` clean on both new shell files.
- [ ] `test-lint-branch-gated-sections.sh` green, with a deliberate-break check proving the suite
      can fail.
- [ ] Lint exits 0 against the live source store and enumerates a non-empty in-scope file set in
      BOTH root-resolution modes.
- [ ] Lint observed exiting 1, naming the pilot file, in the marked-but-unextracted intermediate
      state (detection proven on a real file, not only on fixtures).
- [ ] `verify-deploy.sh` full run green with the new gate.
- [ ] `run-all.sh` green with no regressions.
- [ ] All JSON edited (`core/index-entries.json`, `core/manifest.json`, `email/index-entries.json`)
      parses.
- [ ] Pilot content-preservation diff clean.
- [ ] Deploy places all four artifacts; deployed pointer path resolves.
- [ ] No task-number references outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` (new — the convention)
- `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh` (new — the lint)
- `agent-system/extensions/core/scripts/tests/test-lint-branch-gated-sections.sh` (new — fixture test)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (modified — Gate 19)
- `agent-system/extensions/core/manifest.json` (modified — two `provides.scripts` entries)
- `agent-system/extensions/core/index-entries.json` (modified — one entry)
- `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md` (modified — pilot extraction)
- `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md` (new — pilot destination)
- `agent-system/extensions/email/index-entries.json` (modified — one entry)
- `specs/087_mode_gated_section_loading_convention/summaries/01_mode-gated-section-convention-summary.md` (new)

## Rollback/Contingency

Every phase is independently revertible and all edits are confined to the source store, which is
regenerated into `.claude/` on deploy — so reverting the source-store commits and redeploying
fully restores the prior state.

- **Phase 4 (Gate 19) fails or proves noisy**: revert the `verify-deploy.sh` hunk alone. The lint
  script and its test remain useful standalone; the convention and pilot are unaffected.
- **Phase 5 (pilot) goes wrong**: revert the four pilot files as one unit — the phase is
  `atomic-batch` precisely so this is a single-commit revert. The lint then reports zero marked
  sections, which is its correct clean state, so no other phase needs unwinding.
- **The lint proves mis-calibrated after landing**: change the single `THRESHOLD_BYTES` constant;
  no structural change is needed. If the marker design itself proves wrong, revert Phases 2-5 and
  keep Phase 1's convention doc with the enforcement section removed — the documented convention
  retains value without the lint, whereas the lint is meaningless without the marker.
- **Contingency if the pilot file is found to be concurrently owned**: stop before marking, report
  the conflict, and complete Phases 1-4 and 6 without a pilot. The acceptance criterion's pilot
  clause would then be explicitly unmet and must be reported as such — never silently substituted
  with one of the four prohibited files.

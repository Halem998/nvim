# Implementation Plan: Task #994

- **Task**: 994 - Fix literature-extension tooling landmines and sync pruning
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: 980 (deploy-engine consolidation; already satisfied for planning purposes — see Out-of-Scope Finding below)
- **Research Inputs**: `specs/994_fix_literature_tooling_landmines_and_sync_pruning/reports/01_literature-tooling-landmines-research.md`
- **Artifacts**: plans/01_literature-tooling-doc-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The task's three items resolve into two actionable documentation fixes and one out-of-scope
finding. Item 1 (`zotero-search.sh` multi-term quoting) is a real, entirely undocumented
gotcha: the script OR-scores each query term independently, so a single quoted multi-word
phrase silently returns zero results while the same words passed as separate arguments match.
Item 3 (`deprecated/README.md` retirement rationale) is a confirmed missing-content gap. Item 2
(deployment hygiene) had its premise empirically disproved by research and is recorded here as
an out-of-scope finding with a recommended follow-up task, not fixed. Definition of done: the
quoting warning exists in all four documentation surfaces an agent or human could copy an
invocation from, the retirement rationale is concrete enough that no future reader must
re-derive it from the retired script body, and the deploy-engine defect is durably recorded.

### Research Integration

The plan is built directly on the research report's confirmed findings:

- **Item 1 confirmed real, zero prior coverage.** No warning exists anywhere today — not in the
  script header, not in `literature-agent.md`, not in `skill-literature/SKILL.md`, and not in
  any `context/` file (grep across `context/project/literature/**` and
  `context/guides/literature-organization.md` returns zero hits for `zotero-search`). Internal
  callers are already correct (`literature-discover.sh`'s `tier2_search()` uses a bash array
  expansion; `skill-cite/SKILL.md` already carries the comment "zotero-search.sh accepts query
  terms as positional args"), so this is purely a documentation gap for direct invocation, not a
  script defect. No behavioral change to the script is planned or wanted.
- **`zotero-search.sh` carries the USAGE text twice** — the top-of-file comment block and the
  `show_usage()` heredoc — verified by `grep -c "zotero-search.sh \[OPTIONS\] QUERY"` returning
  `2`. Both copies must be edited or the two drift.
- **Item 3 confirmed missing.** Current text says only "superseded by the inline `jq` logic in
  `skills/skill-literature/SKILL.md`." The specific rationale (20-field vs. 4-field schema,
  different target file, `zot` CLI and undefined `/zotero --setup` dependencies) is absent.
- **Item 2's premise is false** for old-engine-bootstrapped repos; research empirically
  reproduced both failure modes against scratch copies. See Out-of-Scope Finding below.
- **Research confirmed no in-scope source-reference gap for item 2** — `manifest.json` already
  omits `zotero-index-add.sh` from `provides.scripts`, and no `merge-sources/*.md` mentions it.
  Phase 5 addresses two stale stderr hint strings the research did flag as real but low
  priority; see that phase's scope note.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` in delegation context).

## Goals & Non-Goals

**Goals**:

- State the separate-arguments requirement plainly, with a concrete worked example, in both
  `zotero-search.sh` USAGE copies.
- Give `context/project/literature/patterns/agent-exploration.md` a section distinguishing
  `literature-search.sh` (local corpus) from `zotero-search.sh` (Zotero library) and carrying
  the same warning — this file currently documents only the former.
- Replace the ambiguous `{terms}` placeholder in `agents/literature-agent.md` with a concrete
  space-separated example.
- Expand `scripts/deprecated/README.md`'s `zotero-index-add.sh` entry with the concrete
  schema-mismatch and dependency rationale for its retirement.
- Retire the two stale `Run: zotero-index-add.sh $KEY` stderr hints that point at a script no
  longer wired into `manifest.json`.
- Record the deploy-engine legacy-migration defect as an explicit out-of-scope finding with a
  recommended follow-up task.

**Non-Goals**:

- Any change to `zotero-search.sh`'s runtime behavior, argument parsing, scoring, or exit
  codes. This is a documentation-only fix; accepting a quoted phrase by splitting it internally
  would be a behavior change nobody asked for and would alter OR-scoring semantics.
- Any fix to `lua/neotex/plugins/ai/shared/extensions/init.lua`'s `detect_legacy_core()` or any
  other deploy-engine code. Explicitly out of scope.
- Any parallel retirement or pruning mechanism (directly prohibited by the task framing).
- Any write to `.claude/**`. That tree is a gitignored, disposable deploy artifact.
- Any edit to a downstream repository (including PossibleWorlds). Downstream `.claude/CLAUDE.md`
  and `.claude/agents/literature-agent.md` stale rows are deploy artifacts, not source files; a
  manual edit there is overwritten by the next successful sync and is not a durable fix.
- Running `deploy-headless.sh` (either mode) against any live downstream repo.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer edits `.claude/extensions/literature/**` instead of `agent-system/extensions/literature/**` | H | M | Every phase names absolute source-store paths; Phase 7 runs a `git status` audit confirming zero `.claude/` paths in the diff |
| Only one of the two `zotero-search.sh` USAGE copies is updated, leaving them drifted | M | M | Phase 1 is a declared `atomic-batch`-style single objective covering both copies; its verification greps for the warning sentinel and asserts a count of exactly 2 |
| Implementer "helpfully" changes the script to accept a quoted phrase | H | L | Named as an explicit Non-Goal; Phase 1 verification asserts the only changed lines lie inside the comment block and the heredoc |
| Implementer reads item 2 in the task description and runs `deploy-headless.sh --wipe` against a live repo | H | L | Non-Goals name it; Phase 6 restates the empirical finding that this deletes `.claude/` and rebuilds nothing |
| Wording drifts between the four item-1 surfaces | L | M | Phase 1 establishes canonical wording first; Phases 2 and 3 depend on it and copy it |
| Task-number citations leak into a deliverable file | M | L | All five edited files are outside `specs/**`; the write-time `validate-no-task-references.sh` hook and Phase 7's grep both cover this |

## Out-of-Scope Finding: Deploy-Engine Legacy Migration Gap (Item 2)

**This is recorded, not fixed.** Research empirically disproved item 2's premise that
"wipe+regenerate prunes retired scripts by construction." That holds only for repos already
state-tracked by the current manifest-driven engine. For a repo bootstrapped under the retired
glob engine with more than `core` active (verified against scratch copies of a real downstream
repo, which has no root `.claude-extensions.json` at all):

- `deploy-headless.sh --wipe <repo>` reports "Wiped and regenerated 0 extension(s)" and leaves
  `.claude/` **completely absent**. `manager.wipe` deletes the tree unconditionally, then
  `manager.regenerate` reloads only extensions listed in the (nonexistent) root state file.
- `deploy-headless.sh <repo>` (default, non-destructive) force-loads only `core`, silently
  dropping every non-core extension's CLAUDE.md contribution — the literature extension's entire
  "Zotero Integration" section included — while leaving the stale `zotero-index-add.sh` file and
  stale generated rows physically untouched.

**Root cause**: `detect_legacy_core()` in
`lua/neotex/plugins/ai/shared/extensions/init.lua` migrates only `core` from an old-engine repo
into the new state system. No equivalent detection exists for any other extension, and both
`manager.resync_all()` and `manager.wipe()` -> `manager.regenerate()` operate exclusively over
the root `.claude-extensions.json` — never the per-`base_dir` `.claude/extensions.json`, which
does still correctly list the other active extensions.

**Recommended follow-up task** (to be created by the user; this plan does not create it):

> Extend the deploy engine's legacy-repo migration from `core`-only to all previously-loaded
> extensions. `detect_legacy_core()` in `lua/neotex/plugins/ai/shared/extensions/init.lua`
> migrates only `core` into the root `.claude-extensions.json`; extensions loaded under the
> retired glob engine are invisible to `manager.resync_all` and `manager.regenerate`. On such a
> repo the default deploy silently drops every non-core extension's CLAUDE.md contribution, and
> `--wipe` deletes `.claude/` and rebuilds nothing. Reconcile from the per-`base_dir`
> `.claude/extensions.json` (which does list them) during migration detection. Until this lands,
> do not run `deploy-headless.sh` in either mode against any repo lacking a root
> `.claude-extensions.json`.

**Interim warning**: until that task lands, `deploy-headless.sh --wipe` must not be run against
any repo without a root `.claude-extensions.json`, and the stale generated references in such
repos cannot be cleaned up via deploy at all.

## Scope Nuance: Files Outside the Declared `file_scope`

The task's declared `file_scope` is `agent-system/extensions/literature/scripts/` and
`agent-system/extensions/literature/context/`. Phase 3 edits
`agent-system/extensions/literature/agents/literature-agent.md`, which is **outside** that
declaration. It is included deliberately: research identified it as the single most concrete
place an agent copies a hand-written `zotero-search.sh` invocation from, and leaving its
ambiguous `{terms}` placeholder in place would leave item 1's most likely failure path
unaddressed while the less-trafficked surfaces were fixed. `file_scope` is a descriptive,
non-validated field, and the edit is a one-line example change squarely in the spirit of item 1.
The implementer should note this deviation in the implementation summary.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4, 5 | -- |
| 2 | 2, 3 | 1 |
| 3 | 6 | -- |
| 4 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Phase 6 has no code dependencies and is
placed in wave 3 only for narrative ordering; it may run at any point.

---

### Phase 1: Canonical quoting warning in both zotero-search.sh USAGE copies [COMPLETED]

**Goal**: State the separate-arguments requirement, with a concrete worked example, in both
copies of the USAGE text, and fix the canonical wording that later phases reuse.

**Tasks**:

- [ ] Read `agent-system/extensions/literature/scripts/zotero-search.sh` and locate both USAGE
      surfaces: the top-of-file comment block (`# USAGE:` / `# DESCRIPTION:`, roughly lines
      20-33) and the `show_usage()` heredoc (`USAGE:` / `DESCRIPTION:`, roughly lines 71-95).
- [ ] Draft one canonical warning paragraph. It must state, in this order: (a) each search word
      is a SEPARATE argument, (b) a single quoted multi-word phrase will not match, (c) a
      concrete before/after example. Suggested wording, to be reused verbatim in Phases 2 and 3:

      IMPORTANT -- pass each search word as a SEPARATE argument. Query terms are OR-scored
      independently, so a single quoted multi-word phrase is treated as one term and will
      match nothing even when every individual word is present in the library.
        Wrong:   zotero-search.sh "Burgess axioms tense logic"     -> 0 results
        Right:   zotero-search.sh Burgess axioms tense logic       -> matches
      From a shell variable, expand unquoted (or use an array): "${TERMS[@]}".

- [ ] Insert the warning immediately after the `USAGE:` line in the top-of-file comment block,
      comment-prefixed (`#`) to match surrounding style.
- [ ] Insert the identical warning immediately after the `USAGE:` line inside the `show_usage()`
      heredoc, without the `#` prefix (heredoc content is printed verbatim).
- [ ] Confirm the two insertions are textually identical apart from the comment prefix.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The USAGE text appears exactly twice in this file. Confirm at
implementation time with `grep -c 'zotero-search.sh \[OPTIONS\] QUERY'
agent-system/extensions/literature/scripts/zotero-search.sh` — expect `2`. If the count differs,
update every occurrence found and record the actual count in the summary.

**Files to modify**:

- `agent-system/extensions/literature/scripts/zotero-search.sh` - add the warning to both the
  header comment block and the `show_usage()` heredoc; no behavioral change

**Verification**:

- `bash -n agent-system/extensions/literature/scripts/zotero-search.sh` exits 0.
- `grep -c 'SEPARATE argument' agent-system/extensions/literature/scripts/zotero-search.sh`
  returns `2`.
- `bash agent-system/extensions/literature/scripts/zotero-search.sh --help 2>&1 | grep -q 'SEPARATE argument'`
  succeeds (the heredoc copy is the one actually printed).
- `git diff` read-through confirms every changed hunk lies inside the comment block or the
  heredoc — no change to argument parsing, scoring, or exit codes.

---

### Phase 2: Zotero-vs-corpus search section in agent-exploration.md [COMPLETED]

**Goal**: Give the literature extension's context docs their first coverage of
`zotero-search.sh`, distinguished from the corpus-search tool they currently document, carrying
the Phase 1 warning.

**Tasks**:

- [ ] Read `agent-system/extensions/literature/context/project/literature/patterns/agent-exploration.md`.
      It currently documents only `literature-search.sh` (local corpus search) and never
      mentions `zotero-search.sh`.
- [ ] Add a new section (suggested title: "Two Search Tools: Corpus vs. Zotero Library") after
      the existing "Step 1: Search First" / "Step 2: Read Specific Chunks" material and before
      "Selectivity Principle". Content:
  - [ ] A short table distinguishing the two: `literature-search.sh` searches the already-ingested
        local corpus under `$LITERATURE_DIR` and takes a single quoted query string;
        `zotero-search.sh` searches the Better BibTeX CSL-JSON export of the Zotero library and
        takes each term as a separate argument.
  - [ ] The Phase 1 warning paragraph, reproduced verbatim, with its wrong/right example.
  - [ ] A one-line pointer that a matched Zotero entry may then be imported via
        `/literature --search`, so the two tools compose rather than compete.
- [ ] Verify no task-number citation is introduced (this file is outside `specs/**`).

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/literature/context/project/literature/patterns/agent-exploration.md` -
  add the two-search-tools section including the quoting warning

**Verification**:

- `grep -q 'zotero-search.sh' <file>` succeeds (it previously returned nothing).
- `grep -q 'SEPARATE argument' <file>` succeeds and the surrounding text matches Phase 1's
  canonical wording.
- Diff read-through confirms the edit is additive prose; no existing `literature-search.sh`
  guidance was altered or removed.
- The markdown renders: no broken table pipes, no unclosed code fence.

---

### Phase 3: Concrete invocation example in literature-agent.md [COMPLETED]

**Goal**: Replace the ambiguous `{terms}` placeholder with a concrete space-separated example so
an agent copying the line gets a working invocation.

**Tasks**:

- [ ] Read the "Search-to-Import Pipeline Overview" numbered list in
      `agent-system/extensions/literature/agents/literature-agent.md` (the `zotero-search.sh
      --format=json --limit=20 {terms}` bullet, item 1 of that list, near line 110).
- [ ] Replace the bare `{terms}` placeholder with a form that makes the separate-argument
      requirement unmissable — e.g. `{term1} {term2} ...` plus a parenthetical concrete example
      such as `(e.g. "Burgess axioms tense logic" must be passed as four separate arguments:
      Burgess axioms tense logic)`.
- [ ] Add a one-sentence pointer to the fuller warning, referencing `zotero-search.sh --help` and
      `context/project/literature/patterns/agent-exploration.md` as durable anchors.
- [ ] Do not alter any other content in this file.

**Timing**: 0.2 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/literature/agents/literature-agent.md` - one bullet in the
  Search-to-Import Pipeline Overview list (outside declared `file_scope`; see Scope Nuance above)

**Verification**:

- `grep -n 'zotero-search.sh --format=json --limit=20' <file>` shows the updated line with a
  concrete multi-term example rather than a bare `{terms}`.
- `git diff --stat` shows exactly one file changed with a small line delta (a large delta means
  something unintended was touched).
- Diff read-through confirms only prose changed.

---

### Phase 4: Concrete retirement rationale in deprecated/README.md [COMPLETED]

**Goal**: Record why `zotero-index-add.sh` was retired specifically enough that no future reader
must re-derive it by reading the retired script.

**Tasks**:

- [ ] Read `agent-system/extensions/literature/scripts/deprecated/README.md` (the
      `zotero-index-add.sh` bullet under `## Contents`).
- [ ] Expand that bullet — or promote it to a short `### zotero-index-add.sh` subsection if the
      content outgrows a bullet — recording all four points:
  - [ ] **Schema mismatch**: the script builds a ~20-field entry (`zotero_key`, `citation_key`,
        `title`, `authors`, `year`, `item_type`, `abstract_snippet`, `keywords`, `tags`,
        `collections`, `has_pdf`, `pdf_path`, `has_chunks`, `chunk_dir`, `chunk_count`,
        `token_count`, `relevance_keywords`, `notes_summary`, `added_at`, `last_retrieved`),
        while `literature-briefing.sh` — the actual `--lit` consumer — reads only
        `{doc_id, relevance, added, source}`.
  - [ ] **Wrong target file**: the script writes `specs/zotero-index.json`;
        `literature-briefing.sh` reads `specs/literature-index.json`. Different files, not
        different views of one file.
  - [ ] **Unmet dependencies**: it depends on the `zot` CLI (via `zotero-read.sh`) and prints
        setup instructions referencing `/zotero --setup`, a command that does not exist in this
        project's command set (`commands/` contains only `cite.md` and `literature.md`).
  - [ ] **Why retirement over repair**: repair would require schema translation plus a target-file
        change plus removing the `zot`/`--setup` dependency — a rewrite, not a fix. Sub-index
        registration instead uses the documented `jq` append pattern in
        `skills/skill-literature/SKILL.md`'s "Sub-Index Management" section ("Add: Append a
        Document Entry").
- [ ] Leave the `zotero-index-remove.sh` bullet, the Migration Status section, and the
      Quarantine/Removal policy sections unchanged.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/literature/scripts/deprecated/README.md` - expand the
  `zotero-index-add.sh` retirement rationale

**Verification**:

- `grep -q 'literature-index.json' <file>` and `grep -q 'zotero-index.json' <file>` both
  succeed — the two distinct filenames are the load-bearing detail.
- `grep -q 'doc_id' <file>` succeeds (the 4-field consumer shape is recorded).
- `grep -q 'zotero-index-remove.sh' <file>` still succeeds (the sibling entry survives).
- Diff read-through confirms the Quarantine and Removal Policy sections are untouched.

---

### Phase 5: Retire two stale zotero-index-add.sh stderr hints [NOT STARTED]

**Goal**: Stop two live scripts from telling the user to run a script that is no longer deployed.

**Scope note**: the delegation framing stated there is "no in-scope source-reference gap to
fill" for item 2, which is correct as to `manifest.json` and `merge-sources/*.md`. Research
separately confirmed these two stderr hints as real stale references that do point at the
retired script. They sit inside the declared `file_scope`
(`agent-system/extensions/literature/scripts/`) and belong to item 3's retirement hygiene rather
than item 2's deployment hygiene, so they are included here. This is a two-line change; if the
implementer judges it genuinely out of scope, skipping it must be recorded as a reasoned
exclusion with evidence, not dropped silently.

**Tasks**:

- [ ] `agent-system/extensions/literature/scripts/zotero-chunk.sh` line ~145: replace
      `echo "Run: zotero-index-add.sh $KEY" >&2` with a hint pointing at the live mechanism —
      the `jq` append pattern documented in `skills/skill-literature/SKILL.md`'s "Sub-Index
      Management" section.
- [ ] `agent-system/extensions/literature/scripts/zotero-attach-chunks.sh` line ~125: apply the
      identical replacement.
- [ ] Keep both messages on stderr and keep the surrounding `exit 2` unchanged — this is a
      message-text change only, not a control-flow change.

**Timing**: 0.2 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Exactly two such hint strings exist in the source store outside
`deprecated/`. Confirm with `grep -rn 'zotero-index-add' agent-system/extensions/literature/
--include=*.sh | grep -v '/deprecated/'` — expect exactly two hits, in the two files named
above. If more appear, fix all of them and record the actual count.

**Files to modify**:

- `agent-system/extensions/literature/scripts/zotero-chunk.sh` - stderr hint text
- `agent-system/extensions/literature/scripts/zotero-attach-chunks.sh` - stderr hint text

**Verification**:

- `bash -n` exits 0 for both scripts.
- `grep -rn 'zotero-index-add' agent-system/extensions/literature/ --include=*.sh | grep -v '/deprecated/'`
  returns no matches.
- Diff read-through confirms only the `echo` string changed; the `exit 2` and enclosing `if`
  are unchanged.

---

### Phase 6: Record the item 2 out-of-scope finding and follow-up recommendation [NOT STARTED]

**Goal**: Ensure the deploy-engine defect survives past this task's completion as an actionable
recommendation rather than being lost with the research report.

**Tasks**:

- [ ] Reproduce the "Out-of-Scope Finding" section of this plan (root cause, both empirical
      failure modes, the recommended follow-up task description verbatim, and the interim
      "do not run `deploy-headless.sh --wipe` on a repo without a root `.claude-extensions.json`"
      warning) as a dedicated section of the implementation summary.
- [ ] Surface the recommended follow-up task description to the user as a ready-to-use `/task`
      argument. Do NOT create the task — task creation is a user decision.
- [ ] State plainly in the summary that item 2 produced no file edits, and why: its premise was
      empirically disproved and its actual remediation lies in
      `lua/neotex/plugins/ai/shared/extensions/init.lua`, outside this task's file scope.

**Timing**: 0.2 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:

- `specs/994_fix_literature_tooling_landmines_and_sync_pruning/summaries/01_*-summary.md` -
  dedicated out-of-scope-finding section (created at implementation wrap-up)

**Verification**:

- The summary contains the root cause naming `detect_legacy_core`, both failure modes, and the
  verbatim follow-up task description.
- The summary states explicitly that no follow-up task was auto-created.

---

### Phase 7: Boundary and consistency audit [NOT STARTED]

**Goal**: Confirm the change set respects the source-store boundary, the no-task-references
rule, and cross-file wording consistency before the task closes.

**Tasks**:

- [ ] `git status --short` — confirm every modified path begins with
      `agent-system/extensions/literature/` or `specs/994_.../`. Any `.claude/` path is a
      boundary violation and must be reverted.
- [ ] `bash .claude/scripts/check-task-references.sh` (or an equivalent grep for `task [0-9]`
      / `Task #[0-9]` / `tasks [0-9]` across the five modified deliverable files) — confirm no
      task-number citation landed outside `specs/**`.
- [ ] Confirm the warning wording is consistent across `zotero-search.sh` (both copies),
      `agent-exploration.md`, and `literature-agent.md` — same claim, same example, no
      contradiction.
- [ ] `bash -n` on all three modified shell scripts.
- [ ] Confirm `zotero-search.sh`'s argument parsing, scoring block, and exit-code behavior are
      byte-identical to their pre-change state (`git diff` shows changes only inside the comment
      block and the heredoc).
- [ ] Confirm no file under `agent-system/extensions/literature/scripts/deprecated/` other than
      `README.md` was modified — the quarantined scripts stay untouched.

**Timing**: 0.3 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**: none (audit only)

**Verification**:

- All six audit checks pass, with command output recorded in the implementation summary.
- Any check that fails blocks task completion until the underlying phase is corrected.

---

## Testing & Validation

- [ ] `bash -n` exits 0 for `zotero-search.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`.
- [ ] `zotero-search.sh --help` prints the separate-arguments warning with its worked example.
- [ ] The warning appears exactly twice in `zotero-search.sh` (header comment + heredoc).
- [ ] `agent-exploration.md` mentions `zotero-search.sh` (it previously did not) and carries the
      same warning.
- [ ] `literature-agent.md`'s Search-to-Import bullet shows a concrete multi-term example.
- [ ] `deprecated/README.md` names both `specs/zotero-index.json` and
      `specs/literature-index.json`, the 4-field consumer shape, and the `zot` / `/zotero --setup`
      dependencies.
- [ ] No `zotero-index-add` reference remains in any `.sh` under
      `agent-system/extensions/literature/` outside `deprecated/`.
- [ ] `git status --short` contains zero `.claude/` paths.
- [ ] No task-number citation in any modified file outside `specs/**`.
- [ ] `zotero-search.sh`'s executable behavior is unchanged (documentation-only diff).

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/zotero-search.sh` (modified — both USAGE copies)
- `agent-system/extensions/literature/context/project/literature/patterns/agent-exploration.md` (modified)
- `agent-system/extensions/literature/agents/literature-agent.md` (modified — outside declared `file_scope`)
- `agent-system/extensions/literature/scripts/deprecated/README.md` (modified)
- `agent-system/extensions/literature/scripts/zotero-chunk.sh` (modified — stderr hint)
- `agent-system/extensions/literature/scripts/zotero-attach-chunks.sh` (modified — stderr hint)
- `specs/994_fix_literature_tooling_landmines_and_sync_pruning/summaries/01_*-summary.md` (new,
  including the out-of-scope finding and the recommended follow-up task text)

## Rollback/Contingency

All changes are additive documentation edits to six source-store files with no runtime coupling,
so rollback is per-file and carries no dependency ordering: `git checkout -- <path>` for any
individual file after a snapshot (`bash .claude/scripts/git-snapshot.sh 994`), or revert the
phase commit. Nothing here is deployed until an extension reload runs, so an incorrect edit
cannot break a live repo before it is caught. The two stderr-hint changes in Phase 5 are the only
edits touching executable lines; if `bash -n` fails on either, revert that single file and treat
Phase 5 as a reasoned exclusion rather than blocking the rest of the task.

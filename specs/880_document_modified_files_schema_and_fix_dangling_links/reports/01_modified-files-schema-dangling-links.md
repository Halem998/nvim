# Research Report: Task #880

**Task**: 880 - Document the modified_files/files_touched schema that targeted staging depends on
**Started**: 2026-07-15T22:51:27Z
**Completed**: 2026-07-15T22:53:20Z
**Effort**: Small (documentation-only, 2 files to extend, 1 file to fix links in)
**Dependencies**: None
**Sources/Inputs**: Codebase (grep/read of all four citing documents, the schema doc targets, the consuming script, and the state-management schema)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both dangling-reference claims are VERIFIED: `.claude/context/formats/return-metadata-file.md`
  documents no `modified_files` field, and `.claude/context/formats/progress-file.md` documents
  no `files_touched` field, even though four documents point to these two files as the schema
  authority for those exact field names.
- The consuming script (`orchestrator-postflight.sh` lines 449-460) and the producing agent
  (`general-implementation-agent.md` lines 151-155, 166-168, 212-215, 425-435, 494, 538-539)
  agree unambiguously on the contract: `modified_files` is an optional top-level `string[]` in
  `.return-meta.json`, populated from `progress-file.md`'s per-objective `files_touched` arrays,
  and consumed by `jq -r '.modified_files[]? // empty'` then passed straight to `git add`.
- **Path convention is definitively repo-relative, not absolute.** The agent instructions say so
  explicitly twice ("the repo-relative path of every file `Write`/`Edit`-ed", "Append every
  repo-relative path touched") and the consuming script's own `stage_paths` array is built
  entirely from repo-relative literals (`"${task_dir}/"`, `"specs/TODO.md"`, `"specs/state.json"`,
  `$plan_file`) that `git add` is invoked against directly from the repo root — mixing an
  absolute path into that array would be inconsistent with every other entry and with how the
  script is invoked. The sibling `.orchestrator-handoff.json` schema's `files_modified` field
  (`docs/architecture/handoff-schema.md:129`, examples at :313-320) independently corroborates
  "paths ... relative to repo root" as the house convention for this class of field.
- **Directories are not part of the documented contract anywhere.** Every description and every
  worked example (both fields, all four citing documents) refers to individual file paths only
  ("path of every file Write/Edit-ed"). Recommend the new schema entries state explicitly that
  entries are individual file paths, not directory prefixes — this removes an ambiguity that
  none of the four citing documents currently resolve, rather than leaving it merely implied.
- **Empty-array behavior is already specified at the producer and consumer, just not yet in the
  schema files themselves**: `general-implementation-agent.md:430-432` says "If no files were
  touched ... write an empty array — never omit the field"; `orchestrator-postflight.sh:458-459`
  treats an empty/absent array as the trigger for a loud `WARNING: no modified_files reported`
  and falls back to the fixed task-directory staging scope (never `git add -A`).
- One citation in the task description is stale: `general-implementation-agent.md:394` does not
  currently contain a `modified_files`/`files_touched` reference (line 394 is mid-way through an
  unrelated Implementation Summary template). The real citations in that file are at lines
  151-155, 166-168, 212-215, 425-435, and 494 (the file has evidently been edited since the
  description was drafted). This does not change the substance of the finding — the field is
  still genuinely undocumented at its two claimed schema authorities — but the plan/implementer
  should not anchor an edit at line 394 specifically.
- The dangling-link claim about `neovim-integration.md` is also VERIFIED and the correct fix is
  computed: from `.claude/context/project/neovim/guides/neovim-integration.md`, the existing
  6-level-up path (`../../../../../../.claude/docs/guides/...`) resolves outside the repository
  entirely (to `/home/benjamin/.config/.claude/docs/guides/...`, which does not exist). The
  correct depth is 4 levels up, verified by `realpath -m` against the actual filesystem:
  `../../../../docs/guides/permission-configuration.md` and
  `../../../../docs/guides/user-guide.md` both resolve to files confirmed present at
  `.claude/docs/guides/`.

## Context & Scope

This is a meta task, documentation-only, with an explicit constraint of no new scripts. Scope is
three files, matching `file_scope` in state.json:
- `.claude/context/formats/return-metadata-file.md` — add `modified_files` field documentation
- `.claude/context/formats/progress-file.md` — add `files_touched` field documentation (per
  objective, inside the existing `objectives[]` schema)
- `.claude/context/project/neovim/guides/neovim-integration.md` — fix two dangling relative links

No `agent-system/` or `.opencode/` mirror copies are in `file_scope` and none should be touched;
those are separate deploy trees with their own (out-of-scope) copies of these same files.

## Findings

### Codebase Patterns

**Confirmed absence of the fields in their cited schema authorities**:
```
grep -c modified_files .claude/context/formats/return-metadata-file.md  -> 0
grep -c files_touched  .claude/context/formats/progress-file.md         -> 0
```

**Confirmed citing documents and their exact current line numbers**:
- `.claude/context/standards/git-staging-scope.md:133-134` (note: this file lives at
  `context/standards/`, not `context/patterns/` as an early guess might suggest — verified path)
  — cites both files as "Related Documentation" for the `modified_files`/`files_touched` fields,
  and also documents the fields inline at lines 42-46 (the fullest inline description of the
  contract that exists anywhere today, but not in the two files it points readers to).
- `.claude/skills/skill-git-workflow/SKILL.md:106` and `:115` — both citations verified exactly
  at those line numbers.
- `.claude/agents/general-implementation-agent.md` — cites the two schema files repeatedly
  (lines 153, 429-430, 494) but NOT at line 394 as the task description states; that citation
  appears to be stale relative to the current file state.

**Producer mechanism** (`general-implementation-agent.md`):
- Step 2 of the per-step protocol (lines 147-155): after each `Write`/`Edit`, the agent appends
  the repo-relative path to the *current objective's* `files_touched` list in the phase's
  progress file.
- Step 4 (lines 161-168): on completing an objective, the progress file's
  `objectives[].files_touched` array is updated additively (never overwritten).
- Stage 6-modified-files (lines 425-435): before writing final metadata, the agent sums every
  phase's every objective's `files_touched` array into one flat, deduplicated list — this
  becomes the `modified_files: string[]` field written to `.return-meta.json` at Stage 7 (line
  494). Empty is explicit and required, never omission.
- The per-objective green-commit block (lines 209-218) reads a single objective's
  `files_touched` directly via `jq -r '.objectives[] | select(.id == {objective_id}) |
  .files_touched[]? // empty'` for the finer-grained per-substep commit — the same array feeds
  both the per-substep commit and, summed across all objectives, the final `modified_files`.

**Consumer mechanism** (`orchestrator-postflight.sh`, Stage 9, lines 429-474):
```bash
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
# implement only, appended:
stage_paths+=("$plan_file")
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f"); modified_files_count=$((modified_files_count + 1))
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
if [ "$modified_files_count" -eq 0 ]; then
  echo "[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually." >&2
fi
git add "${stage_paths[@]}"
```
This is the load-bearing consumption site referenced in the task description ("consumes them via
`jq -r '.modified_files[]? // empty'` and passes them to `git add`") — verified byte-for-byte
except the line numbers shifted slightly (449-460 in the current file, not exactly what a caller
might guess from an older version).

**Prospective/retrospective contrast already exists, one level removed from where it's needed**:
`.claude/context/reference/state-management-schema.md:220-231` (not 220-223 exactly — the
relevant "File Scope Field" table starts at 231 and the contrast paragraph is at 240-247) already
states the exact distinction the task asks to be made explicit in the new schema docs:
`file_scope` (state.json, prospective, task-creation time, lock-overlap detection) versus
`modified_files`/`files_touched` (retrospective, implementation time, self-reported for git
staging) — "The two fields are complementary and are never merged or reconciled against each
other." This paragraph can be linked to, or a condensed version of it repeated, from the new
schema entries.

### External Resources

Not applicable — this is a pure internal documentation-consistency task with no external
dependency.

### Recommendations

1. **`return-metadata-file.md`**: Add a `### modified_files (optional)` subsection alongside the
   existing `### memory_candidates (optional)` / `### reflection (optional)` sections (i.e.
   after `reflection`, before `errors`, matching the field's actual position in the worked
   "Implementation Success" example at lines 319-366 — note that example JSON does NOT currently
   include a `modified_files` key at all, which is itself a second small gap worth closing in
   the same edit for consistency). Content to include:
   - Type: optional `string[]` at the top level of `.return-meta.json`.
   - When populated: only meaningful for `implement`-operation agents (`general-implementation-agent`
     and other implementation agents); absent/unused for research and plan operations.
   - Path form: **repo-relative** paths (relative to the repository root), matching the
     convention used everywhere else `git add` is invoked in the postflight pipeline. State this
     explicitly — do not leave it implied.
   - Entries are individual file paths, not directory prefixes.
   - Empty-array requirement: if no files were touched, write `"modified_files": []` — never
     omit the field. Absence or emptiness triggers a non-fatal fallback in the consumer (staging
     only the fixed task-directory scope) plus a loud stderr warning; it does not fail the run.
   - Source: the flattened, deduplicated union of every phase's every objective's
     `files_touched` array from that task's progress files (see `progress-file.md`).
   - Cross-reference `.claude/context/standards/git-staging-scope.md` (the fullest existing
     narrative description of the contract) and the new `progress-file.md` entry below.
   - Add the prospective/retrospective contrast, either inline or via a pointer to
     `state-management-schema.md`'s existing "File Scope Field" contrast paragraph — do not let
     a reader conflate `modified_files` with state.json's `file_scope`.

2. **`progress-file.md`**: Add a `files_touched` row to the existing `objectives[]` field table
   (currently at lines 108-116, columns `id`/`description`/`status`/`note`) as an additional
   optional column/field: array of repo-relative file path strings, per-objective, additive
   (never overwritten across updates to the same objective — this additivity is already stated
   at `general-implementation-agent.md:166-168` and should be restated here as the schema's own
   authoritative statement rather than only living in the consumer's instructions). Also update
   the worked JSON schema examples (the skeleton at lines 40-79 and the full example at lines
   198-244) to include a `files_touched` array per objective, and note in prose that this is the
   per-objective accumulation mechanism that Stage 6-modified-files in the implementation agent
   sums into the top-level `modified_files` field of `.return-meta.json` — cross-reference
   `return-metadata-file.md`.

3. **`neovim-integration.md`**: Replace both dangling links (lines 333-334) —
   - `[Permission Configuration](../../../../../../.claude/docs/guides/permission-configuration.md)`
     → `[Permission Configuration](../../../../docs/guides/permission-configuration.md)`
   - `[User Guide](../../../../../../.claude/docs/guides/user-guide.md)`
     → `[User Guide](../../../../docs/guides/user-guide.md)`
   Both corrected paths were verified present on disk via `realpath -m` + `test -f` from the
   source file's own directory.

## Decisions

- Scope confirmed to the three `file_scope` paths only; no edits to `agent-system/` or
  `.opencode/` mirror trees, which are separate deploy targets outside this task's declared
  scope.
- Path convention for the new schema text: **repo-relative**, stated explicitly rather than left
  implicit, per direct textual evidence in `general-implementation-agent.md` and structural
  evidence in `orchestrator-postflight.sh`'s `stage_paths` construction.
- Directories: explicitly documented as **not permitted** — entries must be individual file
  paths — since no existing description or example ever uses a directory entry for either field,
  and leaving this unstated is exactly the kind of ambiguity this task exists to close.
- Empty-array behavior: explicitly documented as **write `[]`, never omit**, mirroring the
  producer's existing instruction and the consumer's existing fallback/warning behavior.

## Risks & Mitigations

- **Risk**: A future editor updates `general-implementation-agent.md` again and the line numbers
  in `git-staging-scope.md`'s "Related Documentation" list (currently 133-134, unaffected by this
  task) or in the new schema sections drift again. **Mitigation**: none required by this task's
  constraints (no-new-scripts, documentation-only) beyond writing content that doesn't hardcode
  brittle line-number citations to `general-implementation-agent.md` inside the two schema files
  being edited — cite section names/field names instead of line numbers.
- **Risk**: Someone conflates the new `modified_files`/`files_touched` documentation with
  state.json's `file_scope`. **Mitigation**: explicit contrast paragraph/pointer, per
  Recommendation 1 above, addresses this directly per the task's own instruction.

## Context Extension Recommendations

None (meta task).

## Appendix

### Search/verification commands used

```bash
grep -c modified_files .claude/context/formats/return-metadata-file.md   # -> 0
grep -c files_touched  .claude/context/formats/progress-file.md          # -> 0
find . -iname "git-staging-scope.md"                                     # located at context/standards/
grep -n "modified_files\|files_touched" .claude/scripts/orchestrator-postflight.sh
grep -n "modified_files\|files_touched" .claude/agents/general-implementation-agent.md
sed -n '200,247p' .claude/context/reference/state-management-schema.md
realpath -m "../../../../docs/guides/permission-configuration.md"   # from neovim-integration.md's dir
realpath -m "../../../../docs/guides/user-guide.md"
```

### Files read in full or in relevant part

- `.claude/context/standards/git-staging-scope.md`
- `.claude/skills/skill-git-workflow/SKILL.md`
- `.claude/agents/general-implementation-agent.md` (lines 140-220, 385-540)
- `.claude/scripts/orchestrator-postflight.sh` (lines 300-475)
- `.claude/context/formats/return-metadata-file.md` (full)
- `.claude/context/formats/progress-file.md` (full)
- `.claude/context/reference/state-management-schema.md` (lines 200-247)
- `.claude/context/project/neovim/guides/neovim-integration.md` (lines 325-335)
- `.claude/docs/architecture/handoff-schema.md` (full, for the sibling `files_modified`
  repo-relative convention and for the handoff artifact this report's task must also produce)

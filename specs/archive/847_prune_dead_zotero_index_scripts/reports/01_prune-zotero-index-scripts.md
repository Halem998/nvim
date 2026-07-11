# Research Report: Task #847

**Task**: 847 - Prune dead-code zotero index scripts (zotero-index-add.sh, zotero-index-remove.sh)
**Started**: 2026-07-10T00:00:00Z
**Completed**: 2026-07-10T00:00:00Z
**Effort**: Small (2 files to quarantine, 1 manifest edit, 4 doc files to reconcile)
**Dependencies**: Task #844 (defer-and-document research, prior finding)
**Sources/Inputs**: Codebase grep (deployed `.claude/` + extension source), `check-extension-docs.sh` source read, live baseline run of `check-extension-docs.sh`, task #844 artifacts
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **RE-VERIFICATION RESULT: CONFIRMED — zero live callers.** Exhaustive grep of deployed `.claude/` and the extension source found no invocation (execution) of `zotero-index-add.sh` or `zotero-index-remove.sh` anywhere. All hits are: (a) the scripts' own internal usage/error text, (b) two `echo "Run: zotero-index-add.sh $KEY" >&2` hint strings (printed suggestions to a human, not invocations), (c) doc/comment mentions, and (d) the `manifest.json` `provides.scripts` declaration. **Recommendation: proceed with removal**, not STOP.
- Both scripts exist **only** in extension source (`.claude/extensions/literature/scripts/`) — confirmed absent from deployed `.claude/scripts/` (that directory has no `zotero-index-*` files at all). No deployed-copy cleanup is needed.
- Both scripts **are** listed in `.claude/extensions/literature/manifest.json` `provides.scripts` (lines 36–37, sandwiched between `zotero-attach-chunks.sh` and `literature-briefing.sh`) — must be removed from the array as part of this task.
- **Critical scope gap found**: the task's stated `file_scope` (manifest.json + README.md + the 2 scripts) is **incomplete**. Two additional files not in `file_scope` — `.claude/extensions/literature/EXTENSION.md` (lines 81–82) and `.claude/extensions/literature/agents/literature-agent.md` (lines 172–173) — also list the literal `zotero-index-add.sh` / `zotero-index-remove.sh` filenames in their "Available Scripts" tables. Per `check-extension-docs.sh` Rule E (`check_referenced_scripts_declared`), **any** `.sh`-suffixed filename token appearing in `README.md`, `EXTENSION.md`, `agents/*.md`, or `skills/*/SKILL.md` that is not also present in some `provides.scripts` array trips a `FAIL`. Once the two scripts are dropped from `manifest.json provides.scripts`, leaving the literal filenames untouched in these two additional files **will regress `check-extension-docs.sh` from PASS to FAIL** — a live baseline run today confirms literature currently PASSes. Implementation must either update/remove the filename mentions in `EXTENSION.md` and `literature-agent.md` too, or de-litearlize them (drop the `.sh` suffix from the doc text) so the regex no longer matches.
- `skill-literature/SKILL.md` line 422 also contains a literal `zotero-index-add.sh` mention (inside a comment describing an author-name-formatting heuristic) — this file **is** scanned by Rule E (`skills/*/SKILL.md`) and must also be checked/fixed, though it does not need full removal (it can be reworded to avoid the literal `.sh` token, e.g. "the pattern the former zotero-index-add script produced").
- No pre-existing repo convention for `.claude/`-scoped script quarantine was found. The only quarantine-style directory convention in this repo is `lua/neotex/deprecated/` (for Neovim Lua plugin configs, an unrelated subsystem, but it does establish the pattern of "move to a `deprecated/` subdirectory + document in a README, don't delete"). Recommend mirroring that pattern locally: create `.claude/extensions/literature/scripts/deprecated/` and move both scripts there unchanged (byte-identical, preserving git history via `git mv`), OR the simpler `.removed-<UTC>` filename-suffix rename in place — both satisfy QUARANTINE-NEVER-DELETE; the `deprecated/` subdirectory is closer to the one real precedent in this repo. Either way, the renamed/moved script must **not** remain matched by the `[A-Za-z0-9_-]+\.(sh|sql)\b` regex under an *undeclared* name in any doc surface Rule E scans (moving to a subdirectory sidesteps this cleanly since the doc mentions are removed entirely rather than rewritten around).
- The other five deferred zotero scripts (`zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`) must be left untouched — they are blocked on the external `zot` CLI or superseded-but-not-dead (task 758 design), a different disposition than the two pure-dead-code scripts in scope here. Note `zotero-chunk.sh` and `zotero-attach-chunks.sh` each contain a comment/hint line reading `echo "Run: zotero-index-add.sh $KEY" >&2` — these are stderr hint strings only (not invocations) and are inside `.sh` files, which Rule E does not scan, so they do not block the check-extension-docs gate. They should be left as-is (or optionally reworded in a future task) since editing them is outside this task's scope, but flagging so an implementer isn't surprised if a broad text-search still turns them up after the quarantine.

## Context & Scope

Task #844 confirmed `zotero-index-add.sh` and `zotero-index-remove.sh` are dead code: `skill-literature/SKILL.md` reimplements identical "add/remove entry in `specs/literature-index.json`" logic inline via `jq` (add logic ~line 2154-2170, remove logic ~line 2180-2189, per task #844's report), so the two scripts have no live caller. Task #844 explicitly deferred pruning ("DEFER-AND-DOCUMENT" — see `specs/844_finish_or_defer_zotero_cite_install/reports/01_install-status-research.md` lines 97-98, 110, 118) and instead documented the two scripts as "quarantined, not deleted" prune candidates in `.claude/extensions/literature/README.md`. Task #847 is the follow-up cleanup task: re-verify zero live callers, then perform the quarantine (never hard-delete) and keep the manifest/doc surface consistent so `check-extension-docs.sh` still exits 0.

This report is RESEARCH ONLY — no files were modified. Scope was: (1) re-verify zero live callers via exhaustive grep, (2) confirm deployed-vs-source-only location, (3) confirm manifest declaration, (4) locate the exact README "Deployment Status" section to update, (5) determine the quarantine convention to use, (6) confirm the other five deferred zotero scripts are out of scope and must be untouched.

## Findings

### Codebase Patterns

**1. Exhaustive grep — zero live callers confirmed.**

`grep -rn "zotero-index-add" .claude/` and `grep -rn "zotero-index-remove" .claude/` (run against the full deployed `.claude/` tree, which includes the extension source at `.claude/extensions/literature/`) produced these hit categories, with no exceptions:

| File | Line(s) | Nature of reference |
|------|---------|---------------------|
| `.claude/extensions/literature/scripts/zotero-index-add.sh` | 2,7,49,50,58,67,73,83,89 | The script's own header/usage/error text (self-reference) |
| `.claude/extensions/literature/scripts/zotero-index-remove.sh` | 2,7,45,46,54,63,69,80 | The script's own header/usage/error text (self-reference) |
| `.claude/extensions/literature/scripts/zotero-chunk.sh` | 146 | `echo "Run: zotero-index-add.sh $KEY" >&2` — a printed hint string suggesting the *user* run the script manually; **not an invocation** (no `$(...)`, no direct call) |
| `.claude/extensions/literature/scripts/zotero-attach-chunks.sh` | 126 | Same pattern, same hint string, same non-invocation status |
| `.claude/scripts/literature-normalize-authors.sh` | 9 | Comment citing `zotero-index-add.sh:142-148` as the source of a formatting convention being mirrored — documentation only, not a call |
| `.claude/extensions/literature/scripts/literature-normalize-authors.sh` | 9 | Same comment (extension-source copy of the same file) |
| `.claude/extensions/literature/skills/skill-literature/SKILL.md` | 422 | Comment inside a bash heredoc referencing the historical author-formatting pattern "zotero-index-add.sh itself produces" — documentation only |
| `.claude/extensions/literature/README.md` | 147,148,168,169 | "Available Scripts" table row + "Deployment Status" inactive-artifacts table row, for each script |
| `.claude/extensions/literature/EXTENSION.md` | 81,82 | "Available Scripts" table row for each script |
| `.claude/extensions/literature/agents/literature-agent.md` | 172,173 | "Available Scripts" table row for each script |
| `.claude/extensions/literature/manifest.json` | 36,37 | `provides.scripts` array declaration |

No skill, command, agent-invocation code path, or `Bash(...)` call anywhere in the codebase actually executes `zotero-index-add.sh` or `zotero-index-remove.sh`. **Verdict: CONFIRMED zero live callers — safe to proceed with quarantine/removal, not STOP.**

A repo-wide search (not scoped to `.claude/`) additionally surfaced only `specs/` task-artifact mentions (task #844's own reports/summaries, task #841's drift audit, task #758's infra reports, and this task's own `TODO.md`/`state.json` entries) — all historical/planning documentation, none of which are live code paths.

**2. Deployed vs. extension-source-only — confirmed extension-source-only.**

`ls .claude/scripts/` shows the deployed zotero surface is exactly: `zotero-export-status.sh`, `zotero-generate-export.sh`, `zotero-resolve-pdf.sh`, `zotero-resolve-sqlite-path.sh`, `zotero-search.sh`, and `.zotero-title-sim.py`. **No `zotero-index-add.sh` or `zotero-index-remove.sh` present in deployed `.claude/scripts/`.** This matches the README's own "Deployment Status" record: only `cite-extract.sh` + the `/cite` trio + `zotero-search.sh` were ever deployed byte-for-byte from extension source to `.claude/scripts/`/`skills/`/`commands/`; the remaining seven zotero scripts (including these two) are intentionally source-only. **No deployed-copy cleanup action is required** — quarantine only needs to touch the extension-source copies.

**3. `manifest.json provides.scripts` — confirmed both listed.**

`.claude/extensions/literature/manifest.json` lines 25-42 (the `provides.scripts` array) lists both `"zotero-index-add.sh"` (line 36) and `"zotero-index-remove.sh"` (line 37), positioned between `"zotero-attach-chunks.sh"` and `"literature-briefing.sh"`. These entries must be removed from the array as part of implementation. This is what keeps `check-extension-docs.sh`'s drift guard (`check_deployed_script_drift`, Rule F) happy — Rule F only fires when both a source copy AND a deployed copy exist and diverge; with the manifest entry gone, the quarantined source file is no longer part of `provides.scripts` at all, so Rule F has nothing to check for it (consistent with the "seven zotero scripts... absent from `.claude/scripts/`... skips scripts whose deployed copy is absent" behavior already documented in the README for the *other* five deferred scripts, which stay in `provides.scripts` while undeployed).

**4. Exact 'Deployment Status' note to update in README.md.**

`.claude/extensions/literature/README.md` contains two relevant tables:

- **"Available Scripts" table** (~lines 143-152): a row `| \`zotero-index-add.sh\` | Add item to per-repo \`specs/literature-index.json\` | No — inactive, see below |` and the mirrored row for `zotero-index-remove.sh`.
- **"Deployment Status (task 844)" section → "Inactive" table** (~lines 160-176): the authoritative record. The two rows to change are exactly:
  ```
  | `zotero-index-add.sh` | Superseded — dead code; add-to-index logic is reimplemented inline via `jq` in `skill-literature/SKILL.md`. Prune candidate for a future task; quarantined, not deleted. |
  | `zotero-index-remove.sh` | Superseded — same as above (inline `jq` remove logic in `skill-literature/SKILL.md`). Prune candidate for a future task; quarantined, not deleted. |
  ```
  These are the rows task #844 added and that task #847 should move from "deferred/prune-candidate" to "removed" phrasing (e.g., updating the "Reason" text to record the quarantine location/date and that task #847 completed the prune). The paragraph immediately below the inactive table (~lines 176-181) currently states "Seven zotero scripts above remain declared in `manifest.json` provides.scripts but are absent from `.claude/scripts/`" — this sentence's "seven" count must drop to "five" once these two are removed from `provides.scripts`, or the sentence must otherwise be reworded to avoid an inaccurate count.

**5. Quarantine convention — no `.claude`-scoped precedent; one analogous repo-wide precedent found.**

Searched for `.removed-*`, `.deprecated-*`, and any `deprecated/`/`archive/` directories under `.claude/` — none exist. The only quarantine-style directory in the whole repo is `lua/neotex/deprecated/` (referenced in the top-level `CLAUDE.md`'s "Deprecated features moved to `lua/neotex/deprecated/`"), which contains a `README.md` documenting purpose, contents, "Migration Status" (not loaded), a "Removal Policy" (may be hard-deleted after >6 months with no migration need), and cross-links. This is a different subsystem (Neovim Lua plugin configs) but is the repo's only existing model for "prune candidate — quarantine, don't delete, document why." Task #847's own description offers both options explicitly ("rename with a `.removed-<UTC>` suffix or move to a `deprecated/` dir per repo convention"). Given the `lua/neotex/deprecated/` precedent leans toward a subdirectory-with-README approach and that a subdirectory move also cleanly satisfies the Rule E doc-drift concern (finding 6 below, since a moved file's old doc mentions are simply removed rather than needing careful literal-string rewriting), recommend: create `.claude/extensions/literature/scripts/deprecated/`, `git mv` both scripts into it unchanged, and add a brief note (either a small `deprecated/README.md` mirroring the Lua one's format, or a paragraph in the main `README.md`'s Deployment Status section) recording what was pruned, when, and why — satisfying QUARANTINE-NEVER-DELETE without leaving stale filename tokens scattered across doc surfaces that Rule E scans. The `.removed-<UTC>` suffix rename-in-place is an acceptable alternative if the implementer prefers to avoid introducing a new subdirectory, but is slightly more error-prone with Rule E as analyzed below (finding 6) since it is easier to accidentally leave a literal `.sh`-suffixed mention in a doc table row that no longer resolves against `provides.scripts`.

**6. Rule E interaction — critical for implementation correctness (beyond stated `file_scope`).**

Live-ran `bash .claude/scripts/check-extension-docs.sh` as a baseline: literature currently `PASS`, and overall `PASS: all extensions OK`. Reading `check_referenced_scripts_declared()` (Rule E, `.claude/scripts/check-extension-docs.sh` lines 370-434) shows it: (1) extracts every `[A-Za-z0-9_-]+\.(sh|sql)` token from `$ext_path/commands/*.md`, `$ext_path/skills/*/SKILL.md`, `$ext_path/agents/*.md`, `$ext_path/README.md`, and `$ext_path/EXTENSION.md` (URLs stripped first); (2) excludes tokens declared in the core extension's `provides.scripts`/`provides.hooks`; (3) excludes tokens declared in **any** extension's `provides.scripts` (confirmed via direct check: only `literature/manifest.json` declares `zotero-index-add.sh`/`zotero-index-remove.sh` — no other extension manifest does); (4) excludes tokens in the extension's own `provides.hooks`; (5) `fail`s on anything left over.

Once `zotero-index-add.sh`/`zotero-index-remove.sh` are removed from `literature/manifest.json` `provides.scripts`, **any surviving literal mention of these two filenames (with the `.sh` suffix) in `README.md`, `EXTENSION.md`, `agents/literature-agent.md`, or `skills/skill-literature/SKILL.md` will trip Rule E and fail `check-extension-docs.sh`.** Confirmed literal-token locations that will need to be addressed:
- `README.md` — 4 occurrences (2 tables × 2 scripts), already in task's `file_scope`.
- `EXTENSION.md` lines 81-82 — **not in task's `file_scope`** — same "Available Scripts" table pattern as `README.md`.
- `agents/literature-agent.md` lines 172-173 — **not in task's `file_scope`** — same table pattern.
- `skills/skill-literature/SKILL.md` line 422 — **not in task's `file_scope`** — a single comment mention, reworded rather than deleted (the surrounding logic/comment is still functionally relevant, just needs to not say "`.sh`").

The task's stated VERIFICATION criterion ("`check-extension-docs.sh` still exits 0 with literature PASS") cannot be satisfied by editing only `manifest.json` and `README.md` as `file_scope` states — `EXTENSION.md`, `agents/literature-agent.md`, and `skills/skill-literature/SKILL.md` must also be touched (either removing the table rows / rewording the comment, or converting `\`zotero-index-add.sh\`` to a non-`.sh`-suffixed mention like `\`zotero-index-add\` (removed, see README)`). Recommend the implementation plan explicitly widen `file_scope` to include these three files, or the phase-verification step must run `check-extension-docs.sh` before considering the phase done — a plain "remove from README + manifest" pass will regress the drift-guard PASS.

### External Resources

Not applicable — this is a pure internal-consistency/dead-code-removal task; no external documentation was consulted beyond the local codebase and the task-844 research artifacts already produced within this repo.

### Recommendations

1. Re-verification gate: PASS — proceed with removal (do not STOP).
2. Quarantine method: `git mv` both scripts into a new `.claude/extensions/literature/scripts/deprecated/` subdirectory (byte-identical, history-preserving), mirroring the repo's one existing "prune-candidate quarantine" precedent (`lua/neotex/deprecated/`). Document the move (what/why/when) in the literature `README.md` Deployment Status section, replacing the "quarantined, not deleted" phrasing with a pointer to the new location.
3. Remove both entries from `.claude/extensions/literature/manifest.json` `provides.scripts` (lines 36-37).
4. Update `README.md`'s "Available Scripts" and "Deployment Status → Inactive" tables (4 row edits) — move from "deferred"/"prune candidate" language to "removed (quarantined in `scripts/deprecated/`, see task #847)", and fix the "Seven zotero scripts... remain declared" sentence's count (→ five).
5. **Widen scope beyond the stated `file_scope`**: also update `EXTENSION.md` (lines 81-82) and `agents/literature-agent.md` (lines 172-173) to drop or reword the two table rows, and reword `skills/skill-literature/SKILL.md` line 422's comment to avoid the literal `zotero-index-add.sh` token — all four are required to keep `check-extension-docs.sh` Rule E passing.
6. Leave `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh` entirely untouched (including their `echo "Run: zotero-index-add.sh $KEY"` hint lines — those are outside this task's file_scope and are in `.sh` files Rule E does not scan, so they do not block the gate; a future task may choose to update the hint text since the target script will have moved, but that is optional polish, not correctness-required).
7. After implementation, run `bash .claude/scripts/check-extension-docs.sh` and confirm `literature PASS` / `PASS: all extensions OK` (same command used for this report's baseline) as the concrete verification step.

## Decisions

- **Do not STOP** — re-verification found zero live callers; the task's own STOP condition is not triggered.
- **Quarantine, not delete** — both scripts must be preserved (renamed/moved), consistent with QUARANTINE-NEVER-DELETE and task #844's original disposition.
- **Recommend `scripts/deprecated/` subdirectory** over `.removed-<UTC>` suffix rename, as the closer match to this repo's one existing quarantine precedent and the cleaner fit with Rule E (doc mentions removed rather than rewritten in place).
- **Scope must expand beyond the stated `file_scope`** to include `EXTENSION.md`, `agents/literature-agent.md`, and `skills/skill-literature/SKILL.md`, or `check-extension-docs.sh`'s Rule E will fail post-implementation.

## Risks & Mitigations

- **Risk**: Implementing only against the literal stated `file_scope` (2 scripts + manifest.json + README.md) will pass a naive read of the task but will regress `check-extension-docs.sh` from PASS to FAIL for the `literature` extension. **Mitigation**: this report documents the exact 3 additional files/line numbers; the plan should include them explicitly, and the verification step must actually run `check-extension-docs.sh`, not just visually inspect README.md.
- **Risk**: A blind find-and-delete of every "zotero-index-add"/"zotero-index-remove" string could accidentally touch the `echo "Run: zotero-index-add.sh $KEY"` hint lines in `zotero-chunk.sh`/`zotero-attach-chunks.sh`, which are out of scope (those scripts are untouched deferred scripts, not part of this prune). **Mitigation**: scope any automated edit to the specific line-numbered locations identified in this report; leave those two `.sh`-file hint lines alone (or defer their update to whichever future task touches the chunk/attach scripts).
- **Risk**: Moving files into a brand-new `scripts/deprecated/` subdirectory is itself a small manifest/doc-surface change (a new directory doesn't need a `provides.scripts` entry since nothing there is "provided," but ensure no other check assumes all files under `scripts/` are flat-deployable). **Mitigation**: `check_deployed_script_drift`/Rule F and Rule E only iterate `provides.scripts` array entries and specific doc-file globs — neither recursively globs `scripts/`, so a new subdirectory is safe; confirmed no `scripts/*` recursive-glob logic exists in `check-extension-docs.sh` (only `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md`, `EXTENSION.md` are globbed for Rule E, and `provides.scripts` is manifest-array-driven for Rule F).

## Context Extension Recommendations

- **Topic**: `.claude/`-internal script quarantine convention.
- **Gap**: No documented convention exists (in `.claude/context/` or `.claude/docs/`) for how to quarantine a dead script within `.claude/extensions/*/scripts/` — the only precedent is the unrelated `lua/neotex/deprecated/` pattern for Neovim plugin configs. This task had to reason about that precedent by analogy.
- **Recommendation**: once this task (or a similar future prune) establishes the `scripts/deprecated/` subdirectory pattern in practice, consider adding a short pattern doc (e.g. `.claude/context/patterns/script-quarantine.md`) documenting the convention (subdirectory name, README/note requirement, interaction with `check-extension-docs.sh` Rule E/F) so future prune tasks don't have to re-derive it from first principles.

## Appendix

### Search queries used

- `grep -rn "zotero-index-add" .claude/`
- `grep -rn "zotero-index-remove" .claude/`
- `grep -rln "zotero-index-add\|zotero-index-remove" .` (repo-wide, excluding `.git/`)
- `python3 -c "..."` reading `manifest.json` `provides.scripts` array (literature and all sibling extensions)
- `ls .claude/scripts/ | grep -i zotero` and full `ls .claude/scripts/`
- `sed -n` targeted reads of `README.md` (130-215), `EXTENSION.md` (75-85), `agents/literature-agent.md` (165-178), `manifest.json` (25-42), `zotero-chunk.sh` (140-150), `zotero-attach-chunks.sh` (120-130), `literature-normalize-authors.sh` (1-15), `skill-literature/SKILL.md` (415-428)
- `find . -type d -iname "deprecated" -o -type d -iname "archive"` (repo-wide quarantine-convention search)
- `bash .claude/scripts/check-extension-docs.sh` (live baseline run — literature PASS confirmed pre-change)
- `Read` of `.claude/scripts/check-extension-docs.sh` lines 360-434 (Rule E: `check_referenced_scripts_declared`)

### References

- `specs/844_finish_or_defer_zotero_cite_install/reports/01_install-status-research.md` (lines 17, 42, 59-60, 79-81, 97-98, 110, 118 — original DEFER-AND-DOCUMENT finding)
- `specs/844_finish_or_defer_zotero_cite_install/summaries/01_install-summary.md` (lines 12, 42-44, 92-93 — confirms defer disposition and names this exact follow-up)
- `.claude/extensions/literature/README.md` lines 143-181 (Available Scripts table + Deployment Status section)
- `.claude/extensions/literature/manifest.json` lines 25-42 (`provides.scripts`)
- `.claude/extensions/literature/EXTENSION.md` lines 75-85
- `.claude/extensions/literature/agents/literature-agent.md` lines 165-178
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` line 422
- `.claude/scripts/check-extension-docs.sh` lines 104-135 (Rule F: `check_deployed_script_drift`), lines 364-434 (Rule E: `check_referenced_scripts_declared`)
- `lua/neotex/deprecated/README.md` (repo's one existing quarantine-directory precedent)
- `specs/TODO.md` task 847 entry (REQUIRED WORK / CONSTRAINTS / VERIFICATION text)

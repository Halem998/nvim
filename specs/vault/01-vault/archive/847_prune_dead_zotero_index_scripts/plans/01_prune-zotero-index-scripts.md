# Implementation Plan: Prune dead zotero index scripts

- **Task**: 847 - Prune dead-code zotero index scripts (zotero-index-add.sh, zotero-index-remove.sh)
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task #844 (defer-and-document; disposition source)
- **Research Inputs**: reports/01_prune-zotero-index-scripts.md
- **Artifacts**: plans/01_prune-zotero-index-scripts.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

Prune two confirmed dead-code scripts — `zotero-index-add.sh` and `zotero-index-remove.sh` —
from `.claude/extensions/literature/`, using a QUARANTINE-NEVER-DELETE posture. Research
(report 01) re-verified **zero live callers** (safe to proceed, not STOP); both scripts exist
only in extension source (never deployed to `.claude/scripts/`) and are declared in
`manifest.json` `provides.scripts` (lines 36-37). The prune moves both scripts into a new
`scripts/deprecated/` subdirectory via `git mv` (mirroring the repo's only quarantine
precedent, `lua/neotex/deprecated/`), removes the two manifest entries, and reconciles every
doc surface that mentions the filenames. **Definition of done**: no live reference to the two
scripts; `manifest.json` + `README.md` + `EXTENSION.md` + `literature-agent.md` +
`skill-literature/SKILL.md` updated consistently; `check-extension-docs.sh` exits 0 with
`literature PASS`; both quarantined files still exist on disk (not hard-deleted).

### Research Integration

Report 01 findings integrated into this plan:
- **Zero live callers CONFIRMED** — proceed with quarantine (Recommendation 1, Decision "Do not STOP").
- **Quarantine convention** — `git mv` into new `scripts/deprecated/` subdirectory, NOT a
  `.removed-<UTC>` suffix rename (Finding 5, Recommendation 2, Decision).
- **Critical scope widening** — the task's original `file_scope` (2 scripts + manifest.json +
  README.md) is incomplete. `check-extension-docs.sh` Rule E scans `README.md`, `EXTENSION.md`,
  `agents/*.md`, and `skills/*/SKILL.md` for any `[A-Za-z0-9_-]+\.(sh|sql)` token and FAILs if
  the token is not declared in some `provides.scripts` array. Once the manifest entries are
  removed, three additional files with literal `.sh` mentions must be cleaned or Rule E
  regresses from PASS to FAIL (Findings 6, Recommendation 5): `EXTENSION.md` (lines 81-82),
  `agents/literature-agent.md` (lines 172-173), `skills/skill-literature/SKILL.md` (line 422).
- **Leave the other five deferred zotero scripts untouched** — `zotero-read.sh`,
  `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`
  (Recommendation 6). In particular, do NOT edit the `echo "Run: zotero-index-add.sh $KEY"`
  hint lines in `zotero-chunk.sh` (line 146) and `zotero-attach-chunks.sh` (line 126) — those
  are stderr hint strings inside `.sh` files, which Rule E does not scan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task; roadmap flag not set.

## Goals & Non-Goals

**Goals**:
- Quarantine both dead scripts into `.claude/extensions/literature/scripts/deprecated/` via
  `git mv` (byte-identical, history-preserving), never hard-deleting them.
- Remove both entries from `manifest.json` `provides.scripts` (lines 36-37).
- Update `README.md` "Available Scripts" + "Deployment Status → Inactive" rows from
  "deferred / prune candidate" to "removed (quarantined in `scripts/deprecated/`, task #847)",
  and fix the "Seven zotero scripts... remain declared" count sentence (seven -> five).
- Clean the three additional doc surfaces (`EXTENSION.md`, `literature-agent.md`,
  `skill-literature/SKILL.md`) so no undeclared `.sh` token survives Rule E.
- Keep `check-extension-docs.sh` at `literature PASS` / `PASS: all extensions OK`.

**Non-Goals**:
- Touching the other five deferred zotero scripts or their `echo "Run: ..."` hint lines.
- Hard-deleting the two scripts (explicitly prohibited by QUARANTINE-NEVER-DELETE).
- Creating a new reusable `.claude/context/patterns/script-quarantine.md` doc (flagged by
  research as a future Context Extension recommendation, out of scope here).
- Any deployed-copy cleanup in `.claude/scripts/` (the two scripts were never deployed there).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing only manifest.json + README.md (naive file_scope) regresses Rule E from PASS to FAIL | H | H | Phase 3 explicitly cleans all four doc surfaces; Phase 4 runs `check-extension-docs.sh` as the gate, not visual inspection |
| Blind find/replace touches out-of-scope `echo "Run: zotero-index-add.sh"` hint lines in zotero-chunk.sh / zotero-attach-chunks.sh | M | M | Scope every edit to the exact line-numbered locations from report 01; never run a repo-wide sed |
| Hard-deleting instead of quarantining | H | L | Use `git mv` (never `rm`); Phase 4 verifies both files exist under `scripts/deprecated/` |
| README count sentence left saying "seven" after removing two from provides.scripts | L | M | Phase 3 explicitly updates the count sentence to "five" |
| New `scripts/deprecated/` subdirectory triggers an unexpected check | L | L | Report 01 Finding + Risk confirm no recursive `scripts/*` glob exists in check-extension-docs.sh; Phase 4 run confirms empirically |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Quarantine both scripts into scripts/deprecated/ [COMPLETED]

- **Goal:** Move `zotero-index-add.sh` and `zotero-index-remove.sh` out of the active
  `scripts/` directory and into a quarantine subdirectory, preserving git history and file
  bytes.
- **Tasks:**
  - [x] `mkdir -p .claude/extensions/literature/scripts/deprecated/` *(completed)*
  - [x] `git mv .claude/extensions/literature/scripts/zotero-index-add.sh .claude/extensions/literature/scripts/deprecated/zotero-index-add.sh` *(completed)*
  - [x] `git mv .claude/extensions/literature/scripts/zotero-index-remove.sh .claude/extensions/literature/scripts/deprecated/zotero-index-remove.sh` *(completed)*
  - [x] (Optional) add a short `scripts/deprecated/README.md` noting what was quarantined,
        when (task #847), and why (dead code; inline `jq` in SKILL.md supersedes them),
        mirroring `lua/neotex/deprecated/README.md` format. *(completed)*
- **Timing:** ~15 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/literature/scripts/zotero-index-add.sh` -> moved to `scripts/deprecated/`
  - `.claude/extensions/literature/scripts/zotero-index-remove.sh` -> moved to `scripts/deprecated/`
  - `.claude/extensions/literature/scripts/deprecated/README.md` (optional, new)
- **Verification:** Both files exist under `scripts/deprecated/` and are gone from the flat
  `scripts/` directory; `git status` shows renames (R), not deletes.

### Phase 2: Remove both entries from manifest.json provides.scripts [COMPLETED]

- **Goal:** Drop the two dead scripts from the `provides.scripts` array so no other check
  expects them deployed, and so Rule E no longer counts them as "declared".
- **Tasks:**
  - [x] Remove `"zotero-index-add.sh"` (line 36) from `provides.scripts`. *(completed)*
  - [x] Remove `"zotero-index-remove.sh"` (line 37) from `provides.scripts`. *(completed)*
  - [x] Confirm JSON stays valid (trailing-comma correctness) with `jq . manifest.json`. *(completed: jq . parses cleanly, index() returns null for both entries)*
- **Timing:** ~10 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/literature/manifest.json` - remove lines 36-37 from `provides.scripts`
- **Verification:** `jq -e '.provides.scripts | index("zotero-index-add.sh") // index("zotero-index-remove.sh")'`
  returns null/false; `jq .` parses cleanly; the other five deferred zotero scripts remain in
  the array.

### Phase 3: Reconcile all doc surfaces (README + 3 widened-scope files) [COMPLETED]

- **Goal:** Remove/reword every literal `zotero-index-add.sh` / `zotero-index-remove.sh` `.sh`
  mention so no undeclared token survives Rule E, and record the quarantine in the README's
  Deployment Status section.
- **Tasks:**
  - [x] `README.md` "Available Scripts" table (~lines 147-148): remove or reword the two rows.
        *(completed: removed both rows)*
  - [x] `README.md` "Deployment Status → Inactive" table (~lines 168-169): change the two rows
        from "Prune candidate for a future task; quarantined, not deleted." to
        "Removed (quarantined in `scripts/deprecated/`, task #847)." *(completed: removed the
        two literal-`.sh` table rows entirely and added a "Removed (task 847)" prose note
        below the table referencing `scripts/deprecated/README.md`, since keeping the literal
        `zotero-index-add.sh`/`zotero-index-remove.sh` tokens anywhere in README.md — even in
        the Reason column only — would still match Rule E's regex and FAIL now that the
        scripts are no longer declared in any manifest.json)*
  - [x] `README.md` count sentence (~lines 176-181): change "Seven zotero scripts... remain
        declared" to "Five zotero scripts...". *(completed)*
  - [x] `EXTENSION.md` lines 81-82: remove or de-literalize the two "Available Scripts" rows
        (drop the `.sh` suffix or remove the rows) so the tokens no longer match Rule E's regex.
        *(completed: removed both rows)*
  - [x] `agents/literature-agent.md` lines 172-173: same treatment as EXTENSION.md.
        *(completed: removed both rows)*
  - [x] `skills/skill-literature/SKILL.md` line 422: reword the comment to avoid the literal
        `zotero-index-add.sh` token (e.g., "the pattern the former zotero-index-add script
        produced") while keeping the surrounding logic intact. *(completed)*
  - [x] Do NOT touch the `echo "Run: zotero-index-add.sh $KEY"` hint lines in `zotero-chunk.sh`
        / `zotero-attach-chunks.sh` (out of scope; inside `.sh` files Rule E does not scan).
        *(completed: verified untouched)*
- **Timing:** ~20 min
- **Depends on:** 1, 2
- **Files to modify:**
  - `.claude/extensions/literature/README.md` - 4 row edits + 1 count-sentence fix
  - `.claude/extensions/literature/EXTENSION.md` - lines 81-82
  - `.claude/extensions/literature/agents/literature-agent.md` - lines 172-173
  - `.claude/extensions/literature/skills/skill-literature/SKILL.md` - line 422
- **Verification:** `grep -rn 'zotero-index-add\.sh\|zotero-index-remove\.sh'` over
  `README.md`, `EXTENSION.md`, `agents/`, and `skills/` returns no hits (or only non-`.sh`
  reworded mentions); the quarantined script bodies (self-references inside `scripts/deprecated/`)
  are the only remaining literal matches and are outside Rule E's scanned globs.

### Phase 4: Verify drift guard and quarantine integrity [COMPLETED]

- **Goal:** Prove the prune is consistent and non-destructive.
- **Tasks:**
  - [x] Run `bash .claude/scripts/check-extension-docs.sh`; confirm exit code 0 and
        `literature PASS` / `PASS: all extensions OK`. *(completed: exit=0, literature PASS,
        PASS: all extensions OK)*
  - [x] Confirm both scripts still exist at `.claude/extensions/literature/scripts/deprecated/`.
        *(completed)*
  - [x] Confirm the flat `scripts/` directory no longer contains the two scripts. *(completed)*
  - [x] Confirm the other five deferred zotero scripts are untouched (unchanged in git diff).
        *(completed: `git diff HEAD~4` on zotero-read/write/setup/chunk/attach-chunks.sh is
        empty)*
  - [x] Spot-check no live caller: `grep -rn 'zotero-index-add\|zotero-index-remove' .claude/`
        surfaces only quarantined self-references, doc/comment mentions that were reworded,
        and out-of-scope hint lines — no invocation path. *(completed: remaining hits are the
        quarantined scripts' own self-references, the deprecated/README.md quarantine note,
        the two out-of-scope `echo "Run: ..."` hint lines, and a stale (harmless, non-invoking)
        path comment in literature-normalize-authors.sh:9 referencing the old pre-move path —
        left untouched as out of the task's explicit file scope; it is a comment, not a live
        caller, and not scanned by Rule E)*
- **Timing:** ~15 min
- **Depends on:** 1, 2, 3
- **Files to modify:** none (verification only)
- **Verification:** `check-extension-docs.sh` exits 0 with literature PASS; both files present
  under `scripts/deprecated/`; five other zotero scripts unchanged.

## Testing & Validation

- [x] `bash .claude/scripts/check-extension-docs.sh` exits 0, `literature PASS`, `PASS: all extensions OK`.
- [x] `jq . .claude/extensions/literature/manifest.json` parses; `provides.scripts` no longer
      lists either script; the five other deferred zotero scripts remain.
- [x] `ls .claude/extensions/literature/scripts/deprecated/` shows both scripts (not hard-deleted).
- [x] `ls .claude/extensions/literature/scripts/` no longer shows either script.
- [x] No undeclared `.sh` token for the two scripts remains in `README.md`, `EXTENSION.md`,
      `agents/*.md`, or `skills/*/SKILL.md`.
- [x] `git diff --stat` shows no changes to `zotero-read.sh`, `zotero-write.sh`,
      `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`.

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/deprecated/zotero-index-add.sh` (quarantined)
- `.claude/extensions/literature/scripts/deprecated/zotero-index-remove.sh` (quarantined)
- `.claude/extensions/literature/scripts/deprecated/README.md` (optional quarantine note)
- Updated `.claude/extensions/literature/manifest.json`
- Updated `.claude/extensions/literature/README.md`
- Updated `.claude/extensions/literature/EXTENSION.md`
- Updated `.claude/extensions/literature/agents/literature-agent.md`
- Updated `.claude/extensions/literature/skills/skill-literature/SKILL.md`
- `specs/847_prune_dead_zotero_index_scripts/summaries/01_prune-zotero-index-scripts-summary.md` (on /implement)

## Rollback/Contingency

All changes are on a git branch and fully reversible:
- Quarantine is a `git mv` — `git mv` the two scripts back to the flat `scripts/` directory to
  restore.
- Restore the two `provides.scripts` array entries and revert the five doc edits with
  `git checkout -- <file>` per file, or `git revert` the implementation commit.
- Because scripts are quarantined (never deleted), no script content is ever lost; the
  worst-case recovery is a directory move plus a manifest/doc revert.
- If `check-extension-docs.sh` fails after Phase 3, re-grep the four doc surfaces for any
  surviving `.sh` token before reverting — the failure is almost certainly a missed literal
  mention, fixable forward rather than by rollback.

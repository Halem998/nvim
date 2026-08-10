# Implementation Plan: Task #793

- **Task**: 793 - Fix literature extension script packaging so `<leader>al` deploys a working extension to all repos.
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/793_literature_extension_script_packaging/reports/01_script-packaging-research.md
- **Artifacts**: plans/01_script-packaging-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The literature extension references 7 shell scripts plus one `.sql` schema file that physically
exist only in this repo's *deployed* `.claude/scripts/` directory and are absent from both the
extension source tree (`.claude/extensions/literature/scripts/`) and `manifest.provides.scripts`.
As a result, loading the extension into any other repo via the `<leader>al` picker deposits a
broken literature extension (the missing scripts never deploy). This plan migrates those files
into the extension source as the canonical copy, declares them in the manifest, fixes three
genuinely broken path references, adds a doc-lint regression guard, corrects one misleading doc
claim, and verifies a clean-repo deployment now yields a working `literature-discover.sh`.

Definition of done: `check-extension-docs.sh` passes for the literature extension; every
extension-referenced `.sh`/`.sql` is carried by `manifest.provides.scripts`; a dry-run deploy of
the literature extension into a throwaway target repo produces a runnable `literature-discover.sh`;
this repo's own `/literature` continues to work.

### Research Integration

The plan follows the research report's critical **flat-deploy correction**: `loader.copy_scripts`
(`loader.lua:308-342`) copies every `provides.scripts` entry flat into the consuming repo's
`{base_dir}/scripts/`, never into `{base_dir}/extensions/{name}/scripts/` (`copy_manifest`,
`loader.lua:588-617`, copies only `manifest.json` there). Consequently most `$SCRIPT_DIR`-relative
and flat-cwd-relative references already resolve correctly after migration and need no change; only
the two nested-`extensions/`-path candidate lists and one hardcoded absolute path are genuinely
broken. `.sql` is packaged via `provides.scripts` (not `provides.data`), which `copy_scripts`
handles because `copy_file` only special-cases `%.sh$` for chmod (`loader.lua:77`) and copies any
other filename verbatim. `literature-retrieve.sh` is core-owned and out of scope;
`literature-audit.sh` is orphaned (zero references) and explicitly excluded.

Verified during planning: `check-extension-docs.sh` is **core-owned** (present in
`.claude/extensions/core/manifest.json` `provides.scripts` and at
`.claude/extensions/core/scripts/check-extension-docs.sh`). Its canonical source is therefore the
core extension, and the flat `.claude/scripts/check-extension-docs.sh` is a regenerable copy. The
literature manifest currently has 12 `provides.scripts` entries and will become 20.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Make `.claude/extensions/literature/scripts/` the single canonical source for the 7 scripts +
  `literature-schema.sql`, tracked in `manifest.provides.scripts` (git history preserved via `git mv`).
- Repopulate this repo's flat `.claude/scripts/` from the extension source so local `/literature`
  and `/cite` keep working (no window of breakage committed).
- Fix the three genuinely broken path references (2 nested-path candidate lists + 1 hardcoded
  absolute path).
- Add `check_referenced_scripts_declared` to the core-owned `check-extension-docs.sh` as a
  regression guard that fails when a referenced `.sh`/`.sql` is missing from the extension's manifest.
- Correct EXTENSION.md's false `LITERATURE_DIR` "(already configured)" claim.
- Prove via a throwaway-repo dry-run that the deployed extension now yields a working
  `literature-discover.sh`.

**Non-Goals**:
- Touching `literature-retrieve.sh` (core-owned).
- Migrating or deleting `literature-audit.sh` (orphaned; leave in place).
- Modifying `sync.lua` / "Load Core" (confirmed irrelevant to non-core extension scripts).
- Rewriting `zotero-chunk.sh`'s path resolution (verify-only; optional clarifying comment only).
- Changing any Lua loader code (no loader changes are required).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git mv` breaks this repo's `/literature` and `/cite` between move and repopulate | H | H | Perform move + manifest update + repopulate of the flat copy as ONE atomic phase (Phase 1); do not commit or pause mid-phase. Verify a literature command resolves its scripts before committing. |
| New lint rule produces false positives on other extensions | M | M | Apply core-exclusion + already-declared-exclusion filters; run the new check against ALL extensions and manually triage any new failures before committing. |
| Flat-copy of edited scripts drifts from canonical extension source | M | M | Convention: after ANY edit under `.claude/extensions/literature/scripts/` (or the core scripts dir), re-sync the flat `.claude/scripts/` copy and `git add` both. Final verification (Phase 5) does a full re-sync + diff check. |
| `.sql` not deployed by loader | H | L | Confirmed by research: `copy_scripts` iterates `provides.scripts` by name and `copy_file` copies non-`.sh` verbatim. Phase 5 dry-run explicitly checks the `.sql` lands in the target. |
| Editing only the flat copy of the core-owned `check-extension-docs.sh` causes drift | M | M | Edit the canonical `.claude/extensions/core/scripts/check-extension-docs.sh`, then re-sync the flat `.claude/scripts/check-extension-docs.sh`; `git add` both. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 3 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

**Flat-copy re-sync convention (applies to every phase that edits a packaged file)**: after
editing a file whose canonical home is an extension `scripts/` directory, refresh the deployed flat
copy in `.claude/scripts/` so this repo keeps working. Preferred mechanism is the loader reload
(see Phase 1 Tasks); deterministic fallback is a direct `cp` from the canonical source to
`.claude/scripts/`. Then `git add` both the canonical and flat copies (this repo tracks both, per
the existing dual-copy model — e.g. `generate-todo.sh` is tracked in both locations).

---

### Phase 1: Migrate scripts to extension source, declare in manifest, repopulate flat copy [COMPLETED]

**Goal**: Make the extension source the canonical home for the 7 scripts + schema, declare them in
the manifest, and atomically repopulate this repo's flat `.claude/scripts/` so `/literature` never
breaks. This is a single atomic phase — do not commit until the repopulate + local verification
succeed.

**Tasks**:
- [x] `git mv` the 7 files *(deviation: altered — plan text said "8 files"/"20 entries"; the
      enumerated list is 6 `.sh` + `literature-schema.sql` = 7 files / 19 entries; reconciled per
      orchestrator instructions)* from `.claude/scripts/` into `.claude/extensions/literature/scripts/`:
      `literature-discover.sh`, `literature-ingest.sh`, `literature-search.sh`,
      `literature-build-index.sh`, `literature-convert.sh`, `literature-chunk.sh`,
      `literature-schema.sql`. (Preserves history; extension source becomes canonical.) *(completed)*
- [x] Do NOT move `literature-audit.sh` (orphaned) or `literature-retrieve.sh` (core-owned). *(completed: verified both remain untouched in .claude/scripts/)*
- [x] Add all 7 filenames to `provides.scripts` in
      `.claude/extensions/literature/manifest.json` (12 entries -> 19). Added `literature-schema.sql`
      as a plain `provides.scripts` entry (NOT `provides.data`). *(completed)*
- [x] Confirm the 6 migrated `.sh` files retain their executable bit in the new location
      (`git mv` preserves mode; verify with `ls -l`). *(completed: all 6 rwxr-xr-x, schema.sql rw-r--r--)*
- [x] Repopulate this repo's flat `.claude/scripts/` from the new canonical source. *(completed: used
      the deterministic `cp` fallback — 7 files copied from
      `.claude/extensions/literature/scripts/` back to `.claude/scripts/` with `chmod +x` re-applied
      to the 6 `.sh` files; nvim --headless reload not used since agent shell has no live nvim
      runtime)*
- [x] `git add` the regenerated flat copies in `.claude/scripts/` (keep them git-tracked, matching
      the existing dual-copy model for core/other packaged scripts — do NOT gitignore them). *(completed)*
- [x] Verify locally: `test -x .claude/scripts/literature-discover.sh` and run a non-destructive
      resolution check that `/literature`'s discover path (`literature.md:127`
      `DISCOVER_SCRIPT=".claude/scripts/literature-discover.sh"`) points at an existing runnable file. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/scripts/{literature-discover,literature-ingest,literature-search,literature-build-index,literature-convert,literature-chunk}.sh`, `.claude/scripts/literature-schema.sql` - `git mv` sources (removed from here, then regenerated as tracked deployment copies)
- `.claude/extensions/literature/scripts/` - `git mv` destinations (new canonical copies)
- `.claude/extensions/literature/manifest.json` - add 8 entries to `provides.scripts`

**Verification**:
- `jq '.provides.scripts | length' .claude/extensions/literature/manifest.json` returns 20.
- All 8 files present under `.claude/extensions/literature/scripts/`.
- All 8 files present (regenerated) under `.claude/scripts/`; the 6 `.sh` are executable.
- `git status` shows renames (moves) plus re-added flat copies; no untracked literature script left behind.

**Commit point**: `task 793: phase 1 - migrate literature scripts into extension source and declare in manifest`

---

### Phase 2: Fix genuinely broken path references [COMPLETED]

**Goal**: Correct the three references that do not resolve under the flat-deploy model, then
re-sync the affected flat copies.

**Tasks**:
- [x] `literature-discover.sh:340-342` (now at
      `.claude/extensions/literature/scripts/literature-discover.sh`): reordered the
      `zotero-search.sh` candidate list so the flat sibling path (`$SCRIPT_DIR/zotero-search.sh`) is
      the PRIMARY candidate; demoted the nested
      `.claude/extensions/literature/scripts/zotero-search.sh` candidate to a fallback (dropped the
      duplicate cwd-relative form of the same nested path). *(completed)*
- [x] `skill-literature/SKILL.md:1123-1125` (at
      `.claude/extensions/literature/skills/skill-literature/SKILL.md`): same fix — made
      `.claude/scripts/zotero-search.sh` and `$(dirname "$0")/../../scripts/zotero-search.sh`
      primary/secondary candidates; demoted the nested `extensions/literature/scripts/...`
      candidate to a fallback. *(completed)*
- [x] `literature-briefing.sh:192,195` (at
      `.claude/extensions/literature/scripts/literature-briefing.sh`): replaced the hardcoded absolute
      `~/.config/nvim/.claude/scripts/literature-search.sh` with the repo-relative
      `.claude/scripts/literature-search.sh` so emitted agent instructions are correct in any
      deployed repo. *(completed)*
- [x] Verify-only, escalated to FIX: `zotero-chunk.sh:38-40`
      `LITERATURE_SCRIPTS_DIR="$PROJECT_ROOT/.claude/scripts"` — empirically verified (via a
      throwaway-repo probe simulating both the nested source location and the flat deployed
      location) that the fixed `../../../..` (4-level) `PROJECT_ROOT` computation is GENUINELY
      BROKEN when this script is flat-deployed: it resolves 2 directories ABOVE the actual repo
      root (only correct from the nested 4-levels-deep source tree location), corrupting
      `ZOTERO_INDEX`, `LITERATURE_SCRIPTS_DIR`, and `CHUNK_DIR` in any consuming repo. Fixed by
      replacing the fixed-depth walk-up with a dynamic walk-up that stops at the first ancestor
      directory containing `.claude/`; verified correct from both locations via direct probe.
      *(deviation: altered — plan said verify-only/optional-comment, but the reference was
      empirically confirmed broken so it was fixed per the orchestrator's "change only if
      actually broken" instruction)*
- [x] Re-synced the flat copies of the two edited scripts (`literature-discover.sh`,
      `literature-briefing.sh`) into `.claude/scripts/` via `cp` fallback (byte-identical,
      executable bits reapplied). `skill-literature/SKILL.md` under `.claude/extensions/literature/`
      and `.claude/skills/` are hardlinks (same inode) so no separate re-sync step was needed —
      the edit applied to both automatically. `zotero-chunk.sh` has no existing flat copy in this
      repo (never previously deployed flat here), so no flat re-sync applies to it; the corrected
      source will flat-deploy correctly to any consuming repo via its existing
      `provides.scripts` declaration. `git add` all edited canonical + flat copies. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-discover.sh` (lines ~340-342) - candidate-path reorder
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` (lines ~1123-1125) - candidate-path reorder
- `.claude/extensions/literature/scripts/literature-briefing.sh` (lines 192,195) - hardcoded-path fix
- `.claude/extensions/literature/scripts/zotero-chunk.sh` (lines 38-40) - verify only, optional comment
- Corresponding flat copies under `.claude/scripts/` and `.claude/skills/skill-literature/SKILL.md` - re-synced

**Verification**:
- No remaining primary reference to the nested `extensions/literature/scripts/zotero-search.sh`
  path in `literature-discover.sh` or `skill-literature/SKILL.md` (grep confirms flat path is
  primary).
- No hardcoded `~/.config/nvim/.claude/scripts/` path remains in `literature-briefing.sh`
  (`grep -n '\.config/nvim' literature-briefing.sh` returns nothing).
- Canonical and flat copies of the edited scripts are byte-identical.

**Commit point**: `task 793: phase 2 - fix broken literature script path references`

---

### Phase 3: Add `check_referenced_scripts_declared` lint safeguard [COMPLETED]

**Goal**: Add a reverse-direction doc-lint rule to the core-owned `check-extension-docs.sh` that
fails when an extension references a `.sh`/`.sql` in its prose/commands/skills/agents but omits it
from `manifest.provides.scripts`. Demonstrate it FAILS on the pre-fix state and PASSES post-fix.

**Tasks**:
- [x] Edited the CANONICAL source
      `.claude/extensions/core/scripts/check-extension-docs.sh` (core-owned; confirmed in core
      manifest `provides.scripts`). Added function `check_referenced_scripts_declared` after
      `check_readme_vs_manifest`, wired into the per-extension loop alongside the other `check_*`
      calls. *(completed)*
- [x] Rule logic per research Finding #7, extended with false-positive fixes discovered during
      whole-suite triage (see deviation below):
      (1) extract `.sh`/`.sql` filename tokens from `$ext_path/commands/*.md`,
      `skills/*/SKILL.md`, `agents/*.md`, `README.md`, `EXTENSION.md` via
      `grep -oE '[A-Za-z0-9_-]+\.(sh|sql)\b'` (added `\b` word boundary) after stripping
      `https?://\S+` URL substrings, then `sort -u`;
      (2) exclude names in core's `provides.scripts` OR `provides.hooks`;
      (3) exclude names declared in ANY extension's `provides.scripts` (not just core's) to allow
      legitimate cross-extension invocation (e.g. core's `--lit` integration code invoking
      literature's own already-packaged scripts by name);
      (4) exclude names already in the current extension's own `provides.hooks`;
      (5) for each remaining name, call `fail "script referenced in docs/skills/agents but NOT in
      provides.scripts: $name"` (increments `$FAILURES`; preserves the existing exit-code contract).
      *(completed: altered — see deviation)*
- [x] Re-synced the flat copy: refreshed `.claude/scripts/check-extension-docs.sh` from the edited
      core source via `cp` fallback (byte-identical), and `git add` both copies. *(completed)*
- [x] Demonstrated FAIL on pre-fix state: reconstructed the pre-fix literature manifest (12
      entries, 7 files removed) in a throwaway temp repo and ran the rule via `EXT_DIR`/`REPO_ROOT`
      env-var override; confirmed `[literature]` FAILs and the whole run exits non-zero. Reports 3
      of the 7 names (`literature-discover.sh`, `literature-ingest.sh`, `literature-search.sh`) —
      the other 4 (`literature-build-index.sh`, `literature-convert.sh`, `literature-chunk.sh`,
      `literature-schema.sql`) are referenced only from *inside sibling scripts*
      (`literature-ingest.sh`, `zotero-chunk.sh`), not from commands/skills/agents/README/
      EXTENSION.md, so per the extraction scope specified in research Finding #7 (and preserved
      here) they are correctly out of this rule's detection surface. *(completed: the plan's
      verification text said "exactly the 7+1 missing entries"; the actual detection surface
      per Finding #7's own specified extraction scope only covers 3 of the 7 — documented here
      rather than expanding scope to also grep `scripts/*.sh`, which would deviate from the
      research-specified design)*
- [x] Demonstrated PASS post-fix: ran
      `bash .claude/scripts/check-extension-docs.sh --quiet` against the current (fixed) tree;
      `[literature]` passes with zero FAIL lines. *(completed)*
- [x] Ran the new rule against ALL extensions; triaged failures. Found and fixed 3 classes of
      false positive (Python attribute-access tokens like `df.shape`/`wb.sheetnames`/
      `slide.shapes`/`vim.opt.shiftwidth` matching via unanchored regex; remote install-script
      URLs like `astral.sh`/`elan-init.sh` being mistaken for local scripts; legitimate
      cross-extension invocation of literature's/core's scripts by name) via the rule-logic
      changes in the prior task. After fixing, 2 genuine (non-false-positive) missing-declaration
      bugs remained in `core` (`lifecycle-notify.sh`, `reconcile-artifacts.sh` — referenced in
      core's own skills but never added to any extension source tree or manifest, exactly the
      same bug class this task fixes for literature) and were also fixed by migrating them into
      `.claude/extensions/core/scripts/` and declaring them in core's `provides.scripts` (43 -> 45
      entries), with the flat `.claude/scripts/` copies re-synced. The only remaining whole-suite
      failure is `[lean]` (2 pre-existing `routing_hard`-undeployed-target failures, confirmed via
      `git stash` to predate this task entirely and unrelated to script packaging — out of scope).
      *(completed: altered — expanded beyond literature-only triage to also fix 2 core-owned
      instances of the same bug class, since the new rule's whole point is catching this class
      and leaving genuine newly-discovered instances unfixed would be inconsistent; documented as
      a deviation)*

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/scripts/check-extension-docs.sh` - add `check_referenced_scripts_declared` and wire into per-extension loop
- `.claude/scripts/check-extension-docs.sh` - re-synced flat copy

**Verification**:
- New rule run against a reconstructed pre-fix manifest exits non-zero and names the 7+1 missing entries.
- `bash .claude/scripts/check-extension-docs.sh --quiet` exits 0 with `literature PASS` post-fix.
- Whole-suite run shows no unexpected false positives across other extensions.

**Commit point**: `task 793: phase 3 - add check_referenced_scripts_declared doc-lint rule`

---

### Phase 4: Documentation corrections [COMPLETED]

**Goal**: Correct the false `LITERATURE_DIR` claim and document the default; optionally record the
flat-deploy model to prevent recurrence.

**Tasks**:
- [x] `.claude/extensions/literature/EXTENSION.md:51-55` (the "Centralized Repository" section,
      false claim at line 53): removed the "(already configured)" assertion and the hardcoded personal
      absolute path. States that `LITERATURE_DIR` defaults to `~/Projects/Literature` (via `$HOME`;
      see `literature-discover.sh:36`
      `LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"`) and describes it as an optional
      override env var / settings key a user MAY set. *(completed)*
- [x] `README.md:19` — verified phrasing ("configured via `LITERATURE_DIR`") does not assert it is
      already set; no change needed (describes the mechanism, not current-repo state). *(completed: verify-only, no change)*
- [x] Added a short note to
      `.claude/context/guides/extension-development.md` (new "copy_scripts() Flat-Deploy Model"
      subsection after "copy_context_dirs() Dual Behavior") stating that `provides.scripts` entries
      deploy FLAT into `{base_dir}/scripts/` in the consuming repo — never into
      `{base_dir}/extensions/{name}/scripts/` — and that only `manifest.json` is copied under
      `extensions/{name}/` via `copy_manifest`. *(completed)*
- [x] Discovered `.claude/context/guides/extension-development.md` IS a dual-copy deployment
      artifact of the core-owned canonical source
      `.claude/extensions/core/context/guides/extension-development.md` (confirmed identical
      pre-edit via `diff`); re-synced the canonical copy to match. EXTENSION.md/README.md are not
      part of any loader `copy_*` set (they are extension-root source files, not deployed
      artifacts) so no flat-copy re-sync applies to them. `git add` edited docs (both
      extension-development.md copies + EXTENSION.md). *(completed: altered — added the
      dual-copy re-sync step for extension-development.md, which the plan text did not
      anticipate)*

**Timing**: 0.5 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/EXTENSION.md` (lines 51-55) - remove false claim, document default
- `.claude/extensions/literature/README.md` (line 19) - verify, adjust only if overclaiming
- `.claude/context/guides/extension-development.md` - optional flat-deploy note

**Verification**:
- `grep -n 'already configured' EXTENSION.md` returns nothing.
- EXTENSION.md states the `~/Projects/Literature` default and describes `LITERATURE_DIR` as optional override.

**Commit point**: `task 793: phase 4 - correct LITERATURE_DIR documentation`

---

### Phase 5: Final verification (loader simulation + doc-lint + clean-repo deploy) [COMPLETED]

**Goal**: Prove the packaging is correct end-to-end: the manifest carries every referenced script,
the doc-lint passes, and a clean-repo deploy yields a working `literature-discover.sh`.

**Tasks**:
- [x] Manifest completeness check: `bash .claude/scripts/check-extension-docs.sh --quiet` run;
      `[literature]` PASS with zero FAIL lines. Whole-suite exit code is 1 solely due to a
      pre-existing, unrelated `[lean]` `routing_hard` failure (confirmed via `git stash` to
      predate this task). *(completed)*
- [x] Flat/canonical parity check: diffed all 7 migrated files (`literature-discover.sh`,
      `literature-ingest.sh`, `literature-search.sh`, `literature-build-index.sh`,
      `literature-convert.sh`, `literature-chunk.sh`, `literature-schema.sql`) plus
      `literature-briefing.sh`, `check-extension-docs.sh`, `lifecycle-notify.sh`,
      `reconcile-artifacts.sh`, and `skill-literature/SKILL.md` (hardlinked) — all identical.
      *(completed: altered — 7 files not 8, per the count reconciliation from Phase 1)*
- [x] Clean throwaway-repo deploy (`mktemp -d`): simulated `loader.copy_scripts` by iterating
      `manifest.provides.scripts` (19 entries) and copying each named file from
      `.claude/extensions/literature/scripts/` into `{tmp}/.claude/scripts/` with `chmod +x` for
      `.sh` files. All 19 entries copied (0 missing sources), 6 `.sh` executable,
      `literature-schema.sql` non-executable. `bash -n` syntax check passed;
      `{tmp}/.claude/scripts/literature-discover.sh --task 999999` actually ran (failed later on
      missing `specs/state.json`, an expected throwaway-repo condition, not a path-resolution or
      missing-file error) confirming the deployed script executes. Isolated resolution-logic test
      confirmed the `zotero-search.sh` candidate loop resolves to
      `{tmp}/.claude/scripts/zotero-search.sh` (the flat sibling), not the nested fallback.
      *(completed: altered — 19 not 20, per the count reconciliation; used the `cp`-based
      deterministic simulation rather than `nvim --headless`, consistent with Phase 1's approach)*
- [x] Confirmed `literature-schema.sql` landed in `{tmp}/.claude/scripts/` with byte-identical
      content and default (non-executable) permissions. *(completed)*
- [x] Confirmed no `{tmp}/.claude/extensions/` directory existed at all in the throwaway repo
      (only `{tmp}/.claude/scripts/` was populated), and the `zotero-search.sh` resolution still
      succeeded via the flat sibling path — proving the previously-broken nested candidate is not
      required. *(completed)*
- [x] Cleaned up the temp dir (`rm -rf`; verified removal). *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- None (verification only; may write transient files under a `mktemp -d` target, cleaned up after)

**Verification**:
- `check-extension-docs.sh --quiet` exits 0; literature PASS.
- All 8 migrated files: extension-source copy == flat copy (diff empty).
- Temp-repo deploy places all 20 scripts (incl. `.sql`) flat in `{tmp}/.claude/scripts/`;
  `literature-discover.sh` passes `bash -n` and resolves `zotero-search.sh` via the flat sibling.

**Commit point**: `task 793: complete implementation` (after all phases verified)

---

## Testing & Validation

- [x] `jq '.provides.scripts | length' .claude/extensions/literature/manifest.json` == 19 *(deviation: was specified as 20; reconciled to 19 per the 7-file/19-entry count correction — see Phase 1)*.
- [x] `bash .claude/scripts/check-extension-docs.sh --quiet` exits 0 for `[literature]` (literature PASS) post-fix; whole-suite exit is 1 solely due to a pre-existing, unrelated `[lean]` failure.
- [x] New lint rule exits non-zero against a reconstructed pre-fix manifest, naming 3 of the 7 missing entries *(deviation: the other 4 are referenced only from sibling scripts, outside the rule's documented extraction scope — see Phase 3)*.
- [x] Whole-suite `check-extension-docs.sh` run shows no unexpected false positives (3 false-positive classes found and fixed; 2 genuine core bugs found and fixed; 1 pre-existing unrelated lean failure remains, confirmed out of scope).
- [x] All 7 migrated files exist in both `.claude/extensions/literature/scripts/` and `.claude/scripts/`, byte-identical; 6 `.sh` executable *(deviation: 7 files not 8, per count correction)*.
- [x] `grep -n '\.config/nvim' .claude/extensions/literature/scripts/literature-briefing.sh` returns nothing.
- [x] No primary nested-`extensions/`-path candidate remains in `literature-discover.sh` / `skill-literature/SKILL.md`.
- [x] `grep -n 'already configured' .claude/extensions/literature/EXTENSION.md` returns nothing.
- [x] Throwaway-repo deploy: `literature-discover.sh` runnable and resolves `zotero-search.sh` from flat siblings; `literature-schema.sql` present.
- [x] This repo's own `/literature` discover path resolves to an existing runnable script (no regression) — verified in Phase 1 and re-verified in Phase 5.

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/{literature-discover,literature-ingest,literature-search,literature-build-index,literature-convert,literature-chunk}.sh` and `literature-schema.sql` - migrated canonical scripts
- `.claude/extensions/literature/manifest.json` - 20-entry `provides.scripts`
- `.claude/extensions/literature/scripts/literature-discover.sh`, `literature-briefing.sh` - path fixes
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` - path fix
- `.claude/extensions/core/scripts/check-extension-docs.sh` (+ flat `.claude/scripts/` copy) - new lint rule
- `.claude/extensions/literature/EXTENSION.md` - corrected LITERATURE_DIR doc
- `.claude/context/guides/extension-development.md` - optional flat-deploy note
- Regenerated flat deployment copies under `.claude/scripts/` (git-tracked)
- specs/793_literature_extension_script_packaging/summaries/01_script-packaging-summary.md (on completion)

## Rollback/Contingency

- All changes are staged as per-phase commits; revert individual phases with `git revert` or reset
  the branch to the pre-task commit.
- Phase 1 is the highest-risk (atomic move + repopulate). If the repopulate step fails and this
  repo's `/literature` breaks, immediately restore the flat copies with
  `cp .claude/extensions/literature/scripts/{...} .claude/scripts/` (or `git checkout` the pre-move
  state of `.claude/scripts/`) to recover local function, then diagnose the loader/reload step
  before proceeding.
- Because `git mv` preserves history and the flat copies are regenerable from the canonical source,
  no content is lost; a full rollback is `git reset --hard <pre-task-commit>` on the task branch.

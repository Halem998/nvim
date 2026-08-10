# Research Report: Zotero Resolver Delegation Audit Setup

- **Task**: 904 - zotero_resolver_delegation_audit_setup
- **Started**: 2026-07-25T00:00:00Z
- **Completed**: 2026-07-25T00:00:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/literature/scripts/zotero-resolve-sqlite-path.sh` (canonical resolver, read in full)
  - `agent-system/extensions/literature/scripts/literature-audit.sh` (Defect 1 site, read in full)
  - `agent-system/extensions/literature/scripts/zotero-setup.sh` (Defect 2 site, read in full)
  - `agent-system/extensions/literature/scripts/zotero-export-status.sh`, `zotero-generate-export.sh`,
    `zotero-resolve-pdf.sh`, `literature-ingest-online.sh` (the four existing correct-delegation
    consumers, grepped for their `zotero-resolve-sqlite-path.sh` call sites)
  - `agent-system/extensions/literature/scripts/tests/`, `test-lit-pipeline.sh` (checked for
    coverage of the two defect sites — none found)
  - `agent-system/extensions/literature/EXTENSION.md`, `README.md`, `agents/literature-agent.md`
    (checked for prose describing the candidate-ladder order — none found; only a one-line tool
    summary, so no doc updates are required beyond the in-script diagnostic string)
- **Artifacts**: this report
- **Standards**: report-format.md, artifact-formats.md, no-task-references-in-deliverables.md

## Context & Scope

The task description is already a fully-specified fix (root cause, exact line numbers, exact
replacement logic, non-goals, and a verification procedure). This research pass verifies every
claim against the current file contents, confirms the delegation pattern already used by the
resolver's four existing consumers, checks for any test or documentation coupling that the fix
would need to update, and produces exact patch guidance for planning/implementation.

**SOURCE-STORE RULE confirmed**: all four files in scope live under
`agent-system/extensions/literature/scripts/`, which is the tracked source of truth. `git status
--porcelain agent-system/extensions/literature` is clean, confirming no stray edits are already
in flight. No corresponding `.claude/extensions/literature/scripts/` deploy copies exist in this
checkout, so there is no risk of accidentally editing a disposable artifact.

## Findings

### The canonical resolver (`zotero-resolve-sqlite-path.sh`) — confirmed correct, out of scope

Read in full (179 lines). Three-tier resolution, exactly as the task description states:
1. `$ZOTERO_SQLITE_PATH` explicit override (line 50-53).
2. Auto-detected custom `dataDir` from the default profile's `prefs.js`
   (`extensions.zotero.useDataDir=true` + `extensions.zotero.dataDir`), probing
   `~/.zotero/zotero` then `~/.mozilla/zotero` (lines 55-174).
3. Historical default `${HOME}/Zotero/zotero.sqlite` (lines 176-178).

It always exits 0 (every branch ends in an explicit `echo ...; exit 0`, and `set -euo pipefail`
never trips on a failing internal command because all fallible calls use `|| continue` / `||
use_data_dir=""` guards). It performs no existence check on its own output — this is documented
in its header (lines 41-45) and is a hard invariant callers must preserve. **No changes
recommended to this file.**

### The existing delegation pattern (four correct consumers)

All four already-correct callers use the identical two-line idiom:
```
ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"
ZOTERO_DATA_DIR="$(dirname "$ZOTERO_SQLITE")"   # zotero-resolve-pdf.sh:75-76
```
- `zotero-export-status.sh:80`, `zotero-generate-export.sh:96`: resolve the sqlite path directly,
  keep their own `[ -f "$ZOTERO_SQLITE" ]` probes downstream.
- `zotero-resolve-pdf.sh:75-76`: the closest structural precedent for Defect 1 — it derives the
  **data directory** (not just the sqlite file) via `dirname "$ZOTERO_SQLITE"`, exactly the
  pattern Defect 1 needs for the `/storage` suffix. Its header (line 17) states: "The storage
  root is ALWAYS derived from zotero-resolve-sqlite-path.sh's dataDir — never [hardcoded]."
- `literature-ingest-online.sh:323`: same one-line call, assigned to `zotero_sqlite`.

This confirms the fix for both defects should reuse this exact idiom rather than invent a new
one — consistent with the task's "closed set" framing (resolver already has four correct
consumers; the fix makes it the single ladder for all six).

### Defect 1 — `literature-audit.sh:47` (verified)

Read in full (418 lines). `DEFAULT_SEARCH_PATHS` is a static bash array literal at lines 44-48:
```
DEFAULT_SEARCH_PATHS=(
  "$HOME/Projects/BimodalLogic/specs/literature"
  "$HOME/Projects/Literature/pdfs"
  "$HOME/Zotero/storage"
)
```
`SCRIPT_DIR` is already defined at line 41 (`$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`), so
the resolver is reachable via `"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"` with no new
plumbing. `DEFAULT_SEARCH_PATHS` is consumed read-only by `find_test_pdfs()` (line 96) and
`audit_crossrefs()` (line 303) — both just iterate `-d "$dir"` and `find`; neither depends on the
array being a compile-time literal, so converting the third element to a resolved value at
script-start is a drop-in change.

**Recommended patch** (mirrors the `zotero-resolve-pdf.sh:75-76` idiom):
```bash
# Default search paths for test PDFs
ZOTERO_DATA_DIR="$(dirname "$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")")"
DEFAULT_SEARCH_PATHS=(
  "$HOME/Projects/BimodalLogic/specs/literature"
  "$HOME/Projects/Literature/pdfs"
  "$ZOTERO_DATA_DIR/storage"
)
```
Safe under `set -euo pipefail` (line 38) because the resolver always exits 0. No test file
references `DEFAULT_SEARCH_PATHS` or `find_test_pdfs`/`audit_crossrefs` directly (checked
`tests/` and `test-lit-pipeline.sh` — neither touches `literature-audit.sh`), so no test updates
are required.

### Defect 2 — `zotero-setup.sh:79` and its `:103` diagnostic (verified)

Read in full (300 lines). `_detect_data_dir()` (lines 57-90) is a 3-step ladder:
- Step 1 (lines 59-64): `$ZOT_DATA_DIR` env override — explicit escape hatch, keep as-is.
- Step 2 (lines 66-74): `zotero-index.json`'s `.zot_data_dir` — explicit escape hatch, keep
  as-is.
- Step 3 (lines 76-89, the defect): a private candidate list —
  `"$HOME/Zotero"`, `"$HOME/Documents/Zotero"`, `"${XDG_DATA_HOME:-$HOME/.local/share}/Zotero"` —
  probed in that literal order, so a stale `~/Zotero/zotero.sqlite` always wins over a live
  custom `dataDir` the resolver would have found. This reproduces exactly the symptom described
  in the task (stale April profile read instead of the live one).

`SCRIPT_DIR` is already defined at line 28. `_detect_data_dir()` is called from four sites —
`cmd_detect` (line 98), `cmd_configure` (line 114), `cmd_validate` (line 179), `cmd_status` (line
231) — all treat it as an opaque "resolve or fail" call, so replacing Step 3's body is
transparent to all four callers; no other code in the file inspects the candidate list.

**Recommended patch for Step 3** (lines 76-89):
```bash
  # Step 3: canonical resolver (delegates to zotero-resolve-sqlite-path.sh's 3-tier ladder:
  # $ZOTERO_SQLITE_PATH override, auto-detected custom dataDir from Zotero's prefs.js, or the
  # historical ~/Zotero default)
  local _resolved_sqlite _resolved_dir
  _resolved_sqlite="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"
  _resolved_dir="$(dirname "$_resolved_sqlite")"
  if [[ -d "$_resolved_dir" && -f "$_resolved_sqlite" ]]; then
    echo "$_resolved_dir"
    return 0
  fi

  return 1
```
This preserves the function's existing file/directory probe (per the task's VERIFICATION note:
"the resolver performs no existence check on its result, so both callers keep their own
file/directory probes on the resolved path") while removing the private candidate list entirely.

**`:103` diagnostic** (inside `cmd_detect`, lines 96-106) currently reads:
```
echo "Checked: \$ZOT_DATA_DIR, $ZOTERO_INDEX, ~/Zotero, ~/Documents/Zotero, \$XDG_DATA_HOME/Zotero" >&2
```
This must change to describe the delegated ladder truthfully rather than the now-removed
hardcoded list, e.g.:
```
echo "Checked: \$ZOT_DATA_DIR, $ZOTERO_INDEX, then zotero-resolve-sqlite-path.sh (\$ZOTERO_SQLITE_PATH override, auto-detected custom Zotero dataDir, or the ~/Zotero default)" >&2
```
The exact wording is an implementation-time judgment call; the requirement is that it no longer
lists the three specific removed paths as if they were independently probed.

### Documentation surface check

Grepped `EXTENSION.md`, `README.md`, `agents/literature-agent.md` for `zotero-setup`, `~/Zotero`,
`Documents/Zotero`, `XDG_DATA_HOME`. All three only contain a one-line tool-table summary
("Setup wizard: detect data dir, validate, configure"); none describe the internal candidate
order. `README.md:173` separately notes `zotero-setup.sh` is currently "Blocked on external `zot`
CLI, not installed. No live caller." — informational only, does not affect this fix. **No
documentation files require updates** beyond the in-script `:103` string itself.

### Manifest / caller surface check

`literature-audit.sh` and `zotero-setup.sh` are each referenced from `manifest.json` (as
registered scripts) and their own file headers only; no other script sources or execs either
file's internals (`_detect_data_dir` and `DEFAULT_SEARCH_PATHS` are private to their own files).
The blast radius of both fixes is contained to the two files named in the task.

## Decisions

- Both fixes reuse the exact `"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"` + `dirname` idiom
  already used by `zotero-resolve-pdf.sh:75-76`, rather than introducing a new delegation style.
- Defect 2's Step 1 and Step 2 (env var, index file) are preserved unchanged — only Step 3 is
  replaced, per the task's explicit instruction that these are intentional user-facing escape
  hatches, not duplicate detection.
- No test or documentation files need changes beyond the `:103` diagnostic string inside
  `zotero-setup.sh` itself.

## Recommendations

1. **Defect 1** (`literature-audit.sh`): replace the static third array element `"$HOME/Zotero/storage"`
   with a resolver-derived `"$ZOTERO_DATA_DIR/storage"`, computed once near `SCRIPT_DIR` (line 41)
   via `dirname "$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"`. Single-file, ~4-line diff.
2. **Defect 2** (`zotero-setup.sh`): replace `_detect_data_dir()` Step 3's hardcoded
   `for _candidate in ...` loop with a call to the resolver + `dirname`, keeping the existing
   `[[ -d ... && -f ... ]]` probe. Update the `:103` stderr "Checked:" message in `cmd_detect` to
   name the resolver's actual ladder instead of the removed literal paths. Single-file, ~15-line
   diff across two locations (Step 3 body, `:103` string).
3. **Verification** (matches task's VERIFICATION section): on a machine with both `~/Zotero` and
   a custom `dataDir` configured, `zotero-setup.sh --detect` must print the resolved custom data
   directory, and `literature-audit.sh` must probe `<resolved-dir>/storage`. Both must agree with
   direct invocation of `zotero-resolve-sqlite-path.sh`. This machine currently has a live
   divergence case (`~/Zotero` stale April profile vs. live `~/Documents/Zotero` profile per the
   task's REPRODUCED SYMPTOM), so it can serve as the live verification fixture — implementers
   should run `zotero-setup.sh --detect` before and after the patch and confirm the printed
   directory changes from `~/Zotero` to the resolver's output (`~/Documents/Zotero`, per the
   task's stated resolver behavior on this machine).
4. Both patches are small and independent (different files, no shared state) — safe to implement
   as a single phase or as two trivially-parallel edits.

## Risks & Mitigations

- **Risk**: `set -euo pipefail` in either script could turn an unexpected resolver failure into a
  hard script abort via the nested command substitution. **Mitigation**: the resolver is
  documented and verified to always `exit 0` on every code path (confirmed by full read above),
  so this risk is theoretical, not practical, for the current resolver implementation. No
  defensive `|| true` is warranted, since a silent fallback would reintroduce the same
  correctness bug this task is fixing.
- **Risk**: rewording the `:103` diagnostic could mislead users if worded imprecisely (e.g.,
  implying the resolver does an existence check it doesn't). **Mitigation**: word the new message
  to name the resolver by its actual 3-tier order (override / auto-detected dataDir / historical
  default) rather than asserting specific paths were "checked" for existence by `zotero-setup.sh`
  itself.

## Appendix

- `zotero-resolve-pdf.sh:17` header comment: "The storage root is ALWAYS derived from
  zotero-resolve-sqlite-path.sh's dataDir — never [hardcoded]" — the direct textual precedent
  for Defect 1's fix rationale.
- `git status --porcelain agent-system/extensions/literature` — clean at research time.

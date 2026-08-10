# Research Report: Task #798

**Task**: 798 - Two follow-up fixes to task-797 assisted Zotero export generation (dataDir
auto-detection + open-Zotero-and-retry interactive branch)
**Started**: 2026-07-01
**Completed**: 2026-07-01
**Effort**: Medium (2 scripts + 1 new shared-helper script + literature.md wiring restructure)
**Dependencies**: task-797 (assisted Zotero export generation, COMPLETED), task-793 (dual-copy
extension packaging model, COMPLETED)
**Sources/Inputs**: Direct reads of the three primary files, live filesystem verification of
this machine's Zotero profile/sqlite files, task-793/task-797 summaries, a forked sub-agent
probe of the dual-copy sync mechanism.
**Artifacts**: This report — `specs/798_literature_zotero_datadir_and_retry_fixes/reports/01_zotero-datadir-retry-fixes.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **FIX 1 root cause confirmed at exact lines**: `zotero-export-status.sh:74` and
  `zotero-generate-export.sh:84` both hardcode
  `ZOTERO_SQLITE="${ZOTERO_SQLITE_PATH:-${HOME}/Zotero/zotero.sqlite}"` — byte-identical
  expressions in both files. There is currently **no shared helper file** between them; every
  other cross-script call in this codebase uses subprocess invocation
  (`"$SCRIPT_DIR/other-script.sh"`), never `source`.
- **This machine reproduces the bug exactly as described**: `~/Zotero/zotero.sqlite` exists
  (1,114,112 bytes, `SELECT COUNT(*) FROM items` → 0) and `~/Documents/Zotero/zotero.sqlite`
  is the real library (92,520,448 bytes, 1819 rows). `~/.zotero/zotero/pmqmra0p.default/prefs.js`
  contains `extensions.zotero.dataDir = "/home/benjamin/Documents/Zotero"` and
  `extensions.zotero.useDataDir = true` (lines 34, 74), and `profiles.ini` marks this the
  `Default=1` profile. `grep -oP` (this shell's `grep` is `ugrep 7.5.0`, PCRE-capable) cleanly
  extracts both values.
- **No existing sourceable-lib convention exists in this codebase** — the cleanest "cannot
  drift" fix consistent with the codebase's own precedent (`literature-ingest.sh` calling
  `literature-convert.sh` via command substitution, line 189) is a **new small script**,
  e.g. `zotero-resolve-sqlite-path.sh`, invoked by both callers via
  `ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"`. This is itself a third
  dual-copy pair (canonical + flat) and a new `manifest.json` `provides.scripts` entry.
- **Dual-copy re-sync mechanism confirmed**: the only *automated* mechanism is
  `M.copy_scripts` in `lua/neotex/plugins/ai/shared/extensions/loader.lua:308-342`, reachable
  only via the interactive `<leader>al` picker inside a running Neovim instance — there is no
  headless/CLI equivalent. Per task-793's own precedent, agents without a live nvim runtime
  use a manual `cp -p` + `diff` verification fallback, which is exactly the model to write into
  an implementation plan.
- **FIX 2's current wiring is fully located** in `literature.md` lines 125–218 (step "0." of
  Mode A discover). The NOT_RUNNING branch currently offers only "Generate now" (Path 3) /
  "Skip this run" (lines 168–174). No "Allow other applications on this computer to communicate
  with Zotero" wording exists anywhere in this codebase today — it must be authored fresh,
  matching `zotero-search.sh`'s numbered-heredoc style (lines 143–169 of that file).
- **The orchestrator-mode "silent empty file" target for FIX 2(d) is concretely**
  `zotero-generate-export.sh:542-551` (the `else` branch of the Path1/Path3 `if/elif/else`,
  reached only when neither API nor sqlite is found) which currently writes `ITEMS='[]'` and
  proceeds to `write_output` — producing a 0-item but exit-0 `zotero-library.json`. This is the
  literal bug to convert into a hard failure. A second, related location is `literature.md`'s
  orchestrator-mode branch (lines 203–213), whose current text conflates the RUNNING and
  NOT_RUNNING cases and needs to be split so NOT_RUNNING's orchestrator path no longer
  auto-invokes the generator expecting it might silently no-op.

## Context & Scope

Task 798 requires two fixes to the task-797 assisted Zotero export feature, surfaced by real
user testing on a machine (`~/Projects/Logos/Hardware`, but reproduced identically on this
`~/.config/nvim` box) where Zotero's data directory is *not* the Zotero default (`~/Zotero`)
but a custom location (`~/Documents/Zotero`) configured via Zotero's own "Data Directory"
setting. Both fixes touch exactly three files, all following the task-793 dual-copy model
(canonical under `.claude/extensions/literature/scripts/` or
`.claude/extensions/literature/commands/`, re-synced byte-identically to `.claude/scripts/`
where a flat copy exists).

Out of scope (per task description, confirmed unaffected by this research): Tier 3/Semantic
Scholar, the three-tier pipeline architecture, `literature.md`'s whole-script `2>/dev/null`
capture, the orphaned zot-CLI subsystem.

## Findings

### File 1: `zotero-export-status.sh` (classifier)

Canonical: `.claude/extensions/literature/scripts/zotero-export-status.sh` (168 lines).
Flat copy: `.claude/scripts/zotero-export-status.sh` — confirmed **byte-identical** via `diff`
(exit 0, no output) as of this research.

- **Line 74**: `ZOTERO_SQLITE="${ZOTERO_SQLITE_PATH:-${HOME}/Zotero/zotero.sqlite}"` — the bug.
- **Lines 53–55** (header doc comment) and **lines 24–30** describe the same hardcoded default
  and must be updated to describe the new 3-tier resolution order.
- **Lines 159–163**: the Path-3 viability probe —
  `if [ -f "$ZOTERO_SQLITE" ]; then ... echo "ZOTERO_EXPORT_MISSING_NOT_RUNNING"` — this is
  the exact branch that misfires today because the stale empty `~/Zotero/zotero.sqlite`
  satisfies `[ -f ... ]`.
- **No `SCRIPT_DIR` variable exists in this script today** (unlike `zotero-generate-export.sh`,
  which computes it at line 75). If the shared-helper approach uses a sibling-script
  subprocess call, `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` must be added
  near the top (after the `set -euo pipefail` line, ~line 67).
- Directive contract (stdout: exactly one token; stderr: rationale; never calls
  `AskUserQuestion`) is unaffected by FIX 1 — only the *value* fed into the existing `-f`
  check changes.

### File 2: `zotero-generate-export.sh` (generator)

Canonical: `.claude/extensions/literature/scripts/zotero-generate-export.sh` (566 lines).
Flat copy: `.claude/scripts/zotero-generate-export.sh` — confirmed **byte-identical**.

- **Line 84**: `ZOTERO_SQLITE="${ZOTERO_SQLITE_PATH:-${HOME}/Zotero/zotero.sqlite}"` — same
  bug, independently hardcoded (confirms the "cannot drift" requirement is real: these two
  expressions are currently kept in sync only by developer diligence, not by structure).
- **Lines 24, 60, 84, 197** all reference `~/Zotero/zotero.sqlite` and need updates (doc
  comments + the manual-fallback heredoc at lines 170–202, specifically line 197's "Ensure
  ~/Zotero/zotero.sqlite exists" instruction).
- **Line 75**: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` already exists —
  this script is ready to call a sibling helper script via `"$SCRIPT_DIR/helper.sh"` with no
  additional plumbing.
- **`fetch_path3()` (lines 319–408)**: confirmed structurally correct per the task's own manual
  verification (1819 valid Better-CSL-JSON entries with synthesized citekeys when
  `ZOTERO_SQLITE_PATH` is set correctly by hand) — **no changes needed here**, only to the
  `ZOTERO_SQLITE` resolution feeding it.
- **Lines 521–552 — the full Path-selection control flow**:
  ```
  API_PROBE="$(probe_zotero_api)"
  if [ "$API_PROBE" = "200" ]; then           # Path 1 (+ Path 2 enrichment)
  elif [ -f "$ZOTERO_SQLITE" ] && command -v sqlite3 &>/dev/null; then   # Path 3
  else                                          # <-- FIX 2(d) target
    if [ "$ORCHESTRATOR_MODE" = "true" ]; then
      echo "[zotero:auto] Rationale: ... orchestrator mode takes the visible default of
      writing an empty-but-valid zotero-library.json rather than a silent no-op. ..." >&2
      ITEMS='[]'; SOURCE="none-orchestrator-default"; SOURCE_PATH="n/a"
    else
      manual_fallback_text; exit 1
    fi
  fi
  ```
  This `else` block's `ORCHESTRATOR_MODE = "true"` sub-branch (lines 543–547) is the literal
  "silently-EMPTY … no error, useless result" failure mode the task's HONEST SCOPE NOTE names.
  It is reached whenever *neither* Path 1 nor Path 3 is viable at generator-invocation time —
  today, on this machine, this branch is **not** the one that produces the empty file (Path 3
  wrongly succeeds against the stale empty sqlite instead, via the `elif`); after FIX 1 lands
  and the resolution is correct, this `else`/orchestrator branch becomes the only path that can
  still silently write an empty file (a genuinely fresh Zotero install, no sqlite anywhere,
  Zotero closed). FIX 2(d) requires this specific sub-branch to stop writing `ITEMS='[]'` /
  calling `write_output` and instead print a visible error and exit non-zero (mirroring the
  existing non-orchestrator `else` branch's `manual_fallback_text; exit 1`, but phrased for an
  orchestrator context — "instructing the user to open Zotero", per the requirement).
- Exit-code table (lines 66–71) will need a new/adjusted code or reused `exit 1` for this
  no-longer-silent orchestrator failure; currently exit code 1 is documented as "manual
  fallback instructions printed to stderr" for the *non-orchestrator* case only — the doc
  comment must be updated if orchestrator mode now also exits 1 (or a distinct code) here.

### File 3: `literature.md` (Mode A discover, step "0.")

Canonical (no flat copy exists for `.claude/commands/`-analog files; `literature.md` itself
lives only under `.claude/extensions/literature/commands/literature.md` — confirmed this is
the sole copy, there is no `.claude/commands/literature.md` mirror to sync).

- **Lines 125–219**: the entire "Assisted Zotero export offer" step. Key sub-sections:
  - **Lines 129–138**: `STATUS_SCRIPT=".claude/scripts/zotero-export-status.sh"` /
    `GENERATE_SCRIPT=".claude/scripts/zotero-generate-export.sh"` — both reference the flat
    `.claude/scripts/` paths (correct; both are dual-copied there).
  - **Lines 145–185**: the interactive `AskUserQuestion` branch for
    `ZOTERO_EXPORT_MISSING_RUNNING` **and** `ZOTERO_EXPORT_MISSING_NOT_RUNNING` — today a single
    shared two-option prompt ("Generate now (recommended)" / "Skip this run") whose *description
    text only* differs by directive (lines 168–174). **This is the exact block FIX 2 must
    restructure** so the two directives diverge into different option sets:
    - `RUNNING` stays effectively as-is: "Generate now" (Path 1) / "Skip this run".
    - `NOT_RUNNING` becomes **three options**: (1) "Open Zotero, then retry" (new primary —
      re-invokes `zotero-export-status.sh` in a bounded 2–3 attempt loop, and on flipping to
      `RUNNING` calls `GENERATE_SCRIPT` for Path 1); (2) "Generate an offline snapshot without
      opening Zotero" (the *existing* Path-3-via-`GENERATE_SCRIPT` behavior, demoted to
      secondary per requirement (c) — literal text must be preserved/kept, not deleted); (3)
      "Skip this run" (unchanged).
  - **Lines 176–181**: "On 'Generate now'" success/failure handling — reusable verbatim for
    the new secondary Path-3 option; the new primary "Open Zotero, then retry" option needs
    equivalent handling authored fresh (loop bound, per-attempt `AskUserQuestion` or
    "press enter to retry" convention needs a decision from the planner — this codebase's
    `--lit` precedent (`literature-lit-flag-resolve.sh` / `AUTONOMOUS_GLOBAL`) is the closest
    existing pattern for a bounded-retry, visibly-logged loop, though that precedent doesn't
    literally retry a probe N times — it is a single classify-then-branch, not a loop. **No
    existing retry-loop-with-cap pattern exists elsewhere in this codebase to copy verbatim**;
    this will be genuinely new procedural logic authored directly into `literature.md`.
  - **Lines 187–201**: `ZOTERO_EXPORT_UNAVAILABLE` branch — untouched by FIX 2 (task scope is
    RUNNING/NOT_RUNNING only); manual-setup text here already matches `zotero-search.sh`'s
    wording style (lines 148–162 mirror `zotero-search.sh:150-165` closely) and can serve as
    the second style precedent alongside `zotero-search.sh` itself for the new "Allow other
    applications…" text.
  - **Lines 203–213**: orchestrator-mode branch. Currently a single paragraph covering both
    `RUNNING` and `NOT_RUNNING` with one deterministic action ("generate now" via
    `GENERATE_SCRIPT --orchestrator-mode true`). Per FIX 2(d), this needs to split:
    `RUNNING` keeps calling the generator (Path 1 is viable immediately, no human needed);
    `NOT_RUNNING` must **not** attempt the "open and retry" flow (impossible without a human)
    and, per the literal requirement, must fail loudly rather than silently defaulting —
    the plan should decide explicitly whether "fail loudly" here means (i) skip the generator
    call entirely and log an error pointing at opening Zotero, or (ii) still call the generator
    (which, after FIX 1, will usually succeed via a *correctly resolved* Path 3) and only the
    generator's own now-hardened `else` branch (see File 2 above) provides the loud-failure
    safety net for the true "nothing available" case. **Recommendation**: (ii) is more useful
    to users (Path 3 is a legitimate non-interactive success path once FIX 1 lands) and keeps
    the "never write an empty file" guarantee entirely inside the generator's own hardened
    logic rather than duplicating a data-source check in `literature.md`'s procedural text.
    This should be stated as an explicit design decision in the plan, since the task
    description's literal wording ("fail with a VISIBLE logged error instructing the user to
    open Zotero") is compatible with either reading.

### `zotero-search.sh` wording-style precedent (for FIX 2(b))

`zotero-search.sh` lines 143–169 is the canonical "no local data source, here's how to fix it"
heredoc style in this codebase:
```
if [[ ! -f "$LIBRARY_PATH" ]]; then
  cat >&2 << SETUP_INSTRUCTIONS

Error: Zotero library not found at: $LIBRARY_PATH

To set up Zotero CSL-JSON export:

1. Install the Better BibTeX plugin for Zotero:
   https://retorque.re/zotero-better-bibtex/
...
SETUP_INSTRUCTIONS
  exit 1
fi
```
No existing script or doc anywhere in this codebase mentions "Allow other applications on this
computer to communicate with Zotero" (confirmed via `grep -rn` across
`.claude/extensions/literature/`) — this text must be authored fresh for FIX 2(b), in the same
numbered/blank-line-separated heredoc style, e.g.:
```
Error: Zotero's local API is not responding, even though you said Zotero is open.

To fix this:

1. In Zotero, go to:
   Edit -> Settings -> Advanced

2. Enable:
   "Allow other applications on this computer to communicate with Zotero"

3. Retry this command.
```
(Exact wording/placement to be finalized by the planner; "Edit -> Settings" vs "Zotero ->
Settings" is platform-dependent — Linux/Windows use "Edit -> Settings", macOS uses
"Zotero -> Settings"; the plan should pick one or phrase it platform-neutrally, e.g. just
"Settings -> Advanced".)

### prefs.js format confirmed on this machine

- `profiles.ini` at `~/.zotero/zotero/profiles.ini`:
  ```
  [Profile0]
  Name=default
  IsRelative=1
  Path=pmqmra0p.default
  Default=1
  ```
  One profile, marked default. A robust resolver should honor `Default=1` when multiple
  profiles exist (not needed on this machine, but the task explicitly says "pick the default
  profile").
- `~/.zotero/zotero/pmqmra0p.default/prefs.js` (9426 bytes, 75 lines) contains, among many
  `user_pref(...)` lines:
  - Line 34: `user_pref("extensions.zotero.dataDir", "/home/benjamin/Documents/Zotero");`
  - Line 74: `user_pref("extensions.zotero.useDataDir", true);`
- `~/.mozilla/zotero/` does **not exist** on this machine — confirms the resolver must treat a
  missing base directory as a non-error, simply skipping to the next candidate / the final
  `${HOME}/Zotero` default.
- Extraction verified working via this shell's `grep` (aliased to `ugrep 7.5.0`, PCRE-capable
  via `-P`):
  ```bash
  grep -oP 'user_pref\("extensions\.zotero\.dataDir",\s*"\K[^"]+' "$prefs_file"
  # -> /home/benjamin/Documents/Zotero
  grep -oP 'user_pref\("extensions\.zotero\.useDataDir",\s*\K(true|false)' "$prefs_file"
  # -> true
  ```
  Both patterns returned exactly one match, correctly, with no false positives from the many
  other `extensions.zotero.*` lines in the file (translators.better-bibtex.*, sync.*, etc.).
  Portability note: `grep -P` requires PCRE support; GNU grep (most Linux distros) supports
  `-P` natively. `sed`-based extraction (`sed -n 's/.../\1/p'`) would be a safer
  zero-dependency fallback if strict POSIX/BSD-grep portability is a concern — worth deciding
  in the plan, though this codebase already assumes GNU/Linux tooling throughout (e.g. `date -u
  +%Y-%m-%dT%H:%M:%SZ` GNU date syntax used elsewhere in `zotero-generate-export.sh:492`).

### Dual-copy sync mechanism (task-793 model) — verified via sub-agent probe

- **Automated mechanism**: `M.copy_scripts` in
  `lua/neotex/plugins/ai/shared/extensions/loader.lua:308-342`, reachable only through the
  interactive `<leader>al` "Load Core" picker inside a running Neovim instance. Copies flat
  from `{extension}/scripts/*.sh` into `.claude/scripts/` (never nested), preserves the
  executable bit, honors `.syncprotect`.
- **No headless/CLI equivalent exists.** For an agent shell (no live nvim runtime), the
  established precedent from task-793's own implementation summary is a manual
  `cp -p <canonical> <flat>` followed by `diff` verification — exactly what task-797 did for
  these same two files (confirmed: current `diff` of both files shows zero output, i.e.
  byte-identical, as of this research).
- **Only `zotero-export-status.sh` and `zotero-generate-export.sh` are currently flat-copied**
  into `.claude/scripts/` in this repo — the other 8 `zotero-*.sh` scripts declared in
  `manifest.json`'s `provides.scripts` (search/read/write/setup/chunk/attach-chunks/index-add/
  index-remove) exist only under the canonical `.claude/extensions/literature/scripts/` path in
  this source repo and have no flat sibling here. This is expected/pre-existing (this repo is
  the extension's *source*, not every consuming repo needs every flat copy checked in) and is
  unrelated to task 798 — noted only so the planner doesn't mistake it for drift to fix.
- **Implication for the plan**: any new shared-helper script (e.g.
  `zotero-resolve-sqlite-path.sh`) needs (1) a canonical file under
  `.claude/extensions/literature/scripts/`, (2) a flat copy under `.claude/scripts/` (since its
  two callers are invoked via their flat `.claude/scripts/` paths per `literature.md:130-131`,
  the helper must be resolvable relative to `SCRIPT_DIR` in *both* the canonical and flat
  contexts — i.e. it must exist alongside whichever copy of the caller is actually running),
  and (3) a new entry in `.claude/extensions/literature/manifest.json`'s `provides.scripts`
  array (currently 10 zotero-*.sh entries, would become 11).

## Decisions

- **Shared-helper mechanism**: recommend a new standalone script (subprocess-invoked via
  `"$SCRIPT_DIR/zotero-resolve-sqlite-path.sh"`), matching this codebase's existing
  cross-script convention (`literature-ingest.sh:189`), rather than introducing a novel
  `source`-based shared-lib pattern that has no precedent here. `zotero-export-status.sh` needs
  a `SCRIPT_DIR` variable added (it currently lacks one); `zotero-generate-export.sh` already
  has one (line 75).
- **prefs.js extraction tool**: `grep -oP` is confirmed working on this machine; the plan
  should decide whether to require GNU-grep-compatible `-P` (matches existing codebase
  assumptions) or use a more portable `sed`/`awk` pattern instead.
- **Orchestrator-mode NOT_RUNNING behavior (FIX 2(d))**: recommend keeping the generator call
  in orchestrator mode for NOT_RUNNING (Path 3 becomes legitimately correct post-FIX-1) and
  concentrating the "never write an empty file, fail loudly instead" guarantee entirely inside
  `zotero-generate-export.sh`'s own `else` branch (lines 542–551) rather than duplicating a
  pre-check in `literature.md`. This is a recommendation, not a settled fact — flagged
  explicitly for the planner to confirm or override given the task's literal wording.

## Risks & Mitigations

- **Retry-loop authoring is genuinely new territory**: no existing bounded-retry-with-cap
  pattern exists in this codebase to copy. Mitigate by keeping the loop simple and
  procedural (a `for i in 1 2 3` style bound around `zotero-export-status.sh` re-invocation),
  documented plainly in `literature.md`'s prose-as-pseudocode style (this file is a workflow
  spec executed by an agent, not literal bash — the existing step "0." block already mixes
  real bash fences with branching prose, so the retry loop can follow the same convention).
- **Ambiguity in FIX 2(d)'s exact orchestrator behavior**: as noted above, the task wording
  supports two readings. Mitigate by having the plan state the chosen interpretation explicitly
  as a Decision, not leave it implicit.
- **Portability of `grep -P`**: mitigate by testing on this machine (confirmed working) and
  either documenting the GNU-grep dependency or switching to `sed`.
- **Manifest/flat-copy drift risk for the new helper script**: mitigate by including explicit
  `diff` verification steps in the plan for all three canonical/flat pairs (status, generate,
  and the new helper), exactly matching task-797's own verification pattern.

## Context Extension Recommendations

- **Topic**: Bash cross-script retry-loop-with-cap pattern.
- **Gap**: No documented convention exists for "poll an external process/state N times with a
  cap, non-interactively vs. interactively" in `.claude/context/` — this task will be the first
  instance in this codebase.
- **Recommendation**: after this task completes, consider extracting the retry-loop pattern
  into `.claude/context/project/literature/patterns/` (or similar) if a second consumer
  emerges; premature to create now for a single use site.

## Appendix

### Files read in full
- `.claude/extensions/literature/scripts/zotero-export-status.sh` (168 lines)
- `.claude/extensions/literature/scripts/zotero-generate-export.sh` (566 lines)
- `.claude/extensions/literature/commands/literature.md` (lines 100–330 of 446)
- `.claude/extensions/literature/scripts/zotero-search.sh` (lines 1–180 of full file)
- `specs/793_literature_extension_script_packaging/summaries/01_script-packaging-summary.md`
- `specs/797_literature_zotero_export_assisted_setup/summaries/01_assisted-zotero-export-generation-summary.md`

### Live verification commands run
```bash
diff .claude/extensions/literature/scripts/zotero-export-status.sh .claude/scripts/zotero-export-status.sh   # identical
diff .claude/extensions/literature/scripts/zotero-generate-export.sh .claude/scripts/zotero-generate-export.sh  # identical
ls -la ~/Zotero/zotero.sqlite ~/Documents/Zotero/zotero.sqlite
sqlite3 -readonly ~/Zotero/zotero.sqlite "SELECT COUNT(*) FROM items;"            # 0
sqlite3 -readonly ~/Documents/Zotero/zotero.sqlite "SELECT COUNT(*) FROM items;"  # 1819
grep -oP 'user_pref\("extensions\.zotero\.dataDir",\s*"\K[^"]+' ~/.zotero/zotero/pmqmra0p.default/prefs.js
grep -oP 'user_pref\("extensions\.zotero\.useDataDir",\s*\K(true|false)' ~/.zotero/zotero/pmqmra0p.default/prefs.js
cat ~/.zotero/zotero/profiles.ini
grep -n "zotero-export-status\|zotero-generate-export\|AskUserQuestion" .claude/extensions/literature/commands/literature.md
grep -n "Allow other applications" -r .claude/extensions/literature/   # no matches (confirms text must be authored fresh)
```

### Sub-agent findings incorporated
- Forked probe of the dual-copy sync mechanism: located `M.copy_scripts` in
  `lua/neotex/plugins/ai/shared/extensions/loader.lua:308-342`; confirmed manual `cp -p` +
  `diff` is the correct plan-step pattern for a headless agent shell.

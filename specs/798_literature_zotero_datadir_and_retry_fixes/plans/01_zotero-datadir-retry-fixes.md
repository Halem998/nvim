# Implementation Plan: Zotero dataDir Auto-Detection + Open-and-Retry Branch

- **Task**: 798 - Two follow-up fixes to task-797 assisted Zotero export generation (dataDir auto-detection + open-Zotero-and-retry interactive branch)
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: task-797 (COMPLETED), task-793 (COMPLETED)
- **Research Inputs**: specs/798_literature_zotero_datadir_and_retry_fixes/reports/01_zotero-datadir-retry-fixes.md
- **Artifacts**: plans/01_zotero-datadir-retry-fixes.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two fixes to the task-797 assisted Zotero export feature, touching three primary files under the
task-793 dual-copy model. FIX 1 replaces a hardcoded `${HOME}/Zotero/zotero.sqlite` default (duplicated
in `zotero-export-status.sh:74` and `zotero-generate-export.sh:84`) with a shared, prefs.js-driven
resolver so machines with a custom Zotero data directory read the real database instead of a stale
empty profile. FIX 2 restructures the NOT_RUNNING interactive branch in `literature.md` so the primary
choice becomes "Open Zotero, then retry" (bounded retry, live Path 1 API which is data-dir-agnostic),
keeps the sqlite snapshot as an explicit secondary, and hardens both the interactive and
orchestrator-mode paths so no code path ever silently writes an empty `zotero-library.json`.
Definition of done: all edited scripts pass `bash -n`; every canonical/flat pair is byte-identical;
the resolver resolves to `/home/benjamin/Documents/Zotero/zotero.sqlite` on this machine and the
generator reconstructs ~1819 entries; the classifier still emits exactly one directive token on stdout;
`literature-discover.sh` pure-JSON-array stdout contract is unchanged.

### Research Integration

Key findings integrated from `reports/01_zotero-datadir-retry-fixes.md`:
- Bug confirmed at exact lines: `zotero-export-status.sh:74` and `zotero-generate-export.sh:84`
  (byte-identical hardcoded expressions). Reproduced on this machine: `~/Zotero/zotero.sqlite`
  has 0 items; the real library `~/Documents/Zotero/zotero.sqlite` has 1819 rows.
- No source-based shared-lib convention exists in this codebase. The established cross-script pattern
  is subprocess invocation via `"$SCRIPT_DIR/other.sh"` (e.g. `literature-ingest.sh:189`). The
  "cannot drift" fix is a **new standalone script** invoked by both callers via command substitution.
- `zotero-export-status.sh` has **no** `SCRIPT_DIR` variable today and must gain one;
  `zotero-generate-export.sh:75` already has one.
- prefs.js format confirmed: `~/.zotero/zotero/profiles.ini` (`Default=1`), default profile's
  `prefs.js` has `user_pref("extensions.zotero.dataDir", "/home/benjamin/Documents/Zotero");` (line 34)
  and `user_pref("extensions.zotero.useDataDir", true);` (line 74). `~/.mozilla/zotero/` does not
  exist here — resolver must tolerate a missing base directory as a non-error.
- FIX 2(d) silent-empty target is `zotero-generate-export.sh:542-551` (the `else` branch that writes
  `ITEMS='[]'` then calls `write_output`). This is the literal bug to convert into a loud failure.
- No "Allow other applications on this computer to communicate with Zotero" wording exists anywhere
  in the codebase; it must be authored fresh in `zotero-search.sh:143-169`'s numbered-heredoc style.
- No existing bounded-retry-with-cap pattern exists to copy; the retry loop is genuinely new
  procedural logic authored into `literature.md`'s prose-as-pseudocode step "0.".
- Dual-copy re-sync has only one automated path (`M.copy_scripts`, interactive Neovim only). Agents
  use manual `cp -p` + `diff` verification (task-793/797 precedent).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path provided; no roadmap flag set).

## Design Decisions (Resolving Research-Flagged Open Questions)

**Decision A — Shared-helper mechanism (FIX 1).** Create a new standalone script
`zotero-resolve-sqlite-path.sh`, invoked by both callers via
`ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"`. This matches the codebase's existing
subprocess convention and structurally guarantees the two callers cannot drift. The resolver only
resolves and prints a path string to stdout; it performs **no** existence check — callers keep their
own `[ -f "$ZOTERO_SQLITE" ]` probes, preserving current classifier/generator semantics. Resolution
order (first match wins): (1) `$ZOTERO_SQLITE_PATH` explicit override; (2) `<dataDir>/zotero.sqlite`
when `extensions.zotero.useDataDir` is `true` and `extensions.zotero.dataDir` is found in the default
profile prefs.js; (3) `${HOME}/Zotero/zotero.sqlite` default. Default-profile selection honors
`Default=1` in `profiles.ini`; both `~/.zotero/zotero/` and `~/.mozilla/zotero/` base dirs are
searched and a missing base dir is skipped silently.

**Decision B — prefs.js extraction tool (FIX 1).** Use `grep -oP` (PCRE), matching the codebase's
existing GNU/Linux tooling assumptions (e.g. GNU `date -u` in `zotero-generate-export.sh:492`);
research confirmed both patterns extract cleanly on this machine (ugrep 7.5.0, PCRE-capable). A
short comment in the resolver documents the GNU-grep `-P` dependency. Not adopting `sed`/`awk`
fallback to keep the helper small and readable; revisit only if a non-GNU consumer emerges.

**Decision C — Retry-loop implementation approach (FIX 2, resolving open question 2).** Implement a
**bounded interactive loop, max 3 attempts**, authored as numbered prose-pseudocode in `literature.md`
step "0." (this file is an agent-executed workflow spec, not literal bash — it already mixes bash
fences with branching prose). Each attempt uses one `AskUserQuestion` with choices
["I've opened Zotero — retry now" / "Generate an offline snapshot instead" / "Skip this run"]; on
"retry now" the workflow re-invokes `STATUS_SCRIPT` and inspects the single directive token. If it
flips to `ZOTERO_EXPORT_MISSING_RUNNING`, generate via Path 1 (live API, data-dir-agnostic) and stop.
If after 3 attempts it is still not RUNNING (Zotero unopened, or open-but-API-disabled), surface the
freshly-authored "Allow other applications…" enable-API guidance, then present the secondary Path 3
snapshot option and skip. The explicit cap guarantees an unopened/unreachable Zotero cannot loop
forever (requirement (a)).

**Decision D — Orchestrator-mode NOT_RUNNING behavior (FIX 2(d), resolving open question 1).** Adopt
reading (ii) from the research: in orchestrator/non-interactive mode, do **not** loop or prompt, and
do **not** duplicate a data-source pre-check in `literature.md`. For NOT_RUNNING, `literature.md`
still calls `GENERATE_SCRIPT --orchestrator-mode true`; the "never write an empty file, fail loudly
instead" guarantee is concentrated entirely inside the generator's own hardened `else` branch
(`zotero-generate-export.sh:542-551`, hardened in Phase 3). Rationale: post-FIX-1, Path 3 against a
correctly-resolved sqlite is a legitimate non-interactive success path, so calling the generator is
useful; only the genuine "no data source anywhere" case reaches the `else` branch, which now prints a
visible error instructing the user to open Zotero and exits non-zero (no `ITEMS='[]'`, no
`write_output`). This satisfies requirement (d) — no loop, no prompt, no silent empty file, no silent
no-op — while keeping the guarantee in one place. The `literature.md` orchestrator paragraph
(lines 203-213) is split so RUNNING and NOT_RUNNING are described distinctly, both delegating the
loud-failure safety net to the generator.

## Goals & Non-Goals

**Goals**:
- Resolve the Path 3 sqlite path identically in both scripts via a shared, prefs.js-driven helper.
- Auto-detect a custom Zotero data directory (`extensions.zotero.dataDir` when `useDataDir=true`) from
  the default profile prefs.js, tolerating a missing `~/.mozilla/zotero/` base dir.
- Restructure the NOT_RUNNING interactive branch into "Open Zotero, then retry" (primary, Path 1),
  "offline snapshot" (secondary, Path 3), and "skip", with a bounded (max 3) retry loop.
- Author fresh enable-API guidance ("Allow other applications on this computer to communicate with
  Zotero") in the `zotero-search.sh` heredoc style.
- Harden the generator's orchestrator-mode `else` branch to fail loudly instead of writing an empty
  export; split the `literature.md` orchestrator paragraph accordingly.
- Maintain byte-identical canonical/flat copies for all three flat-copied scripts plus the new helper,
  and register the helper in `manifest.json`.

**Non-Goals**:
- Tier 3 / Semantic Scholar integration.
- Three-tier pipeline architecture changes.
- The `literature.md` whole-script `2>/dev/null` capture.
- The orphaned zot-CLI subsystem.
- Any change to `fetch_path3()` reconstruction logic (confirmed correct; only its input path changes).
- Flat-copying the other 8 zotero-*.sh scripts that currently exist only under the canonical path
  (pre-existing, unrelated to this task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Canonical/flat drift for the new helper or edited scripts | H | M | Phase 5 runs `diff` on all four canonical/flat pairs; each edit phase re-syncs with `cp -p` immediately and diffs before completing |
| `grep -P` unavailable on some consumer machine | M | L | Decision B documents the GNU-grep dependency in-script; resolver still degrades to the `${HOME}/Zotero` default (never crashes) when parsing yields nothing |
| Resolver returns a path that does not exist, breaking callers | H | L | Resolver only produces a string; callers keep their existing `[ -f ]` checks; classifier directive contract unchanged (Phase 2 + Phase 5 verify single-token stdout) |
| Retry loop is novel territory with no pattern to copy | M | M | Decision C keeps it a simple, explicit, capped procedural loop in prose-pseudocode; Phase 4 authors it plainly and bounds it at 3 attempts |
| Hardened `else` branch changes exit semantics | M | L | Phase 3 updates the exit-code doc table (lines 66-71) to match; reuses `exit 1` consistent with the existing non-orchestrator fallback |
| Multiple/absent Zotero profiles | M | L | Resolver honors `Default=1` in `profiles.ini`, skips missing base dirs, and falls through to the `${HOME}/Zotero` default when no profile resolves |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Create shared sqlite-path resolver + manifest registration + flat copy [COMPLETED]

- **Goal:** Introduce `zotero-resolve-sqlite-path.sh` implementing Decisions A and B, register it in
  the manifest, and deploy its flat copy.
- **Files to modify (ownership):**
  - `.claude/extensions/literature/scripts/zotero-resolve-sqlite-path.sh` (NEW canonical) - create
    the resolver.
  - `.claude/scripts/zotero-resolve-sqlite-path.sh` (NEW flat copy) - byte-identical `cp -p`.
  - `.claude/extensions/literature/manifest.json` - add the new script to `provides.scripts`
    (10 -> 11 zotero-*.sh entries).
- **Tasks:**
  - [x] Write `zotero-resolve-sqlite-path.sh` with `#!/usr/bin/env bash`, `set -euo pipefail`, and a
        header doc comment stating the 3-tier resolution order and the GNU-grep `-P` dependency. *(completed)*
  - [x] Implement resolution order: (1) if `${ZOTERO_SQLITE_PATH:-}` is non-empty, echo it and exit 0;
        (2) locate the default profile prefs.js, and if `useDataDir=true` and `dataDir` is found, echo
        `<dataDir>/zotero.sqlite`; (3) else echo `${HOME}/Zotero/zotero.sqlite`.
  - [x] Profile discovery: iterate candidate base dirs `~/.zotero/zotero` and `~/.mozilla/zotero`;
        skip any that do not exist (no error). For each, parse `profiles.ini` and select the section
        with `Default=1` (fall back to the first profile / a lone `*.default` dir if no `Default=1`);
        resolve its `Path=` relative to the base dir. Stop at the first prefs.js that yields a usable
        `dataDir`.
  - [x] Extract values with
        `grep -oP 'user_pref\("extensions\.zotero\.useDataDir",\s*\K(true|false)'` and
        `grep -oP 'user_pref\("extensions\.zotero\.dataDir",\s*"\K[^"]+'`; only honor `dataDir` when
        `useDataDir` is exactly `true`.
  - [x] Ensure the script prints exactly one path line to stdout and nothing else on the happy path
        (no stderr noise required; keep it quiet so command substitution is clean).
  - [x] `chmod +x` the canonical file; `cp -p` to the flat path; confirm the executable bit is set on
        both.
  - [x] Add `"zotero-resolve-sqlite-path.sh"` to `manifest.json` `provides.scripts`.
- **Timing:** 0.75 hours
- **Depends on:** none
- **Verification:**
  - `bash -n .claude/extensions/literature/scripts/zotero-resolve-sqlite-path.sh` exits 0.
  - `diff .claude/extensions/literature/scripts/zotero-resolve-sqlite-path.sh .claude/scripts/zotero-resolve-sqlite-path.sh`
    produces no output.
  - `.claude/scripts/zotero-resolve-sqlite-path.sh` on this machine prints
    `/home/benjamin/Documents/Zotero/zotero.sqlite`.
  - `ZOTERO_SQLITE_PATH=/tmp/x.sqlite .claude/scripts/zotero-resolve-sqlite-path.sh` prints
    `/tmp/x.sqlite` (override wins).
  - `jq -e '.provides.scripts | index("zotero-resolve-sqlite-path.sh")' .claude/extensions/literature/manifest.json`
    succeeds.

---

### Phase 2: Wire resolver into `zotero-export-status.sh` (classifier) + flat copy [NOT STARTED]

- **Goal:** Replace the hardcoded default at line 74 with a resolver call, add the missing
  `SCRIPT_DIR`, update doc comments, and re-sync the flat copy — without altering the single-directive
  stdout contract.
- **Files to modify (ownership):**
  - `.claude/extensions/literature/scripts/zotero-export-status.sh` (canonical).
  - `.claude/scripts/zotero-export-status.sh` (flat copy).
- **Tasks:**
  - [ ] Add `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` near the top (after
        `set -euo pipefail`, ~line 67).
  - [ ] Replace line 74 `ZOTERO_SQLITE="${ZOTERO_SQLITE_PATH:-${HOME}/Zotero/zotero.sqlite}"` with
        `ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"`.
  - [ ] Update the header/doc comments (lines 24-30 and 53-55) to describe the new 3-tier resolution
        order instead of the old hardcoded default.
  - [ ] Leave the Path-3 viability probe (lines 159-163) structurally unchanged — it now `-f`-tests
        the correctly resolved path.
  - [ ] `cp -p` canonical -> flat.
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Verification:**
  - `bash -n` on both canonical and flat copies exits 0.
  - `diff` of canonical vs flat produces no output.
  - Running the classifier on this machine emits exactly one directive token on stdout with rationale
    on stderr; with the real `~/Documents/Zotero` library present it no longer misclassifies via the
    stale empty `~/Zotero` DB.
  - Confirm stdout contains exactly one line/token (e.g. `[ "$(script | wc -l)" -eq 1 ]`).

---

### Phase 3: Wire resolver into `zotero-generate-export.sh` (FIX 1) + harden orchestrator else branch (FIX 2d) + flat copy [NOT STARTED]

- **Goal:** Replace the hardcoded default at line 84 with the resolver call, update doc comments, and
  convert the silent-empty orchestrator `else` sub-branch (lines 542-551) into a loud, non-zero
  failure; re-sync the flat copy.
- **Files to modify (ownership):**
  - `.claude/extensions/literature/scripts/zotero-generate-export.sh` (canonical).
  - `.claude/scripts/zotero-generate-export.sh` (flat copy).
- **Tasks:**
  - [ ] Replace line 84 with `ZOTERO_SQLITE="$("$SCRIPT_DIR/zotero-resolve-sqlite-path.sh")"`
        (`SCRIPT_DIR` already exists at line 75 — no plumbing needed).
  - [ ] Update doc comments referencing `~/Zotero/zotero.sqlite` (lines 24, 60) and the manual-fallback
        heredoc instruction at line 197 to describe the 3-tier resolution.
  - [ ] In the Path-selection `else` block (lines 542-551), change the `ORCHESTRATOR_MODE = "true"`
        sub-branch so it no longer sets `ITEMS='[]'` / `SOURCE="none-orchestrator-default"` and no
        longer proceeds to `write_output`. Instead print a visible stderr error (heredoc/echo)
        instructing the user to open Zotero so the live API or a resolved sqlite becomes available,
        then `exit 1`. This mirrors the existing non-orchestrator `manual_fallback_text; exit 1`
        pattern but phrased for orchestrator context (per Decision D).
  - [ ] Update the exit-code doc table (lines 66-71) so `exit 1` (or a chosen distinct code) covers the
        orchestrator-mode "no data source available" loud failure, not only the non-orchestrator case.
  - [ ] Leave `fetch_path3()` (lines 319-408) unchanged.
  - [ ] `cp -p` canonical -> flat.
- **Timing:** 0.75 hours
- **Depends on:** 1
- **Verification:**
  - `bash -n` on both copies exits 0.
  - `diff` canonical vs flat produces no output.
  - `ZOTERO_SQLITE_PATH=/home/benjamin/Documents/Zotero/zotero.sqlite` (and, separately, letting the
    resolver auto-detect) drives `fetch_path3()` to reconstruct ~1819 valid Better-CSL-JSON entries.
  - Simulate the no-data-source orchestrator case (API down + resolver path missing, e.g.
    `ZOTERO_SQLITE_PATH=/nonexistent` with `--orchestrator-mode true`): the script exits non-zero,
    prints a visible error to stderr, and writes **no** `zotero-library.json` (assert the output file
    is not created/overwritten and contains no `[]`).

---

### Phase 4: Restructure `literature.md` NOT_RUNNING branch (FIX 2 a/b/c/d) [NOT STARTED]

- **Goal:** Split the shared RUNNING/NOT_RUNNING prompt into directive-specific option sets, add the
  bounded "Open Zotero, then retry" primary path with fresh enable-API guidance, keep Path 3 as an
  explicit secondary, and split the orchestrator-mode paragraph per Decision D. Single canonical file
  (no flat copy exists for `.claude/commands/`-analog files).
- **Files to modify (ownership):**
  - `.claude/extensions/literature/commands/literature.md` (canonical only; no mirror to sync).
- **Tasks:**
  - [ ] Split the interactive `AskUserQuestion` block (lines 145-185) so `ZOTERO_EXPORT_MISSING_RUNNING`
        keeps its current two-option prompt ("Generate now" -> Path 1 / "Skip this run"), while
        `ZOTERO_EXPORT_MISSING_NOT_RUNNING` gets three options: (1) "Open Zotero, then retry" (new
        primary); (2) "Generate an offline snapshot without opening Zotero" (existing Path-3 behavior,
        text preserved, demoted to secondary per requirement (c)); (3) "Skip this run".
  - [ ] Author the bounded retry loop (Decision C): max 3 attempts; each attempt re-invokes
        `STATUS_SCRIPT` and inspects the single directive token; on flip to
        `ZOTERO_EXPORT_MISSING_RUNNING` call `GENERATE_SCRIPT` (Path 1) and stop; between attempts use
        one `AskUserQuestion` with ["I've opened Zotero — retry now" / "Generate an offline snapshot
        instead" / "Skip this run"]. Express as numbered prose-pseudocode consistent with step "0."'s
        existing style; state the cap explicitly (requirement (a)).
  - [ ] After the retry cap is exhausted (still not RUNNING / API non-200 though user says Zotero is
        open), surface freshly-authored enable-API guidance in the `zotero-search.sh:143-169`
        numbered-heredoc style (requirement (b)): platform-neutral "Settings -> Advanced" +
        "Allow other applications on this computer to communicate with Zotero" + retry instruction.
        Then offer the secondary Path 3 snapshot and skip.
  - [ ] Reuse the existing "On 'Generate now'" success/failure handling (lines 176-181) verbatim for
        the secondary Path 3 option.
  - [ ] Split the orchestrator-mode paragraph (lines 203-213): RUNNING keeps calling
        `GENERATE_SCRIPT --orchestrator-mode true` (Path 1 immediately viable); NOT_RUNNING also calls
        `GENERATE_SCRIPT --orchestrator-mode true` but the prose states it does **not** loop/prompt and
        relies on the generator's hardened `else` branch (Phase 3) for the loud-failure / never-empty
        guarantee (Decision D). Do not duplicate a data-source pre-check here.
  - [ ] Leave the `ZOTERO_EXPORT_UNAVAILABLE` branch (lines 187-201) untouched.
- **Timing:** 1 hour
- **Depends on:** 2, 3
- **Verification:**
  - Manual read-through: NOT_RUNNING presents exactly three options; primary is the retry path;
    secondary Path-3 text is preserved; skip remains.
  - Retry loop has an explicit numeric cap (<= 3) and cannot loop indefinitely.
  - Enable-API guidance text is present, platform-neutral, and matches the numbered-heredoc style.
  - Orchestrator-mode prose is split into distinct RUNNING and NOT_RUNNING descriptions, neither
    looping nor prompting, both deferring the never-empty guarantee to the generator.
  - No accidental change to the `2>/dev/null` capture or other out-of-scope regions (diff review).

---

### Phase 5: Full integration verification + re-sync audit [NOT STARTED]

- **Goal:** Run the complete verification battery required by the task across all edited files and
  confirm no canonical/flat drift.
- **Files to modify (ownership):** none (verification only; if any diff is found, re-run `cp -p` for
  the affected pair and re-verify).
- **Tasks:**
  - [ ] `bash -n` on all four scripts (resolver, status, generate — canonical and flat copies).
  - [ ] `diff` each canonical/flat pair (resolver, status, generate) — all must produce no output.
  - [ ] End-to-end resolver test: `.claude/scripts/zotero-resolve-sqlite-path.sh` resolves to
        `/home/benjamin/Documents/Zotero/zotero.sqlite` via prefs.js auto-detection (no
        `ZOTERO_SQLITE_PATH` set).
  - [ ] End-to-end generator test: with auto-detection, `zotero-generate-export.sh` reconstructs
        ~1819 Better-CSL-JSON entries into a non-empty `zotero-library.json`.
  - [ ] Classifier contract: `zotero-export-status.sh` emits exactly one directive token on stdout,
        rationale on stderr, and correctly classifies given the resolved (non-stale) DB.
  - [ ] Orchestrator loud-failure: no-data-source orchestrator invocation exits non-zero with a
        visible error and never writes an empty export.
  - [ ] `literature-discover.sh` stdout is still a pure JSON array (unchanged contract) — run it and
        confirm `jq -e 'type == "array"'` succeeds on its stdout.
  - [ ] `manifest.json` lists `zotero-resolve-sqlite-path.sh` in `provides.scripts`.
- **Timing:** 0.75 hours
- **Depends on:** 1, 2, 3, 4
- **Verification:**
  - All checks above pass; any drift found is re-synced and re-diffed to zero output.

---

## Testing & Validation

- [ ] `bash -n` passes on `zotero-resolve-sqlite-path.sh`, `zotero-export-status.sh`, and
      `zotero-generate-export.sh` (both canonical and flat copies).
- [ ] `diff` between each canonical and flat copy (resolver, status, generate) produces no output.
- [ ] Resolver auto-detects and prints `/home/benjamin/Documents/Zotero/zotero.sqlite` on this machine
      (no env override) and honors `$ZOTERO_SQLITE_PATH` when set.
- [ ] Generator reconstructs ~1819 Better-CSL-JSON entries into a non-empty `zotero-library.json`.
- [ ] Classifier emits exactly one directive token on stdout with rationale on stderr.
- [ ] Orchestrator-mode no-data-source path exits non-zero with a visible error and writes no empty
      file (never silent no-op).
- [ ] `literature-discover.sh` stdout remains a pure JSON array.
- [ ] `manifest.json` `provides.scripts` includes the new helper.
- [ ] `literature.md` NOT_RUNNING branch presents three options with a bounded (<= 3) retry loop and
      fresh enable-API guidance.

## Artifacts & Outputs

- `.claude/extensions/literature/scripts/zotero-resolve-sqlite-path.sh` (new canonical resolver)
- `.claude/scripts/zotero-resolve-sqlite-path.sh` (new flat copy)
- `.claude/extensions/literature/manifest.json` (updated `provides.scripts`)
- `.claude/extensions/literature/scripts/zotero-export-status.sh` + `.claude/scripts/` flat copy (edited)
- `.claude/extensions/literature/scripts/zotero-generate-export.sh` + `.claude/scripts/` flat copy (edited)
- `.claude/extensions/literature/commands/literature.md` (edited, canonical only)
- specs/798_literature_zotero_datadir_and_retry_fixes/summaries/01_zotero-datadir-retry-fixes-summary.md
  (on completion)

## Rollback/Contingency

All changes are localized to the literature extension. To revert: `git checkout` the six edited/created
files (resolver canonical+flat, manifest, status canonical+flat, generate canonical+flat, literature.md)
and delete the two new resolver files if the commit is being unwound before it lands. Because callers
retain their own `[ -f ]` existence checks and the resolver falls through to the original
`${HOME}/Zotero/zotero.sqlite` default when parsing yields nothing, a partial rollback (reverting only
the resolver while leaving the caller edits) degrades to the pre-fix behavior rather than crashing.
The canonical/flat `diff` gate in Phase 5 prevents shipping a half-synced pair.

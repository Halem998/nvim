# Implementation Plan: Task #799

- **Task**: 799 - Fix literature-briefing.sh authors-type crash + harden per-entry resilience
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/799_literature_briefing_authors_type_crash_fix/reports/01_authors-type-crash-fix.md
- **Artifacts**: plans/01_authors-type-crash-fix.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`.claude/scripts/literature-briefing.sh` aborts on the first sub-index doc_id whenever that
entry's global-index `.authors` is a plain string: line 143-145 runs `(.authors // []) | join(", ")`,
which throws `Cannot iterate over string` (jq exit 5); under `set -euo pipefail` the bare
(non-`local`) command substitution propagates that exit and kills the whole script mid-loop, so
`--lit` callers receive an empty briefing (`LIT bytes: 0`). The fix normalizes the authors jq to
handle both string and array types (mirroring `literature-discover.sh:281`), and adds
defense-in-depth `|| default` fallbacks with stderr warnings to the remaining unguarded per-entry
substitutions that feed bash arithmetic. Definition of done: the briefing runs to completion
against the cslib sub-index with correct author rendering for both a string-typed and an
array-typed entry, exit 0, while all legitimately-empty `exit 0` paths remain unchanged.

### Research Integration

The research report (`reports/01_authors-type-crash-fix.md`) confirmed the root cause by live
reproduction (`bash -x` traced the abort to `authors_raw=$(...)` on the first doc_id, exit 5) and
enumerated the full per-entry hardening surface. Key integrated findings:
- The authors line (143-145) is the ONLY confirmed jq crash vector — `join` is the only per-entry
  operation that throws on realistic mistyped input. Mandatory fix.
- `parent_tokens` (162-164) and the no-chunks-branch `total_tokens` (167-169) are the only other
  currently-unguarded top-level substitutions; `parent_tokens` feeds bash arithmetic
  (`$(( total_tokens + parent_tokens ))`, line 165) with no numeric validation — a secondary,
  currently-unobserved risk closed in the same pass (recommended defense-in-depth).
- Research REJECTED function-wrapping and global `set +e` relaxation as unnecessarily invasive.
- Corrected verification target: the real cslib sub-index has 11 entries (NOT the 12 in the task
  description) and does NOT include `blackburn_2001` — only `blackburn_2002_book`. It exercises
  both the string path (10 entries) and array path (1 entry: `blackburn_2002_book`).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (meta bug-fix; no roadmap_path provided).

## Goals & Non-Goals

**Goals**:
- Eliminate the mid-loop abort so the briefing never dies on a single string-typed or otherwise
  mistyped per-entry field; a bad field degrades to a sane default with a stderr warning instead.
- Normalize authors rendering for both string-typed and array-typed `.authors` at line 143-145.
- Add `|| default` fallbacks + numeric guard to the remaining unguarded per-entry substitutions
  (`parent_tokens`, no-chunks-branch `total_tokens`) as defense-in-depth.
- Preserve the existing contract: silent `exit 0` when legitimately empty; existing
  "doc_id not found -> warn + continue" skip path unchanged.
- Verify against the actual 11-entry cslib sub-index with `LITERATURE_DIR=~/Projects/Literature`.

**Non-Goals**:
- Function-wrapping the loop body or relaxing `set -e`/`pipefail` (rejected by research).
- Changing the empty-briefing behavior or the global-corpus (`--global`) code path.
- Cross-repo propagation to child-project copies (cslib, Logos/Hardware, BimodalLogic). Flagged
  explicitly in Rollback/Contingency; treated as out-of-scope for this task since the config repo
  is the declared source of truth.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Authors-line rewrite still throws if an array element is a non-scalar object | M | L | Not present in current data (all array entries are string elements); the `\|\| authors_raw=""` tail guard closes the residual gap |
| A `\|\| default` fallback masks a genuinely corrupt `$GLOBAL_INDEX` | M | L | Fallbacks fire only on the narrow per-entry substitutions; the file-existence/empty checks (lines 94-108) still surface a missing/broken index; each fallback emits a stderr warning so a real problem is visible |
| Edit accidentally alters the empty-`exit 0` paths | M | L | Phase 2 explicitly re-verifies all three empty paths (missing sub-index, empty entries, missing global index) still exit 0 with empty stdout |
| Verification uses task-description's stale 12-entry list | L | M | Use the research report's corrected 11-entry list; assert count == 11 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Apply authors normalization + per-entry arithmetic-fallback hardening [COMPLETED]

**Goal**: Fix the confirmed authors-type crash and close the remaining unguarded per-entry
substitutions in the repo-mode loop, so no single bad entry can abort the run.

**Tasks**:
- [x] In `/home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh`, replace the authors
      substitution (lines 143-145) with the type-normalizing pattern from
      `literature-discover.sh:281`, plus a tail guard:
      ```bash
      authors_raw=$(jq -r --arg id "$doc_id" '
        .entries[] | select(.id == $id) | (.authors // [] | if type == "array" then . else [.] end | join(", "))
      ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || authors_raw=""
      ``` *(completed)*
- [x] Harden `parent_tokens` (lines 162-164): add `|| parent_tokens=0` to the substitution, then a
      numeric guard before the arithmetic at line 165:
      `[[ "$parent_tokens" =~ ^[0-9]+$ ]] || { echo "Warning: non-numeric parent token_count for '$doc_id', defaulting to 0" >&2; parent_tokens=0; }` *(completed)*
- [x] Harden the no-chunks-branch `total_tokens` (lines 167-169): add
      `|| { echo "Warning: could not read token_count for '$doc_id', defaulting to 0" >&2; total_tokens=0; }`
      and a numeric guard (`[[ "$total_tokens" =~ ^[0-9]+$ ]] || total_tokens=0`) since it is
      interpolated as `~${total_tokens} tokens`. *(completed)*
- [x] Leave `title`, `year`, `chunk_count`, chunks-branch `total_tokens`, `parent_path`,
      `relevance`, and the two `parent_entry` lookups unchanged (research: `-r`/`tostring`/`length`
      never throw on type; `chunk_count` and chunks-branch `total_tokens` already have `|| echo 0`). *(completed)*
- [x] Do NOT wrap the loop body in a function and do NOT relax `set -e`/`pipefail` (research
      rejected both). *(completed)*

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh` - authors-line rewrite
  (143-145), `parent_tokens` guard (162-165), no-chunks `total_tokens` guard (167-169).

**Verification**:
- [x] `bash -n /home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh` reports no
      syntax errors. *(completed)*
- [x] Visual diff shows ONLY the authors line and the two token substitutions changed; the empty
      `exit 0` guards (94-108, 223-226) and the `--global` branch are untouched. *(completed)*

---

### Phase 2: Verify against cslib sub-index and confirm empty-exit-0 paths [COMPLETED]

**Goal**: Confirm the fixed script produces a populated briefing with correct author rendering for
both author types against the real 11-entry cslib sub-index, exits 0, and that all
legitimately-empty branches still exit 0 with empty stdout.

**Tasks**:
- [x] Run the briefing against the cslib sub-index and confirm exit 0. *(deviation: altered —
      the config-repo copy's `PROJECT_ROOT`/`SUB_INDEX` derives from the script's own
      `$SCRIPT_DIR/../..`, so running it directly from `~/Projects/cslib` would not resolve
      `~/Projects/cslib/specs/literature-index.json`; per the plan's own recipe note ("it may
      copy the cslib sub-index to a scratch location") and the task instructions ("verify against
      the CONFIG-REPO copy... do NOT edit child-project copies"), the config-repo's fixed
      `literature-briefing.sh` and cslib's `specs/literature-index.json` were copied into a
      scratch dir (`/tmp/.../scratchpad/verify799/`) mirroring the research report's own
      reproduction method, then run with `LITERATURE_DIR=~/Projects/Literature`)*.
      Result: `EXIT: 0` (previously exit 5 with empty stdout). *(completed)*
- [x] Confirm all 11 entries render (corrected list; NOT the task's 12-entry list which wrongly
      includes `blackburn_2001`). Result: `grep -c '^[0-9]*\. \*\*'` → `11`. *(completed)*
- [x] Confirm string-typed author renders (burgess_1982_i -> "John P. Burgess"): output contains
      `Burgess` — line 1: `**Axioms for Tense Logic. I. "Since" and "Until"** (1982) — John P.
      Burgess`. *(completed)*
- [x] Confirm array-typed author renders (blackburn_2002_book -> "Patrick Blackburn, Maarten de
      Rijke, Yde Venema"): output contains `Blackburn` with no double-splitting/garbling — line
      11: `**Modal Logic (2002 Cambridge edition)** (2002) — Patrick Blackburn, Maarten de Rijke,
      Yde Venema`. *(completed)*
- [x] Confirm the three legitimately-empty paths still exit 0 with empty stdout (contract
      preserved):
      - Missing sub-index: fresh scratch dir with the fixed script but no
        `specs/literature-index.json` -> `EXIT: 0`, 0 stdout bytes. *(completed)*
      - Missing global index: `LITERATURE_DIR=/nonexistent_lit_dir_xyz` against the scratch dir
        with a sub-index present -> `EXIT: 0`, 0 stdout bytes, stderr:
        `Warning: Global index not found at /nonexistent_lit_dir_xyz/index.json`. *(completed)*
      - Empty entries: scratch sub-index with `.entries: []` -> `EXIT: 0`, 0 stdout bytes.
        *(completed)*
- [x] Confirm no unexpected stderr `Warning:` lines appear in the normal cslib run (fallbacks
      should NOT fire on well-typed data): stderr was empty on the 11-entry cslib run.
      *(completed)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- [x] All commands above produce the expected exit codes and counts. *(completed)*
- [x] Author rendering is correct for both a string-typed (`burgess_1982_i`) and an array-typed
      (`blackburn_2002_book`) entry. *(completed)*

---

## Testing & Validation

- [x] `bash -n` clean on the modified script.
- [x] cslib sub-index run: exit 0, 11 entries, correct rendering for both author types.
- [x] String-typed (`burgess_1982_i`) and array-typed (`blackburn_2002_book`) authors both render
      correctly.
- [x] All three empty-`exit 0` contract paths (missing sub-index, missing global index, empty
      entries) still exit 0 with empty stdout.
- [x] No spurious stderr `Warning:` output on well-typed data.

## Artifacts & Outputs

- `/home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh` (modified: authors line +
  two token-substitution guards)
- `specs/799_literature_briefing_authors_type_crash_fix/plans/01_authors-type-crash-fix.md` (this plan)
- `specs/799_literature_briefing_authors_type_crash_fix/summaries/01_authors-type-crash-fix-summary.md`
  (produced by /implement)

## Rollback/Contingency

- The change is confined to one file and three substitution sites. To revert:
  `git checkout -- .claude/scripts/literature-briefing.sh`.
- If verification fails, the pre-fix behavior (exit 5, empty briefing) is the prior state; no data
  or index files are touched, so revert is clean.
- **Child-project propagation (out-of-scope, flagged not silently skipped)**: `~/Projects/cslib`
  and `~/Projects/Logos/Hardware` copies are byte-identical to this source of truth and carry the
  same bug at the same line; `~/Projects/BimodalLogic` is structurally older but has the same
  vulnerable authors expression. The identical one-line authors fix (and, for cslib/Logos, the
  per-entry guards) would apply verbatim to cslib and Logos/Hardware; BimodalLogic needs the
  authors-line pattern applied at its own equivalent line. Per the task (config repo is the source
  of truth), cross-repo propagation is deferred to a separate follow-up rather than performed here.

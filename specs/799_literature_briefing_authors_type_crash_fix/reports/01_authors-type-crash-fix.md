# Research Report: Task #799

**Task**: 799 - Fix literature-briefing.sh authors-type crash + harden per-entry resilience
**Started**: 2026-07-01T00:00:00Z
**Completed**: 2026-07-01T00:00:00Z
**Effort**: 1-3 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (`.claude/scripts/literature-briefing.sh`, `literature-discover.sh`), live reproduction against `~/Projects/Literature/index.json` and `~/Projects/cslib/specs/literature-index.json`
**Artifacts**: - specs/799_literature_briefing_authors_type_crash_fix/reports/01_authors-type-crash-fix.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed by live reproduction**: `literature-briefing.sh:143-145` runs `(.authors // []) | join(", ")` inside a `jq -r ... | head -1` command substitution. For the 12 (of 222) global-index entries whose `.authors` is a plain string (e.g. `burgess_1982_i`), `join` errors with `jq: error: Cannot iterate over string`, jq exits 5, `pipefail` surfaces that 5 through the `| head -1` pipe, and — because the assignment is a plain top-level `authors_raw=$(...)` (not `local`, so `set -e` is not masked) — the entire script aborts immediately on the *first* doc_id processed. A caller capturing stdout (e.g. `LIT=$(literature-briefing.sh)`) simply gets an empty string with no visible error, matching the reported `LIT bytes: 0`.
- **Full hardening surface enumerated (goal 1)**: of the 9 per-entry `jq ... | head -1`/command-substitution sites in the repo-mode loop (lines 119–221), only the authors line is a *confirmed* crash vector (it is the only one using `join`, which throws on non-array input). All other unguarded sites (`title`, `year`, `parent_tokens`, the no-chunks-branch `total_tokens`, `parent_path`) use only `.field // default` plus `-r`/`tostring`, which jq never errors on regardless of value type — so they cannot themselves throw a jq runtime error. However, `parent_tokens` and the no-chunks `total_tokens` feed into **bash arithmetic** (`$(( total_tokens + parent_tokens ))`) with no numeric validation; a non-numeric `token_count` (e.g., a malformed string or nested object) would raise a bash arithmetic syntax error under the same `set -e`, a secondary risk worth closing in the same pass. `chunk_count`, the chunks-branch `total_tokens` (via `add`), already have `|| echo 0` fallbacks and are safe.
- **Reference pattern confirmed correct**: `literature-discover.sh:281` — `.authors // [] | if type == "array" then . else [.] end | join(", ")` — correctly normalizes both types and was verified live to produce `John P. Burgess` (string input) and `Patrick Blackburn, Maarten de Rijke, Yde Venema` (one-element comma-joined array input) with exit 0 in both cases.
- **Recommended hardening strategy**: apply the type-normalizing jq pattern at the authors call site (mandatory — fixes the confirmed crash), *and* add `|| default` fallbacks to the remaining currently-unguarded per-entry substitutions (mirroring the `|| echo 0` idiom already used at lines 152–160), each paired with a one-line stderr warning when the fallback actually fires. This is defense-in-depth: even the type-normalizing pattern can still throw if an array element is itself an object (verified: `{"authors":[{"name":"X"}]}` still errors with exit 5) — a case not present in current data but not structurally impossible. The existing "doc_id not found → warn + `continue`" skip behavior (lines 133–136) and the "exit 0 when empty" contract (lines 94–108, 223–226) are both preserved unchanged.
- **Child-project copies**: `~/Projects/cslib/.claude/scripts/literature-briefing.sh` and `~/Projects/Logos/Hardware/.claude/scripts/literature-briefing.sh` are byte-identical to the config-repo copy and carry the same bug at the same line. `~/Projects/BimodalLogic/.claude/scripts/literature-briefing.sh` is an older pre-`--global`-mode version but contains the *same* vulnerable authors expression at the equivalent point in its per-repo loop — it needs the same fix applied to its own copy (structure differs, so the diff cannot be applied verbatim; the authors-line fix pattern is portable, the per-entry-loop hardening is not verbatim-portable due to structural drift).
- **Verification procedure defined and pre-validated (goal 5)**: reproduced the crash live, confirmed the exact failing jq invocation via `bash -x`, and hand-verified that patching only the authors line (using the `literature-discover.sh:281` pattern) causes the script to process all 11 cslib sub-index entries (10 string-typed + 1 array-typed authors) to completion with exit 0, correct author rendering in both cases. Exact commands below.

## Context & Scope

Investigated the reported `--lit` briefing crash (task 464 transcript `.claude/output/lit.md`, `LIT bytes: 0`) by reading `literature-briefing.sh` in full, reproducing the failure against the real global Literature index and the cslib sub-index, comparing to the tolerant pattern in `literature-discover.sh`, and surveying other `.claude/` checkouts under `~/Projects/` for copies of the script that may need the same fix. No files were modified; this is research only, feeding a subsequent `/plan`.

## Findings

### Codebase Patterns

**The crash site** (`.claude/scripts/literature-briefing.sh:143-145`):
```bash
authors_raw=$(jq -r --arg id "$doc_id" '
  .entries[] | select(.id == $id) | (.authors // []) | join(", ")
' "$GLOBAL_INDEX" 2>/dev/null | head -1)
```
`set -euo pipefail` is set at line 41. This assignment is a bare top-level `authors_raw=$(...)` (no `local`), so a non-zero exit from the pipeline is not masked — it propagates directly through `set -e`. `2>/dev/null` only suppresses jq's stderr message; it does **not** suppress the exit code. Confirmed via `bash -x` trace: the script processes `burgess_1982_i` (first doc_id in the cslib sub-index), successfully resolves `parent_entry` and `title`, then dies silently at the `authors_raw=$(...)` line with no further trace output — i.e., the process terminates inside that command substitution, exit code 5.

**Full per-entry command-substitution inventory, lines 119-221** (9 sites):

| Line(s) | Variable | jq expression | Fallback present? | Can jq itself error on type? | Downstream risk |
|---|---|---|---|---|---|
| 121-124 | `parent_entry` | `select(.id==$id and parent_doc null/"")` | No (but handled: empty → retry, then warn+`continue` at 133-136) | No — pure `select`, no `join`/`add` | None — already the intended skip path |
| 128-130 | `parent_entry` (fallback) | `select(.id==$id)` | Same as above | No | None |
| 139-141 | `title` | `.title // "Unknown Title"` | No | No — `-r` never errors on type, just formats non-strings as JSON | None (worst case: ugly title string) |
| **143-145** | **`authors_raw`** | **`(.authors // []) \| join(", ")`** | **No** | **YES — `join` requires array input; string input throws `Cannot iterate over string`, exit 5** | **CONFIRMED CRASH** |
| 147-149 | `year` | `(.year // "?") \| tostring` | No | No — `tostring` never errors on any type | None |
| 152-154 | `chunk_count` | `[select(parent_doc==$id)] \| length` | Yes, `\|\| echo 0` | No — `length` never errors | None (already guarded) |
| 157-160 | `total_tokens` (chunks branch) | `[...token_count // 0] \| add // 0` | Yes, `\|\| echo 0` | Could error if `add` mixes incompatible types (e.g. one chunk's `token_count` is a string, another a number) — but caught by the existing fallback | None (already guarded) |
| 162-164 | `parent_tokens` | `.token_count // 0` | No | No — plain `-r` extraction | **Secondary risk**: fed into bash arithmetic `$(( total_tokens + parent_tokens ))` at line 165 with no numeric validation; a non-numeric string (e.g. containing commas, or a stringified object) would raise a bash arithmetic *syntax* error under `set -e` |
| 167-169 | `total_tokens` (no-chunks branch) | `.token_count // 0` | No | No | Low — used only in string interpolation (`~${total_tokens} tokens`), not arithmetic, but still an unguarded top-level substitution for consistency |
| 174-176 | `parent_path` | `.path // ""` | No | No | None — pure string used in bash path logic, no arithmetic/join |
| 195-197 | `relevance` | (from `$SUB_INDEX`) `.relevance // ""` | No | No | None |

**Conclusion for goal 1**: the authors line is the *only* per-entry jq call in the loop that both (a) lacks a `\|\| default` fallback and (b) uses an operation (`join`) that jq will actually throw on for realistic malformed/mistyped input. It is therefore the complete explanation for the observed 100%-reproducible crash. The `parent_tokens`/`total_tokens` (no-chunks branch) sites are not currently observed to crash (current `token_count` values in the global index are always numeric or absent) but are recommended secondary hardening targets since they are the only other *unguarded* substitutions in the loop and have a plausible (if currently unobserved) failure mode via bash arithmetic on a non-numeric string.

**Reference pattern** (`.claude/scripts/literature-discover.sh:281`, inside `tier1_search()`):
```bash
authors=$(echo "$entry" | jq -r '.authors // [] | if type == "array" then . else [.] end | join(", ")' 2>/dev/null)
```
This is the correct model: `.authors // []` first normalizes `null`/missing to `[]`; the `if type == "array"` branch handles the common case unchanged; the `else [.] end` branch wraps a bare string (or number, or any scalar) in a single-element array before `join`. Live-verified against both failure modes present in the real data:
```
$ jq -r --arg id burgess_1982_i '.entries[] | select(.id==$id) | (.authors // [] | if type == "array" then . else [.] end | join(", "))' ~/Projects/Literature/index.json
John P. Burgess          # exit 0 — string-typed authors
$ jq -r --arg id blackburn_2002_book '.entries[] | select(.id==$id) | (.authors // [] | if type == "array" then . else [.] end | join(", "))' ~/Projects/Literature/index.json
Patrick Blackburn, Maarten de Rijke, Yde Venema   # exit 0 — one-element comma-joined array
```
This pattern is the correct fix. Note the same file's `literature-search.sh` was not checked (out of scope; task only names `literature-discover.sh` as the reference).

**Global index authors typing** (`~/Projects/Literature/index.json`, 222 total entries):
```
210 array
 12 string
```
The 12 string-typed entries: `burgess_1982_i`, `burgess_1982_ii`, `caleiro_2013`, `gabbay_1993`, `goldblatt_2003`, `hodkinson_2006`, `libkin_2004_ch3_ch7`, `rabinovich_2014`, `reynolds_2001`, `thomas_1997`, `venema_1993_anti_axioms`, `venema_1993_since_until`. Confirmed some arrays are one-element comma-joined strings, e.g. `blackburn_2002_book`, `blackburn_2002_ch00`, and every other `blackburn_2002_*` chunk entry: `"authors": ["Patrick Blackburn, Maarten de Rijke, Yde Venema"]`.

**Discrepancy note for the planner**: the task description's verification list names 12 doc_ids including both `blackburn_2001` and `blackburn_2002_book`. The actual `~/Projects/cslib/specs/literature-index.json` sub-index currently contains **11** entries, not 12, and does **not** include `blackburn_2001` (it includes only `blackburn_2002_book`). `blackburn_2001` does exist in the global index (id `blackburn_2001`, array-typed authors, `"Modal Logic"`, 2001) but is not referenced by the cslib sub-index today. This does not block the fix or its verification — the sub-index as it stands already exercises both the string-typed (10 of 11 entries) and array-typed (1 of 11: `blackburn_2002_book`) code paths — but the planner/implementer should use the **actual 11-entry list** below rather than the 12-entry list in the task description, or optionally add a `blackburn_2001` entry to the sub-index if 12-entry coverage is specifically desired (not required for verification).

Actual cslib sub-index doc_ids (11): `burgess_1982_i` (string), `burgess_1982_ii` (string), `reynolds_2001` (string), `venema_1993_since_until` (string), `venema_1993_anti_axioms` (string), `gabbay_1993` (string), `goldblatt_2003` (string), `rabinovich_2014` (string), `caleiro_2013` (string), `hodkinson_2006` (string), `blackburn_2002_book` (array).

### External Resources

Not applicable — this is a self-contained shell/jq bug in project-internal tooling; no external documentation was consulted beyond standard jq semantics (verified empirically rather than via docs, since the exact error behavior of `join`/`-r`/`tostring`/`add` on mismatched types is best confirmed by direct testing, which was done above).

### Recommendations

1. **Primary fix (mandatory)** — replace lines 143-145 with the type-normalizing pattern from `literature-discover.sh:281`:
   ```bash
   authors_raw=$(jq -r --arg id "$doc_id" '
     .entries[] | select(.id == $id) | (.authors // [] | if type == "array" then . else [.] end | join(", "))
   ' "$GLOBAL_INDEX" 2>/dev/null | head -1) || authors_raw=""
   ```
   The `|| authors_raw=""` tail guard is optional given the type-normalization makes the jq call itself non-throwing for all data currently in the index, but is cheap defense-in-depth (see next point) and costs nothing.

2. **Secondary hardening (recommended, not strictly required to fix the reported bug)** — add `|| default` fallbacks to the remaining unguarded per-entry substitutions, mirroring the existing `|| echo 0` idiom at lines 152-160, each paired with a stderr warning only when the fallback actually triggers (to avoid noisy output in the normal case):
   - `title=$(... | head -1) || title="Unknown Title"`
   - `year=$(... | head -1) || year="?"`
   - `parent_tokens=$(... | head -1) || parent_tokens=0`, plus a numeric guard before the arithmetic: `[[ "$parent_tokens" =~ ^[0-9]+$ ]] || parent_tokens=0` (closes the bash-arithmetic risk identified above)
   - `total_tokens=$(... | head -1) || total_tokens=0` (no-chunks branch, line 167-169)
   - `parent_path=$(... | head -1) || parent_path=""`

   This satisfies the task's request that "a single malformed/failing entry WARNS to stderr and is SKIPPED" in the sense that pipefail/set-e can no longer kill the *whole run* over any single field — a malformed field degrades that field to a sane default (with a warning) rather than aborting all remaining doc_ids. Recommend **not** dropping the whole document (i.e., not treating a malformed field the same as "doc_id not found → skip entirely") because a document with, say, a corrupted `year` field but otherwise-valid `title`/`authors`/`path` is still useful in the briefing — silently discarding it loses more information than defaulting one field. The existing "doc_id not found in global index" skip-and-warn behavior (lines 133-136) is untouched and remains the sole full-document-skip path.

3. **Why not wrap the whole per-entry body in a function + `if ! process_entry; then continue; fi`**: this was considered (bash's `set -e` is suspended for commands tested in an `if` condition, including function calls, so this would also stop the abort). It is a larger, more invasive restructuring (extracting ~80 lines into a function, threading `briefing_lines`/`doc_num` in/out) for no behavioral benefit over the per-line `|| default` guards, which are a minimal diff, consistent with the file's existing style (`|| echo 0` already appears twice), and easier to review/verify line-by-line. Not recommended unless the implementer independently judges the loop body has grown unwieldy.

4. **Do not relax `set -e`/`pipefail` globally or locally with `set +e ... set -e`** around the block: this would also suppress genuine errors (e.g., a truly corrupt `$GLOBAL_INDEX` JSON file) that should be visible, and is a blunter instrument than per-substitution guards.

### Verification Procedure (goal 5)

Reproduced end-to-end in the scratchpad (not the real repo) to validate the fix before handing off to `/plan`:

```bash
# 1. Reproduce the crash (uses the REAL global index + REAL cslib sub-index):
mkdir -p /tmp/repro/.claude/scripts /tmp/repro/specs
cp ~/.config/nvim/.claude/scripts/literature-briefing.sh /tmp/repro/.claude/scripts/
cp ~/Projects/cslib/specs/literature-index.json /tmp/repro/specs/
LITERATURE_DIR=~/Projects/Literature bash /tmp/repro/.claude/scripts/literature-briefing.sh
echo "EXIT: $?"   # currently: EXIT: 5, stdout empty (matches "LIT bytes: 0")

# 2. After applying the fix to /tmp/repro/.claude/scripts/literature-briefing.sh,
#    re-run the same command:
LITERATURE_DIR=~/Projects/Literature bash /tmp/repro/.claude/scripts/literature-briefing.sh
echo "EXIT: $?"   # expected: EXIT: 0

# 3. Confirm all 11 cslib entries are present and both author-type renderings are correct:
LITERATURE_DIR=~/Projects/Literature bash /tmp/repro/.claude/scripts/literature-briefing.sh \
  | grep -c '^[0-9]*\. \*\*'          # expect: 11
LITERATURE_DIR=~/Projects/Literature bash /tmp/repro/.claude/scripts/literature-briefing.sh \
  | grep 'Burgess'                     # string-typed author renders: "... — John P. Burgess"
LITERATURE_DIR=~/Projects/Literature bash /tmp/repro/.claude/scripts/literature-briefing.sh \
  | grep 'Blackburn'                   # array-typed (one-elem comma string) renders correctly, no double-splitting
```

The exact fix was pre-validated in this manner during research (patched copy at
`/tmp/claude-*/scratchpad/repro/.claude/scripts/literature-briefing-patched.sh`, ephemeral,
not committed): after replacing only the authors line, the script produced all 11 entries
with exit 0, e.g.:
```
1. **Axioms for Tense Logic. I. "Since" and "Until"** (1982) — John P. Burgess
   1 chunk(s), ~5437 tokens | dir: /home/benjamin/Projects/Literature/sources/burgess_1982_i
...
11. **Modal Logic (2002 Cambridge edition)** (2002) — Patrick Blackburn, Maarten de Rijke, Yde Venema
   35 chunk(s), ~365065 tokens | dir: /home/benjamin/Projects/Literature/sources/blackburn_2002
```
Once the implementer applies the fix to the real `.claude/scripts/literature-briefing.sh`
(and, per the propagation note below, the child-project copies), the same commands can be
run directly against `~/Projects/cslib` (`cd ~/Projects/cslib && LITERATURE_DIR=~/Projects/Literature bash .claude/scripts/literature-briefing.sh`) since cslib's `specs/literature-index.json` already exists and `PROJECT_ROOT` is derived from the script's own location (`$SCRIPT_DIR/../..`), so running the *cslib copy* of the script from anywhere resolves correctly, and running the *config-repo copy* requires either `cd`-ing into a directory whose `specs/literature-index.json` exists relative to the script's own `$SCRIPT_DIR/../..`, or (simpler) just directly invoking `~/Projects/cslib/.claude/scripts/literature-briefing.sh` after propagating the fix there.

## Decisions

- Recommend fixing the authors jq expression (mandatory, confirmed crash) plus adding `|| default` fallbacks to the four other currently-unguarded per-entry substitutions (`title`, `year`, `parent_tokens`, no-chunks `total_tokens`, `parent_path`) — five total guard additions plus the one authors-line rewrite — as the complete hardening surface for this task. Function-based restructuring or global `set +e` relaxation are explicitly not recommended (see Recommendations §3-4).
- The task description's 12-doc_id verification list contains one inaccuracy (`blackburn_2001` is not in the current cslib sub-index; `blackburn_2002_book` is) — the planner should verify against the actual 11-entry sub-index content reproduced above, not the task description's list verbatim.
- `cslib` and `Logos/Hardware` copies of `literature-briefing.sh` are byte-identical to the config-repo source of truth and can receive the identical patch (copy-paste of the fixed line range). `BimodalLogic`'s copy is structurally older (no `--global` mode) and needs the authors-line fix applied at its own equivalent line rather than a verbatim diff.

## Risks & Mitigations

- **Risk**: fixing only the authors line (option a) leaves the four other unguarded substitutions and the bash-arithmetic risk unaddressed, so a future malformed `token_count`/`title`/`year`/`path` field could reintroduce a similar silent-abort bug. **Mitigation**: implement the secondary hardening (Recommendation 2) in the same pass, since it is a small, low-risk, additive diff.
- **Risk**: propagating the fix to child-project copies could drift further if those repos' scripts are independently edited later. **Mitigation**: out of scope for this task per the description ("config repo is source of truth... keep consistent with child-project copies") — the implementer should propagate the identical fix to `cslib` and `Logos/Hardware` (byte-identical today) and apply the equivalent fix to `BimodalLogic`'s older structure, but a sync mechanism is a separate concern not raised by this task.
- **Risk**: the type-normalizing jq pattern can still throw if an array element is a non-scalar (verified: `{"authors":[{"name":"X"}]}` → exit 5). **Mitigation**: not observed in current data (all 210 array-typed entries in the global index contain only string elements per the type breakdown above); the secondary per-entry guard (`|| authors_raw=""`) closes this residual gap without needing more complex jq.

## Context Extension Recommendations

- None. This is a narrow, well-scoped bug fix in existing shared infrastructure; no new context documentation is warranted.

## Appendix

**Search/verification commands used**:
```bash
jq -r '.entries[] | .authors | type' ~/Projects/Literature/index.json | sort | uniq -c
jq -r '.entries[] | select((.authors|type)=="string") | .id' ~/Projects/Literature/index.json
jq -c '.entries[] | select((.authors|type)=="array") | select((.authors|length)==1) | select(.authors[0] | test(","))' ~/Projects/Literature/index.json
find ~/Projects -maxdepth 6 -path "*/.claude/scripts/literature-briefing.sh"
diff ~/.config/nvim/.claude/scripts/literature-briefing.sh ~/Projects/cslib/.claude/scripts/literature-briefing.sh   # identical
diff ~/.config/nvim/.claude/scripts/literature-briefing.sh ~/Projects/Logos/Hardware/.claude/scripts/literature-briefing.sh   # identical
diff ~/.config/nvim/.claude/scripts/literature-briefing.sh ~/Projects/BimodalLogic/.claude/scripts/literature-briefing.sh   # structurally older, same bug present
bash -x /tmp/repro/.claude/scripts/literature-briefing.sh   # traced crash to authors_raw=$(...) on first doc_id
```

**Files read**:
- `/home/benjamin/.config/nvim/.claude/scripts/literature-briefing.sh` (full, 314 lines)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-discover.sh` (lines 260-300, tier1_search reference pattern)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/handoff-schema.md` (orchestrator handoff schema)
- `~/Projects/Literature/index.json` (222 entries, read-only queries)
- `~/Projects/cslib/specs/literature-index.json` (11 entries, read-only)

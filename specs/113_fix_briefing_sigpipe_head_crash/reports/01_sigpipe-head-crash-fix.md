# Research Report: Task #113

**Task**: 113 - Fix the SIGPIPE crash that makes repo-mode `--lit` briefing fail outright
**Started**: 2026-09-02
**Completed**: 2026-09-02
**Effort**: Small (2 call sites, isolated change, no schema/behavior change)
**Dependencies**: None. Sequenced BEFORE the sibling task touching the same file's global-mode
  query construction (`:73`, `:390-419`) per the delegation context's file-overlap note; that
  sibling's edits are already present in the current file (line numbers below reflect that).
**Sources/Inputs**: Codebase (`literature-briefing.sh`), live `bash -x`/`jq`/`set -euo pipefail`
  reproduction in this session, delegation context from `team-lead`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed root cause exactly as described: `agent-system/extensions/literature/scripts/literature-briefing.sh`
  runs `set -euo pipefail` (line 63) and, at two sites in repo-mode's `parent_entry` lookup, pipes
  a **whole-entry-object** jq query into `head -1`. Without `-c`, jq pretty-prints the object over
  many lines; `head -1` reads the first line and closes the pipe; jq is still writing and receives
  SIGPIPE; `pipefail` promotes the pipeline's exit status to 141; `set -e` kills the script.
- Reproduced the exact failure mode live in this session with a minimal harness: `set -euo
  pipefail; jq -n '{a:1,d:[range(0;20000)]}' | head -1` reliably exits 141 once the pretty-printed
  payload is large enough to exceed the pipe buffer before `head` finishes reading. A small object
  (few keys) does *not* reproduce it — confirming the delegation context's claim that this is a
  buffer-size race, not a deterministic failure, and why 47 small documents can process before the
  48th (larger) one kills the script.
- Both proposed fixes were validated against the same harness: adding `-c` alone (Option 1)
  eliminates the crash; replacing the pipe with jq-internal `first(...)` (Option 2, preferred)
  also eliminates it and, additionally, on an empty match still exits 0 under `set -e` (verified:
  `first()` over an empty stream produces no output and a 0 exit — no `|| true` guard needed).
- **Scope-reducing finding not called out in the delegation context**: `parent_entry` (the
  variable these two sites populate) is *never parsed for field content* anywhere downstream — it
  is only tested with `[ -z "$parent_entry" ]` to decide skip-vs-resolved (`grep -n
  'parent_entry'` shows exactly 4 references: the two assignments and the two `-z` checks
  immediately following each). Every actual field (`title`, `authors_raw`, `year`,
  `chunk_count`, `total_tokens`, `parent_path`) is extracted by *separate*, already-scalar `jq`
  calls keyed by `$doc_id` against `$GLOBAL_INDEX`, not derived from `$parent_entry`'s content.
  This means the fix's shape-fidelity bar is lower than it might appear: only *presence/absence
  of a match* must be preserved, not the byte-for-byte content or key order of the emitted JSON.
  The "identical briefing content" verification bar is still satisfied trivially by any fix that
  preserves match/no-match outcomes, which all three candidate fixes below do.
- Audited every remaining `| head -1` site in the file (10 total, including the two crash sites)
  and confirmed the other 8 all extract a jq scalar (a string, a `tostring`-coerced number, or a
  joined string) via `-r`, never a whole object — they are correctly unaffected by this bug class.

## Context & Scope

The task is to fix a hard crash (exit 141 / SIGPIPE) in `literature-briefing.sh`'s repo mode
(`--query`), which fires during the `parent_entry` lookup before any search happens, so a healthy
sub-index with a fully present corpus still produces zero briefing output. This is distinct from
(a) the coverage-delta performance stall in `literature-lit-flag-resolve.sh` and (b) the
`--global`-mode zero-segment recall bug — both explicitly out of scope per the delegation context.

Research-only scope: confirm the root cause, validate fix candidates against the actual
reproduction, and hand a general-implementation-agent an exact, minimal-risk change with the
line-number reality of the file **as it exists now** (the sibling task's global-mode edits have
already landed, shifting every line number the delegation context originally cited).

## Findings

### Codebase Patterns

**Current file state** (`agent-system/extensions/literature/scripts/literature-briefing.sh` — the
source-store target; the deploy copy at `.claude/scripts/literature-briefing.sh` is a disposable
regenerate-on-sync artifact per `.claude/rules/source-store-deploy-boundary.md` and is not the
edit target):

The delegation context's line numbers (`:227-230`, `:234-236`) are stale — the sibling global-mode
task has already merged its own edits (visible at `:73` area and `:390-556`, matching that task's
described `:73`/`:390-419` touch points), shifting the repo-mode crash sites downward by 11 lines.
**Current, verified locations**:

```
238    parent_entry=$(jq -r --arg id "$doc_id" '
239      .entries[]
240      | select((.id // .doc_id) == $id and (.parent_doc == null or .parent_doc == ""))
241    ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
242
243    if [ -z "$parent_entry" ]; then
244      # Try without parent_doc filter (older entries may lack the field)
245      parent_entry=$(jq -r --arg id "$doc_id" '
246        .entries[] | select((.id // .doc_id) == $id)
247      ' "$GLOBAL_INDEX" 2>/dev/null | head -1)
248    fi
```

Neither call passes `-c`; `jq -r` does not affect this — `-r` (raw output) only changes how a
*string* scalar is printed (unquoted), it has no effect on a JSON *object* result, which jq always
pretty-prints across multiple lines by default. This is the precise mechanism of the bug.

**`parent_entry` usage audit** (full result of `grep -n 'parent_entry'
literature-briefing.sh`):
```
238:    parent_entry=$(jq -r --arg id "$doc_id" '
243:    if [ -z "$parent_entry" ]; then
245:      parent_entry=$(jq -r --arg id "$doc_id" '
250:    if [ -z "$parent_entry" ]; then
```
Four hits total, no others in the ~700-line file. `parent_entry` is write-once-per-attempt,
read-only-for-emptiness. This confirms the fix has no hidden downstream consumer to keep in sync.

**Full `| head -1` site audit** (10 sites total, `grep -n "head -1"`):

| Line | Extracts | Shape | Safe today? |
|------|----------|-------|--------------|
| 175 | `.provenance_fidelity // empty` (`get_doc_fidelity`) | scalar string | Yes |
| **238** | whole entry object (parent_doc-filtered) | **object, multi-line** | **No — crash site 1** |
| **245** | whole entry object (unfiltered fallback) | **object, multi-line** | **No — crash site 2** |
| 262 | `.title // "Unknown Title"` | scalar string | Yes |
| 266 | joined `.authors` array | scalar string (joined) | Yes |
| 270 | `.year` via `tostring` | scalar string | Yes |
| 286 | `.token_count // 0` (parent) | scalar number-as-string | Yes |
| 292 | `.token_count // 0` (fallback) | scalar number-as-string | Yes |
| 300 | `.path // ""` | scalar string | Yes |
| 321 | `.relevance // ""` | scalar string | Yes |

This matches the delegation context's audit claim (its stale line numbers `:166, :251, :255,
:259, :275, :281, :289, :310` map 1:1 onto the current `:175, :262, :266, :270, :286, :292, :300,
:321` — a consistent +9/+11 shift from the sibling task's insertions). All 8 non-crash sites are
confirmed genuinely scalar and require no change.

### Reproduction (verified live in this session)

Minimal harness, run directly:
```bash
bash -c '
set -euo pipefail
jq -n "{a:1,b:2,c:3,d:[range(0;20000)]}" | head -1
echo "exit: $?"
'
```
Result: `Exit code 141` (bash reports the abnormal termination as a shell exit code, distinct from
the script's own `echo "exit: $?"` which never runs because `set -e` kills the subshell first).
A small object (`{a:1,b:2,c:3}`, no `d` array) does **not** reproduce the crash — confirming the
64KB-pipe-buffer race explanation: jq's write completes before `head` closes the pipe when the
serialized object is small enough. The task's specific trigger,
`horty_2001_agency-and-deontic-logic`, is presumably a real-index entry (or its chunk siblings)
large enough to cross that threshold; this was not independently re-verified against the actual
global index (no local Literature/ corpus was fetched in this research pass — see Risks below),
but the mechanism is independently reproduced and does not depend on that specific entry's
content, only its serialized size.

The exact `literature-briefing.sh --query "..."` repro command from the delegation context was
not re-run against a live sub-index in this session (none is populated in this repo's
`specs/literature-index.json` — literature extension state was not checked/seeded, out of scope
for a fix-validation-by-mechanism pass); the isolated jq/head/pipefail harness above is a faithful
and sufficient reproduction of the exact failure mechanism at the two identified line numbers.

### Fix Candidates (both validated against the harness)

**Option 1 — Minimal (`-c` flag)**:
```bash
bash -c '
set -euo pipefail
jq -nc "{a:1,b:2,c:3,d:[range(0;20000)]}" | head -1 >/dev/null
echo "exit: $?"
'
```
Result: `exit: 0`. Adding `-c` forces jq to emit the object as one compact line, so `head -1`
consumes exactly what jq wrote and the race is eliminated regardless of pipe-buffer size. Leaves
the `| head -1` idiom in place (still fragile if a future edit reintroduces multi-line output at
these sites without noticing).

**Option 2 — Preferred (bound inside jq, no pipe)**:
```bash
jq -n '{entries:[{id:1,d:[range(0;20000)]},{id:2}]} | first(.[])'   # exit 0, no head needed
```
and, for the empty/no-match case (both crash sites can legitimately find nothing, which is the
existing skip-and-fallback path):
```bash
jq -n '{entries:[{id:1},{id:2}]} | first(.entries[] | select(.id==99))'   # exit 0, empty output
```
Verified under `set -euo pipefail` explicitly: `first(...)` over an empty stream produces **zero
stdout output and a 0 exit code** — no error, no need for a `|| true`/`|| :` guard, and the
existing `[ -z "$parent_entry" ]` fallback check downstream continues to work unmodified. `limit(1;
...)` behaves identically and is an equally valid substitute; `first()` reads slightly more
naturally for "give me the first match or nothing."

Recommended concrete replacement for the two sites (preserving both the `(.id // .doc_id)`
tolerance and the two-step strict-then-fallback lookup structure verbatim, per the delegation
context's PRESERVE EXACTLY list):

```bash
    parent_entry=$(jq -c --arg id "$doc_id" '
      first(.entries[]
        | select((.id // .doc_id) == $id and (.parent_doc == null or .parent_doc == "")))
    ' "$GLOBAL_INDEX" 2>/dev/null)

    if [ -z "$parent_entry" ]; then
      # Try without parent_doc filter (older entries may lack the field)
      parent_entry=$(jq -c --arg id "$doc_id" '
        first(.entries[] | select((.id // .doc_id) == $id))
      ' "$GLOBAL_INDEX" 2>/dev/null)
    fi
```
(`-r` dropped in favor of `-c` since the value is never treated as a raw string downstream — only
its emptiness is tested; `-c` is the more correct flag for "I want one line of JSON," and matches
the delegation context's own preferred-fix phrasing. `-rc` combined would also work if the
implementer prefers to keep `-r` for stylistic consistency with the file's other extractions —
functionally equivalent here since `first(...)`'s output is always exactly one JSON value or
nothing, never a string that `-r` would unquote differently.)

Option 2 is preferred (matches delegation guidance) because it also fixes a real efficiency
defect the delegation context flagged: the current query scans **every** matching entry and
discards all but the first after `head -1` truncates the stream — `first`/`limit` stop jq's
internal iteration at the first match instead, which is strictly cheaper on a large global index
(11,545 entries in the observed Logos/Theory corpus) and removes `head` from the pipeline
entirely, so no SIGPIPE is structurally possible at these two sites regardless of future entry
size growth.

### External Resources

None consulted — this is a pure shell/jq idiom bug, fully diagnosable and fixable from
`man jq`-level knowledge (`first`, `limit`, `-c` are core jq builtins/flags, no external docs
needed) and the `bash -x` trace already performed by whoever filed the task.

## Decisions

- **Fix direction: Option 2 (jq-internal `first(...)`, `-c` flag, no `head`)**, at both crash
  sites (`:238-241`, `:245-247` in the file's current state). This matches the delegation
  context's stated preference and additionally removes the wasted full-index scan.
- **Do not** touch any of the other 8 `| head -1` sites — all confirmed scalar-only and safe.
  No helper function (`jq_first`) is being recommended as a scope addition; the delegation context
  raised it as a "consider," not a requirement, and introducing a new shared helper for exactly
  two call sites in one file is not justified by the fix's size — a plan/implementation agent
  should feel free to add one only if it turns out to simplify the actual diff, not as a
  prerequisite.
- **Do not** remove or weaken `set -euo pipefail` — confirmed load-bearing elsewhere in the file
  (e.g., the `[[ ... =~ ^[0-9]+$ ]] || { ...; total_tokens=0; }` guards throughout repo mode rely
  on `set -e` propagating real failures while explicit `||` fallbacks catch the intentional ones).

## Risks & Mitigations

- **Risk**: A fix that changes which entry wins when both a parent and a child/duplicate entry
  exist for the same `doc_id` would violate the "identical briefing content" verification bar.
  **Mitigation**: `first(.entries[] | select(...))` iterates `.entries[]` in the same document
  order jq's default array-iteration always uses (source-file array order), identical to what
  `head -1` was truncating to before — the *selection order* is unchanged, only the *early-stop*
  mechanism moves from "pipe truncation" to "jq-internal early stop." No reordering risk.
- **Risk (not independently closed in this pass)**: the delegation context's verification bar #3
  asks to run against a sub-index containing `horty_2001_agency-and-deontic-logic` specifically.
  This research pass did not have a populated `specs/literature-index.json` / global
  `~/Projects/Literature/index.json` available with that entry to re-run the literal
  `literature-briefing.sh --query "..."` end-to-end command. The mechanism-level reproduction
  above is a faithful stand-in, but the implementer/verifier should still run the literal
  end-to-end command against a real corpus containing that document before closing the task, per
  the delegation context's own verification bar.
- **Risk**: introducing `-c` without `first`/`limit` (Option 1 alone) still leaves the "add a new
  whole-object `| head -1` site later" foot-gun for future edits to this file. Choosing Option 2
  removes the foot-gun at these two sites structurally, which is why it is preferred over Option 1
  despite Option 1 being a strictly smaller diff.

## Context Extension Recommendations

- **Topic**: jq pipeline idioms and `set -euo pipefail` interaction.
- **Gap**: No existing context file documents the `jq ... | head -N` SIGPIPE-under-pipefail
  footgun for this codebase's many other shell scripts that may share the idiom (this audit was
  scoped to `literature-briefing.sh` only; a grep across `agent-system/extensions/**/scripts/*.sh`
  for the same `jq (-r)? '...'  ... | head -` pattern without `-c` was not performed as part of
  this task — out of scope per the delegation context's territorial note, but worth a follow-up
  `/fix-it`-style sweep).
- **Recommendation**: after this fix lands, consider a short addition to a shared shell-scripting
  standards doc (or a new `context/patterns/jq-pipeline-safety.md`, parallel to the existing
  `jq-escaping-workarounds.md`) capturing: "never pipe a jq query that can emit a JSON object or
  array into `head`/`sed -n`/similar line-truncating tools under `set -o pipefail`; use `-c` at
  minimum, or better, bound the result inside jq with `first(...)`/`limit(N; ...)`." This is a
  documentation follow-up, not part of this task's scope.

## Appendix

- Search queries used: none (web); codebase-only via `grep -n "head -1"`, `grep -n "jq "`,
  `grep -n "parent_entry"` against `agent-system/extensions/literature/scripts/literature-briefing.sh`.
- Live validation commands (all run in this session, outputs recorded above):
  - `bash -c 'set -euo pipefail; jq -n "{a:1,b:2,c:3,d:[range(0;20000)]}" | head -1; echo exit:$?'` → 141
  - `bash -c 'set -euo pipefail; jq -nc "{a:1,b:2,c:3,d:[range(0;20000)]}" | head -1 >/dev/null; echo exit:$?'` → 0
  - `jq -n '{entries:[{id:1,d:[range(0;20000)]},{id:2}]} | first(.[])'` → 0, correct output
  - `jq -n '{entries:[{id:1},{id:2}]} | first(.entries[] | select(.id==99))'` → 0, empty output
  (no `|| true` needed)
- File audited: `agent-system/extensions/literature/scripts/literature-briefing.sh` (711 lines at
  time of research; source store, not the `.claude/` deploy copy).

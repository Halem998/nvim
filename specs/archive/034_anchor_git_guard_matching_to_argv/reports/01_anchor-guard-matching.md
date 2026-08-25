# Research Report: anchor_git_guard_matching_to_argv

**Task**: 34 - anchor_git_guard_matching_to_argv
**Started**: 2026-08-17
**Completed**: 2026-08-17
**Effort**: medium
**Dependencies**: None (explicitly independent of orchestrator run-state work)
**Sources/Inputs**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (read in full, 222 lines)
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (model suite)
- `agent-system/extensions/core/scripts/tests/test-common-lib.sh` (model suite)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (house convention)
- `agent-system/extensions/core/manifest.json` (`provides.scripts` registration)
- `agent-system/extensions/core/scripts/tests/run-all.sh` (discovery engine)
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` (cross-references the guard)
- git history: commits `a1dd3774d`, `18f8ec610`, `eeec9fd16`
- Live bash reproductions of the guard's actual regex/sed logic (isolated fragments, run directly)
**Artifacts**:
- this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both root causes named in the third addendum are confirmed against the current source-store
  file, at the line numbers claimed, with live reproduction. Cause 1 (line-based quote-strip) and
  Cause 2 (over-broad flag regex) are real and independently necessary for the observed false
  positive; fixing Cause 1 alone is sufficient to close every reproduced failure, because every
  observed trigger was text inside a `-m "..."` argument.
- The correct minimal fix is architectural, not a patch to the existing per-segment `sed` calls:
  strip quoted spans from the **entire multi-line `$COMMAND` string once, up front**, using a
  slurp-mode `sed` (`N`-loop), before any segment extraction or flag regex runs — then point every
  detector (both the two "already safe" over-staging detectors AND the five vulnerable destructive
  detectors) at that one stripped string instead of raw `$COMMAND`/raw `$seg`. This is confirmed
  by reproduction to fix the multi-line case, preserve every true-positive detection, and preserve
  the `--staged` inverse-hazard exemption boundary.
- The task's own inverse-hazard concern (a quoted `--staged` in a message must not falsely exempt
  a real `git restore`) is currently **safe by accident** of `;`/`&`/`|` segment boundaries, but a
  closely related, currently-live bypass exists that the primary fix does **not** close: a bash
  `#` comment sharing the same segment as a real `git restore <path>` invocation (e.g.
  `git restore foo.txt # use --staged next time`) is not quote-delimited, so the literal
  `--staged` substring in the comment falsely exempts a genuinely destructive restore today, and
  will continue to after the primary fix, unless comments are also stripped or the segment split
  is made comment-aware. This is a real, additional finding — recommend closing it in the same
  change, since it is one extra `sed` clause on the same stripped string, not a new architecture.
- The non-quote-aware `[^;&|]*` segment splitting (secondary defect) is a distinct, broader
  architectural gap. Recommend recording it explicitly **out of scope** for this task: neither
  live firing traces to it, closing it properly requires a real tokenizer (not a regex tweak) for
  all seven detectors, and the task's acceptance criteria do not name it.
- `run-all.sh` needs **no code change** — it already glob-discovers `test-*.sh` in both
  source-store and deployed mode (confirmed by reading it in full). The "declared in file scope"
  item referenced in the task is already resolved (commit `a1dd3774d`) and refers to a dispatch
  territory-contract/file-scope declaration, not a code change to `run-all.sh` itself. The one
  registration step that **is** still required is adding
  `"tests/test-guard-destructive-git.sh"` to `manifest.json`'s `provides.scripts` array
  (confirmed required by `shell-script-testing.md`'s "Registration" section and by the existing
  pattern at lines 165-180 of `manifest.json`).

## Context & Scope

Researched the exact current matching behavior of `guard-destructive-git.sh`'s seven detectors,
verified the two root causes named in the task's third addendum against the live file (not taken
on faith), designed and reproduced a minimal fix shape, analyzed the inverse-hazard risk the task
explicitly calls out, and characterized the house test conventions a new
`test-guard-destructive-git.sh` must follow, including the registration step and the current state
of the `run-all.sh` "file scope" item.

## Findings

### Detector inventory: current matching behavior and vulnerability status

All line numbers below were read directly from the current 222-line file and match the task
description's claims exactly (no drift found).

| # | Detector | Lines | Reads | Quote-strip? | Vulnerable to message-text FP? |
|---|----------|-------|-------|---------------|-------------------------------|
| 1 | `git add -A`/`--all`/bare `.` | 76-89 | segments of `$COMMAND` | yes, per-segment (line 80), **but line-based** | Latent: safe for single-line messages; same Cause-1 defect exists structurally, just not yet reproduced live for `git add` |
| 2 | `git commit -a`/`-am`/`--all` | 94-106 | segments of `$COMMAND` | yes, per-segment (line 99), **but line-based** | **Confirmed live locus of both reproduced firings** — vulnerable via Cause 1 + Cause 2 combined on multi-line messages |
| 3 | `git reset --hard` | 120 | raw `$COMMAND` | none | Vulnerable if a message contains the literal phrase `git reset ... --hard` |
| 4 | `git checkout -- <path>` | 126 | raw `$COMMAND` | none | Vulnerable if a message contains literal `checkout -- ` |
| 5 | `git restore` (no `--staged`) | 132-144 | raw segments | none | Vulnerable to false block from message text containing `git restore ...`; see inverse-hazard analysis below for the exemption direction |
| 6 | `git clean -f -d` | 148-163 | raw segments (HAS_F/HAS_D) | none | Vulnerable — task's own worked example (`git commit -m "revert the git clean -fd fallout"`) trips this |
| 7 | forced checkout/switch (`-f`/`--force`) | 172-184 | raw segments | none | Vulnerable — task's own worked example (`-m "hotfix -f rollout"`) trips this |

Confirms the task body's framing exactly: detectors 1-2 are the only ones with any quote-strip at
all, and detectors 3-7 grep raw text with none. The addendum's correction — that 1-2 are only
"already safe" for single-line commands — is also confirmed (see reproduction below).

### Cause 1 verified: line-based quote-strip fails on multi-line messages

`COMMIT_SEGMENTS` is built via `echo "$COMMAND" | grep -oE '...git[[:space:]]+commit[^;&|]*'`
(line 95). `grep` (without `-z`) matches per input line and never extends a match across a
newline. For a multi-line `-m "..."` message, the extracted segment therefore terminates at the
**first** newline inside the still-open quoted string — the segment is exactly the header/first
line of the message, with its opening `"` never closed within that segment. The subsequent
`sed -e 's/"[^"]*"/""/g'` (line 99) then finds no closing `"` on that single line and strips
nothing, so the header line is flag-scanned as raw text. Live reproduction:

```
SINGLE-LINE topic mid-message:
  seg_scan=[git commit -m ""]                     -> no match (quote closed, stripped correctly)

MULTI-LINE, topic on first line of a real, multi-paragraph message:
  seg_scan=[git commit -m "task: group the essential-refactor batch by topic]
  -> MATCH: WOULD BLOCK
```
This is character-for-character the failure shape the addendum describes ("same header text,
PASS as one line, BLOCK as the first line of a multi-line message"). One refinement worth noting
for the fix design: it is not literally true that "every line of the message is flag-scanned" —
only the header/first line becomes part of a captured segment at all (later message lines don't
start with `git commit` or a `;&|`-prefix, so `grep -oE` never captures them as segments in the
first place). The practical risk surface is specifically **the first line of any multi-line
message that reaches this detector**, which is exactly where a commit's own subject line usually
lives — the worst possible place for this bug to live in practice, since subject lines are exactly
where topic words like "essential-refactor" get written.

### Cause 2 verified: flag regex matches ordinary hyphenated prose

The regex at line 100, `(^|[^-])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)`, matches any hyphenated token
whose part after the hyphen contains an `a` and is followed by whitespace/end-of-string —
independent of whether that token is a real git flag. Reproduced against the addendum's own named
examples, using the actual regex and actual first-line-of-multiline-message extraction path:

```
un-edged            -> no-match   (no 'a' after the hyphen)
repo-wide            -> no-match   (no 'a' after the hyphen)
essential-refactor   -> MATCH-BLOCK
auto-repair           -> MATCH-BLOCK
multi-task            -> MATCH-BLOCK
```
Confirms both the addendum's specific claim about which neutral words pass and which don't, and
the "combined defect" framing: Cause 2 is harmless whenever Cause 1's strip actually works (a
correctly-stripped `seg_scan` is just `git commit -m ""`, nothing left to false-match), and Cause
1 is harmless whenever no message line happens to contain a Cause-2-shaped token. The false
positive needs both simultaneously, which is why three separate live firings (two of which
couldn't even identify a trigger) looked nondeterministic before bisection.

### Recommended fix: one whole-command, multi-line-aware strip, applied before all seven detectors

Do not patch the existing per-segment `sed` calls in place. The structural problem is that
quote-stripping currently happens **after** line-based segment extraction, which is exactly what
throws away the closing `"` for multi-line content. Reorder instead: strip quoted spans from the
**entire `$COMMAND` string in one pass**, immediately after `COMMAND` is read (before line 67),
using a slurp-mode `sed` so newlines inside a quoted span do not defeat the match:

```bash
COMMAND_SCAN=$(printf '%s' "$COMMAND" | sed -e ':a' -e 'N' -e '$!ba' \
  -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g")
```

Then:
- Every one of the seven detectors reads `$COMMAND_SCAN` instead of raw `$COMMAND`.
- The now-redundant per-segment `sed` calls at lines 80 and 99 are deleted — the strip has
  already happened once, upstream, correctly.

This was reproduced end-to-end and confirmed to satisfy all three of the task's fix-shape
requirements simultaneously:

1. **Multi-line message no longer false-positives.** The same multi-line `essential-refactor`
   message that blocked above, run through the whole-command slurp strip first, stripped
   correctly to `git commit -m ""` before any flag regex ever sees it (segment extraction on the
   already-stripped string no longer straddles the unclosed-quote boundary, because there is no
   unclosed quote left in `$COMMAND_SCAN` — the newline-spanning `N`-loop closed it).
2. **True positives remain detected.** `git clean -fd -m "cleanup"` stripped to
   `git clean -fd -m ""` — the real, unquoted `-fd` flags survive the strip untouched and are
   still caught by the existing HAS_F/HAS_D logic. This is the correct general property: quoting
   only ever protects text that is *inside* quotes; real flags on the actual command line are
   never inside quotes and are never affected.
3. **The `--staged` inverse hazard stays closed.** `git restore foo.txt; echo "note: use --staged
   next time"` stripped to `git restore foo.txt; echo ""` — the `--staged` mention was inside a
   quoted echo argument and is removed before segment extraction, so the `git restore` segment
   correctly has no `--staged` token and is still flagged as `MATCHED` (blocked), exactly as a
   real destructive `git restore foo.txt` should be. Verified live: `restore seg: git restore
   foo.txt` / `WOULD BLOCK (correct)`.

This also directly extends the "already safe" pattern (which the task explicitly said to extend
rather than reinvent) to the five previously-unprotected destructive detectors — with the one
required correction, made **first**, that the pattern itself must become multi-line-aware or it
would propagate Cause 1 into the destructive chain rather than fix it there, exactly as the
addendum warns.

**Cause 2 (regex breadth) does not additionally need to be tightened for the reproduced failures**
to be closed — every reproduced trigger lived inside a `-m "..."`/`-m '...'` quoted argument, and
the whole-command strip removes that text before the flag regex ever runs. Recommend leaving the
existing flag regex's breadth as-is rather than tightening it in the same change: tightening it
correctly (distinguishing real short-option clusters from arbitrary hyphenated prose) is a
separate, riskier regex-design problem with its own false-negative surface, and the architecture
fix above already satisfies every acceptance criterion the task lists for Cause 2's symptoms
("essential-refactor", "auto-repair", "multi-task" never blocked, single- or multi-line). If a
future case surfaces where destructive-looking flag text appears *outside* any quoting (e.g. an
unquoted heredoc body, or `git commit -F somefile` where the message never appears in `$COMMAND`
at all and is therefore moot), that would be new evidence for tightening Cause 2 specifically —
not something to speculatively fix now without a reproduction.

### Additional finding: `#`-comment bypass of the `--staged` inverse-hazard boundary (not closed by the primary fix)

While verifying the inverse hazard in both directions, found a real, currently-live gap that the
whole-command quote-strip does **not** close, because `#` is not a quote character. A bash comment
sharing the same `;&|`-delimited segment as a real `git restore <path>` invocation is not stripped
by either the current or the recommended fix:

```
git restore foo.txt # use --staged next time
```

This is a single segment (no `;`, `&`, or `|` inside it), so `RESTORE_SEGMENTS` captures the whole
line including the comment, and the literal `--staged` substring in the comment falsely satisfies
the exemption check at line 137 — a genuinely destructive, path-discarding `git restore foo.txt`
is silently allowed through today, and would remain allowed through after the quote-strip fix
alone, since it was never inside quotes.

This is directly on-topic for the task's explicit acceptance criterion #3 ("The false-exemption
inverse is also closed"), and is cheap to close in the same change: strip `#`-to-end-of-line
comment text using the same upfront pass (a third `sed` clause on `$COMMAND_SCAN`, guarded so it
does not strip `#` characters that are themselves inside a quoted string — order the comment-strip
*after* the quote-strip so quoted `#` characters have already been neutralized to `""` and cannot
be mistaken for a real comment marker). Recommend including this as part of the same fix rather
than filing it separately, since it shares the exact mechanism and file location as the primary
fix and the task's own acceptance criteria already cover its symptom.

### Secondary defect: non-quote-aware `[^;&|]*` segment splitting — recommend out of scope

All seven detectors split `$COMMAND`/`$COMMAND_SCAN` into segments using a
`[^;&|]*`-terminated grep, which is not aware that `;`, `&`, or `|` characters can legitimately
appear inside a quoted string (already neutralized to `""`/`''` by the recommended fix, so this
risk is now confined to *unquoted* occurrences of those characters, which are rare and not
implicated in either live firing). Recommend recording this explicitly as **out of scope** for
this task:

- Neither of the two live firings, nor the third bisected reproduction, traces to segment-splitting
  truncation — both are fully explained by Causes 1 and 2 in the over-staging detector.
- A correct fix requires a real quote-aware tokenizer applied consistently across all seven
  detectors' segment-extraction regexes, which is a materially larger and separately-reviewable
  change than the quote-strip reordering above.
- None of the task's six acceptance criteria name `;`/`&`/`|`-inside-quotes as a required fix.

Recommend a one-line note in the implementation summary and/or a follow-up task/memory candidate
flagging it for future work, per the task's own instruction to "decide ... and record."

### Header comment update requirement (acceptance criterion 6)

Lines 41-47 currently frame "the whole tool_input.command string" as the sole observation
boundary (true and unaffected by this fix — still accurate). What needs updating is the
"Over-staging patterns" comment block at lines 67-72, which currently claims the quote-strip
belongs to (and is scoped to) the two over-staging detectors only ("Quoted spans are stripped
before flag-scanning so free-text commit messages ... never false-positive" — stated as if this
were already a complete, working guarantee). Post-fix, this should instead describe: (a) the
strip now happens once, upstream, against the whole multi-line command, before segment extraction;
(b) it now protects all seven detectors, not just the two over-staging ones; (c) comment text
(`# ...`) is also stripped for the same reason, closing the `--staged` inverse-hazard comment
bypass found above.

### Test suite house conventions (`context/standards/shell-script-testing.md`, confirmed against sibling suites)

Full convention doc read; canonical shape confirmed against `test-common-lib.sh` and
`test-validate-no-task-references.sh` (the closest analog — its own header literally says
"Modeled on guard-destructive-git.sh"):

- **Location**: `scripts/tests/test-guard-destructive-git.sh` — this is a narrow, single-script
  fixture-driven suite (not a broad pipeline suite), so it belongs under `scripts/tests/`, not flat
  in `scripts/`.
- **Helper convention**: `pass()`/`fail()`/`info()` functions incrementing integer `PASSED`/
  `FAILED` counters; `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` so the suite runs
  identically from source-store and deployed locations; `mktemp -d` workdir with
  `trap '...' EXIT` cleanup; exit 0 iff `FAILED` is 0, else exit 1.
- **Driving the hook**: model directly on `test-validate-no-task-references.sh` — drive the hook
  as a **real subprocess**, piping a synthetic PreToolUse JSON payload
  (`{"tool_input":{"command": "..."}}`, built with `jq`) on stdin, and assert on **exit code**
  (2 = blocked, 0 = allowed), never on stdout — this hook writes only stderr diagnostics and exits
  2/0, matching the same "no JSON on stdout" contract the model suite already documents.
- **Critical environmental setup this suite must get right, or it will silently always pass**:
  `guard-destructive-git.sh` line 63 exits 0 (allowed) immediately whenever
  `git status --porcelain` is empty **or errors** (stderr is discarded, so running outside any git
  repo also yields empty output and an early allow). Every test case that expects a BLOCK must run
  the hook with its cwd inside a real, dirty (uncommitted change present) git repo created fresh
  in the suite's `mktemp -d` workdir (e.g. `git init`, write and stage/modify a file, no snapshot
  marker present) — otherwise the clean-tree/non-repo exemption fires first and every case looks
  like a false "PASS" for the wrong reason.
- **Fixture convention**: inline heredocs constructed at suite start, no committed fixture files
  and no fixture-generator script — matches this hook's needs exactly (all fixtures are short
  command-line strings).
- **Mutation-check requirement (must not skip)**: per the "Mutation checks for regex-shaped fixes"
  section, this suite is not trustworthy until shown to fail against the pre-fix code at least
  once — revert the fix, confirm the new multi-line/comment cases go red, then restore the fix.
  This directly satisfies the task's own "a single-line-only suite would have passed against this
  defect" requirement.
- **Registration (required, separate from `run-all.sh` discovery)**: add
  `"tests/test-guard-destructive-git.sh"` to `manifest.json`'s `provides.scripts` array
  (subdirectory-qualified, matching the existing `"tests/test-..."` entries at manifest.json
  lines 165-180). This is required per `shell-script-testing.md`'s "Registration" section — it is
  independent of, and in addition to, `run-all.sh`'s own glob-based discovery.

### `run-all.sh` "declared in file scope" — already resolved, no code change needed

Read `run-all.sh` in full (180 lines). It auto-discovers every `scripts/tests/test-*.sh` and flat
`scripts/test-*.sh` under every extension directory via a glob loop (lines 82-100 source-store
mode, 106-116 deployed mode) — there is no per-suite registration list inside `run-all.sh` itself
to edit; a new suite dropped at `scripts/tests/test-guard-destructive-git.sh` is picked up
automatically the next time `run-all.sh` runs, in both modes, with zero code changes to that file.

Checked the referenced "open item": commit `a1dd3774d` ("task 34: declare run-all.sh in file
scope") is already present in this repository's history, with commit body: "The new regression
suite must be wired into the shared test runner, so that file belongs in the declared footprint."
This is a dispatch/orchestration-plan **file-scope declaration** (a territory-contract bookkeeping
entry naming which files this task's dispatch is allowed to touch, per the H7 pattern in
CLAUDE.md), not a code change to `run-all.sh`'s discovery logic — confirmed by reading the commit
diff scope and by `run-all.sh`'s own glob-based design requiring no registration step. No further
action is needed on `run-all.sh` itself beyond the manifest.json registration named above.

## Decisions

- Fix Cause 1 architecturally (whole-command, slurp-mode, multi-line-aware quote-strip applied
  once before all seven detectors), not by patching the existing per-segment `sed` calls in place.
- Do not additionally tighten the Cause-2 flag regex in this change; the architectural fix already
  satisfies every reproduced failure and every stated acceptance criterion.
- Close the `#`-comment inverse-hazard bypass found during this research in the same change (one
  additional `sed` clause, ordered after the quote-strip), since it is directly on-topic for
  acceptance criterion 3 and shares the same mechanism and location.
- Record the non-quote-aware `[^;&|]*` segment-splitting defect as explicitly out of scope for
  this task, with a one-line note/follow-up recommendation.
- New suite: `scripts/tests/test-guard-destructive-git.sh`, modeled directly on
  `test-validate-no-task-references.sh`'s subprocess-JSON-stdin/exit-code-assertion pattern, run
  inside a fresh dirty git repo per case, registered in `manifest.json`'s `provides.scripts`, and
  proven via the mandatory mutation check (fails against a reverted fix, passes against the real
  fix).
- `run-all.sh` requires no code change; only the `manifest.json` registration step is needed.

## Risks & Mitigations

- **Risk**: reordering the strip to run once, upstream, on the whole `$COMMAND` could
  unintentionally change over-staging detector behavior for cases the existing per-segment strip
  handled differently. **Mitigation**: the new suite must include the existing over-staging
  true/false-positive cases (criterion 4) alongside the new multi-line/comment cases, so any
  behavioral drift is caught before the old per-segment `sed` calls are deleted.
- **Risk**: a suite that constructs the dirty-git-repo fixture incorrectly (e.g. omitting the
  uncommitted change, or running outside a git repo) will silently pass every case regardless of
  the fix, per the clean-tree/non-repo early-exit at line 63. **Mitigation**: explicitly documented
  above; the suite should include one explicit meta-case asserting the fixture repo genuinely
  reports a dirty `git status --porcelain` before running any hook cases, so a broken fixture fails
  loudly rather than silently.
- **Risk (self-referential hazard named in the task)**: this task's own commits, plans, and test
  fixtures discuss destructive git commands and could trip the very guard being fixed, before the
  fix lands. **Mitigation**: none needed for this report (research only, no commits made by this
  agent); the implementer should expect this and, if blocked, record the exact trigger as
  additional evidence per the task's own instruction, rather than treating it as an obstacle.

## Context Extension Recommendations

- **Topic**: quote-stripping / flag-scanning contract for PreToolUse guard hooks.
- **Gap**: no standards doc currently states "strip quoted spans from the whole command once,
  upstream, before any line-based segment extraction" as a house pattern; the two over-staging
  detectors reinvented a per-segment version of it independently, and it silently didn't handle
  multi-line input. A short addition to an existing hooks/guard-related context file (or a new
  `context/patterns/quote-aware-command-scanning.md`) documenting this pattern would prevent the
  same line-based-strip mistake in any future PreToolUse guard.
- **Recommendation**: capture as a memory candidate (below) rather than a new context file for
  now, since this is the first occurrence of the pattern in this codebase; promote to a context
  file if a second guard hook needs the same treatment.

## Appendix

- Reproductions run as standalone bash fragments extracted verbatim from the live hook's own
  logic (not a modified copy of the hook), confirming both root causes and the candidate fix
  end-to-end, including the inverse-hazard direction.
- `git log -1` read for commits `a1dd3774d`, `18f8ec610`, `eeec9fd16` to confirm the "run-all.sh
  file scope" item's current resolved state and to double-check the reproduction commit shapes
  referenced in the task addenda.
- `grep -rn guard-destructive` cross-check confirmed the task's claim: only
  `root-files/settings.json` (registration), the hook's own header, and two "modeled on / mirrors"
  references in `hooks/validate-no-task-references.sh` reference this hook; no test coverage
  exists anywhere in the repository.

## Memory Candidates

1. **content**: "PreToolUse guard hooks that quote-strip free-text argument content (e.g. commit
   messages) before flag-scanning must do so on the whole (potentially multi-line) input string in
   one pass, using a slurp-mode sed (`:a;N;$!ba`) or equivalent — a per-segment strip applied after
   line-based `grep -oE` segment extraction silently fails on any quoted span containing a
   newline, because grep never matches across lines. Verified against
   `guard-destructive-git.sh`'s `git commit -a/-am` over-staging detector."
   **category**: PATTERN | **source_artifact**: this report | **confidence**: 0.85
   **suggested_keywords**: quote-strip, multi-line, sed slurp, PreToolUse hook, grep line-based

2. **content**: "guard-destructive-git.sh's early clean-tree exemption (`git status --porcelain`
   empty or erroring) means the hook silently allows EVERYTHING when run outside a real git repo
   or against a clean tree — any test suite for this hook must construct a fresh, genuinely dirty
   git repo as its execution cwd per case, or every case will falsely 'pass' via the exemption
   rather than via the detector logic under test."
   **category**: TECHNIQUE | **source_artifact**: this report | **confidence**: 0.8
   **suggested_keywords**: guard-destructive-git, test fixture, dirty git repo, false pass, cwd

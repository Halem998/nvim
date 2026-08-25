# Research Report: Task #79

**Task**: 79 - Make subagent-postflight hook diagnosable when its marker is malformed
**Started**: 2026-08-24T21:40:00Z
**Completed**: 2026-08-24T21:54:00Z
**Effort**: 1-3 hours
**Dependencies**: Sequenced after the subagent-postflight marker-ownership/correlation task (same
file, adjacent region of `main()`/`find_marker()`) — see "Sequencing" below.
**Sources/Inputs**: Codebase (hooks/, scripts/, context/patterns/, context/schemas/,
context/formats/, scripts/tests/, manifest.json)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is exactly as described: `jq -r '.reason // "Postflight operations pending"' 2>/dev/null`
  at `subagent-postflight.sh:90` returns empty string (not the default) on a JSON *parse* error,
  because `//` only fires on `null`/`false`, never on a parse failure — and `2>/dev/null` hides
  jq's own diagnostic. The blocked agent sees `{"decision":"block","reason":""}`.
- **Fix**: check parse validity with `jq empty` first (same call `events-log-lifecycle.sh:127`
  already makes against the identical file), branch to a reason that names the marker path and
  jq's own error text when it fails, and always build the final JSON with `jq -n --arg` instead
  of hand-interpolating `$reason` into a string literal. This single change satisfies acceptance
  criteria 1–3 at once; verified as valid JSON for quote/backslash/newline content (see Findings).
- **Design question 2 (block vs. fail-open) has a decisive answer already in the file**:
  `check_loop_guard()` unconditionally allows the stop after `MAX_CONTINUATIONS` (3) blocks
  regardless of *why* it blocked, clearing the marker and loop guard itself. This is a pre-existing
  circuit breaker. **Recommendation: keep blocking (fail closed) with a diagnostic reason** — the
  entrapment risk the task worries about is already bounded to 3 continuations by code that exists
  today, so there is no need to invent a fail-open path to avoid it.
- **Hook survey result is narrower than the task's own estimate**: of the ~52 occurrences of the
  `jq -r '... // ...'` idiom across the 13 core hook files, only **one** site — this one —
  has a non-empty, semantically load-bearing default that a parse error silently defeats. Two
  other non-`// empty'` sites (`wezterm-task-number.sh:38`, `wezterm-preflight-status.sh:55`) use
  `// ""`, which is behaviorally indistinguishable from `// empty` for their callers (both treat
  "no prompt text" as a no-op). No other site needs a code change; all are tolerant-by-design.
- `events-log-lifecycle.sh`'s `exit_success` on `jq empty` failure (line 127) is a correct guard
  as a guard, but its *consequence* — total silence, no event — is the "second victim" the task
  names. The task-number segment of `dirname "$MARKER_FILE"` is available *before* the JSON parse
  is attempted, so a malformed-marker event can be logged using the same state.json-lookup
  fallback the hook's own Stop path already uses (lines 176–184) to recover `session_id` when it
  isn't directly available. No new correlation mechanism is needed.

## Context & Scope

Researched the exact failure mechanism, the sibling-hook precedent, the hook-wide idiom survey,
the three design questions, and the file/directory conventions needed to write phase-ready
findings for `/plan`. Did not modify any files — this is a research-only dispatch producing a
report, `.return-meta.json`, and the orchestrator handoff JSON.

## Findings

### Codebase Patterns

**`subagent-postflight.sh` (agent-system/extensions/core/hooks/subagent-postflight.sh)**

- Lines 12–31 (`find_marker`): resolves `MARKER_FILE`/`TASK_DIR`/`LOOP_GUARD_FILE` from
  `find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1`, with a global-marker
  fallback. This resolution happens on the *path*, before any JSON parsing — so a task number and
  marker path are always available even when the marker's content is garbage. (Ownership of which
  marker `head -1` picks is the sibling task's concern, out of scope here per the file-scope note
  in the task description.)
- Lines 42–61 (`check_loop_guard`): increments `.postflight-loop-guard`'s counter on every call and,
  on `count >= MAX_CONTINUATIONS` (3), **unconditionally** removes both the loop guard and the
  marker file and returns 1 (allow stop) — this runs identically whether the block reason was
  meaningful or empty. This is the existing circuit breaker referenced in the Executive Summary.
- Line 90 is the defect site: `jq -r '.reason // "Postflight operations pending"' "$MARKER_FILE" 2>/dev/null`.
  Verified locally: `jq empty` on a non-JSON file exits nonzero and prints
  `jq: parse error: Invalid numeric literal at line 1, column 4` (or similar) to stderr only;
  `jq -r '.reason // "default"'` on the same file produces empty stdout, not `"default"`. This
  confirms the task's stated mechanism exactly.
- Line 95: `echo "{\"decision\": \"block\", \"reason\": \"$reason\"}"` — hand-built JSON with
  `$reason` interpolated unescaped. Any `.reason` value containing `"`, `\`, or a literal newline
  produces invalid JSON on stdout. The inline comment justifying this ("no jq dependency for
  robustness") is already false: line 90 unconditionally shells out to `jq`, so there is no
  jq-free code path being protected. Fixing line 90's branch and line 95's JSON construction in
  the same change is a single coherent fix, not two separate ones — both stem from "we have jq
  available, use it correctly."

**`events-log-lifecycle.sh` (agent-system/extensions/core/hooks/events-log-lifecycle.sh)**

- Line 125: identical marker resolution to `subagent-postflight.sh`'s `find_marker`
  (`find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1`), duplicated rather than
  shared — worth noting for the plan but not this task's problem to fix (no shared helper exists
  today for this specific find-and-select operation).
- Line 127: `jq empty "$MARKER_FILE" 2>/dev/null || exit_success` — this is the exact fix pattern
  the task points to. It is correct as a guard against processing garbage, but `exit_success`
  means `echo '{}'; exit 0` (line 54–57): the malformed-marker case produces **zero** durable
  signal. This is real: an operator reconstructing "what happened to this stuck agent" from
  `specs/events.jsonl` after the fact finds nothing between the last real event and whatever
  eventually resolved the stop (loop-guard timeout or manual intervention).
- Lines 176–184 (Stop path, unrelated branch but directly reusable): when `session_id` cannot be
  read from a marker/direct source, the hook recovers it by reading the **task number** from a
  different signal (there: `workflow-active-<CC_SESSION_ID>` or a regex over
  `last_assistant_message`) and then looking up `.active_projects[] | select(.project_number ==
  $num) | .session_id` in `specs/state.json`. The exact same technique applies to the malformed-
  marker case in the SubagentStop branch: `task_dir=$(dirname "$MARKER_FILE")` and the
  `specs/([0-9]+)_` regex already used at line 137 (in the *successful*-parse path further down)
  recover a task number from the **path alone**, with no dependency on the marker's content
  parsing. That task number can then feed the identical state.json lookup used at lines 181–183.
  This closes the "second victim" gap with an in-repo pattern, not a new mechanism, matching the
  task's instruction not to invent one.
- `category` for such an event: schema's closed 4-value taxonomy is
  `deviation|blocker|milestone|success` (`context/schemas/events-schema.json`). A malformed
  marker preventing a subagent from stopping cleanly is a `deviation` (an actual anomaly in the
  expected flow, not a `blocker` from an external dependency and not a `milestone`/`success`).
  Recommend `--event-type malformed_postflight_marker --category deviation` with `--detail-json`
  carrying the marker path and jq's error text, mirroring the existing `--detail-json` usage
  pattern documented in `events-append.sh`'s own usage block.
- **Constraint to carry into planning**: `session_id` is a *required*, pattern-constrained
  (`^sess_[0-9]+_[a-zA-Z0-9]+$`) field on every events.jsonl line (`events-schema.json`). If the
  state.json lookup itself comes up empty (task not found, or found but session_id absent — e.g.
  a task directory whose state.json entry was already archived), there is still no valid
  `session_id` to emit with, and the existing `[ -z "$session_id" ] && exit_success` idiom used
  everywhere else in this file is the right fallback for that residual case — the fix narrows the
  silent-failure window, it does not eliminate every path to `exit_success`.

**`skill_create_postflight_marker` (agent-system/extensions/core/scripts/skill-base.sh:247)**
confirmed as the single production writer of Shape A markers (per its own header comment,
already-settled canonical schema: `session_id, skill, task_number, operation, reason, created,
stop_hook_active`). Confirms the task's framing: this function is not the culprit; some other,
already-understood caller bug produced the malformed marker observed live, and that bug is out of
scope here.

### Hook-Wide `jq -r '... // ...'` Idiom Survey (Acceptance Criterion 5)

Ran `grep -n "jq -r '.*//.*'" agent-system/extensions/core/hooks/*.sh` — **52 occurrences across
13 files** (broader than the task description's ~38-site/8-file estimate, which undercounted;
the extra files are `validate-state-sync.sh`, `wezterm-preflight-status.sh`,
`validate-plan-write.sh`, `wezterm-task-number.sh`). Classified every occurrence by its fallback
expression:

| Fallback shape | Count | Verdict |
|---|---|---|
| `// empty` | 49 | Tolerant-by-design. Parse failure and "field absent" both yield empty string, and every calling site already treats empty as "skip/no-op" (`[ -z "$X" ] && exit_success`-style guards throughout). Parse-error and absent-field are indistinguishable **and that is fine** because both are handled identically downstream. |
| `// .new_string` / `// .tool_input.new_string` (2, both in `validate-no-task-references.sh:60,64`) | 2 | Field-name fallback chains, not "default value" patterns — both terminate in `// empty` (`.content // .new_string // empty`), so they collapse into the same tolerant-by-design bucket. |
| `// ""` (`wezterm-task-number.sh:38`, `wezterm-preflight-status.sh:55`) | 2 | Same class as `// empty` for the caller's purposes: both extract `.prompt` for pattern-matching tier logic that already treats an empty/missing prompt as "nothing to do." A parse failure here (which would mean Claude Code's own hook stdin was itself malformed — a different, more fundamental failure) produces the same safe no-op as an absent field. |
| `// "Postflight operations pending"` (`subagent-postflight.sh:90`) | **1** | **The only site with a non-empty, semantically meaningful default that a parse error silently discards, producing user-visible confusion.** This is the fix target. |

**Conclusion**: the survey requirement is satisfied by documenting 51 of 52 sites as
tolerant-by-design (no code change needed) and fixing the one genuine defect. This is a narrower,
more defensible scope than the task description's directive to "classify the sites" might suggest
was needed — there turns out to be exactly one site needing intervention, not a family of them.

### Design Question Resolutions

1. **Distinguishing "no `.reason` field" from "does not parse at all"**: solved structurally by
   checking `jq empty "$MARKER_FILE"` *before* attempting to read `.reason`, exactly mirroring
   `events-log-lifecycle.sh:127`'s existing guard. Parse-success path keeps today's
   `.reason // "Postflight operations pending"` behavior unchanged (acceptance criterion 2).
   Parse-failure path builds an explicit reason naming the marker's path and jq's own error text.

2. **Block vs. fail-open on an unparseable marker**: **block, with a diagnostic reason** (fail
   closed). The task frames this as an open tradeoff to argue, but `check_loop_guard()` already
   resolves the entrapment risk that would otherwise motivate fail-open: after 3 blocked
   continuations the hook itself deletes the marker and loop guard and allows the stop,
   unconditionally, independent of the reason text's content. A malformed marker therefore costs
   at most 3 continuation cycles before self-resolving — the same bound that already applies to
   *every* blocked stop today, malformed marker or not. Failing open instead would mean: any
   marker corruption (including transient corruption from a concurrent writer mid-write, which is
   plausible given the marker is a plain `cat > file <<EOF` with no atomic rename) silently loses
   the premature-termination guard the whole pattern exists to provide. Fail-closed-with-diagnostic
   dominates fail-open here because the existing loop guard already caps the downside of failing
   closed, while fail-open has no corresponding cap on its downside (an unbounded window of
   silently-unprotected premature stops). No new mechanism is needed for this decision — it falls
   out of code that already exists.

3. **Reason content when blocking on a parse failure**: must name the marker path and state that
   it could not be parsed (task's own requirement, and acceptance criterion 1). Verified pattern:
   ```bash
   if jq empty "$MARKER_FILE" 2>/dev/null; then
     reason=$(jq -r '.reason // "Postflight operations pending"' "$MARKER_FILE" 2>/dev/null)
   else
     parse_err=$(jq empty "$MARKER_FILE" 2>&1 >/dev/null | head -1)
     reason="Postflight marker at ${MARKER_FILE} could not be parsed as JSON (${parse_err}); manual inspection required"
   fi
   echo "{\"decision\": \"block\", \"reason\": $(jq -n --arg r "$reason" '$r')}"
   ```
   Locally verified: produces valid JSON for the parse-failure case (jq's own error text embedded
   safely), and separately verified `jq -n --arg` round-trips a reason string containing an
   embedded `"`, a `\`, and a literal newline into valid JSON — closing acceptance criterion 3 for
   *both* the parse-failure reason and the normal-default reason in one construction, since both
   paths converge on the same `jq -n --arg` output step.

### Sequencing (file-scope overlap)

Confirmed via `find_marker()`/`main()` read above: the sibling ownership/correlation task and this
task touch adjacent but non-overlapping regions of the same function body (`find_marker`'s
`head -1` selection logic vs. `main`'s `.reason` extraction/JSON-construction at lines 90–95). No
line-level conflict is expected, but this task's diff is only meaningful once the marker
*selection* logic from the sibling task has landed — reviewing/planning against the current
`head -1` call as a stable base risks basing the reason/format fix on code that is about to move.
Confirmed the task's own instruction to sequence this task second is consistent with what's in the
file today.

### Test Design Recommendation

No existing test exercises `subagent-postflight.sh` or `events-log-lifecycle.sh`'s SubagentStop
branch directly (`find agent-system/extensions/core/scripts/tests -iname '*postflight*'` returns
only `test-lint-postflight-boundary.sh` and `test-postflight-marker-schema.sh`, neither of which
drives the hook script itself). The established pattern for hook-as-subprocess testing in this
repo is `test-guard-destructive-git.sh`: pipe a synthetic JSON payload on stdin, drive the hook as
a real subprocess from a `mktemp -d` fixture directory, assert on stdout/exit code, `pass()`/
`fail()`/`info()` counters, `trap EXIT` cleanup, register in
`agent-system/extensions/core/manifest.json`. A new `test-subagent-postflight-marker.sh` (or
similarly named) suite should follow this exact structure with cases for: (a) well-formed marker
with `.reason` present → existing reason passes through unchanged; (b) well-formed marker missing
`.reason` → `"Postflight operations pending"` default fires; (c) non-JSON marker content → reason
names the marker path and states parse failure, and stdout is valid JSON; (d) marker whose
`.reason` contains a `"`, a `\`, and a newline → stdout remains valid JSON. A companion case in an
`events-log-lifecycle.sh` suite should assert that a malformed marker produces exactly one
`deviation`-category event with a valid `session_id` recovered via the state.json path-based
lookup (or, when that lookup itself fails, that the hook still exits cleanly with `{}`).

## Decisions

- Fix targets exactly one hook idiom site (`subagent-postflight.sh:90`); no other of the 52
  surveyed sites needs a code change.
- Resolve unparseable-marker handling as **fail-closed with a diagnostic reason**, relying on the
  existing `MAX_CONTINUATIONS=3` loop guard as the entrapment bound — do not add a new fail-open
  path.
- Build the hook's JSON output via `jq -n --arg` unconditionally (both the default-reason and
  parse-failure-reason branches), removing the stale "no jq dependency" justification comment at
  line 94, since line 90 already makes jq a hard dependency.
- Close the events-log-lifecycle.sh "second victim" gap by recovering task number from the marker
  file's *path* (available pre-parse) and looking up `session_id` via the same
  `specs/state.json` `.active_projects[] | select(.project_number == $num)` pattern the Stop path
  in the same file already uses at lines 181–183 — emit one `deviation`-category event, not a
  new event schema or field.
- New regression coverage should be a new `test-subagent-postflight-marker.sh`-style suite
  following `test-guard-destructive-git.sh`'s subprocess-driven structure, registered in
  `agent-system/extensions/core/manifest.json`.

## Risks & Mitigations

- **Risk**: embedding jq's raw stderr text into the reason string could leak an unexpectedly long
  or multi-line parse error for a badly corrupted file. **Mitigation**: `head -1` on the captured
  error (already reflected in the verified snippet above) bounds it to one line; `jq -n --arg`
  handles any remaining special characters safely regardless of length.
- **Risk**: the state.json task-number lookup for the malformed-marker event could itself return
  no `session_id` (task already archived/vaulted). **Mitigation**: already covered by the
  existing `[ -z "$session_id" ] && exit_success` fallback used throughout the file — no new
  failure mode is introduced, the fix only narrows an existing silent-failure window.
- **Risk**: sequencing collision with the marker-ownership task if both land against a stale base.
  **Mitigation**: this task's plan/implementation should re-read `find_marker()`/`main()` fresh
  immediately before editing, per the task's own sequencing note; do not implement against a
  cached read of the current file.

## Context Extension Recommendations

- **Topic**: `jq` parse-error vs. missing-field distinction as a general hook-writing hazard.
- **Gap**: `context/patterns/postflight-control.md` documents the marker protocol and hook
  behavior narratively but does not call out the `//`-operator parse-error blind spot this task
  fixes; a future hook author reusing `jq -r '.field // "default"'` with a non-empty default could
  reintroduce the same class of defect elsewhere.
- **Recommendation**: after the fix lands, add a short note to
  `context/patterns/postflight-control.md`'s "SubagentStop Hook Behavior" section (or a new
  shared shell-scripting standard) stating the rule surfaced by this survey: `// "non-empty
  default"` is only safe when preceded by an explicit `jq empty` parse-validity check; `// empty`
  is safe unguarded because absent-field and parse-error are equivalent for a caller that already
  treats empty as "skip."

## Appendix

- Search queries used: `grep -n "jq -r '.*//.*'" agent-system/extensions/core/hooks/*.sh`;
  `grep -n "jq -r '.*//.*'" ... | grep -v "// empty'"`; `find ... -iname "*postflight*"`.
- Files read in full: `agent-system/extensions/core/hooks/subagent-postflight.sh`,
  `agent-system/extensions/core/hooks/events-log-lifecycle.sh`,
  `agent-system/extensions/core/context/patterns/postflight-control.md` (partial, through the
  SubagentStop Hook Behavior section), `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
  (partial), `agent-system/extensions/core/scripts/tests/test-postflight-marker-schema.sh` (partial).
- Files inspected via targeted excerpt: `agent-system/extensions/core/scripts/skill-base.sh`
  (`skill_create_postflight_marker`), `agent-system/extensions/core/scripts/events-append.sh`
  (usage block), `agent-system/extensions/core/context/formats/events-format.md` (session_id
  field table), `agent-system/extensions/core/context/schemas/events-schema.json` (full schema).
- Verified locally (scratch, not committed): `jq empty` error text on a non-JSON file;
  `jq -r '.field // "default"'` returning empty (not the default) on the same file;
  `jq -n --arg` round-tripping a reason string with embedded `"`, `\`, and newline into valid JSON.

# Research Report: Task #65

**Task**: 65 - Fix skill_orchestrate_mint_dispatch_seq to increment from the persisted counter
**Started**: 2026-08-17T18:26:00Z
**Completed**: 2026-08-17T18:45:00Z
**Effort**: 1-2 hours (single-function fix + one new regression test)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/skill-base.sh` (the defective function)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage 2 init/resume, Stage
  3/4/5 call sites, Stage MT-4 multi-task engine)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (Stage 2 init/resume,
  Stage 3/4/5 call sites)
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh`
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh`
- `context/patterns/dispatch-report-not-termination.md` (cited rationale for why `dispatch_seq`
  must be orchestrator-minted and never repeat)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Confirmed exactly as described: `skill_orchestrate_mint_dispatch_seq()`
  (`agent-system/extensions/core/scripts/skill-base.sh:947-955`) computes
  `dispatch_seq_counter=$((dispatch_seq_counter + 1))` from the **ambient shell variable**, then
  persists that result to the loop guard file. It never reads the counter back out of the file
  inside the function itself.
- Both engines' Stage 2 *does* correctly read `dispatch_seq_counter` from the loop guard on
  init/resume — but that read happens in Stage 2's own fenced ```bash``` block. Every call site
  that actually invokes `mint_dispatch_seq` (`dispatch_seq=$(mint_dispatch_seq)`) lives in a
  **separate** fenced ```bash``` block further down the same SKILL.md (Stage 3/4/5, one block per
  stage — 8 call sites in the base engine, 5 in the hard engine). An orchestrator that executes
  each fenced block as its own Bash tool call runs each block in a fresh shell, so the Stage
  2-populated `dispatch_seq_counter` variable is gone by the time `mint_dispatch_seq` runs. In a
  fresh shell the unset variable arithmetically evaluates to `0 + 1 = 1`, so every dispatch in a
  multi-Bash-call orchestration re-mints `dispatch_seq=1` regardless of how many prior dispatches
  already ran.
- The **correct pattern already exists in the same codebase**: the multi-task engine's Stage MT-4
  (`skill-orchestrate/SKILL.md:2086`) mints its own per-task `dispatch_seq_counter` with
  `task_dispatch_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$mt_state_file")` — reading and
  incrementing from the persisted file in one jq expression, never touching an ambient shell
  variable. This is the idiom to port into `skill_orchestrate_mint_dispatch_seq`.
- **Test coverage gap confirmed**: `test-handoff-dispatch-identity.sh` never calls
  `mint_dispatch_seq()` or `skill_orchestrate_mint_dispatch_seq()` at all — it injects a
  `minted_seq` value directly as a fixture parameter and only exercises the Stage 5 *comparison*
  logic downstream of minting. `test-loop-guard-budget-override.sh` checks that
  `dispatch_seq_counter` survives a budget-continuation re-init, but likewise never calls the
  mint function. No existing test would catch this defect or a regression of the fix.
- Both `skill-orchestrate/SKILL.md` and `skill-orchestrate-hard/SKILL.md` share the exact same
  `mint_dispatch_seq()` named-shim body (`skill_orchestrate_mint_dispatch_seq "$loop_guard_file"`,
  deliberately kept in sync per the task-055 dedup work), so both are affected identically and
  both are fixed by a single change to the shared function in `skill-base.sh`. No SKILL.md edit
  is required.
- Impact confirmed as stated: a same-value `dispatch_seq` across dispatches defeats the Stage 5
  identity gate `context/patterns/dispatch-report-not-termination.md` documents as the
  discriminator against a woken predecessor's late handoff write — a scenario mtime alone cannot
  catch.

## Context & Scope

Scope is a single-function bug fix in `scripts/skill-base.sh`, confined to
`skill_orchestrate_mint_dispatch_seq()`. No SKILL.md changes are required because both engines
call the shared function through an already-correct named-shim (`mint_dispatch_seq()` ->
`skill_orchestrate_mint_dispatch_seq "$loop_guard_file"`) with no engine-specific logic to touch.
The fix must preserve the function's existing contract: read `<loop_guard_file>` as `$1`, persist
the incremented `dispatch_seq_counter` and `last_updated` to it, and echo the new value on stdout
for the caller to capture via `dispatch_seq=$(mint_dispatch_seq)`.

## Findings

### Codebase Patterns

**The defect, verbatim** (`agent-system/extensions/core/scripts/skill-base.sh:947-955`):

```bash
skill_orchestrate_mint_dispatch_seq() {
  local loop_guard_file="$1"
  dispatch_seq_counter=$((dispatch_seq_counter + 1))
  jq --argjson seq "$dispatch_seq_counter" \
     --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.dispatch_seq_counter = $seq | .last_updated = $updated' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "$dispatch_seq_counter"
}
```

`dispatch_seq_counter` is read here as an ambient global — never as a value read from
`$loop_guard_file` inside the function body. It relies entirely on the caller having already set
it correctly in the *same shell process*.

**Why the ambient variable is unreliable across dispatches.** Both SKILL.md files read
`dispatch_seq_counter` from the loop guard at Stage 2 (resume path, e.g.
`skill-orchestrate/SKILL.md:166`: `dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0'
"$loop_guard_file")`), define `mint_dispatch_seq()` as a shim right after, then the SKILL.md
continues through several further fenced ```bash``` blocks (Stage 3 write-context, Stage 4
dispatch, Stage 5 result-read, each its own code block) that call `dispatch_seq=$(mint_dispatch_seq)`.
Confirmed call sites:
- Base engine (`skill-orchestrate/SKILL.md`): lines 339, 383, 422, 465, 502, 574, 631, 1151 — 8
  separate call sites, each inside its own fenced block, all downstream of the Stage 2 block that
  set the ambient variable.
- Hard engine (`skill-orchestrate-hard/SKILL.md`): lines 582, 617, 669, 706, 835 — 5 call sites,
  same shape.

An orchestrator that runs the whole SKILL.md body as one long-lived shell (heredoc or a single
`bash -c` covering every stage) would keep the ambient variable alive across all these blocks and
never see the bug. An orchestrator that issues each fenced block as its own Bash tool
invocation — the normal execution shape for an LLM agent driving `/orchestrate`, per both the
original report and the second independent confirmation from a different repository — starts a
fresh shell per block. `dispatch_seq_counter` is unset in that fresh shell, so
`$((dispatch_seq_counter + 1))` evaluates to `1` (bash treats an unset variable as `0` in
arithmetic context) every single time, regardless of how many dispatches already happened and
regardless of what value is already persisted in the loop guard file.

**The correct idiom already lives in the same file**, in the multi-task engine's Stage MT-4
(`skill-orchestrate/SKILL.md:2081-2088`):

```bash
task_dispatch_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$mt_state_file")
jq --argjson t ... --arg ts ... --argjson seq "$task_dispatch_seq" \
  '.dispatch_start_ts[$t] = $ts | .dispatch_seq[$t] = $seq | .dispatch_seq_counter = $seq' \
  ...
```

This reads and increments the counter from the persisted state file in one `jq` expression,
independent of any shell variable set by an earlier block. This is the exact idiom the task
description's "likely fix" names, and it is already proven correct and battle-tested elsewhere
in the same codebase (it is what the caller-side workaround in the second independent
confirmation manually re-derived by hand: `dispatch_seq_counter=$(jq -r
'.dispatch_seq_counter // 0' "$loop_guard_file")` immediately before each mint call).

**No engine-specific logic to preserve.** Both engines' `mint_dispatch_seq()` shims are
byte-identical one-liners delegating to `skill_orchestrate_mint_dispatch_seq "$loop_guard_file"`
(confirmed at `skill-orchestrate/SKILL.md:223-225` and `skill-orchestrate-hard/SKILL.md:420-422`,
part of the task-055 dedup that collapsed both engines' bodies onto this one shared function —
see `specs/archive/055_dedupe_orchestrate_skill_bodies/locked-regions.md`). Fixing the shared
function in `skill-base.sh` fixes both engines simultaneously; no SKILL.md edit is needed or
warranted.

**Ambient `dispatch_seq_counter` has no other readers after Stage 2.** Grep across both SKILL.md
files for `$dispatch_seq_counter` / `.dispatch_seq_counter` shows the ambient variable is read
only at Stage 2 (init/resume assignment) and written only inside the mint function. Nothing else
in either engine depends on the ambient variable's value being kept in sync across calls, so
switching the function to read-from-file exclusively (and no longer depending on the ambient
value at all) changes no other behavior.

### External Resources

Not applicable — this is a self-contained shell/jq bug in project-owned orchestration
infrastructure, not a third-party library issue.

### Recommendations

**Fix** (in `agent-system/extensions/core/scripts/skill-base.sh`, function body only):

```bash
skill_orchestrate_mint_dispatch_seq() {
  local loop_guard_file="$1"
  local new_seq
  new_seq=$(jq -r '(.dispatch_seq_counter // 0) + 1' "$loop_guard_file")
  jq --argjson seq "$new_seq" \
     --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.dispatch_seq_counter = $seq | .last_updated = $updated' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "$new_seq"
}
```

This mirrors the MT-4 idiom exactly (`(.dispatch_seq_counter // 0) + 1`), removes all dependence
on the ambient `dispatch_seq_counter` shell variable inside the function, and is safe under
repeated same-shell calls too (each call re-reads the file, which the prior call already
persisted — no double-increment or skipped-increment risk from calling it twice in one shell).

Whether to also drop the now-functionally-dead Stage 2 ambient `dispatch_seq_counter` assignment
lines (`skill-orchestrate/SKILL.md:166,211`; `skill-orchestrate-hard/SKILL.md:368,409`, plus the
two `dispatch_seq_counter=0` fresh-start assignments) is a judgment call for planning, not
research: they become unused by the mint path after this fix, but they are also read into
`jq -n` literals when re-persisting the guard on the fresh-start branches (`"dispatch_seq_counter":
0` in the `jq -n` init payload) and referenced in nearby comments explaining the counter's
survive-across-resume contract. Leaving them in place is harmless (dead-but-documented) and lower
risk than touching two files whose bodies are deliberately kept byte-identical by the task-055
dedup; recommend leaving them as-is unless the plan phase decides the comment/variable now reads
as misleading.

**Test recommendation**: `test-handoff-dispatch-identity.sh` and
`test-loop-guard-budget-override.sh` both stop short of the minting function itself. Neither
would have caught this defect, and neither will catch a regression of the fix. Recommend a new
regression test (or a new case appended to one of the above, following its existing
mktemp-workdir + subshell harness pattern) that specifically:
1. Sources `skill-base.sh` fresh (unsetting/not pre-seeding `dispatch_seq_counter`) — reproducing
   the "fresh shell" precondition described in both incident reports.
2. Seeds a loop guard fixture with `dispatch_seq_counter: 1`.
3. Calls `skill_orchestrate_mint_dispatch_seq "$loop_guard_file"` once and asserts the returned
   value is `2` (not `1`), and that the file's persisted `.dispatch_seq_counter` is also `2`.
4. Calls it again in the SAME subshell (simulating a second dispatch inside a script that already
   consumed a stale ambient value) and asserts it returns `3`.
5. A companion case launching the function call in a genuinely separate `bash -c '...'`
   subprocess (no shared shell state at all) against the same guard file, asserting the counter
   still advances monotonically — this is the most faithful reproduction of the reported
   multi-Bash-tool-call execution shape.

## Decisions

- Scope the fix to `skill_orchestrate_mint_dispatch_seq()` in `scripts/skill-base.sh` only; no
  SKILL.md changes needed since both engines already delegate through an identical named-shim.
- Adopt the `jq -r '(.dispatch_seq_counter // 0) + 1' "$loop_guard_file"` idiom, matching
  Stage MT-4's proven pattern rather than inventing a new one.
- Recommend leaving the now-redundant Stage 2 ambient-variable reads/writes in both SKILL.md
  files untouched — they are harmless and touching them risks the byte-identical-twin invariant
  the task-055 dedup established; defer any cleanup there to the planning stage's judgment.
- Recommend a new fresh-shell/fresh-subprocess regression test as a required companion to the
  fix, since neither existing test exercises the mint function itself.

## Risks & Mitigations

- **Risk**: A caller that (incorrectly) relies on the ambient `dispatch_seq_counter` being
  mutated as a side effect of calling `mint_dispatch_seq` (rather than only reading the function's
  stdout) would silently stop seeing that mutation once the fix removes the ambient
  read/increment. **Mitigation**: grep confirms no such reader exists in either SKILL.md — the
  ambient variable is written only at Stage 2 and read only inside the (now-fixed) mint function;
  all real consumers use `dispatch_seq=$(mint_dispatch_seq)`, the stdout-capture form.
- **Risk**: jq read failure (missing/corrupt loop guard) inside the new read expression could
  break minting where the old ambient-arithmetic path degraded silently instead.
  **Mitigation**: by the time `mint_dispatch_seq` is ever called, Stage 2 has already
  unconditionally created or validated the loop guard file (`jq empty "$loop_guard_file"` gate
  plus init-marker atomic creation), so the file is guaranteed to exist and be valid JSON at every
  call site; this is the same precondition Stage MT-4's existing identical idiom already relies
  on without incident.
- **Risk**: Concurrent dispatches minting against the same loop guard file could race between the
  read and the write (read-then-write is not atomic). **Mitigation**: out of scope for this task
  — the existing write already uses the tmp-file + `mv` idiom for atomic replacement, and
  single-task loop-guard access is already serialized by the orchestrator's own single-threaded
  cycle loop; the multi-task engine's per-task lock (Stage MT-4) is the existing mitigation for
  its own concurrent case and is unaffected by this fix.

## Appendix

- Search queries used: `grep -rn skill_orchestrate_mint_dispatch_seq`, `grep -n
  dispatch_seq_counter` (both SKILL.md files and skill-base.sh), `grep -n mint_dispatch_seq\b`
  (call-site enumeration), targeted `sed -n` reads of Stage 2 blocks in both engines and of
  Stage MT-4's per-task dispatch-seq block.
- Related prior work: `specs/archive/055_dedupe_orchestrate_skill_bodies/` established the
  shared-function/named-shim architecture this fix operates within;
  `locked-regions.md` from that task documents exactly where `mint_dispatch_seq`'s definition
  sits relative to the two engines' locked test-extraction regions (outside both, confirmed safe
  to touch without affecting `test-loop-guard-budget-override.sh`'s or
  `test-handoff-dispatch-identity.sh`'s `eval`-extracted regions).
- `context/patterns/dispatch-report-not-termination.md` — cited rationale for why `dispatch_seq`
  must be orchestrator-minted, monotonic, and never repeated within a task; this is the property
  the current bug violates.

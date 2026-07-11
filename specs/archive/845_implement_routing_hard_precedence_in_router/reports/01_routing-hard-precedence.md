# Research Report: Task #845

**Task**: 845 - Implement the `--hard`/`routing_hard` 5-step precedence in `command-route-skill.sh`
**Started**: 2026-07-11T00:52:24Z
**Completed**: 2026-07-11T01:15:00Z
**Effort**: ~45 minutes (research only)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/scripts/command-route-skill.sh`, `.claude/extensions/core/scripts/command-route-skill.sh`,
  `.claude/tests/test-command-route-skill.sh`, `.claude/scripts/check-extension-docs.sh`,
  `.claude/context/guides/hard-mode-routing.md`, `.claude/extensions/{core,cslib,lean}/manifest.json`,
  `.claude/CLAUDE.md`, `.claude/extensions/core/merge-sources/claudemd.md`,
  `.claude/commands/{research,plan,implement}.md`
- Git history: `git log`, `git show` on the above files (commits `1e74df259`, `b77ca0396`,
  `574bf515a`, `40210f576`), archived task artifacts at `specs/archive/768_routing_hard_resolution_composition/`
- Live test execution: `bash .claude/tests/test-command-route-skill.sh`, `bash .claude/scripts/check-extension-docs.sh`
**Artifacts**: This report (`specs/845_implement_routing_hard_precedence_in_router/reports/01_routing-hard-precedence.md`)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Re-verification confirms task #843's finding**: `.claude/scripts/command-route-skill.sh`
  (and its byte-identical extension-source copy) currently take only 3 positional args and
  never read `.routing_hard` from any manifest. Running the test suite live gives **6 PASS / 8
  FAIL** (exit 1), not the "matches docs" state CLAUDE.md implies.
- **This is a REGRESSION, not a never-built feature.** Git history shows the full 5-step
  precedence was implemented, tested (12/12 passing at the time), and documented by task #768
  in commit `574bf515a` (2026-06-24) — but task #768 patched **only the deployed copy**
  (`.claude/scripts/command-route-skill.sh`), never the extension-source copy
  (`.claude/extensions/core/scripts/command-route-skill.sh`). That is itself a byte-identity
  drift violation of the kind task #841's guard now polices.
- **The stale extension-source copy silently overwrote the fix.** `check-extension-docs.sh`'s
  own Rule F comment documents the mechanism: the Lua extension loader does a byte-for-byte
  overwrite of `.claude/scripts/<name>` from `<extension>/scripts/<name>` on every extension
  load/reload. Because the source copy was never updated, a later reload (landing inside
  unrelated commit `40210f576`, task #784, "/pr command workflow selection", 2026-06-30) wiped
  the Step 4 block back out of the deployed copy, restoring the pre-768 3-arg script. That
  commit's diff to `command-route-skill.sh` is a pure revert of task #768's hard-mode block
  and nothing else.
- **Source of truth**: the documented 5-step precedence in CLAUDE.md / `hard-mode-routing.md`
  and the test file are correct and match task #768's original (working) implementation
  byte-for-byte in spirit. The **script is behind**, and the fix is best understood as
  "restore task #768's Step 4 block into BOTH copies" rather than a fresh design.
- **The task-description path for the test file is wrong**: it says
  `.claude/scripts/test-command-route-skill.sh`; the actual (and only) location is
  `.claude/tests/test-command-route-skill.sh`. There is no extension-source counterpart (it is
  not in `core`'s `manifest.json` `provides.scripts` list), so no drift-guard applies to it.
- **A second, narrower divergence exists and is worth flagging but is out of file_scope for
  this task**: `commands/research.md` and `commands/plan.md` no longer call
  `command-route-skill.sh` at all for routing (they use an inline static table and only pass
  `effort_flag` as prompt context, not for skill substitution); `commands/implement.md` does
  call the script but omits the 4th `effort_flag` argument entirely (`command-route-skill.sh
  "implement" "$TASK_TYPE" "skill-implementer"`, no 4th arg). Fixing the script alone will make
  `test-command-route-skill.sh` pass (it sources the script directly with an explicit 4th arg)
  but will **not** restore working `--hard` routing end-to-end for `/research`, `/plan`, or
  `/implement` without a follow-up fix to the three command files.
- **`check-extension-docs.sh` already anticipates this fix and will need a follow-on edit of
  its own comment/rationale** (not its logic) once routing_hard dispatch is real — see Risks.

## Context & Scope

Task #845 asks for RESEARCH ONLY: establish source of truth among code/tests/docs, document
exact current script behavior, document exact test assertions, map what a correct
implementation must do, note the byte-identical deployed/extension-source constraint (task
#841), and check whether the Step 5 SKILL.md-existence gate is already partially present. No
code changes were made.

## Findings

### Codebase Patterns

#### 1. Current `command-route-skill.sh` behavior (both copies, byte-identical)

Both `.claude/scripts/command-route-skill.sh` and
`.claude/extensions/core/scripts/command-route-skill.sh` are **67 lines**, `cmp -s` identical,
and implement only Steps 1-3 of the documented precedence:

```bash
_route_operation="$1"
_route_task_type="$2"
_route_default_skill="$3"

SKILL_NAME=""

# Step 1: exact task_type match across ALL extension manifests (.routing[$op][$tt])
# Step 2: compound-key (":" split) fallback across ALL extension manifests
# Step 3: fall back to $_route_default_skill

unset _route_operation _route_task_type _route_default_skill _manifest _ext_skill _base_type
export SKILL_NAME
```

- **No 4th positional argument is read at all.** `$4` (would-be `effort_flag`) is never
  referenced anywhere in the file.
- **No `.routing_hard` key is ever consulted** in any manifest, core or non-core.
- **No `routing_exempt` check exists** — the concept of "core manifest" vs "non-core manifest"
  used by Steps 1-2 exact/compound routing is undifferentiated (both scan `.routing`
  identically, all manifests in one pass); this undifferentiated-pass structure would need to
  be split for hard-mode's "non-core before core" rule but Steps 1-3 don't need this split
  themselves.
- **No Step 5 append-fallback or SKILL.md-existence gate exists in the live script at all** —
  contrary to a literal reading of "already partially present," there is currently **zero**
  hard-mode code path, so nothing is partially present in the *script*. (The gate's *logic* is
  fully specified and was previously implemented — see below.)

#### 2. Test file: exact location and exact assertions

The task description names `.claude/scripts/test-command-route-skill.sh`; this path **does not
exist**. The actual (only) copy is `.claude/tests/test-command-route-skill.sh` (177 lines, one
commit ever, `574bf515a`). It is **not** listed in `core`'s `manifest.json`
`provides.scripts`, so it has no extension-source counterpart and is exempt from the task #841
byte-identity drift guard — this is purely a deployed-only test asset.

Running it live now (`bash .claude/tests/test-command-route-skill.sh`) gives:

```
Passed: 6
Failed: 8
```

Full pass/fail breakdown (14 total assertions across ~12 named test cases; some cases assert
both `SKILL_NAME` and a stderr message, counted as separate PASS/FAIL lines):

| # | Test | Args (op, task_type, default, effort) | Expected `SKILL_NAME` | Result |
|---|------|------------------------------------------|------------------------|--------|
| 1 | std: implement/meta | implement, meta, skill-implementer, "" | skill-implementer | PASS |
| 2 | std: research/general | research, general, skill-researcher, "" | skill-researcher | PASS |
| 3 | std: plan/general | plan, general, skill-planner, "" | skill-planner | PASS |
| 4 | std: implement/cslib | implement, cslib, skill-implementer, "" | skill-cslib-implementation | PASS |
| 5 | hard: implement/meta -> hard | implement, meta, skill-implementer, hard | skill-implementer-hard | **FAIL** (got skill-implementer) |
| 6 | hard: plan/general -> hard | plan, general, skill-planner, hard | skill-planner-hard | **FAIL** (got skill-planner) |
| 7 | hard: research/meta -> hard | research, meta, skill-researcher, hard | skill-researcher-hard | **FAIL** (got skill-researcher) |
| 8 | hard: research/cslib extension override | research, cslib, skill-researcher, hard | skill-cslib-research-hard | **FAIL** (got skill-cslib-research) |
| 9 | hard: implement/cslib extension override | implement, cslib, skill-implementer, hard | skill-cslib-implementation-hard | **FAIL** (got skill-cslib-implementation) |
| 10 | hard: no-hard-variant, neovim, SKILL_NAME | research, neovim, skill-researcher, hard | skill-neovim-research (unchanged) | PASS (accidentally — script never touches hard path at all) |
| 10b | hard: no-hard-variant, neovim, stderr | (same) | stderr contains `[route] No hard variant for skill-neovim-research; using standard skill` | **FAIL** (stderr empty) |
| 11 | hard: no-hard-variant, nix, SKILL_NAME | implement, nix, skill-implementer, hard | skill-nix-implementation (unchanged) | PASS (accidentally) |
| 11b | hard: no-hard-variant, nix, stderr | (same) | stderr contains `[route] No hard variant for skill-nix-implementation; using standard skill` | **FAIL** (stderr empty) |
| 12 | hard: compound key cslib:pr fallback | implement, cslib:pr, skill-implementer, hard | skill-cslib-implementation-hard | **FAIL** (got skill-cslib-implementation) |

Tests 10 and 11 "pass" only by coincidence: because the script does nothing at all with
`effort_flag`, `SKILL_NAME` stays at the Step 1-3 result, which happens to equal the expected
*fallback* value for those two cases — but the required stderr diagnostic (the safety-gate
side effect) never fires, so the *sub-assertion* for those same two cases fails. This confirms
the test suite is written against the full 5-step design, not a partial one.

#### 3. Documented contract (CLAUDE.md "Routing Mechanism" section, verified verbatim against
   the merge-source)

`.claude/CLAUDE.md` (deployed, generated) and
`.claude/extensions/core/merge-sources/claudemd.md` (source) both contain, byte-identically,
the 5-step precedence quoted in the task description:

1. Non-core extension `routing_hard` exact match
2. Non-core extension `routing_hard` compound-key fallback
3. Core extension `routing_hard` exact match (core identified via `routing_exempt: true`)
4. Core extension `routing_hard` compound-key fallback
5. `-hard` append fallback, gated on `.claude/skills/${candidate}-hard/SKILL.md` existing on
   disk; otherwise stderr note + `SKILL_NAME` unchanged

This text is unchanged since task #770 synced it (per commit `574bf515a`'s message: "770: sync
CLAUDE.md merge-source to 5-step algorithm; document re-deploy procedure"). There is **no
divergence between CLAUDE.md and its merge-source** — the documentation layer is internally
consistent and stable. The gap is entirely between docs+tests (source of truth) and the script
(regressed).

A second, more detailed document — `.claude/context/guides/hard-mode-routing.md` (created by
task #768, 174 lines) — describes the identical 5-step algorithm with explicit pseudocode for
Steps 4a-4e, matching both the test file and the git-historical implementation. This guide
explicitly states it documents "the `--hard` routing resolution **implemented** in
`command-route-skill.sh`" (present tense) — i.e., it documents intended/prior behavior that is
no longer true of the live script. Its own footer notes "Scope: This document covers the
script/skill routing layer only... Do NOT edit CLAUDE.md based on this document," confirming
CLAUDE.md's copy is the independently-maintained canonical summary, not derived from this
guide.

#### 4. Root cause: the regression, reconstructed from git history

```
1e74df259  task 595 phase 1: create command-route-skill.sh          (both copies created, 3-arg, Steps 1-3 only)
b77ca0396  task 669 phase 1: routing infrastructure...               (no changes to Step 1-3 script; unrelated)
6163257a7  task 612: complete implementation                          (last-ever commit touching the
                                                                        EXTENSION-SOURCE copy)
574bf515a  orchestrate tasks 767-770: complete orchestration           <-- task #768 adds the 4th arg +
                                                                        Step 4a-4e block, but ONLY to
                                                                        .claude/scripts/command-route-skill.sh
                                                                        (127-line diff). The extension-source
                                                                        copy .claude/extensions/core/scripts/
                                                                        command-route-skill.sh is NOT touched
                                                                        by this commit (confirmed: git log
                                                                        --follow shows no entry here).
                                                                        Test suite created in same commit:
                                                                        12/12 passing per task #768's own
                                                                        summary at specs/archive/
                                                                        768_routing_hard_resolution_composition/
                                                                        summaries/01_hard-routing-resolution-
                                                                        summary.md.
40210f576  task 784: complete orchestration ("/pr" workflow selection) <-- Unrelated task. Diff to
                                                                        command-route-skill.sh is a pure
                                                                        removal of the entire Step 4 block
                                                                        added by 574bf515a (127 lines
                                                                        removed, "127 +---" in --stat),
                                                                        restoring the file to its pre-768,
                                                                        3-arg, Steps-1-3-only state. No other
                                                                        commit since has touched either copy.
```

The mechanism is directly explained by `check-extension-docs.sh`'s own Rule F comment
(`.claude/scripts/check-extension-docs.sh:112-124`):

> "copy_scripts()/copy_file() in `lua/neotex/plugins/ai/shared/extensions/loader.lua` performs
> a byte-for-byte overwrite of `.claude/scripts/<name>` from `<extension>/scripts/<name>` on
> every extension load/reload. If a script is later hotfixed directly in the deployed
> `.claude/scripts/` copy (instead of the extension source), that fix silently regresses on the
> next sync."

Task #768 did exactly the hotfix-only-the-deployed-copy anti-pattern this comment warns
against (ironically, in the very same commit that also *introduced* this Rule F drift-guard
logic into `check-extension-docs.sh` — task #769 was bundled into the same orchestration run).
Since the extension-source copy was never updated, some subsequent extension
load/reload — landing inside task #784's unrelated session — resynced the deployed copy from
the still-stale source, silently deleting the Step 4 block. This is precisely the failure mode
task #841's later drift guard exists to prevent going forward, but task #768 predates that
guard's consistent enforcement in this specific instance (or the guard did not catch this
particular deployed-only edit before the next sync occurred — the check only fails on *content
mismatch at check time*, not on *the moment a deployed-only edit is made*, so a same-session
deployed-only edit followed by a same-session reload before the next `check-extension-docs.sh`
run would not necessarily be caught before it regressed).

#### 5. Manifest `routing_hard` data: already fully present and correct

Both the core manifest and the extension manifests already declare complete, correct
`routing_hard` blocks — this data was never lost, only the script logic that reads it:

```json
// .claude/extensions/core/manifest.json (routing_exempt: true)
"routing_hard": {
  "research":  {"general": "skill-researcher-hard",  "meta": "skill-researcher-hard",  "markdown": "skill-researcher-hard"},
  "plan":      {"general": "skill-planner-hard",      "meta": "skill-planner-hard",      "markdown": "skill-planner-hard"},
  "implement": {"general": "skill-implementer-hard", "meta": "skill-implementer-hard", "markdown": "skill-implementer-hard"}
}

// .claude/extensions/cslib/manifest.json
"routing_hard": {
  "research":  {"cslib": "skill-cslib-research-hard",       "pr": "skill-researcher-hard"},
  "plan":      {"cslib": "skill-planner-hard",               "pr": "skill-planner-hard"},
  "implement": {"cslib": "skill-cslib-implementation-hard", "pr": "skill-implementer-hard"}
}

// .claude/extensions/lean/manifest.json
"routing_hard": {
  "research":  {"lean4": "skill-lean-research-hard"},
  "implement": {"lean4": "skill-lean-implementation-hard"}
}
```

All targets referenced by core and cslib `routing_hard` entries have deployed `SKILL.md` files
(verified: `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard`,
`skill-cslib-research-hard`, `skill-cslib-implementation-hard` all exist under
`.claude/skills/`). The lean extension's `routing_hard` targets
(`skill-lean-research-hard`, `skill-lean-implementation-hard`) are **not** deployed — this is
expected/flagged as `WARN` by `check-extension-docs.sh` (lean extension not installed) and was
explicitly noted as out-of-scope by task #768's own summary ("noted... but not corrected").

#### 6. Step 5 SKILL.md-existence gate: not present in the live script; fully specified
   elsewhere

Direct answer to the task's question "Is the on-disk SKILL.md existence gate (Step 5) already
partially present?": **No, not in the live script** — Steps 1-3 are the only code path that
exists today, and none of it touches `SKILL.md` existence checks. However, the gate's exact
logic is fully specified and was previously live code, recoverable verbatim from git:

```bash
# From commit 574bf515a's version of .claude/scripts/command-route-skill.sh (now reverted)
_candidate_hard="${SKILL_NAME}-hard"
if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then
  SKILL_NAME="$_candidate_hard"
else
  echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
fi
```

This exact block (confirmed by `git show 40210f576 -- .claude/scripts/command-route-skill.sh`,
the revert diff) already satisfies the test file's Step-5 assertions (tests 10b/11b above) and
the documented "Step 5" contract verbatim, including the stderr message format the tests assert
against (`[route] No hard variant for ${SKILL_NAME}; using standard skill`).

#### 7. Byte-identical deployed/extension-source constraint (task #841 guard)

`command-route-skill.sh` **is** listed in `core`'s `manifest.json`
`provides.scripts` array, so `check-extension-docs.sh`'s Rule F drift check (added by task
#769, same orchestration run as #768) applies to it: `cmp -s` between
`.claude/scripts/command-route-skill.sh` and
`.claude/extensions/core/scripts/command-route-skill.sh` must succeed or the extension check
`FAIL`s. Currently both copies are identical (both lack Step 4/5) so the check passes green —
but this is a "both wrong together" state, not evidence of correctness. **Any fix must be
applied to the extension-source copy first (source of truth per CLAUDE.md's "Context
Architecture" — extensions own their own scripts) and then re-synced/copied byte-for-byte to
the deployed copy**, exactly reversing task #768's original mistake of patching the deployed
copy only. `check-extension-docs.sh` currently runs clean (exit 0, all 19 extensions PASS) as
of this research pass — confirmed by live execution — so this is the correct green baseline to
preserve.

#### 8. Precedence self-consistency check (traced by hand against the 5-step spec)

Using the deployed manifest data, tracing each documented step by hand against the test cases
confirms the documented precedence is internally coherent and matches every test expectation:

- `(implement, meta, hard)`: no non-core manifest declares `routing_hard.implement.meta` ->
  Steps 1-2 miss; core declares it -> Step 3 hits -> `skill-implementer-hard`. Matches test 5.
- `(research, cslib, hard)`: cslib (non-core) declares `routing_hard.research.cslib` -> Step 1
  hits before core is ever consulted -> `skill-cslib-research-hard`. Matches test 8 and
  demonstrates "extension overrides core" (core also declares
  `routing_hard.research.general`/`.meta`/`.markdown` but not `.cslib`, so there's no actual
  conflict in this particular case — the override rule is about scan order, not a live
  collision here).
- `(implement, cslib:pr, hard)`: no manifest declares exact key `"cslib:pr"`; compound base
  `"cslib"` -> non-core (cslib) declares `routing_hard.implement.cslib` -> Step 2 hits ->
  `skill-cslib-implementation-hard`. Matches test 12. (Note: cslib's manifest separately
  declares a literal `"pr"` key mapped to `skill-implementer-hard` — irrelevant here since the
  task_type under test is the compound `"cslib:pr"`, not bare `"pr"`.)
- `(research, neovim, hard)`: no manifest (core or non-core) declares
  `routing_hard.research.neovim` at any step -> Steps 1-4 all miss -> Step 5 fallback:
  candidate `skill-neovim-research-hard` -> `.claude/skills/skill-neovim-research-hard/SKILL.md`
  does not exist (verified) -> stderr note, `SKILL_NAME` stays at whatever Steps 1-3 resolved
  (`skill-neovim-research`, from standard extension routing). Matches test 10/10b.

No step ordering or fallback logic needs to change from what's documented — the specification
is correct and self-consistent; only the implementation needs restoring.

### External Resources

Not applicable — this is a pure codebase/git-history investigation; no external documentation
was consulted.

### Recommendations

1. **Restore the Step 4/5 block into the extension-source copy first**
   (`.claude/extensions/core/scripts/command-route-skill.sh`), using the git-historical
   implementation from commit `574bf515a` (retrievable via
   `git show 574bf515a:.claude/scripts/command-route-skill.sh`) as the starting point — it is
   already known to make all 14 test assertions pass (it made 12/12 pass under the original,
   slightly different test count, and the current 14-assertion test file was created in the
   very same commit against this exact implementation, so no logic drift between test and
   implementation is expected).
2. **Copy byte-for-byte to the deployed location**
   (`.claude/scripts/command-route-skill.sh`) so `cmp -s` succeeds, satisfying task #841's
   drift guard.
3. **Run `bash .claude/tests/test-command-route-skill.sh`** and confirm 14/14 (or however many
   assertions the file currently contains) pass, exit 0.
4. **Run `bash .claude/scripts/check-extension-docs.sh`** and confirm it remains exit 0 / all
   extensions PASS — pay particular attention to the `[core]` and `[cslib]` sections since their
   `routing_hard` blocks will now be live-dispatched rather than dormant data.
5. **Consider (not required by this task's file_scope, but flag for a follow-up task)**:
   updating the rationale comment in `check-extension-docs.sh` at lines ~200-204 and ~299-305
   ("command-route-skill.sh does not implement routing_hard dispatch at all... so an
   uninstalled extension with a source-grounded but undeployed routing_hard target is expected,
   not a live bug") — the premise sentence becomes stale prose once dispatch is implemented,
   even though the WARN-vs-FAIL severity policy itself likely still holds (an uninstalled
   extension's routing_hard entries are still unreachable in practice, since Steps 1-4 only
   scan manifests for extensions that would route real task types). This is a comment-accuracy
   nit, not a logic bug, and does not block #845.
6. **Consider (definitely out of #845's file_scope, flag as a separate follow-up task)**:
   `commands/research.md` and `commands/plan.md` do not call `command-route-skill.sh` at all
   for skill routing (they use an inline static table and pass `effort_flag` only as prompt
   context); `commands/implement.md` calls the script but omits the 4th argument
   (`source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE"
   "skill-implementer"` — no `"${EFFORT_FLAG:-}"` 4th arg). Fixing the script alone satisfies
   `test-command-route-skill.sh` (which sources the script directly) and reconciles
   docs/tests/script for the script itself, but does **not** restore working end-to-end
   `--hard` skill routing for `/research`, `/plan`, or `/implement` in practice. A prior task
   (#768) did wire this correctly per its own summary, so this too is likely
   revert/regression fallout rather than a new gap — but it is a distinct file_scope
   (`commands/*.md`) from #845's declared scope and should be a separate task.

## Decisions

- **Source of truth = docs + tests + git-historical implementation.** The script is
  confirmed behind; no evidence supports "docs/tests are wrong" as an alternative resolution.
- **The fix is a restoration, not a redesign.** The exact Step 4/5 block from commit
  `574bf515a` already satisfies every test assertion; a from-scratch reimplementation is
  unnecessary and riskier than restoring known-good code.
- **Fix must land in the extension-source copy first**, per CLAUDE.md's context-architecture
  rule that extensions own their own scripts, and per task #841's byte-identity drift guard —
  reversing the exact mistake (deployed-only edit) that caused this regression.

## Risks & Mitigations

- **Risk**: Re-patching only the deployed copy again would recreate the exact same regression
  on the next extension reload. **Mitigation**: patch extension-source first, then sync/copy to
  deployed; verify with `cmp -s` before considering the fix complete.
- **Risk**: `check-extension-docs.sh`'s Rule C comment for `routing_hard` (uninstalled
  extension -> WARN not FAIL) cites "command-route-skill.sh does not implement routing_hard
  dispatch at all" as its rationale; once dispatch is implemented this sentence is stale prose
  (though the policy itself is probably still correct). **Mitigation**: flag as a documentation
  follow-up; not a blocker for #845's narrow file_scope.
- **Risk**: Scope creep into `commands/{research,plan,implement}.md` caller-wiring, which is a
  real but separate regression from what #845's `file_scope` declares.
  **Mitigation**: implement #845 narrowly (script + test + CLAUDE.md/docs reconciliation only,
  which are already in agreement and need no doc edits — only the script needs to change);
  raise the caller-wiring gap as a new task rather than silently expanding #845.
- **Risk**: The task description's test file path
  (`.claude/scripts/test-command-route-skill.sh`) is wrong; an implementer following it
  literally would create a *new*, wrong-location test file instead of fixing the real one at
  `.claude/tests/test-command-route-skill.sh`. **Mitigation**: this report documents the
  correct path explicitly; the implementation plan/task should reference
  `.claude/tests/test-command-route-skill.sh`.

## Context Extension Recommendations

None — this is a meta task focused on a specific script/test/doc reconciliation; the existing
`.claude/context/guides/hard-mode-routing.md` already documents the target design in full and
needs no changes (it describes the correct, restorable behavior).

## Appendix

### Commands run

```bash
bash .claude/tests/test-command-route-skill.sh          # 6 PASS / 8 FAIL, exit 1 (baseline, before any fix)
bash .claude/scripts/check-extension-docs.sh             # exit 0, all 19 extensions PASS (current baseline)
cmp -s .claude/scripts/command-route-skill.sh .claude/extensions/core/scripts/command-route-skill.sh  # identical (both regressed)
git log --oneline --all -- .claude/scripts/command-route-skill.sh
git log --oneline --all --follow -- .claude/extensions/core/scripts/command-route-skill.sh
git show 574bf515a:.claude/scripts/command-route-skill.sh   # recovers the working 5-step implementation
git show 40210f576 -- .claude/scripts/command-route-skill.sh # confirms the revert diff
```

### Key file locations

- `.claude/scripts/command-route-skill.sh` (deployed, 67 lines, Steps 1-3 only)
- `.claude/extensions/core/scripts/command-route-skill.sh` (extension source, byte-identical to
  deployed, Steps 1-3 only)
- `.claude/tests/test-command-route-skill.sh` (actual test location; NOT
  `.claude/scripts/test-command-route-skill.sh` as the task description states)
- `.claude/context/guides/hard-mode-routing.md` (full target-design documentation, still
  accurate as a spec)
- `.claude/CLAUDE.md` / `.claude/extensions/core/merge-sources/claudemd.md` ("Routing
  Mechanism" section, internally consistent, accurate spec)
- `.claude/extensions/{core,cslib,lean}/manifest.json` (`routing_hard` data, already correct
  and complete)
- `specs/archive/768_routing_hard_resolution_composition/` (original implementation's plan,
  research, and summary artifacts — useful primary source for the restoration)
- Git commit `574bf515a` (working implementation), commit `40210f576` (accidental revert)

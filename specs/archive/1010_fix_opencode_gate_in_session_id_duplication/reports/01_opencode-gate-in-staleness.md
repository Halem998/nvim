# Research Report: Task #1010

**Task**: 1010 - Fix opencode gate-in session-id duplication (test-common-lib.sh deployed-mode failure)
**Started**: 2026-08-10
**Completed**: 2026-08-10
**Effort**: small (single-file catch-up) once root cause is accepted; large if the broader staleness gap is also addressed
**Dependencies**: None currently open (spawned standalone per delegation context); overlaps in kind with 1017/1018/1019 (deploy-staleness family) but does not depend on them
**Sources/Inputs**: Codebase inspection (agent-system/extensions/core/scripts/, .opencode/scripts/, .claude/scripts/, lua/neotex/plugins/ai/shared/extensions/*.lua), git log
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `.opencode/` **is** a generated deploy target, on par with `.claude/` — deployed by the same
  parameterized Lua extension loader (`base_dir = ".claude"` or `".opencode"`), from the same
  single source-store file. It is not hand-maintained.
- The single source-store equivalent of `.opencode/scripts/command-gate-in.sh` is
  `agent-system/extensions/core/scripts/command-gate-in.sh`. That source file is **already
  correct** — it sources `scripts/lib/common.sh` and calls `common_session_id()` instead of
  inline `sess_$(date +%s)_...` generation. No source-store edit is needed to fix the
  session-ID-duplication defect itself.
- The actual defect is that **`.opencode/` is a stale snapshot**, not that the source needs a
  fix. `.opencode/scripts/command-gate-in.sh` still carries the *old* inline generator because it
  was never resynced after the source-store file was updated. The staleness is much broader than
  this one file: `.opencode/scripts/` is missing 38 of the 68 `*.sh` files present in
  `agent-system/extensions/core/scripts/` (top-level only), including `task-lock.sh`,
  `verify-deploy.sh`, `state-write.sh`, and the entire `lib/` subdirectory
  (`.opencode/scripts/lib/` does not exist at all — `.opencode/scripts/lib/common.sh` is absent).
- `test-common-lib.sh` passes in source-store mode and fails in deployed mode purely because of
  **where the test computes its scan root**, not because of any environment-conditional logic in
  the test itself (the deployed and source-store copies of the test file are byte-identical).
- **Root cause of why `.opencode/` never gets resynced**: `deploy-headless.sh`, the only headless
  (non-interactive) deploy entry point in the repo, is hardcoded to `ext_config.claude()` and has
  no `.opencode` equivalent — even though the Lua loader/config modules are already fully
  parameterized for `.opencode` (`config.opencode()` exists in `config.lua`, `base_dir` is
  threaded throughout `loader.lua`/`merge.lua`/`init.lua`). Redeploying `.opencode/` today is
  only reachable via the interactive Neovim picker, not headlessly/by an agent.

## Context & Scope

Task 1010 asks: where does the source-store equivalent of `.opencode/scripts/command-gate-in.sh`
live (or is `.opencode/` hand-maintained), and why does `test-common-lib.sh` pass in
source-store mode but fail in deployed mode. This report answers both questions with direct
evidence and recommends a fix direction, but does not implement it (task type `meta`,
research-only handoff to `/plan`).

## Findings

### `.opencode/` is a deploy target, not a hand-maintained tree

Evidence, in order of directness:

1. `lua/neotex/plugins/ai/shared/extensions/config.lua` defines two constructor functions:
   `M.claude(global_dir)` (`base_dir = ".claude"`, `root_state_file = ".claude-extensions.json"`)
   and `M.opencode(global_dir)` (`base_dir = ".opencode"`, `root_state_file =
   ".opencode-extensions.json"`). Both feed into the same `manager` object returned by
   `init.lua`'s `M.create(config)`.
2. `loader.lua`'s file-copy engine (`copy_file`, `M.load_syncprotect`, and the doc comments
   throughout) is explicitly parameterized: *"File copy engine for extension loading/unloading
   (parameterized)"*, `@param target_dir string Target base directory (.claude or .opencode)`.
   It is one engine serving both trees, doing a straight byte-for-byte copy — no per-target
   text substitution inside file contents.
3. `merge.lua` and `verify.lua` have `.opencode`-specific branches (`opencode_md` merge key,
   `is_opencode_target`, `generate_opencode_json`), confirming `.opencode/` goes through the same
   merge/verify pipeline as `.claude/`, just with different config.
4. Git history directly shows mechanical, repo-wide edits landing in `.opencode/**` files
   identically to `.claude/**` files — e.g. commit `957c2140c` ("purge remaining .opencode/**
   files (batch C, independent triage)") touched `.opencode/scripts/command-gate-in.sh` and 22
   other `.opencode/**` files with small mechanical diffs (task-reference-citation cleanup),
   the same class of edit `.claude/**` files receive from the same lineage of work.

Conclusion: `.opencode/scripts/command-gate-in.sh`'s source-store equivalent is the **same single
file** that already serves `.claude/scripts/command-gate-in.sh`:
`agent-system/extensions/core/scripts/command-gate-in.sh`. There is no separate
opencode-flavored source file to find or create.

### The source-store file is already fixed; `.opencode/`'s copy is an old snapshot

Diffing the three copies:

```
diff .claude/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh
# → no output: byte-identical
```

`.claude/`'s deployed copy is byte-identical to source. It already:
- Sources `agent-system/extensions/core/scripts/lib/common.sh` (via a repo-root-absolute path
  check, with a same-directory fallback) and calls `SESSION_ID="$(common_session_id)"`.
- Carries newer features absent from `.opencode/`'s copy entirely: the `"revise"` operation
  exemption from the terminal-status guard, and the full task-lock acquire/register sequence
  (`task-lock.sh acquire-retry`, `session-register`).

```
diff .opencode/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh
```
shows `.opencode/`'s copy is missing all of the above and still has the literal
`SESSION_ID="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"` line — this is the
flagged defect. It also still says `# Usage: source .opencode/scripts/command-gate-in.sh` where
the current source says `.claude/scripts/command-gate-in.sh` in the same comment line — this
discrepancy is **not** evidence of a legitimate per-target customization (the copy engine does no
content substitution, confirmed above); it is simply a leftover comment string from an earlier
revision of the single shared source file, before that comment was later reworded to name
`.claude` explicitly. A fresh resync of `.opencode/` from the current source would carry the
`.claude`-worded comment into the `.opencode/` copy verbatim (a latent, harmless, pre-existing
cosmetic inaccuracy — out of scope for this task to fix, since it lives in the shared source and
also renders identically into `.claude/`'s already-correct copy).

Independent confirmation the whole `.opencode/scripts/` tree is stale, not just this one file
— comparing top-level `*.sh` filenames present in
`agent-system/extensions/core/scripts/` vs `.opencode/scripts/`:

```
57 files in .opencode/scripts/*.sh   vs   68 files in agent-system/extensions/core/scripts/*.sh
```

38 files exist in source but not in `.opencode/scripts/`, including `task-lock.sh`,
`verify-deploy.sh`, `state-write.sh`, `deploy-headless.sh` itself, `deploy-root-guard.sh`,
`command-route-agent.sh`, and every `test-*.sh` added since. The entire `scripts/lib/`
subdirectory is missing from `.opencode/` (`.opencode/scripts/lib/common.sh` does not exist),
whereas `.claude/scripts/lib/common.sh` exists and matches source. `.opencode/` is not merely
behind on this one file — it appears to have not been resynced in a long time relative to
`.claude/`, which by contrast is kept current (0-diff against source for every file checked in
this investigation).

Despite the missing `.opencode/scripts/lib/common.sh`, the deployed `.opencode/` copy of
`command-gate-in.sh` (once fixed) would still resolve `common_session_id` correctly at runtime in
*this* repo, because the sourcing logic resolves `lib/common.sh` via a **repo-root-absolute**
path first (`${repo_root}/.claude/scripts/lib/common.sh`), which exists since `.claude/` is
deployed alongside `.opencode/` in the same repo; the same-directory fallback
(`.opencode/scripts/lib/common.sh`) is only reached if that first path is absent.

### Why `test-common-lib.sh` passes in source-store mode and fails in deployed mode

The deployed and source-store copies of the test file itself are byte-identical (confirmed via
`diff`). The split comes entirely from where `SCRIPT_DIR/../../..` resolves at run time
(`agent-system/extensions/core/scripts/tests/test-common-lib.sh:230`):

```bash
EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
offending=$(grep -rl 'sess_\$(date' --include="*.sh" "$EXTENSIONS_ROOT" 2>/dev/null \
  | grep -v -F "/lib/common.sh" | grep -v -F "/tests/test-common-lib.sh" || true)
```

- **Source-store mode**: the running copy lives at
  `agent-system/extensions/core/scripts/tests/test-common-lib.sh`. Three levels up from
  `SCRIPT_DIR` is `agent-system/extensions/`. The grep scans only that subtree — which never
  contains `.opencode/` or `.claude/` at all (those live at the repo root, outside
  `agent-system/`). The offending file is structurally outside the scanned tree, so the
  assertion vacuously passes.
- **Deployed mode**: the running copy lives at `.claude/scripts/tests/test-common-lib.sh`. Three
  levels up from `SCRIPT_DIR` is the **repo root** (`.claude/scripts/tests/../../..` = repo
  root). The grep now scans the *entire repo root* for `*.sh` files, which includes
  `.opencode/scripts/command-gate-in.sh` — the only file repo-wide (besides `lib/common.sh`
  itself, which is excluded) still containing the literal `sess_$(date` pattern. That single
  file is what fails the assertion.

This is a deliberate, working design for a single-source-of-truth check — it is only meaningful
when run against a fully-deployed tree, which is exactly the deployed-mode failure signal task
1010 was spawned to chase down. No change to the test itself is implicated or recommended.

## Recommendations

Two viable directions; the boundary rule in
`.claude/rules/source-store-deploy-boundary.md` (`.claude/**` is a disposable deploy artifact —
never hand-edit, edit `agent-system/extensions/**` instead) applies equally to `.opencode/**` per
the evidence above (same generated-artifact status, same loader).

1. **Narrow stopgap (recommended for this task's scope)**: perform a one-off catch-up sync of
   just `.opencode/scripts/command-gate-in.sh` to match
   `agent-system/extensions/core/scripts/command-gate-in.sh` byte-for-byte (the same content
   `.claude/scripts/command-gate-in.sh` already carries). This is the minimum change that makes
   `test-common-lib.sh` pass in both modes, since the source-store file is already correct and no
   source edit is needed. Frame it explicitly as a manual redeployment of a single already-correct
   source file into a stale target — not as a new hand-authored customization — so a future real
   resync is a no-op for this file. This does not address the other 38 missing scripts or the
   missing `scripts/lib/` subdirectory in `.opencode/`; those remain stale.

2. **Root-cause fix (larger scope, not recommended inside this task)**: `deploy-headless.sh` has
   no way to target `.opencode/` at all — it hardcodes `ext_config.claude()` even though
   `config.opencode()` already exists and the whole loader pipeline is base_dir-parameterized.
   Adding a `.opencode` target option to `deploy-headless.sh` (or a thin parameterized sibling
   script) and running a full resync would fix this defect *and* the other 38-script gap in one
   motion, and would close a genuine capability gap (no headless way to redeploy `.opencode/`
   today — only the interactive Neovim picker can). This is a materially larger, higher-risk
   change (touches the deploy engine, affects every `.opencode/**` file, no headless testing
   precedent for the `.opencode` target) and is a better candidate for its own spawned task in
   the same family as 1017/1018/1019 (deploy-staleness/deploy-mechanism tasks already open) than
   for folding into this narrowly-scoped fix.

Recommend direction 1 for this task, with a note in the task's summary/handoff flagging direction
2 as a spawn-worthy follow-up (the general `.opencode/` staleness gap and the missing headless
`.opencode` deploy entrypoint), parallel to how 1017/1018/1019 were already spawned from other
investigations that surfaced adjacent structural gaps.

## Risks & Mitigations

- **Risk**: hand-syncing `.opencode/scripts/command-gate-in.sh` looks like exactly the kind of
  hand-edit the source-store-deploy-boundary rule warns against. **Mitigation**: the content
  being written is not authored — it is a verbatim copy of the file the deploy engine would
  itself produce from the unmodified source-store file, performed only because no headless
  `.opencode` deploy entrypoint exists yet (see Recommendation 2). Document this rationale at the
  point of the edit (commit message / summary) so a future reader does not mistake it for a
  legitimate divergence to preserve.
- **Risk**: fixing only this one file leaves `.opencode/` broadly stale (38 missing scripts,
  missing `lib/`), so other deployed-mode test failures in the same family may surface later.
  **Mitigation**: explicitly out of scope per the task's own targeting (`TARGET:` names only
  `command-gate-in.sh` and `lib/common.sh`); flagged above as a spawn candidate rather than
  silently left undiscovered.

## Context Extension Recommendations

- **Topic**: `.opencode/` deploy mechanism and its lack of a headless entrypoint.
- **Gap**: `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (referenced
  from `deploy-headless.sh`'s header) documents the `.claude/` redeploy contract in detail but,
  per this investigation, does not appear to cover the `.opencode/` target or the fact that no
  headless redeploy path exists for it at all.
- **Recommendation**: a future task (not this one) should either extend that pattern doc to state
  explicitly that `.opencode/` redeploys are interactive-picker-only today, or implement and then
  document a headless `.opencode` deploy path.

## Appendix

Key commands run during this investigation:
- `find . -name "command-gate-in.sh"` — located the three copies (source, `.claude/`, `.opencode/`)
- `diff .claude/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh`
  — confirmed 0 diff (deployed `.claude/` matches source exactly)
- `diff .opencode/scripts/command-gate-in.sh agent-system/extensions/core/scripts/command-gate-in.sh`
  — showed the inline-generator, missing-common.sh-sourcing, missing-task-lock gap
- `grep -n "opencode" lua/neotex/plugins/ai/shared/extensions/{loader,merge,verify,config,init}.lua`
  — established the parameterized single deploy engine and confirmed `config.opencode()` exists
- `grep -n "opencode\|base_dir" agent-system/extensions/core/scripts/deploy-headless.sh` — confirmed
  it hardcodes `ext_config.claude()` with no `.opencode` option
- `comm -23 <(find agent-system/extensions/core/scripts -maxdepth 1 -name "*.sh" -printf "%f\n" | sort) <(find .opencode/scripts -maxdepth 1 -name "*.sh" -printf "%f\n" | sort)`
  — enumerated the 38 scripts present in source but missing from `.opencode/scripts/`
- Read `agent-system/extensions/core/scripts/tests/test-common-lib.sh:218-242` — the single-source
  assertion and its `SCRIPT_DIR/../../..` scan-root computation
- `git log --oneline -- .opencode/scripts/command-gate-in.sh` and `git show --stat 957c2140c` —
  confirmed `.opencode/**` receives the same mechanical repo-wide edits as `.claude/**`, ruling out
  "hand-maintained, never synced" in favor of "generated, but not resynced recently"

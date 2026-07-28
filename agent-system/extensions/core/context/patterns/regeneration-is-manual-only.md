# Regeneration: Interactive by Default, Headless When Driven Deliberately

## Overview

The `<leader>al` picker ("Load Core" / "Load All") is the primary mechanism that deploys the
extension source store (`agent-system/extensions/**`) into a consuming repo's gitignored
`.claude/` tree. Every deployed file under `.claude/` has a source under
`agent-system/extensions/**`; nothing under `.claude/` is hand-authored.

**CORRECTION.** An earlier revision of this document asserted that regeneration had *no*
headless, scripted, or CI equivalent, and instructed future work not to retread the question.
**That assertion was wrong, and it was load-bearing** -- it propagated into research findings,
implementation plans, and user-facing handoffs, each of which concluded that deployment could
only ever be a manual, user-owned step. A headless path exists, is straightforward, and is now
implemented as `scripts/deploy-headless.sh`.

## The Headless Path (verified)

The two claims that produced the wrong conclusion, and what is actually true:

| Earlier claim | Reality |
|---|---|
| `execute_sync` is module-local, so nothing can trigger a sync | True but irrelevant -- `M.load_all_globally` **is** exported and calls `execute_sync` internally |
| `vim.fn.confirm()` blocks every code path with no bypass | It is an ordinary function reference and can be stubbed in-process before the call |

The working invocation, run with cwd at the target repo root:

```bash
nvim --headless \
  -c "lua vim.fn.confirm = function() return 1 end" \
  -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync').load_all_globally(nil)" \
  -c "qa!"
```

Returning `1` selects the first dialog button -- "Sync all (replace existing)" when replacements
are pending, "Add all" when only additions are. Both are the intended full-deploy choice.

This was verified by deploying into a throwaway directory: 263 artifacts copied, including the
event scripts, hooks, schema, and format docs, with all hook registrations present in the
resulting `settings.json`.

Use `scripts/deploy-headless.sh` rather than open-coding the invocation above -- it resolves the
repo root, refuses to run outside a git repository, and reports the artifact count it deployed.

## When to Prefer Which

- **Interactive `<leader>al`** remains the right default for a human at a terminal. The confirm
  dialog is a genuine safeguard: a full sync overwrites deployed files, and seeing the
  replacement count before agreeing is worth the keystroke.
- **`scripts/deploy-headless.sh`** is for scripted, CI, and agent-driven contexts where no human
  is present to answer a dialog. It deliberately bypasses that safeguard, so it must be invoked
  explicitly and never as a silent side effect of an unrelated operation.

## Automated Exception: The Inter-Cycle Self-Modification Checkpoint

The sentence directly above -- `scripts/deploy-headless.sh` "must be invoked explicitly and never
as a silent side effect of an unrelated operation" -- is left byte-for-byte intact by this
subsection. It is not edited, weakened, or reworded here, matching this document's own
established correction-as-addition pattern (see the `**CORRECTION.**` block above): a constraint
that is no longer fully true is narrowed by a labeled, additive exception, never quietly rewritten
in place.

**The exact and only sanctioned automated call site**: `skill-orchestrate`'s Stage MT-3 step 7 --
the inter-cycle redeploy checkpoint. No other automated caller is sanctioned by this subsection.

**Why this is not a side effect of an unrelated operation**: the fix that triggers the checkpoint
is precisely the fix the checkpoint exists to make live. A dispatched task's commit at Stage MT-4
step 5.5 touching an orchestrator-critical path is the operation the redeploy is *for*, not an
operation the redeploy is merely alongside. The operation is not unrelated -- it is the operation
being corrected.

**Why this is not silent**: the checkpoint logs on fire (naming the matched critical paths it
detected), on success (naming the deployed artifact count and the `verify-deploy` pass), and on
failure (naming the failing gate and its exit code). An operator reading the run's output can
always distinguish "the checkpoint did not fire" from "it fired and passed" from "it fired and
failed."

**Why this is bounded**: the checkpoint is evidence-gated on actual `modified_files` overlapping a
declared critical path -- never an unconditional "always between cycles" trigger. It fires at most
once per critical path per invocation, via the idempotence guard. Any failure of either gate defers
the remainder of the invocation rather than proceeding past an unverified deploy.

**What this carve-out explicitly does NOT license**: no other automated caller may invoke
`scripts/deploy-headless.sh` without its own equivalent exception recorded in this same section. A
future reader must not read this subsection as general precedent for scripted deploys elsewhere in
the system -- it licenses exactly the one call site named above, nothing broader.

The full trigger, failure contract, sequencing, and idempotence-guard contract is recorded once,
authoritatively, in `context/patterns/batch-orchestration-guardrails.md`'s
`### The Inter-Cycle Redeploy Checkpoint` subsection. It is cross-referenced here, not restated.

## What This Means for Automation

- **Source-store edits still do not deploy themselves.** Edits under
  `agent-system/extensions/**` are the durable, version-controlled truth; the deployed `.claude/`
  tree reflects them only after a regeneration -- interactive or headless -- actually runs.
- **A stale deployed tree remains an expected state**, and doc-lint's core deploy-drift lane
  (`check-extension-docs.sh`) surfaces it. What has changed is the remedy: drift is now
  resolvable by a script, not only by a human at a keyboard.
- **Verifying deployed behavior still takes two gates**: the regeneration, then real usage for
  anything hook-driven. Inspecting source-store code alone never establishes either. Use
  `scripts/verify-deploy.sh` for the first gate; the second requires actual command invocations.

## Merge Semantics That Regeneration Cannot Fix

Two deploy behaviors are structural and survive any number of regenerations:

- **Install-once root files.** `settings.json` and `settings.local.json` are listed in
  `INSTALL_ONCE_ROOT_FILES`; `copy_root_files` skips them entirely once the target exists.
  Anything added only to `root-files/settings.json` can therefore never reach an
  already-initialized repo. Additions intended for existing repos belong in
  `merge-sources/settings-hooks.json`, which is what the merge step actually reads.
- **Add-only, object-granularity dedup.** The merge compares whole matcher objects via
  `vim.deep_equal` and only declines to add -- it never removes. A duplicate command entry
  already present in a deployed tree survives every future merge and requires manual removal.
  Fresh trees are unaffected: a first-time deploy produces exactly one entry.

The practical consequence for authors: register each new hook as its **own dedicated
single-command matcher object**. That shape is idempotent across re-merges, whereas appending a
command into an existing shared matcher makes that object non-equal to the source and causes its
siblings to be registered twice.

## Root-Resolution Guard for Core Scripts

Any core script under `agent-system/extensions/core/scripts/` that resolves its repo root as
`"$(cd "${SCRIPT_DIR}/../.." && pwd)"` is correct ONLY once deployed (`.claude/scripts/` or
`.opencode/scripts/`, two levels under the repo root). Run from the source store, the same
expression silently resolves to `agent-system/extensions/` and proceeds against a bogus root.
Every such script MUST source the shared guard immediately after that root computation:
`. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` -- the trailing `|| exit 1` is required
because several core scripts do not use `set -e`, so a bare `source` of a missing/failing
helper would otherwise print an error and continue unguarded. `deploy-root-guard.sh` validates
its own `BASH_SOURCE[0]` location structurally (no filesystem I/O) against exactly two accepted
deploy-tree grandparents, `.claude` and `.opencode` -- never hardcode just one. Do NOT use
`git rev-parse --show-toplevel` as a substitute: it would silently succeed by finding the true
repo root, masking the invocation-context error this guard exists to surface.

## Related Documentation

- `scripts/deploy-headless.sh` -- scripted regeneration for non-interactive contexts
- `scripts/verify-deploy.sh` -- checks a deployed tree against its source store
- `docs/guides/creating-extensions.md` -- extension authoring guide (manifest schema, file
  templates, deployment categories)
- `scripts/check-extension-docs.sh` -- doc-lint gate; its core deploy-drift lane surfaces
  never-deployed core scripts/hooks
- `context/patterns/batch-orchestration-guardrails.md` -- the authoritative inter-cycle redeploy
  checkpoint contract (trigger, failure contract, sequencing, idempotence guard) that this
  document's `## Automated Exception` subsection reconciles against the deliberate-invocation
  constraint above

# Regeneration: Interactive by Default, Headless When Driven Deliberately

## Overview

The `<leader>al` picker's `[Reload All]` (non-destructive force-resync) and `[Regenerate]`
(destructive wipe + rebuild) entries are the primary interactive mechanism that deploys the
extension source store (`agent-system/extensions/**`) into a consuming repo's gitignored
`.claude/` tree. Every deployed file under `.claude/` has a source under
`agent-system/extensions/**`; nothing under `.claude/` is hand-authored. Both entries -- and the
headless path below -- are backed by the same single manifest-driven engine
(`neotex.plugins.ai.shared.extensions`'s `manager.resync_all`/`manager.wipe`); there is no second,
independent sync mechanism to keep in sync with this one.

**CORRECTION.** An earlier revision of this document asserted that regeneration had *no*
headless, scripted, or CI equivalent, and instructed future work not to retread the question.
**That assertion was wrong, and it was load-bearing** -- it propagated into research findings,
implementation plans, and user-facing handoffs, each of which concluded that deployment could
only ever be a manual, user-owned step. A headless path exists, is straightforward, and is now
implemented as `scripts/deploy-headless.sh`.

## The Headless Path (verified)

`scripts/deploy-headless.sh` calls the manifest-driven engine's `manager` functions directly with
an explicit `confirm = false` option, rather than stubbing `vim.fn.confirm()` in front of an
interactive-only entry point (the technique this section originally documented, back when the
only bulk-sync engine was the picker-only, confirm-dialog-gated `load_all_globally`). That engine
has since been retired: the picker's `[Reload All]`/`[Regenerate]` entries and this script are
both direct `manager` callers now, with no confirm-stubbing indirection involved on either path.

```bash
# Default: bootstrap-safe, non-destructive force-resync of every active extension
bash scripts/deploy-headless.sh [TARGET_REPO]

# Full destructive wipe + rebuild (snapshot -> rm -rf .claude -> regenerate -> restore)
bash scripts/deploy-headless.sh --wipe [TARGET_REPO]
```

This was verified against a from-scratch scratch git repository: a fresh (no prior `.claude/`)
default-mode deploy correctly reconstructs the full tree, including subdirectory-declared
`provides.scripts`/`provides.hooks` entries -- the exact class of entry the retired engine
silently dropped on both a fresh deploy and a resync alike (see
`scripts/tests/test-deploy-propagation.sh`, whose Assertions A and B guard against a regression
of this exact defect). `--wipe` was verified to survive `settings.local.json` and every
`.syncprotect`-listed path byte-identically across the deletion.

Use `scripts/deploy-headless.sh` rather than open-coding an equivalent `manager` call -- it
resolves the repo root, refuses to run outside a git repository, holds the `specs/.deploy-lock`
mutex, and reports the artifact/extension count it deployed.

## When to Prefer Which

- **The interactive picker's `[Reload All]`/`[Regenerate]` entries** remain the right default for
  a human at a terminal. `[Regenerate]` (the destructive path) is gated behind a `vim.fn.confirm`
  yes/no dialog -- a genuine safeguard, since it deletes and rebuilds `.claude/` from scratch.
  `[Reload All]` (non-destructive) is gated behind its own submenu choice
  ("Reload All"/"Unload All"/"Step Through"/"Cancel") rather than a yes/no dialog, matching its
  lower-risk, non-destructive intent while still requiring an explicit selection.
- **`scripts/deploy-headless.sh`** is for scripted, CI, and agent-driven contexts where no human
  is present to answer a dialog. Its `--wipe` flag deliberately bypasses the interactive
  confirmation `[Regenerate]` would otherwise show, so it must be invoked explicitly and never as
  a silent side effect of an unrelated operation.

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
  `INSTALL_ONCE_ROOT_FILES`; the `root_files` category's descriptor-driven copier
  (`loader.lua`'s `M.copy_category`, keyed by `CATEGORY_DESCRIPTORS.root_files.install_once`)
  skips them entirely once the target exists. Anything added only to `root-files/settings.json`
  can therefore never reach an already-initialized repo. Additions intended for existing repos
  belong in `merge-sources/settings-hooks.json`, which is what the merge step actually reads.
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

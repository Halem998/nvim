# CI Deploy-Tree Bootstrap

The recipe for running this repo's gate suite in a CI runner (GitHub Actions or any fresh
checkout), captured once so it never has to be re-derived. See
`.github/workflows/check-extension-docs.yml` for the live implementation of every step below.

## Why a deploy step must come first

`.claude/` is fully gitignored in this repo (`git ls-files .claude` returns nothing), so a fresh
checkout — exactly what a CI runner starts from — has no `.claude/` tree at all. Almost every
gate script inspects deployed files (`.claude/scripts/*`, `.claude/context/*`, `.claude/hooks/*`,
`.claude/settings.json`), so any gate invoked before a deploy step fails immediately with a
missing-file error, not a meaningful signal. The fix is unconditional and structural, not a
per-gate workaround: materialize `.claude/` from the source store (`agent-system/extensions/**`)
as the very first step, before any gate runs.

## The single shared aggregator

There is exactly one definition of "verified": `scripts/verify-deploy.sh`. It is the same
aggregator `scripts/deploy-headless.sh` invokes inline (with `--skip-slow`) after every local
redeploy, and the same one CI invokes explicitly (without `--skip-slow`, for full-suite
coverage) as its own final step. A CI workflow must never grow a second, parallel notion of
"the gates pass" — always drive `verify-deploy.sh`, never reimplement its checks.

`verify-deploy.sh`'s own header documents its exit-code contract precisely: exit 0 is pass, exit
1 is one or more failed checks, and exit 2 ("cannot run" — target missing, or no deploy tree to
inspect) MUST be treated as a failure by any automated caller, never as a pass. A CI step that
runs this script directly (no `|| true`, no `continue-on-error`) gets this for free, since GitHub
Actions marks any non-zero exit as a failed step by default.

## No lazy.nvim bootstrap needed

A CI runner has no user nvim config, no `lazy.nvim`, and (in the common case) no network access
to plugin repositories. The extension manager
(`neotex.plugins.ai.shared.extensions.config`/`.init`) that both `deploy-headless.sh` and
`verify-deploy.sh` drive headlessly has **no plugin dependency** — its `manager.load`,
`manager.resync_all`, `manager.verify_all`, and `manager.find_orphans` all succeed under `nvim
--clean` with only `rtp` set, confirmed by a direct probe before this was relied on in CI. Both
scripts therefore expose an opt-in `--minimal-init DIR` flag: when set, their nvim invocations
become `nvim --headless --clean --cmd "set rtp+=DIR"` instead of the default plain `nvim
--headless` (which would load `init.lua` and pay the full `lazy.nvim` bootstrap). `DIR` is the
nvim **config directory**, not necessarily the deploy `TARGET` — for a consumer repo the two
differ; in this repo's own CI they coincide, since the checkout IS the nvim config repo. Absent
`--minimal-init`, both scripts' behavior is byte-for-byte unchanged from before the flag existed.
`deploy-headless.sh` threads its own `--minimal-init` value into its inline `verify-deploy.sh`
call automatically, so a caller only needs to pass the flag once, at the deploy step.

## The four-step recipe

1. **Checkout** (`actions/checkout@v4` or equivalent) — gives you the source store
   (`agent-system/extensions/**`) but no `.claude/` tree yet.
2. **Install neovim** on the runner — not preinstalled on `ubuntu-latest`. Use the official
   release tarball (`nvim-linux-x86_64.tar.gz` from the latest GitHub release) rather than a
   possibly-stale distro package or a third-party action.
3. **Deploy**: `bash agent-system/extensions/core/scripts/deploy-headless.sh --minimal-init
   "$TARGET" "$TARGET"` (invoke the **source-store** copy — `.claude/` doesn't exist yet, so the
   deployed copy isn't there to invoke). This materializes `.claude/` and runs its own inline
   fast-gate verification (`--skip-slow`); a red fast gate here fails the step before the slow
   suite ever runs, which is correct — no point paying for `tests/run-all.sh` if the tree is
   already broken.
4. **Verify (full suite)**: `bash .claude/scripts/verify-deploy.sh --findings --minimal-init
   "$TARGET" "$TARGET"` (no `--skip-slow` — a push gate should not silently drop the shell test
   suite runner, gate 8). `--findings` makes a red build's log carry the normalized,
   machine-diffable `FINDING ` set rather than only a narrative failure.

## What CI deliberately does NOT run, and why

- `check-deploy-freshness.sh`: its own header states it "ALWAYS EXITS 0 ... this is not a
  preflight gate" — structurally incapable of failing a build, so running it adds cost with zero
  gating value.
- `check-consumer-freshness.sh`: an opt-in whole-fleet audit of *other* repos on the operator's
  machine, not a per-repo gate. CI has no access to those repos and would assert on checkouts it
  cannot see.

## A caution for anyone adding a new gate to verify-deploy.sh

Adding a gate that inspects the *filesystem or git state of an arbitrary throwaway repo* (not
just the deploy tree) can silently break scratch-repo test harnesses that never onboarded the
conventions that gate assumes. This repo hit exactly this case once: `check-runtime-file-tracking.sh`
(gate 14, wired into `verify-deploy.sh`) asserts a repo's root `.gitignore` covers the ephemeral
runtime-file classes described in `context/standards/orchestrator-runtime-files.md`'s "Consumer
Repo Setup" section. Two shell-test harnesses
(`scripts/tests/test-deploy-propagation.sh`, `scripts/tests/test-deploy-orphans.sh`) create bare
`git init` scratch repos with no `.gitignore` at all to test the deploy engine itself — those
scratch repos correctly failed the new gate, which in turn made `deploy-headless.sh`'s own inline
verification fail, breaking both harnesses. The fix was **not** to relax the gate; it was to seed
the same documented `.gitignore` block into each harness's scratch fixture, so the fixture
represents a properly-onboarded consumer repo (which is what these harnesses are actually meant
to simulate). The general lesson: before adding a new `verify-deploy.sh` gate, grep
`agent-system/extensions/core/scripts/tests/` for any harness that spins up a bare scratch git
repo and deploys into it — such a harness needs the same onboarding fixture your new gate now
assumes every real consumer repo has.

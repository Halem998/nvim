# Implementation Summary: Task #843

**Completed**: 2026-07-10
**Duration**: ~30 minutes

## Overview

Fixed all 4 doc-lint FAILs reported by `bash .claude/scripts/check-extension-docs.sh` — 2 in the
`core` section (undeclared `provides.scripts` entries) and 2 in the `lean` section (an
accidentally-reverted WARN-vs-FAIL classification for the two `-hard` `routing_hard` targets).
The check now exits 0 with all 19 extension sections showing PASS.

## What Changed

- `.claude/extensions/core/scripts/orchestrator-postflight.sh` — Created (new). Byte-identical
  backport (`cp`, mode 755) of the deployed `.claude/scripts/orchestrator-postflight.sh`, which
  previously existed only in the deployed tree and was never captured as extension source.
- `.claude/extensions/core/manifest.json` — Added `"task-lock.sh"` and
  `"orchestrator-postflight.sh"` to `provides.scripts`. `task-lock.sh` source already existed and
  was already byte-identical to the deployed copy; it had simply never been registered.
- `.claude/scripts/check-extension-docs.sh` — In `check_routing_consistency`'s `routing_hard`
  loop, changed the final uninstalled-extension `else` branch from
  `fail "routing_hard target declared but not deployed (and extension not installed): $t"` to
  `info "WARN: routing_hard target declared but not deployed (extension not installed): $t"`
  (matching the existing WARN-emission convention used a few lines above for the parallel
  non-hard `routing` case). Updated the preceding block comment to document task #771's original
  reasoning (`command-route-skill.sh` does not implement `routing_hard` dispatch at all, so the
  "unconditional dispatch" rationale that previously justified FAIL is false) and to note that
  task #792's sync had reverted this from a stale extension-source copy. The `installed -eq 1`
  branch and the not-resolvable branch were left unchanged (still FAIL).
- `.claude/extensions/core/scripts/check-extension-docs.sh` — Identical edit, applied by `cp`ing
  the fully-edited deployed file over the extension-source copy (verified no other content
  differed beforehand), preserving Rule F (#841 drift guard) byte-identity.

## Decisions

- Sequenced Phase 1 as backport-then-register (never manifest-only), per the plan's explicit
  risk mitigation: a manifest-only edit for `orchestrator-postflight.sh` would trip a new
  "missing on disk" FAIL.
- Used the codebase's existing `info "WARN: ..."` helper convention (identical to the parallel
  non-hard `routing` uninstalled-branch pattern immediately above) rather than introducing a new
  `warn()` function name, since none exists in this script — a faithful implementation of the
  plan's `fail -> warn` intent without inventing new severity-reporting infrastructure.
- For Phase 2's second copy, used `cp` of the already-edited, verified deployed file rather than
  re-typing the edit by hand, after confirming via `diff` that no other content differed between
  the two copies beforehand — this guarantees byte-identity by construction rather than by
  double independent editing.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell script project)
- Tests: `bash .claude/scripts/check-extension-docs.sh; echo "exit=$?"` -> `exit=0`, all 19
  extension sections (core, cslib, email, epidemiology, filetypes, formal, founder, latex, lean,
  literature, memory, nix, nvim, present, python, slidev, typst, web, z3) show PASS.
- `skill-lean-research-hard` and `skill-lean-implementation-hard` now emit
  `WARN: routing_hard target declared but not deployed (extension not installed): ...` instead of
  FAIL.
- `diff -q` byte-identity confirmed for all three touched scripts (deployed vs. extension-source):
  `check-extension-docs.sh`, `orchestrator-postflight.sh`, `task-lock.sh` — all identical.
- `jq empty .claude/extensions/core/manifest.json` succeeds (valid JSON).
- `git status` shows no changes under any literature path — the literature section was untouched
  and continues to PASS (no regression).
- Files verified: Yes.

## Notes

Per the plan's explicit non-goal, `command-route-skill.sh`'s missing `routing_hard`
implementation (it takes 3 positional args and never reads `.routing_hard`, so the
CLAUDE.md-documented 5-step precedence is not actually implemented there) was recorded but
deliberately NOT fixed in this task — it is a separate, larger drift between documentation and
implementation that the plan scoped out.

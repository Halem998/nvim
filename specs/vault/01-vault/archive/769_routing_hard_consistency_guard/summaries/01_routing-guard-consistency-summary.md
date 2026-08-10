# Implementation Summary: Task #769

**Completed**: 2026-06-24
**Duration**: ~2 hours

## Overview

Extended `.claude/scripts/check-extension-docs.sh` with four new consistency check rules (A-D) that catch manifest-vs-disk and routing-target inconsistencies in extension manifests. The script now exits 1 with 4 FAILs total: 2 pre-existing (core extension issues) + 2 new (lean routing_hard targets undeployed because lean is not installed). The core extension copy was synced byte-identical.

## What Changed

- `.claude/scripts/check-extension-docs.sh` — Added env-overridable `REPO_ROOT`/`EXT_DIR`, three new check functions (`check_undeclared_skills`, `check_routing_consistency`, `check_deployed_skill_agents`), and wired them into the main loop.
- `.claude/extensions/core/scripts/check-extension-docs.sh` — Synced to be byte-identical copy of the working script.
- `specs/769_routing_hard_consistency_guard/test-guard.sh` — New fixture-based harness with 22 assertions covering all four rules.

## Decisions

- **Colon-notation in routing values**: Routing targets like `skill-grant:assemble` use a colon sub-operation suffix (not a skill name with colon). When resolving routing targets against `provides.skills` and the deployed tree, the base skill name (part before the colon) is extracted via `${t%%:*}`. This prevents false Rule B FAILs from the `present` extension's compound routing values.
- **routing_hard severity policy** (plan Phase 2 rationale): Deployment-dimension severity is keyed on install status for BOTH `routing` and `routing_hard` (FAIL if installed, WARN if not). The asymmetry that makes `routing_hard` stricter is in a separate dimension: `routing_hard` targets that exist in extension source but are undeployed because the extension is uninstalled are a FAIL — because `command-route-skill.sh` steps 4a-4d scan `routing_hard` across ALL manifests with no install guard, making these targets live correctness bugs regardless of install status. This is the lean case.
- **Rule B resolvability check**: A routing target that does not appear in any extension's `provides.skills` AND is not deployed is a FAIL (manifest typo or stale entry). Cross-extension core targets (e.g., `skill-planner`) satisfy this via deployment check.
- **Harness uses temp file for exit-code capture**: The `output=$(...)` bash assignment makes `$?` reflect the subshell's exit. To correctly capture the guard script's exit code, the harness writes output to a temp file, runs the script with redirect, and captures `$?` directly.

## Plan Deviations

- **Colon-notation handling** (implementation deviation from research sketch): The research's Function 2 (`check_routing_consistency`) sketch did not account for routing values containing colon sub-operation suffixes (e.g., `skill-grant:assemble` in the present extension). Without this fix, the implementation would produce 6 FAILs instead of the expected 4. The fix strips the colon suffix for skill-resolution using `${t%%:*}`.

## Verification

- **Harness**: 22/22 assertions pass; exit 0. All four rules fire on violation fixtures and are silent on clean fixtures.
- **Real run**: exit 1, exactly 4 FAILs.
  - PRE-EXISTING: `manifest script entry missing on disk: scripts/dispatch-agent.sh`
  - PRE-EXISTING: `command /zulip listed in manifest but not mentioned in README.md`
  - NEW: `routing_hard target declared but not deployed (and extension not installed): skill-lean-research-hard`
  - NEW: `routing_hard target declared but not deployed (and extension not installed): skill-lean-implementation-hard`
- **Core copy**: `diff -q` reports identical; both copies produce 4 FAILs when run with correct `REPO_ROOT`.
- **Installed heuristic**: core/cslib/nvim/nix/literature/memory all classified as installed (23/8/2/2/1/1 deployed skills respectively); lean classified as uninstalled (0 deployed skills).
- **No fixture residue**: `git status` shows no stray entries in `.claude/extensions/` from the harness.

## Notes

- The lean extension's routing_hard targets (`skill-lean-research-hard`, `skill-lean-implementation-hard`) FAIL by design. They will continue to FAIL until the lean extension is installed. This is the intended CI signal: the extension has routing_hard entries but is not deployed, and `command-route-skill.sh` would route to these skills unconditionally for `--hard lean4` tasks.
- The present extension's compound routing values (`skill-grant:assemble`, `skill-slides:assemble`) produce WARNs (not FAILs) because `present` is uninstalled and the base skills (`skill-grant`, `skill-slides`) are resolvable via `provides.skills`.
- Pre-existing failures (dispatch-agent.sh, /zulip README gap) are out of scope per the plan's Non-Goals. They are preserved and not masked.

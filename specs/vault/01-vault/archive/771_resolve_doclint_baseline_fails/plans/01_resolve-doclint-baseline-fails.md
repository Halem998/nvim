# Implementation Plan: Task #771

- **Task**: 771 - resolve_doclint_baseline_fails
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 769 (added the doc-lint guard)
- **Research Inputs**: specs/771_resolve_doclint_baseline_fails/reports/01_doclint-baseline-fails.md
- **Artifacts**: plans/01_resolve-doclint-baseline-fails.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Resolve the 4 doc-lint baseline FAILs reported by `bash .claude/scripts/check-extension-docs.sh`. The research report concluded all 4 are fixable across 3 files without installing lean or modifying uninstalled extensions: (1) remove a stale script entry from the core manifest, (2) document the `/zulip` command in the core README, and (3) make the `routing_hard` uninstalled-extension branch of the doc-lint guard a WARN rather than a FAIL. The work is a single, tightly-scoped meta change sized to one implementation run, followed by a verification step.

### Research Integration

The research report (`reports/01_doclint-baseline-fails.md`) provides the complete resolution with exact file locations:
- FAIL 1 root cause: task 766 (`706fff1f7`) deleted `dispatch-agent.sh` but left it in `provides.scripts` (manifest line 95). Fix is to remove the stale entry, not restore the file.
- FAIL 2 root cause: `/zulip` is in the core manifest's commands list but absent from the README Commands table. Fix is one table row plus a count update (15 -> 16).
- FAILs 3 & 4: Option (a) — change the `routing_hard` uninstalled-extension branch in `check-extension-docs.sh` (line 260) from `fail` to `info`, and correct the policy rationale comment (lines 156-162). This does NOT weaken detection of the original bug class: `check_routing_consistency` runs for all extensions including core, and core is always `installed=1`, so core `routing_hard` deployment violations still FAIL via the installed branch (line 255).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Remove the stale `dispatch-agent.sh` entry from the core manifest `provides.scripts`.
- Add a `/zulip` row to the core README Commands table and update the command count.
- Convert the `routing_hard` uninstalled-extension FAIL to a WARN and correct the policy comment.
- Achieve a clean `check-extension-docs.sh` run: exit 0 with no FAILs (WARNs acceptable).

**Non-Goals**:
- Do NOT install the lean extension or any other uninstalled extension.
- Do NOT modify uninstalled extension manifests/skills (e.g., lean's `routing_hard`) to satisfy the check.
- Do NOT modify `command-route-skill.sh` to add a Steps 4a-4d deployment guard (research notes this is a separate corner-case fix, out of scope for task 771).
- Do NOT clean up the informational stale doc references to `dispatch-agent.sh` in `docs/` (non-blocking, can be handled separately).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Weakening the guard for core hard skills | H | L | Not a real risk — core is always `installed=1`; the installed-branch FAIL (line 255) still triggers for core. Verify by reading the surrounding branch logic before editing. |
| Missing a regression from an uninstalled extension's routing_hard | L | L | Acceptable: an uninstalled extension having undeployed targets is the expected state; WARN surfaces it without failing the build. |
| README count update wrong (manifest has 17 commands) | L | M | Follow research decision: update overview count 15 -> 16 to reflect adding the `/zulip` row; `/orchestrate` already passes the grep check via architecture text so no row needed for it. |
| Editing wrong comment block or branch in the script | M | L | Use exact line references from research (comment 156-162, branch 257-260) and read surrounding context before each Edit. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Resolve all 4 doc-lint FAILs and verify clean run [COMPLETED]

**Goal**: Apply the three file edits from the research report and confirm `check-extension-docs.sh` exits 0 with no FAILs.

**Tasks**:
- [x] FAIL 1: In `.claude/extensions/core/manifest.json`, remove the `"dispatch-agent.sh",` entry from `provides.scripts` (currently line 95). Ensure surrounding JSON commas remain valid. *(completed)*
- [x] FAIL 2: In `.claude/extensions/core/README.md`, add a `/zulip` row to the Commands table (table at lines ~26-46) with a short description (e.g., "Fetch a Zulip thread via API and write formatted JSON to a file"). Match the existing column structure of adjacent rows. *(completed)*
- [x] FAIL 2: In `.claude/extensions/core/README.md`, update the overview command count from `15` to `16`. *(completed)*
- [x] FAILs 3 & 4: In `.claude/scripts/check-extension-docs.sh`, change the `routing_hard` uninstalled-extension branch (the `else` clause at lines 257-260) from `fail "routing_hard target declared but not deployed (and extension not installed): $t"` to `info "WARN: routing_hard target declared but not deployed (extension not installed): $t"`. *(completed)*
- [x] FAILs 3 & 4: Update the policy rationale comment (lines 152-162) so it accurately states that `routing_hard` and `routing` share the same deployment-dimension severity (FAIL when installed, WARN when uninstalled), and that the unconditional-dispatch concern for uninstalled extensions is intentionally downgraded to WARN because core (the only always-installed extension) still FAILs via the installed branch. Keep the Rule B (resolvability) FAIL description intact. *(completed)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm exit code 0. *(completed: exit=0, all 18 extensions PASS, lean routing_hard items now WARN)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/manifest.json` - remove stale `dispatch-agent.sh` from `provides.scripts`
- `.claude/extensions/core/README.md` - add `/zulip` Commands-table row; update count 15 -> 16
- `.claude/scripts/check-extension-docs.sh` - change routing_hard uninstalled branch FAIL -> WARN; correct policy comment

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh; echo "exit=$?"` prints `exit=0`.
- The `[core]` block shows no FAILs (a README-drift WARN may remain and is acceptable).
- The `[lean]` block shows WARNs (not FAILs) for the two `routing_hard` targets (`skill-lean-research-hard`, `skill-lean-implementation-hard`).
- The summary reports 0 FAILs / all extensions PASS.
- Confirm no FAIL line contains the string "routing_hard target declared but not deployed".

---

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [ ] No FAIL lines in the output; lean `routing_hard` targets appear as WARN.
- [ ] `.claude/extensions/core/manifest.json` is valid JSON (`jq . .claude/extensions/core/manifest.json` succeeds) and no longer lists `dispatch-agent.sh`.
- [ ] `.claude/extensions/core/README.md` Commands table contains a `/zulip` entry and the overview count reads 16.
- [ ] lean extension files and `command-route-skill.sh` are unchanged (no out-of-scope edits).

## Artifacts & Outputs

- Modified `.claude/extensions/core/manifest.json`
- Modified `.claude/extensions/core/README.md`
- Modified `.claude/scripts/check-extension-docs.sh`
- Clean `check-extension-docs.sh` run (exit 0) documented in the implementation summary

## Rollback/Contingency

All changes are confined to three tracked files. To revert, run `git checkout -- .claude/extensions/core/manifest.json .claude/extensions/core/README.md .claude/scripts/check-extension-docs.sh`. If the script still reports a FAIL after edits, re-read the relevant `check_routing_consistency` branch and the README Commands grep check (`check_readme_vs_manifest`) to confirm the edited lines match the FAIL message, then adjust. Do not satisfy any residual FAIL by installing extensions or editing uninstalled-extension manifests — instead document the finding as an accepted baseline if it is genuinely non-actionable.

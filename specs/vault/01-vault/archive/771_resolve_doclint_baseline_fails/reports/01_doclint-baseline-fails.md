# Research Report: Task #771

**Task**: 771 - resolve_doclint_baseline_fails
**Started**: 2026-06-24T21:00:00Z
**Completed**: 2026-06-24T21:30:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 769 (doc-lint guard was added in this task)
**Sources/Inputs**: Codebase (check-extension-docs.sh, core/manifest.json, lean/manifest.json, core/README.md, command-route-skill.sh, skill-orchestrate-hard/SKILL.md, git log)
**Artifacts**: specs/771_resolve_doclint_baseline_fails/reports/01_doclint-baseline-fails.md
**Standards**: report-format.md

---

## Executive Summary

- All 4 FAILs are fixable; none require installing lean or modifying uninstalled extensions.
- **FAIL 1**: `dispatch-agent.sh` was intentionally deleted in task 766 but the core manifest was not updated. Fix: remove from `provides.scripts`.
- **FAIL 2**: `/zulip` command is declared in core manifest but missing from `core/README.md`. Fix: add one table row.
- **FAILs 3 and 4**: Option (a) is the correct resolution. Making `routing_hard` install-gated (WARN when extension is uninstalled) does NOT weaken the guard — core extension is always `installed=1`, so core hard-skill deplyoment violations still FAIL. Lean's routing_hard targets being undeployed in an uninstalled extension is not an actionable problem.

---

## Context & Scope

The doc-lint guard (`check-extension-docs.sh`, task 769) exits 1 with 4 FAILs. Task 771 asks: resolve or formally accept each. Constraint: do not install lean or modify uninstalled extensions to satisfy the check.

---

## Findings

### FAIL 1: `dispatch-agent.sh` missing on disk

**Root cause**: Task 766 ("modernize agent dispatch architecture") deliberately deleted `dispatch-agent.sh`. The commit `706fff1f7` shows:

```
D	.claude/extensions/core/scripts/dispatch-agent.sh
D	.claude/scripts/dispatch-agent.sh
```

The commit message confirms: "Remove dispatch-agent.sh indirection layer (4 files, ~361 lines of pseudocode)."

The core manifest (`extensions/core/manifest.json` line 95) still lists `"dispatch-agent.sh"` in `provides.scripts`. This was an oversight — the manifest should have been updated when the script was deleted.

**No other scripts reference dispatch-agent.sh at runtime.** Stale documentation references exist in `docs/architecture/architecture-spec.md` and `docs/guides/creating-agents.md` but those are informational and do not cause runtime failures. `fork-patterns.md` explicitly notes the mechanism is obsolete.

**Fix**: Remove `"dispatch-agent.sh"` from `provides.scripts` in `extensions/core/manifest.json`.

---

### FAIL 2: `/zulip` not mentioned in `core/README.md`

**Root cause**: The doc-lint guard checks that every command listed in `manifest.provides.commands[]` appears (as `/commandname`) somewhere in the README. The core manifest lists `"zulip.md"` in commands but the README Commands table has 15 entries and does not include `/zulip`.

Exact check from `check-extension-docs.sh` (`check_readme_vs_manifest`):
```bash
for c in $cmds; do
  local cmd_name="${c%.md}"
  if ! grep -q "/$cmd_name" "$readme"; then
    fail "command /$cmd_name listed in manifest but not mentioned in README.md"
  fi
done
```

The README overview table says "Commands | 15" but the manifest has 17 commands. Two commands (`/zulip`, `/orchestrate`) were added after the README was written. `/orchestrate` is incidentally mentioned as text on line 88 (`skill-orchestrate/ # Autonomous lifecycle state machine (/orchestrate command)`), so the grep check passes. `/zulip` has zero occurrences.

**Fix**: Add a `/zulip` row to the Commands table in `extensions/core/README.md` and update the overview count from 15 to 16 (or 17 to match the full manifest count).

---

### FAILs 3 and 4: lean `routing_hard` targets declared but not deployed

**Root cause analysis**:

The lean extension (`extensions/lean/manifest.json`) declares:
```json
"routing_hard": {
  "research": { "lean4": "skill-lean-research-hard" },
  "implement": { "lean4": "skill-lean-implementation-hard" }
}
```

Both `skill-lean-research-hard` and `skill-lean-implementation-hard` exist in `extensions/lean/skills/` (source) and in `lean/manifest.json provides.skills`. But lean is not installed in this project — no lean skills or agents appear in `.claude/skills/` or `.claude/agents/`.

The current `check_routing_consistency` function in `check-extension-docs.sh` treats routing_hard targets for uninstalled extensions as FAIL (line 260):
```bash
fail "routing_hard target declared but not deployed (and extension not installed): $t"
```

whereas non-hard routing targets for uninstalled extensions are WARN (line 237):
```bash
info "WARN: routing target not deployed (extension not installed): $t"
```

**Does the "unconditional-dispatch" concern justify FAIL?**

The comment in `check-extension-docs.sh` (lines 157-162) argues: "command-route-skill.sh steps 4a-4d scan routing_hard across ALL manifests without an install guard."

This is accurate for the committed HEAD version of `command-route-skill.sh` (185 lines, implementing the 5-step algorithm from task 768). The working tree currently has the older 66-line version due to uncommitted modifications. In the HEAD version, Step 4a scans all non-core extension manifests for `routing_hard[$op][$task_type]` without checking if the extension is installed.

If task_type is `lean4` and `--hard` is passed, Step 4a finds `skill-lean-research-hard` from lean's manifest and sets `SKILL_NAME = "skill-lean-research-hard"` — there is no deployment check at this point (Step 4e's safety gate only applies to the -hard-append fallback, not to direct manifest matches).

**However**, this concern is moot in practice:

1. `lean4` task type is only assigned during `/task` creation when the lean extension is loaded. A user without lean installed cannot normally have a `lean4`-typed task.
2. Even if a `lean4` task existed and `--hard` was run, `skill-orchestrate-hard/SKILL.md` handles `lean4` via its own `case` statement (lines 80-87) with explicit file-existence fallback checks before the manifest-scan override runs — though the manifest scan can override that fallback.
3. The risk scenario (lean uninstalled + lean4 task + --hard) is a corner case that should be fixed in `command-route-skill.sh` by adding a deployment check for Steps 4a-4d (not in scope for task 771).

**Does option (a) weaken the guard's ability to catch "core hard skills declared but undeployed"?**

No. The key insight:

- `check_routing_consistency` does NOT check `routing_exempt`. It runs for ALL extensions including core.
- Core extension is always `installed=1` because all its source skills are deployed in `.claude/skills/`.
- For installed extensions, both `routing` and `routing_hard` missing-deployment cases are FAIL via "Rule C (routing_hard, installed)".
- Making the "extension not installed" branch of routing_hard a WARN instead of FAIL only affects uninstalled extensions like lean.
- Core is never uninstalled, so core routing_hard violations would still FAIL regardless of option (a).

**Recommendation: Option (a)**

Change the `else` branch in `check_routing_consistency` for routing_hard (line 257-260) from:
```bash
fail "routing_hard target declared but not deployed (and extension not installed): $t"
```
to:
```bash
info "WARN: routing_hard target declared but not deployed (extension not installed): $t"
```

Also update the policy rationale comment to accurately reflect this change.

**Why not option (b) (baseline allowlist)?**

Option (b) adds maintenance burden without adding correctness. An allowlist of accepted FAILs must be updated every time a new extension adds routing_hard. Option (a) encodes the correct policy in the guard itself: uninstalled extensions are not expected to be deployed, regardless of whether targets are hard or non-hard routing.

---

## Decisions

1. **FAIL 1**: Remove `dispatch-agent.sh` from core manifest (not restore the deleted file).
2. **FAIL 2**: Add `/zulip` to core README Commands table; update count from 15 to 16 (two commands were added post-README, `/orchestrate` incidentally passes the grep check via architecture text, `/zulip` does not).
3. **FAILs 3/4**: Apply option (a) — change routing_hard uninstalled-extension FAIL to WARN in `check-extension-docs.sh`. Update the policy rationale comment to reflect this. No changes to lean extension or command-route-skill.sh in scope for this task.

---

## Files to Change

| File | Change |
|------|--------|
| `.claude/extensions/core/manifest.json` | Remove `"dispatch-agent.sh"` from `provides.scripts` (line 95) |
| `.claude/extensions/core/README.md` | Add `/zulip` row to Commands table; update count 15->16 in overview |
| `.claude/scripts/check-extension-docs.sh` | Change routing_hard uninstalled-extension branch from `fail` to `info`; update policy comment |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Weakening guard for core hard skills | Not a risk — core is always installed; FAIL path still triggers for core |
| Missing a new regression from uninstalled extension routing_hard | Acceptable: uninstalled extension routing is expected-undeployed state; WARN is sufficient |
| Stale doc references to dispatch-agent.sh | Non-blocking; stale docs don't cause runtime failures. Can be cleaned separately. |

---

## Verification

After fixes, run `bash .claude/scripts/check-extension-docs.sh` and confirm:
1. `[core]` block shows OK (no FAILs)
2. `[lean]` block shows WARNs (not FAILs) for routing_hard targets
3. Exit code 0
4. Summary table shows all extensions PASS

---

## Appendix

### Script run output (current state)

```
[core]
  FAIL: manifest script entry missing on disk: scripts/dispatch-agent.sh
  WARN: README.md older than manifest.json (possible drift)
  FAIL: command /zulip listed in manifest but not mentioned in README.md

[lean]
  WARN: routing target not deployed (extension not installed): skill-lean-research
  ... (routing WARNs) ...
  FAIL: routing_hard target declared but not deployed (and extension not installed): skill-lean-research-hard
  FAIL: routing_hard target declared but not deployed (and extension not installed): skill-lean-implementation-hard

FAIL: 4 issue(s) found
```

### Key file locations

- `check-extension-docs.sh` routing_hard logic: lines 242-263
- `core/manifest.json` scripts section: lines 85-130
- `core/README.md` Commands table: lines 26-46
- `lean/manifest.json` routing_hard section: lines 56-63
- `command-route-skill.sh` (HEAD) Step 4a-4e: lines 66-184
- `skill-orchestrate-hard/SKILL.md` lean4 case: lines 80-87

### Git history context

- Task 766 (`706fff1f7`): deleted `dispatch-agent.sh`, forgot to update manifest
- Task 767-770 (`574bf515a`): added 5-step routing_hard to `command-route-skill.sh`, added doc-lint guard (769), wrote policy comment incorrectly characterizing the lean FAIL as inherently justified

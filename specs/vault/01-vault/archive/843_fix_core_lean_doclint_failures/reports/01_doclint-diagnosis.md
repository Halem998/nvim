# Research Report: Task #843

**Task**: 843 - Restore the `core` and `lean` sections of `.claude/scripts/check-extension-docs.sh` to PASS
**Started**: 2026-07-10
**Completed**: 2026-07-10
**Effort**: small (diagnosis only; fixes are 1-3 line manifest/source edits)
**Dependencies**: None (predates and is independent of tasks #840/#841)
**Sources/Inputs**:
- `bash .claude/scripts/check-extension-docs.sh` (live re-run, 2026-07-10)
- `.claude/scripts/check-extension-docs.sh` (check logic, Rules B/C/E)
- `.claude/extensions/core/manifest.json`, `.claude/extensions/lean/manifest.json`
- `.claude/scripts/command-route-skill.sh` (actual runtime routing implementation)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` (`copy_scripts`)
- `git log -p` on `.claude/scripts/check-extension-docs.sh` (commits 574bf515a, 072df550e,
  827277328, 3c2c04b7e, cd9c36d23) and on `.claude/extensions/core/scripts/task-lock.sh`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Re-verification result**: only **4** FAILs remain (not 5, and not the "6" mentioned in the
  task prompt) — 2 in `core`, 2 in `lean`. The third core item the task listed,
  `literature-briefing-invoke.sh`, is **already fixed** (registered in the `literature`
  extension's `provides.scripts` by commit `fa8e68ed6`) and no longer fails, and there is
  **no double-ownership conflict** — it does not also appear in core's `provides.scripts`.
- **Core fix (both remaining items) is a clean manifest/source-packaging fix**, following the
  exact precedent set by task #793 for `lifecycle-notify.sh`/`reconcile-artifacts.sh`:
  - `task-lock.sh`: already exists in `.claude/extensions/core/scripts/task-lock.sh` (source) and
    is byte-identical to the deployed copy — it was simply never added to core's
    `provides.scripts` array when it was introduced (commit `5721a451e`, "orchestrate tasks
    788,796"). Fix: add the one string to the array.
  - `orchestrator-postflight.sh`: **does not exist in core's extension source at all** — it only
    exists as a deployed-only file (`.claude/scripts/orchestrator-postflight.sh`), despite being
    described in `git-staging-scope.md` as "the canonical authority" / "single shared execution
    site." This is the same class of bug task #793 fixed for `lifecycle-notify.sh` and
    `reconcile-artifacts.sh` (both were also core-owned, deployed-only, referenced-but-unpackaged
    scripts). Fix: copy the deployed file into
    `.claude/extensions/core/scripts/orchestrator-postflight.sh` and add it to `provides.scripts`.
    A manifest-only edit is **not sufficient** here — `check_manifest_entries` (Rule: "manifest
    script entry missing on disk") will newly FAIL if the source file isn't also created.
- **Lean fix requires a decision, not a mechanical edit.** Git archaeology shows the current FAIL
  state is the result of an **accidental regression**, not a settled design choice:
  1. Commit `574bf515a` introduced routing_hard as an unconditional FAIL ("Rule C extra ...
     unconditional-dispatch FAIL clause").
  2. Task #771 (commit `072df550e`, "resolve doc-lint baseline fails") deliberately **downgraded
     this to WARN**, reasoning explicitly: *"The same WARN-when-uninstalled rule applies to
     routing_hard targets: an uninstalled extension having undeployed targets is the expected
     state, not a live correctness bug."* — but this edit touched **only** the deployed copy
     `.claude/scripts/check-extension-docs.sh`, not the extension-source copy
     `.claude/extensions/core/scripts/check-extension-docs.sh`.
  3. Task #792 (commit `827277328`, a large sync/resync-style orchestration run touching
     `extensions.json`, `index.json`, and dozens of command frontmatter files) silently
     **overwrote the deployed copy from the still-stale source copy**, reverting task #771's WARN
     fix back to FAIL — with no mention of routing_hard in its commit message. This is exactly
     the "deployed-vs-source content drift" class of bug that task #841 Phase 4 later added
     **Rule F** to `check-extension-docs.sh` to catch (Rule F did not exist yet at the time of the
     792 revert).
  4. Task #793 (commit `3c2c04b7e`, one day later) explicitly noted the lean FAIL was already
     back and called it *"a pre-existing, unrelated lean routing_hard issue (confirmed via git
     stash to predate this task)"* — i.e., the accidental revert had already happened by then and
     was correctly triaged as out-of-scope for #793, not re-litigated.
  - **Independent confirmation the WARN reasoning is objectively correct today**: the check
    script's FAIL rationale claims `command-route-skill.sh` "scans routing_hard across ALL
    manifests without an install guard." Reading the actual deployed
    `.claude/scripts/command-route-skill.sh`, it **does not implement `routing_hard` dispatch at
    all** — it only has 3 positional params and only ever reads `.routing[$op][$tt]`, never
    `.routing_hard`. (`.claude/tests/test-command-route-skill.sh` tests a 4-arg
    `effort`/hard-mode precedence that the shipped script does not implement — a separate,
    pre-existing drift between CLAUDE.md's documented "Routing Mechanism" 5-step precedence and
    the actual script, out of scope for #843 but worth flagging.) Because the "unconditional
    dispatch" premise does not hold in the current runtime script, task #771's WARN framing is
    the factually accurate one; the "FAIL is correct because it's a live correctness bug"
    rationale is not currently true.
  - Both `skill-lean-research-hard` and `skill-lean-implementation-hard` are legitimate,
    fully-built skills that exist in `.claude/extensions/lean/skills/` and are already correctly
    declared in `lean`'s own `provides.skills` — they are not aspirational stubs. The `lean`
    extension itself is simply not installed in this repo (`extensions.json` only lists core,
    nix, memory, nvim as active) — the same situation as z3, formal, python, typst, web, which
    all show WARN-only for their (non-hard) `routing` targets with no FAIL.

## Context & Scope

Task 843 asked for diagnosis of 4-6 pre-existing doc-lint failures in the `core` and `lean`
extension sections of `check-extension-docs.sh`, predating tasks #840/#841, which currently keep
the overall check exit code non-zero (blunting task #841's literature drift guard in the same
script). The task explicitly required diagnosing root cause per failure rather than assuming the
fix, and flagged a possible double-ownership conflict for `literature-briefing-invoke.sh` between
`core` and `literature` following a related fix in commit `fa8e68ed6`.

## Findings

### Complete current failure list (re-verified 2026-07-10)

```
[core]
  FAIL: script referenced in docs/skills/agents but NOT in provides.scripts: orchestrator-postflight.sh
  FAIL: script referenced in docs/skills/agents but NOT in provides.scripts: task-lock.sh

[lean]
  FAIL: routing_hard target declared but not deployed (and extension not installed): skill-lean-research-hard
  FAIL: routing_hard target declared but not deployed (and extension not installed): skill-lean-implementation-hard

Summary: FAIL: 4 issue(s) found  (only core and lean are FAIL; all other 17 extensions PASS)
```

This is **4** failures, not the 5 the task description enumerated (3 core + 2 lean) and not the
"6" mentioned in deliverable #3. `literature-briefing-invoke.sh` no longer fails — see below.

### `literature-briefing-invoke.sh` — already fixed, no double ownership

- Source lives at `.claude/extensions/literature/scripts/literature-briefing-invoke.sh`.
- It is registered in `literature`'s `provides.scripts` (confirmed present at
  `.claude/extensions/literature/manifest.json`, line 50).
- It is **not** present in `core`'s `provides.scripts` array (46 entries, checked directly) — so
  there is no double-ownership conflict. `check_referenced_scripts_declared`'s step 3
  ("Exclude names declared in ANY extension's provides.scripts") is exactly why core's own
  references to `literature-briefing-invoke.sh` (in `skill-implementer/SKILL.md` and
  `skill-planner/SKILL.md`) no longer trip a core FAIL: the cross-extension exclusion set already
  covers it.
- **No action needed** for this item; task 841's earlier fix is complete and clean.

### `task-lock.sh` — core, undeclared script

| Field | Value |
|---|---|
| Failure | `script referenced in docs/skills/agents but NOT in provides.scripts: task-lock.sh` |
| Owning extension | `core` (unambiguous — it's a core lock-management script) |
| Source file | `.claude/extensions/core/scripts/task-lock.sh` (exists, 21849 bytes) |
| Deployed file | `.claude/scripts/task-lock.sh` (exists, byte-identical to source — `diff` empty) |
| Referenced from | `commands/research.md`, `commands/plan.md`, `commands/implement.md`, `commands/revise.md`, `agents/general-implementation-agent.md`, `skills/skill-implementer/SKILL.md`, `skills/skill-orchestrate/SKILL.md`, `skills/skill-orchestrate-hard/SKILL.md`, plus `context/patterns/task-lock.md` (not scanned by the check — only commands/skills/agents/README/EXTENSION.md are scanned) |
| Root cause | The script was added to core's extension source in commit `5721a451e` ("orchestrate tasks 788,796") but that commit never touched `manifest.json` — `provides.scripts` registration was simply omitted at creation time. |
| Recommended fix | Add `"task-lock.sh"` to `provides.scripts` in `.claude/extensions/core/manifest.json`. Source and deployed copies already match, so no file copy is needed — this is a pure manifest edit. |

### `orchestrator-postflight.sh` — core, deployed-only (never packaged)

| Field | Value |
|---|---|
| Failure | `script referenced in docs/skills/agents but NOT in provides.scripts: orchestrator-postflight.sh` |
| Owning extension | `core` (unambiguous — it's the canonical Stage 9 commit-pipeline execution site per `git-staging-scope.md`) |
| Source file | **Does not exist** anywhere under `.claude/extensions/*/scripts/` |
| Deployed file | `.claude/scripts/orchestrator-postflight.sh` exists (21687 bytes, actively used) |
| Referenced from | `agents/general-implementation-agent.md`, `context/standards/git-staging-scope.md` (calls it "the canonical authority" / "single shared execution site" for Stage 9), `skills/skill-git-workflow/SKILL.md`, `skills/skill-implementer/SKILL.md`, and internally by `scripts/lifecycle-notify.sh`'s own header comment |
| Root cause | Same bug class as task #793's `lifecycle-notify.sh`/`reconcile-artifacts.sh` fix (see #793 commit message: *"2 genuine pre-existing core bugs remained ... referenced in core's own skills but never packaged in any manifest -- fixed by migrating them into core's extension source and declaring them in provides.scripts (43 -> 45)"*). `orchestrator-postflight.sh` is a third sibling of that same bug that #793 did not catch (its own SKILL.md/agent references may not have existed yet, or the script was added later/separately). |
| Recommended fix | Mirror #793's precedent exactly: (1) copy the current deployed `.claude/scripts/orchestrator-postflight.sh` content into a new file `.claude/extensions/core/scripts/orchestrator-postflight.sh` (source = deployed content, since deployed is the live, in-use version and no separate "correct" version exists); (2) add `"orchestrator-postflight.sh"` to `provides.scripts` in `.claude/extensions/core/manifest.json`. A manifest-only edit is **not sufficient**: `check_manifest_entries` would immediately raise a *new* FAIL ("manifest script entry missing on disk: scripts/orchestrator-postflight.sh") if the source file isn't created too. This is content-copy + manifest edit, not a runtime-behavior change — the script's logic is untouched, only its source-of-truth location is corrected. |

### `skill-lean-research-hard` / `skill-lean-implementation-hard` — lean, routing_hard FAIL

| Field | Value |
|---|---|
| Failure | `routing_hard target declared but not deployed (and extension not installed): skill-lean-{research,implementation}-hard` |
| Owning extension | `lean` |
| Source state | Both skills fully exist as complete source directories: `.claude/extensions/lean/skills/skill-lean-research-hard/`, `.claude/extensions/lean/skills/skill-lean-implementation-hard/`. Both are already correctly declared in `lean`'s own `provides.skills` and `provides.agents` (with matching `*-hard-agent.md` files). Not aspirational stubs — fully implemented. |
| Installed state | `lean` extension is **not installed** in this repo — `extensions.json` lists only `core`, `nix`, `memory`, `nvim` as active. No `.claude/skills/skill-lean-*` or `.claude/agents/lean-*` directories exist. This matches every other non-installed extension (z3, formal, python, typst, web, epidemiology, founder, present) which show WARN, not FAIL, for their `routing` targets. `lean` is the **only** extension anywhere in the repo that declares a `routing_hard` block at all — it is the sole exemplar the stricter FAIL rule was written for. |
| Root cause (why it currently FAILs) | **Accidental regression via deploy/source drift, not a deliberate design decision.** Full timeline via `git log -p`: <br>1. Commit `574bf515a` (task 767-770 orchestration) introduced the strict "unconditional-dispatch FAIL clause" for routing_hard. <br>2. Task #771 (commit `072df550e`) deliberately reverted this to WARN, with an explicit, reasoned comment: *"The same WARN-when-uninstalled rule applies to routing_hard targets: an uninstalled extension having undeployed targets is the expected state, not a live correctness bug."* This edit touched **only** the deployed `.claude/scripts/check-extension-docs.sh`, not the extension-source copy at `.claude/extensions/core/scripts/check-extension-docs.sh` — the source copy was left stale with the old FAIL logic. <br>3. Task #792 (commit `827277328`, six days later) performed a broad orchestration/sync run (touching `extensions.json`, `index.json`, dozens of command files) that triggered `loader.lua`'s `copy_scripts()` byte-for-byte overwrite of deployed scripts from extension source — this **silently reverted #771's WARN fix back to FAIL**, since the stale source copy still had the old logic. The commit message never mentions routing_hard; this is best explained as an unintentional side effect of the sync, not a re-decision. <br>4. Task #793 (commit `3c2c04b7e`, the very next day) independently re-ran the full check suite and explicitly flagged this exact FAIL as *"a pre-existing, unrelated lean routing_hard issue (confirmed via git stash to predate this task)"* — correctly triaging it as out of scope rather than re-litigating it. <br>5. Task #841 Phase 4 (commit `cd9c36d23`) later added **Rule F** (deployed-vs-source content-diff drift guard) specifically to catch this exact class of silent-overwrite regression for `provides.scripts` entries — but Rule F does not cover `check-extension-docs.sh` itself differing in *logic* from an earlier, deliberately-chosen version; it only catches deployed-copy-differs-from-current-source-copy drift, and by definition both copies now agree (both have the FAIL logic) so Rule F reports no drift today. |
| Is the FAIL rationale currently true? | No. The FAIL rationale (both in the current code comment and in commit 827277328) claims `command-route-skill.sh` "scans routing_hard across ALL manifests without an install guard," making an uninstalled-but-undeployed routing_hard target "a live correctness bug." Reading the actual deployed `.claude/scripts/command-route-skill.sh` directly: it takes exactly 3 positional args (`operation`, `task_type`, `default_skill`), and only ever queries `.routing[$op][$tt]` — it contains **no reference to `.routing_hard` anywhere** and does not implement the 4th-arg `effort_flag` / 5-step hard-mode precedence that CLAUDE.md's "Routing Mechanism" section documents and that `.claude/tests/test-command-route-skill.sh` tests against. So today, an uninstalled `lean` extension's undeployed `routing_hard` targets genuinely cannot be dispatched to at runtime — the "unconditional dispatch" premise does not hold. (This command-route-skill.sh vs. CLAUDE.md/tests drift is itself a separate, real gap — flagged below, out of scope for #843.) |
| Recommended fix (three candidate resolutions, per task framing) | **(a) Deploy the skills**: copy `skill-lean-research-hard`/`skill-lean-implementation-hard` (and their agents) into `.claude/skills/`/`.claude/agents/` without going through the full `lean` extension installer. Rejected as the primary recommendation — this half-installs `lean` (2 skills present, but no lean commands/rules/context/other skills), which is inconsistent with `extensions.json`'s bookkeeping and would likely trip *other* lint checks (orphan/undeclared-file detection) for a partial install. <br>**(b) Correct the routing_hard declaration** (remove the two entries from `lean`'s manifest, or otherwise mark them not-ready): rejected — these are fully-built, source-grounded, already-declared-in-provides.skills capabilities; removing the declaration would be "papering over a real gap" (explicitly disallowed by the task), since the skills are genuinely ready for use wherever `lean` *is* installed (e.g. a CSLib/Lean-focused repo). <br>**(c) Restore task #771's WARN classification** in `check-extension-docs.sh`, this time correctly, in **both** copies (source `.claude/extensions/core/scripts/check-extension-docs.sh` and deployed `.claude/scripts/check-extension-docs.sh`, byte-identical, per Rule F's own drift-prevention discipline) — **recommended**. This is not a re-litigation but a restoration of a previously deliberate, well-reasoned decision that was lost to an accidental sync overwrite, and it is empirically grounded in the actual (non-hard-mode-aware) behavior of `command-route-skill.sh` today. |
| Note for planner | Option (c) is a change to a *check/lint script's* severity classification, not to a manifest. The task's stated default ("SOURCE OF TRUTH is manifests — edit there") assumed a manifest-shaped fix; this is the one failure of the four where the evidence points to the check script itself being the thing that regressed. Flagging explicitly so the planner can weigh this against the task's manifest-only framing rather than have it decided silently in research. If the planner prefers to stay strictly manifest-only despite the evidence, options (a) or accepting an intentionally-scoped WARN-suppression flag (would require a new, currently-nonexistent manifest field, since `routing_exempt` only gates `check_routing_block`, not `check_routing_consistency` — confirmed by code inspection) are the fallback paths, but both are weaker than (c). |

## Decisions

- Confirmed `literature-briefing-invoke.sh` is already fixed and non-conflicting; no work needed.
- Confirmed the true current failure count is 4 (2 core + 2 lean), not 5 or 6.
- Diagnosed root cause per-failure via source/deployed file comparison, manifest inspection, and
  `git log -p` archaeology rather than assuming the fix.
- Established via direct inspection of `command-route-skill.sh` that the lean routing_hard FAIL's
  stated rationale ("unconditional dispatch, no install guard") does not hold against the actual
  shipped script, which strengthens the case that task #771's WARN reversion (option (c) above)
  is the objectively correct fix, not merely a preference.

## Risks & Mitigations

- **Risk**: Fixing `orchestrator-postflight.sh` by copying deployed content into extension source
  could pick up an out-of-date or already-drifted deployed copy as the new "source of truth."
  **Mitigation**: the plan/implementation phase should diff the copied content against its own
  references (e.g. `git log` on the deployed file) to confirm no in-flight edits are lost, then
  treat the copy as authoritative going forward (matching how #793 handled its two siblings).
- **Risk**: Editing `check-extension-docs.sh` (source + deployed) for the lean WARN restoration
  could be perceived as exceeding "manifest/doc hygiene only." **Mitigation**: flagged explicitly
  above as a planner decision point rather than resolved unilaterally in research.
- **Risk**: If a future extension picker installs `lean` in this repo, `routing_hard` targets
  would then correctly need to FAIL (installed=1 branch already handles this — no change needed
  there; only the uninstalled branch is being restored to WARN).

## Context Extension Recommendations

- **Topic**: `command-route-skill.sh` hard-mode dispatch.
- **Gap**: CLAUDE.md's "Routing Mechanism" section and `.claude/tests/test-command-route-skill.sh`
  both describe/test a 5-step `--hard` routing precedence (4th `effort_flag` arg,
  `routing_hard` lookups, core-vs-non-core precedence, `-hard` append fallback) that the actual
  deployed `.claude/scripts/command-route-skill.sh` does not implement at all (3 params only, no
  `.routing_hard` reference). This is a real, separate documentation/implementation drift,
  independent of task #843's scope. Recommend spawning a follow-up task to either implement the
  documented behavior in `command-route-skill.sh` or reconcile the docs/tests to match current
  behavior — until resolved, `check-extension-docs.sh`'s FAIL-vs-WARN policy rationale for
  routing_hard cannot be verified against the real runtime script (which is exactly the
  discrepancy diagnosed above for the lean case).

## Appendix

### Search/verification commands used

```bash
bash .claude/scripts/check-extension-docs.sh
jq '{name, routing, routing_hard, provides}' .claude/extensions/lean/manifest.json
jq -r '.provides.scripts[]' .claude/extensions/core/manifest.json
diff .claude/extensions/core/scripts/task-lock.sh .claude/scripts/task-lock.sh
git log --oneline --follow -- .claude/scripts/check-extension-docs.sh
git show 072df550e -- .claude/scripts/check-extension-docs.sh
git show 827277328 -- .claude/scripts/check-extension-docs.sh
git show 3c2c04b7e --stat
git log --oneline --diff-filter=A --follow -- .claude/extensions/core/scripts/task-lock.sh
grep -n "routing_hard" .claude/scripts/command-route-skill.sh   # no matches
grep -n "routing_exempt" .claude/scripts/check-extension-docs.sh
```

### Per-failure fix table (summary)

| Failure | Owning extension | Root cause | Recommended fix |
|---|---|---|---|
| `task-lock.sh` not in `provides.scripts` | core | Script added to source (commit 5721a451e) without manifest registration | Add `"task-lock.sh"` to core `provides.scripts` (manifest-only; source/deployed already match) |
| `orchestrator-postflight.sh` not in `provides.scripts` | core | Script exists only as a deployed file, never placed in extension source (same bug class as #793's lifecycle-notify.sh/reconcile-artifacts.sh) | Copy deployed content to `.claude/extensions/core/scripts/orchestrator-postflight.sh`, then add to core `provides.scripts` |
| `skill-lean-research-hard` routing_hard undeployed | lean | Task #771's deliberate WARN fix was accidentally reverted to FAIL by task #792's sync-driven source-copy overwrite; #793 correctly triaged it as pre-existing/out-of-scope the next day | Restore WARN classification in `check-extension-docs.sh` (both source and deployed copies) — planner decision point; see full analysis above for alternatives (a)/(b) |
| `skill-lean-implementation-hard` routing_hard undeployed | lean | Same as above | Same as above |

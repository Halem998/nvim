# Implementation Plan: Routing/Deployment Consistency Guard

- **Task**: 769 - Add manifest-vs-disk and routing-target consistency guard to doc-lint
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: 767, 768 (declarations and routing_hard semantics — both presumed satisfied; this plan validates the artifacts they produce)
- **Research Inputs**: specs/769_routing_hard_consistency_guard/reports/01_routing-guard-research.md
- **Artifacts**: plans/01_routing-guard-consistency.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend `.claude/scripts/check-extension-docs.sh` with four new check rules (A–D) that catch manifest-vs-disk and routing-target inconsistencies, accumulating violations into the existing `FAILURES` counter so the script continues to exit non-zero in CI. The four rules are: (A) skill directories present in extension source but absent from `provides.skills`; (B) routing/routing_hard targets not resolvable to any `provides.skills` declaration; (C) routing/routing_hard targets not deployed under `.claude/skills/`; (D) deployed skills whose `subagent_type:` references a missing agent file. The work also keeps the duplicated copy at `.claude/extensions/core/scripts/check-extension-docs.sh` byte-identical. Definition of done: the script flags the two known lean `routing_hard` violations as new FAILs, preserves the two pre-existing core FAILs, exits non-zero when any violation is present, and a fixture-based harness proves each rule fires on a synthetic violation and is silent when clean.

### Research Integration

The research report (`reports/01_routing-guard-research.md`) supplies: the exact current script structure (REPO_ROOT at line 27, `fail()`/`info()` helpers, the `CURRENT_EXT` tracking pattern, the main loop call site at lines 178–180), the skill→agent naming convention (`subagent_type:` grep extraction, no reliable frontmatter `agent:` field), three ready bash function sketches (`check_undeclared_skills`, `check_routing_consistency`, `check_deployed_skill_agents`), the authority-tree decision table, and the predicted output (+2 FAILs from lean routing_hard, no new agent-existence FAILs for deployed extensions). Baseline verified live during planning: current run reports exactly 2 FAILs (core `dispatch-agent.sh` missing, `/zulip` README gap), exit 1; the source script and core copy are byte-identical.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (roadmap_flag not set).

## Goals & Non-Goals

**Goals**:
- Implement check rules A, B, C, D inside `check-extension-docs.sh` as new functions following the existing `fail()`/`info()` pattern.
- Resolve the routing_hard severity policy so it is internally consistent with the routing (non-hard) policy and still catches the known lean violations (see Risks and the Phase 2 rationale).
- Accumulate all new violations into `FAILURES`; preserve non-zero exit; do not reset or mask the two pre-existing core failures.
- Keep `.claude/extensions/core/scripts/check-extension-docs.sh` byte-identical to the working copy.
- Prove each rule fires on a controlled violation and is silent when clean, via a fixture harness, distinguishing new from pre-existing failures.

**Non-Goals**:
- Fixing the two pre-existing core failures (`dispatch-agent.sh`, `/zulip` README) — out of scope; left as-is and explicitly accounted for in verification.
- Adding a machine-readable `agent:` frontmatter field to every SKILL.md (research Decision 4: out of scope).
- Deploying the lean extension or altering `command-route-skill.sh` / `install-extension.sh`.
- Introducing a separate "known failures" counter (research Recommendation: Option A — treat all failures equally).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Routing/routing_hard severity policy is internally inconsistent (routing_hard FAILs for uninstalled lean while routing only WARNs) — flagged by the task as the key decision | M | H | Phase 2 adopts an explicit, documented policy: deployment checks (Rule C) FAIL only when the extension is installed; routing_hard adds a stricter SOURCE-existence sub-check that FAILs regardless of install status. This catches lean's case via Rule B/the source sub-check, not via a special-cased deployed-tree exception. See Phase 2 rationale. |
| Guard emits 90+ WARN lines from 11 uninstalled extensions | L (non-blocking) | H | WARNs are informational only (use `info()`), never increment `FAILURES`; suppressed under `--quiet`. |
| `subagent_type:` grep is brittle (multiline/formatting) | M | M | Narrow `grep -o 'subagent_type: "[^"]*"'`, take first match; skip empties (direct-execution skills) and `fork`. Accept false negatives over false positives. |
| Core copy drifts from working copy | M | M | Phase 4 copies the file and asserts `diff -q` returns identical; verification gate fails the phase otherwise. |
| Fixture harness leaves stray test extensions in `.claude/extensions/` polluting real runs | M | M | Fixtures created under a scratch temp tree with an overridable `EXT_DIR`/`REPO_ROOT`, or removed in a trap; Phase 5 verifies a clean post-run `git status`. |
| `installed` heuristic misclassifies a symlink-deployed extension | M | L | Heuristic checks both `.claude/skills/<skill>` (dir or symlink) and `.claude/agents/<agent>.md`; matches research Decision 3. Validated against known-installed (core/nvim/nix/cslib) and known-uninstalled (lean) in Phase 5. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase produces script state the next phase depends on.

---

### Phase 1: Rule A — Undeclared skill dirs + harness scaffold [COMPLETED]

- **Goal:** Add `check_undeclared_skills()` to `check-extension-docs.sh`, wire it into the main loop, and make `EXT_DIR`/`REPO_ROOT` overridable via environment so a fixture harness can point the script at a synthetic extension tree.
- **Tasks:**
  - [ ] Make `REPO_ROOT` (line 27) and `EXT_DIR` (line 28) honor pre-set environment values: `REPO_ROOT="${REPO_ROOT:-$(cd ... && pwd)}"` and `EXT_DIR="${EXT_DIR:-$REPO_ROOT/.claude/extensions}"`. This enables fixture testing without touching the real tree.
  - [ ] Add `check_undeclared_skills(ext_path)` per research Function 1: for each `skills/skill-*/` dir, `fail` if its basename is not in `.provides.skills`. Guard with `[[ -d "$ext_path/skills" ]] || return 0`.
  - [ ] Insert the call into the main loop after `check_manifest_entries` (between lines 178 and 179), inside the `jq empty` valid-manifest block.
  - [ ] Create a fixture harness script at `specs/769_routing_hard_consistency_guard/test-guard.sh` that builds a synthetic `EXT_DIR` in a temp dir, runs `check-extension-docs.sh` against it, and asserts FAIL/exit codes. Phase 1 adds the Rule A fixture: a test extension with a `skill-undeclared/` dir missing from `provides.skills`.
- **Timing:** 40 min
- **Depends on:** none
- **Files to modify:**
  - `.claude/scripts/check-extension-docs.sh` — env-overridable roots, new function, call site
  - `specs/769_routing_hard_consistency_guard/test-guard.sh` — new harness (created when first written)
- **Verification:**
  - Run the harness Rule A fixture: script emits `FAIL: skill dir on disk NOT in provides.skills: skill-undeclared` and exits non-zero.
  - Run against a clean fixture (all dirs declared): Rule A produces no FAIL.
  - Full real run still exits 1 with exactly the 2 pre-existing core FAILs plus zero new FAILs from Rule A (all real skill dirs are declared) — confirm count unchanged at 2.

---

### Phase 2: Rule B + Rule C — Routing target consistency and deployment [COMPLETED]

- **Goal:** Add `check_routing_consistency()` covering Rule B (target resolvable to some `provides.skills`) and Rule C (target deployed), with a documented, internally consistent severity policy that catches the two known lean `routing_hard` violations.
- **Tasks:**
  - [ ] Implement the `installed` heuristic per research Decision 3: extension is installed if any of its source skills appears as a dir/symlink under `.claude/skills/` OR any of its source agents appears under `.claude/agents/`.
  - [ ] Enumerate routing targets: `jq -r '.routing // {} | to_entries[] | .value | to_entries[] | .value'`; same for `.routing_hard`.
  - [ ] **Rule B (resolvable to a declaration, all extensions):** a target must be in `provides.skills` of SOME extension OR be deployed under `.claude/skills/`. Cross-extension core targets (`skill-planner`, `skill-implementer`, `skill-researcher`) satisfy this via deployment. If a target resolves to neither, `fail` (Rule B violation). This applies to both `routing` and `routing_hard` and is install-status-independent.
  - [ ] **Rule C (deployment, severity by policy below):**
    - `routing` target not deployed AND extension installed → `fail`.
    - `routing` target not deployed AND extension NOT installed → `info` WARN (expected; not yet deployed).
    - `routing_hard` target: same install-gated FAIL/WARN as routing for the *deployment* dimension — BUT additionally apply the **source-existence sub-check**: if a `routing_hard` target is not deployed, verify it exists in some extension's SOURCE (`.claude/extensions/*/skills/<target>/SKILL.md` AND in that extension's `provides.skills`). If the source skill exists but the target is undeployed in an *uninstalled* extension, this is the lean case — emit FAIL with message `routing_hard target declared but not deployed (and extension not installed): <skill>`.
  - [ ] Insert the call into the main loop after `check_routing_block`.
- **Timing:** 50 min
- **Depends on:** 1
- **Files to modify:**
  - `.claude/scripts/check-extension-docs.sh` — `check_routing_consistency()` + call site
  - `specs/769_routing_hard_consistency_guard/test-guard.sh` — Rule B/C fixtures
- **Design decision rationale (REQUIRED by task):**
  - The task flags an inconsistency in the research's "revised Rule C": routing_hard "always FAIL if not deployed" vs routing "WARN if uninstalled". Hard-failing every uninstalled extension's routing_hard would also be wrong if we keyed purely on deployment, because deployment status is identical for routing and routing_hard targets of an uninstalled extension.
  - **Chosen policy (internally consistent):** Deployment-dimension severity is keyed on a single rule for BOTH routing and routing_hard — FAIL if installed, WARN if not. The asymmetry that makes routing_hard stricter is moved to a *separate, well-defined dimension*: a `routing_hard` target MUST correspond to a real skill that exists in extension SOURCE and is declared in `provides.skills`. This is justified because `command-route-skill.sh` Steps 4a–4d scan `routing_hard` across ALL manifests with no install guard, so a `routing_hard` target that does not even exist in source is a live correctness bug regardless of installation.
  - **Why this catches lean:** lean's `skill-lean-research-hard` / `skill-lean-implementation-hard` DO exist in source and ARE in `provides.skills`, but lean is uninstalled. Under a pure deployment rule they would only WARN. The task explicitly requires these to FAIL. We therefore add the narrow FAIL clause above: a `routing_hard` target that exists in source but is undeployed because its owning extension is uninstalled is a FAIL, because `routing_hard` (unlike `routing`) is dispatched unconditionally by the router. This preserves consistency: routing and routing_hard share the same deployment rule; routing_hard additionally enforces source-grounding and the unconditional-dispatch FAIL clause. The policy is documented inline in the script via a comment block above the function.
  - **Net effect on counts:** +2 FAILs (lean hard skills), and WARNs (non-blocking) for uninstalled extensions' non-hard routing targets — matching the research's predicted output.
- **Verification:**
  - Harness Rule B fixture (routing target `skill-nonexistent` declared nowhere): emits FAIL, exits non-zero.
  - Harness Rule C fixture, installed extension with undeployed routing target: FAIL. Uninstalled extension with undeployed routing target: WARN only (no FAIL, count unchanged).
  - Harness routing_hard fixture mirroring lean (source skill present, extension uninstalled, target undeployed): FAIL.
  - Full real run: FAIL count rises from 2 to 4 (the two lean `routing_hard` targets). Capture and record the exact two new FAIL lines.

---

### Phase 3: Rule D — Agent existence for deployed skills [COMPLETED]

- **Goal:** Add `check_deployed_skill_agents()` so every deployed skill whose SKILL.md names a `subagent_type:` agent is verified to have a matching `.claude/agents/<agent>.md`.
- **Tasks:**
  - [ ] Implement per research Function 3: iterate `.provides.skills[]`; skip if not deployed (`.claude/skills/<s>/SKILL.md` absent); extract agent via `grep -o 'subagent_type: "[^"]*"' | head -1 | cut -d'"' -f2`; skip empty (direct-execution) and `fork`; `fail` if `.claude/agents/<agent>.md` is missing.
  - [ ] Insert the call into the main loop after `check_routing_consistency`.
  - [ ] Add a harness fixture: a deployed test skill referencing `subagent_type: "ghost-agent"` with no agent file → FAIL; and a control skill referencing an existing agent → no FAIL.
- **Timing:** 35 min
- **Depends on:** 2
- **Files to modify:**
  - `.claude/scripts/check-extension-docs.sh` — `check_deployed_skill_agents()` + call site
  - `specs/769_routing_hard_consistency_guard/test-guard.sh` — Rule D fixtures
- **Verification:**
  - Harness Rule D fixture (missing agent): FAIL, exit non-zero. Control (existing agent): no FAIL.
  - Full real run: FAIL count remains 4 (research confirms all deployed extensions — core, cslib, nix, nvim, literature, memory — have their referenced agents present). If any unexpected new FAIL appears, investigate and record it as a real finding before proceeding.

---

### Phase 4: Sync core copy and finalize script [COMPLETED]

- **Goal:** Mirror the updated script into the core extension source copy and confirm byte-identity, so the extension deploy mechanism cannot ship a stale guard.
- **Tasks:**
  - [ ] Copy `.claude/scripts/check-extension-docs.sh` to `.claude/extensions/core/scripts/check-extension-docs.sh` (preserve executable bit).
  - [ ] Confirm `diff -q` reports the two files identical.
  - [ ] Re-run both files independently and confirm identical FAIL count and exit code.
- **Timing:** 20 min
- **Depends on:** 3
- **Files to modify:**
  - `.claude/extensions/core/scripts/check-extension-docs.sh` — synced copy
- **Verification:**
  - `diff -q .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh` → identical.
  - Both invocations exit 1 with FAIL count 4.

---

### Phase 5: Full verification and cleanup [COMPLETED]

- **Goal:** Prove the complete rule set end-to-end, distinguish new from pre-existing failures, and ensure no fixture residue remains.
- **Tasks:**
  - [ ] Run the full harness (`specs/769_routing_hard_consistency_guard/test-guard.sh`): assert each of Rules A/B/C/D fires on its violation fixture and is silent on its clean fixture; assert exit 0 on a fully clean fixture tree and non-zero when any violation present.
  - [ ] Run the real guard; record the FAIL inventory and annotate each line as PRE-EXISTING (`dispatch-agent.sh`, `/zulip`) or NEW (the two lean `routing_hard`).
  - [ ] Verify the `installed` heuristic classifies core/nvim/nix/cslib/literature/memory as installed and lean as uninstalled (spot-check via WARN/FAIL placement).
  - [ ] Confirm `git status` shows only the intended changes (two scripts + harness + plan/summary artifacts); ensure the harness uses a temp dir and leaves no stray entries under `.claude/extensions/`.
- **Timing:** 35 min
- **Depends on:** 4
- **Files to modify:** none (verification only; may adjust harness for cleanup)
- **Verification:**
  - Harness exits 0 (all assertions pass).
  - Real run: exit 1, FAIL count 4, with 2 PRE-EXISTING + 2 NEW correctly attributed.
  - Clean `git status` apart from intended files.

---

## Testing & Validation

- [ ] Rule A fires on an undeclared skill dir; silent when all dirs declared.
- [ ] Rule B fires on a routing/routing_hard target that resolves to no `provides.skills` and is not deployed.
- [ ] Rule C FAILs for an installed extension's undeployed routing target; WARNs (no FAIL) for an uninstalled one.
- [ ] routing_hard source-grounding/unconditional-dispatch clause FAILs on the lean fixture and on the two real lean targets.
- [ ] Rule D fires on a deployed skill referencing a missing agent; skips direct-execution and `fork` skills.
- [ ] Script exits non-zero whenever any violation present; exits 0 on a fully clean fixture tree.
- [ ] Pre-existing core failures preserved and not masked (2 PRE-EXISTING accounted for).
- [ ] Working copy and core copy byte-identical.
- [ ] No fixture residue in the real `.claude/extensions/` tree.

## Artifacts & Outputs

- `.claude/scripts/check-extension-docs.sh` — extended guard with Rules A–D
- `.claude/extensions/core/scripts/check-extension-docs.sh` — byte-identical synced copy
- `specs/769_routing_hard_consistency_guard/test-guard.sh` — fixture-based verification harness
- `specs/769_routing_hard_consistency_guard/plans/01_routing-guard-consistency.md` — this plan
- `specs/769_routing_hard_consistency_guard/summaries/01_routing-guard-consistency-summary.md` — execution summary (on completion)

## Rollback/Contingency

- All changes are confined to two script files and a new harness script under `specs/`. Revert via `git checkout -- .claude/scripts/check-extension-docs.sh .claude/extensions/core/scripts/check-extension-docs.sh` and `rm specs/769_routing_hard_consistency_guard/test-guard.sh`.
- If the routing_hard FAIL policy proves too noisy in CI, the documented inline comment block identifies the single clause to downgrade to WARN without affecting Rules A/B/D.
- No state.json, manifest, or deployed-tree mutations are made, so rollback cannot affect routing behavior.

# Implementation Plan: Task #779

- **Task**: 779 - Hard-mode: fix-forward recovery contract (disambiguate 'restore green')
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: 778 (DONE - strategic-sorry skeleton), 780 (DONE - git-snapshot.sh + guard-destructive-git.sh + git-workflow.md rule)
- **Research Inputs**: reports/01_fix-forward-recovery-contract.md
- **Artifacts**: plans/01_recovery-contract-fix-forward.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 779 creates an unambiguous recovery contract so that "reach green" / "restore green" ALWAYS
means FIX FORWARD (correct code in the working tree) and NEVER means revert/reset/checkout to a
prior green commit. The core deliverable is a new single-copy contract file
`.claude/context/contracts/recovery.md` (following the one-contract-per-H-technique pattern of
anti-analysis.md/wrap-up.md/convergence.md) that states the fix-forward disambiguation and the
canonical 3-rung RECOVERY LADDER: (a) fix forward, (b) documented strategic-sorry skeleton (task
778 mechanism), (c) snapshot-then-smallest-scope-rollback (task 780 mechanism). The contract is
then wired into `skill-orchestrate-hard`'s dispatch-prompt construction (a 5th contract slot),
referenced from `skill-implementer-hard` and `general-implementation-hard-agent.md`, and aligned
with `error-handling.md`'s Build Error Recovery block. Definition of done: every hard-mode
implementation dispatch emits the disambiguated recovery phrasing by default, and all dual
deployed/core copies stay byte-consistent.

### Research Integration

The plan honors all four explicit plan requirements from reports/01_fix-forward-recovery-contract.md:
1. New standalone `recovery.md` (NOT a wrap-up.md section); single-copy (no core mirror); dual
   consumption modeled on convergence.md (skill direct-read) + anti-analysis.md (agent Context
   Reference).
2. The 3 rungs cite REAL shipped mechanisms verbatim by path/command: rung (b) = anti-analysis.md
   five-condition strategic-sorry test + wrap-up.md skeleton/sorry_inventory schema (778); rung
   (c) = `.claude/scripts/git-snapshot.sh` + `.claude/hooks/guard-destructive-git.sh` +
   git-workflow.md "No Destructive Git on Uncommitted Work" rule (780).
3. Injection point confirmed: `build_hard_mode_prompt_context()` in
   `skill-orchestrate-hard/SKILL.md` (function at line 307, CONTRACT SLOTS block at lines 309-314,
   consumed by per-phase dispatch line 301 and parallel-wave dispatch line 339). Grep confirmed
   zero pre-existing RED/green/revert/rollback language in that file.
4. Dual-copy edits to skill-implementer-hard, general-implementation-hard-agent.md, and
   error-handling.md Build Error Recovery block.

Verification during planning confirmed: skill-orchestrate-hard, general-implementation-hard-agent,
and error-handling.md dual copies are currently IDENTICAL; the recovery.md contract file has no
core mirror (single-copy); index.json contracts entries exist at lines 149/237/291.

### Prior Plan Reference

No prior plan. This is the first plan for task 779.

### Roadmap Alignment

No ROADMAP.md consulted (roadmap_flag not set). Task advances the hard-mode contract suite
(H2/H3/H4/H6/H7/H9) by adding a cross-cutting fix-forward recovery discipline.

## Goals & Non-Goals

**Goals**:
- Create `.claude/context/contracts/recovery.md` as the canonical fix-forward recovery contract
  with the 3-rung ladder, grounding rungs (b)/(c) in the actual task-778/780 mechanisms.
- Register recovery.md in `.claude/context/index.json` (subdomain contracts, domain core,
  load_when.agents = ["general-implementation-hard-agent"]).
- Bake a 5th "Recovery Discipline" contract slot into `build_hard_mode_prompt_context()` so every
  per-phase and parallel-wave dispatch emits the disambiguated phrasing by default.
- Add recovery.md references to skill-implementer-hard and general-implementation-hard-agent.md
  (both alongside their existing anti-analysis.md/wrap-up.md references).
- Reword error-handling.md's ambiguous "Keep source unchanged" line to explicit fix-forward +
  no-discard language cross-referencing recovery.md and git-workflow.md.
- Keep every dual deployed/core copy byte-consistent.

**Non-Goals**:
- Do NOT mint a new "H10" label or edit CLAUDE.md's Hard Mode H1-H9 enumeration (out of scope;
  deferred per research Decisions).
- Do NOT modify the lean extension's contract override copies (domain specialization, out of
  scope; task 779 is domain-agnostic).
- Do NOT edit `.claude/context/standards/error-handling.md` Rollback Strategy (optional/secondary
  per research; not required scope).
- Do NOT alter git-snapshot.sh, guard-destructive-git.sh, or git-workflow.md (778/780 mechanisms
  referenced as-is, not changed).
- Do NOT touch sibling-task sections in shared files (see Territory table); confine 779's edits to
  distinct recovery-reference sections so they compose with tasks 772/773/774/781.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Shared-file concurrent edits with siblings (772/773 -> skill-orchestrate-hard; 774 -> skill-implementer-hard; 781 -> general-implementation-hard-agent.md) | H | M | Territory table below enumerates every file; orchestrator must serialize per-file across tasks. 779 edits are confined to distinct recovery sections/slots. |
| Editing only one of a dual deployed/core pair reintroduces drift | H | M | Each dual-edit phase lists BOTH paths as a single atomic unit; Phase 6 verifies with `diff -q` per pair. |
| skill-implementer-hard deployed vs core copies ALREADY differ (pre-existing drift observed at plan time) | M | H | Phase 3 must inspect both copies first, apply the recovery.md addition to the matching section in each, and reconcile so both end consistent; do not blindly assume identical baselines. |
| Reworded "Keep source unchanged" read as license for large speculative changes | M | L | Use narrowly-scoped wording ("correct the source to resolve the error") + explicit "Never discard uncommitted changes" clause; preserve original no-silent-patch intent. |
| recovery.md load disclaimer wrongly scopes fix-forward statement to --hard only | M | L | Scope the `--hard`-only disclaimer to rungs (b)/(c) mechanics; explicitly mark the rung (a) fix-forward statement as safe to quote in standard-mode dispatch prompts. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Note: Wave-2 parallelism is internal to task
779 (phases 2-5 touch disjoint files). Cross-task serialization on shared files is the
orchestrator's responsibility per the Territory table.

### Territory: Files Touched by Task 779 (for orchestrator serialization)

| File | Copy | 779 edit | Sibling overlap |
|------|------|----------|-----------------|
| `.claude/context/contracts/recovery.md` | single (new) | create | none |
| `.claude/context/index.json` | single | add contracts entry | none known |
| `.claude/skills/skill-orchestrate-hard/SKILL.md` | deployed | 5th CONTRACT SLOT | 772, 773 |
| `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` | core | 5th CONTRACT SLOT | 772, 773 |
| `.claude/skills/skill-implementer-hard/SKILL.md` | deployed | add recovery.md ref | 774 |
| `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md` | core | add recovery.md ref | 774 |
| `.claude/agents/general-implementation-hard-agent.md` | deployed | Context Ref + Recovery Ladder section | 781 |
| `.claude/extensions/core/agents/general-implementation-hard-agent.md` | core | Context Ref + Recovery Ladder section | 781 |
| `.claude/rules/error-handling.md` | deployed | reword Build Error Recovery | none known |
| `.claude/extensions/core/rules/error-handling.md` | core | reword Build Error Recovery | none known |

### Phase 1: Create recovery.md contract and register in index.json [NOT STARTED]

- **Goal:** Author the canonical `.claude/context/contracts/recovery.md` (single copy) and add its
  index.json entry so downstream phases can reference it.
- **Tasks:**
  - [ ] Create `.claude/context/contracts/recovery.md` following the anti-analysis.md/wrap-up.md
    structural convention:
    - Opening paragraph naming the technique (Recovery Contract - Fix-Forward Discipline).
    - A `--hard`-only load disclaimer scoped to rungs (b)/(c) mechanics; explicitly note the rung
      (a) fix-forward statement is safe to quote verbatim in standard-mode dispatch prompts.
    - "'Green' Means Fix Forward" section: the canonical disambiguation statement ("reach green"/
      "restore green" = make the current working tree pass build/tests by adding/correcting code;
      NEVER `git reset`/`git checkout`/`git restore`/revert while uncommitted changes exist; an
      agent MUST NOT discard uncommitted work to reach green).
    - "The Recovery Ladder" section, three rungs, each naming its actual mechanism/paths (not
      paraphrased): rung (a) fix forward (default, no external file); rung (b) strategic-sorry
      skeleton citing anti-analysis.md's five-condition test + wrap-up.md's skeleton/sorry_inventory
      schema; rung (c) snapshot-then-rollback citing `bash .claude/scripts/git-snapshot.sh [--branch] <task>`,
      `.claude/hooks/guard-destructive-git.sh`, and git-workflow.md's "No Destructive Git on
      Uncommitted Work" rule, preferring smallest revert scope.
    - "Domain Specialization" section noting rung (b) placeholders are domain-specific (Lean4
      `sorry`, Python `NotImplementedError`, etc.).
  - [ ] Add an index.json entry under subdomain "contracts", domain "core", path
    `contracts/recovery.md`, `load_when.agents: ["general-implementation-hard-agent"]`, keywords
    including `fix-forward`, `recovery-ladder`, `strategic-sorry`, `snapshot`, `restore-green`,
    `rollback`. Match the structure of the existing anti-analysis.md/wrap-up.md entries.
  - [ ] Confirm no core mirror is needed (contracts/*.md are single-copy).
- **Timing:** 1 hour
- **Depends on:** none

- **Files to modify:**
  - `.claude/context/contracts/recovery.md` - new file
  - `.claude/context/index.json` - add contracts entry
- **Verification:**
  - File exists and contains the disambiguation statement + 3 named rungs with real paths.
  - `python3 -c "import json; json.load(open('.claude/context/index.json'))"` parses cleanly and the
    new entry is present.

---

### Phase 2: Bake recovery slot into skill-orchestrate-hard dispatch prompt [NOT STARTED]

- **Goal:** Add a 5th "Recovery Discipline" slot to `build_hard_mode_prompt_context()` so every
  per-phase (line 301) and parallel-wave (line 339) dispatch emits the disambiguated phrasing by
  default.
- **Tasks:**
  - [ ] In the deployed copy, add slot 5 to the CONTRACT SLOTS block (currently lines 309-314):
    "5. Recovery Discipline: If RED, FIX FORWARD to reach green - never revert/reset/checkout to a
    prior commit. If a sub-goal is genuinely blocked, land a documented strategic-sorry skeleton
    (anti-analysis.md) instead of discarding structure. Only if rollback is truly required:
    snapshot first via `bash .claude/scripts/git-snapshot.sh`, then use the smallest revert scope.
    Full ladder: .claude/context/contracts/recovery.md."
  - [ ] Apply the identical edit to the core copy.
  - [ ] Confine the edit to the CONTRACT SLOTS block only (distinct from any 772/773 sections).
- **Timing:** 0.5 hour
- **Depends on:** 1

- **Files to modify:**
  - `.claude/skills/skill-orchestrate-hard/SKILL.md` - add slot 5
  - `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - add slot 5 (identical)
- **Verification:**
  - `grep -c "Recovery Discipline" ` on both copies returns >= 1.
  - `diff -q` between the two copies reports no difference.

---

### Phase 3: Add recovery.md reference to skill-implementer-hard [NOT STARTED]

- **Goal:** List recovery.md alongside the existing anti-analysis.md/wrap-up.md/territory.md
  contract references, and mention it in the dispatch-prompt-construction text.
- **Tasks:**
  - [ ] FIRST inspect BOTH copies (they currently DIFFER - pre-existing drift); locate the contract
    reference list (deployed lines ~24-26) in each.
  - [ ] Add `- Path: `.claude/context/contracts/recovery.md` - recovery/fix-forward ladder (loaded
    by agent)` to the reference list in each copy.
  - [ ] Add a recovery.md mention to the dispatch-prompt-construction text (near the anti-analysis
    contract reference passing, deployed ~line 239) in each copy.
  - [ ] Reconcile so both copies end byte-consistent for the sections 779 touches (do not
    overwrite sibling-task 774 content; only add the recovery reference lines).
- **Timing:** 0.5 hour
- **Depends on:** 1

- **Files to modify:**
  - `.claude/skills/skill-implementer-hard/SKILL.md` - add recovery.md ref
  - `.claude/extensions/core/skills/skill-implementer-hard/SKILL.md` - add recovery.md ref
- **Verification:**
  - `grep -c "contracts/recovery.md"` on both copies returns >= 1.
  - Both copies are consistent for the recovery-reference lines (spot-diff the touched region).

---

### Phase 4: Update general-implementation-hard-agent.md Context References + Recovery Ladder section [NOT STARTED]

- **Goal:** Add recovery.md to the MANDATORY Context References and a short "Recovery Ladder (Hard
  Mode)" section mirroring the existing "Strategic-Sorry Skeleton (Hard Mode)" section.
- **Tasks:**
  - [ ] Add `- `@.claude/context/contracts/recovery.md` - recovery/fix-forward ladder (MANDATORY)`
    to the Context References list (after line 27, alongside anti-analysis.md/wrap-up.md).
  - [ ] Add a "Recovery Ladder (Hard Mode)" section (mirroring the "Strategic-Sorry Skeleton (Hard
    Mode)" section at line 44) stating the fix-forward default and pointing to rung (b)/(c)
    mechanics in recovery.md rather than re-deriving them.
  - [ ] Apply identical edits to both deployed and core copies (currently IDENTICAL).
  - [ ] Confine edits to the recovery section (distinct from any 781 sections).
- **Timing:** 0.5 hour
- **Depends on:** 1

- **Files to modify:**
  - `.claude/agents/general-implementation-hard-agent.md` - Context Ref + Recovery Ladder section
  - `.claude/extensions/core/agents/general-implementation-hard-agent.md` - identical
- **Verification:**
  - `grep -c "contracts/recovery.md"` on both copies returns >= 1; "Recovery Ladder" heading present.
  - `diff -q` between the two copies reports no difference.

---

### Phase 5: Align error-handling.md Build Error Recovery with fix-forward language [NOT STARTED]

- **Goal:** Replace the ambiguous "Keep source unchanged" line with explicit fix-forward +
  no-discard guidance and a cross-reference to recovery.md and git-workflow.md.
- **Tasks:**
  - [ ] In the "### Build Error Recovery" block (deployed lines ~82-87), replace step 3 "Keep
    source unchanged" with: "Fix forward: correct the source to resolve the error. Never discard
    uncommitted changes to reach a passing build - see .claude/context/contracts/recovery.md for
    the full recovery ladder (fix forward -> strategic-sorry skeleton -> snapshot-then-rollback)
    and the 'No Destructive Git on Uncommitted Work' rule in git-workflow.md."
  - [ ] Apply the identical edit to the core copy.
  - [ ] Keep wording narrowly scoped (do not license large speculative changes); preserve the
    original no-silent-patch intent.
- **Timing:** 0.25 hour
- **Depends on:** 1

- **Files to modify:**
  - `.claude/rules/error-handling.md` - reword Build Error Recovery
  - `.claude/extensions/core/rules/error-handling.md` - identical
- **Verification:**
  - `grep -c "Fix forward"` on both copies returns >= 1; "Keep source unchanged" no longer present.
  - `diff -q` between the two copies reports no difference.

---

### Phase 6: Cross-file verification and consistency check [NOT STARTED]

- **Goal:** Confirm all edits landed, all dual copies are consistent, and the disambiguated phrasing
  is now the default everywhere it should appear.
- **Tasks:**
  - [ ] `diff -q` each dual pair (skill-orchestrate-hard, general-implementation-hard-agent,
    error-handling.md) - expect no difference; for skill-implementer-hard, confirm the
    recovery-reference lines match in both copies.
  - [ ] `grep -rn "contracts/recovery.md"` across `.claude/` - confirm references from
    skill-orchestrate-hard, skill-implementer-hard, general-implementation-hard-agent, and
    error-handling.md (both copies each).
  - [ ] Validate index.json parses and the recovery.md entry is present.
  - [ ] Confirm no edits leaked into sibling-task sections (spot-review the CONTRACT SLOTS block,
    the implementer-hard reference list, and the agent Recovery Ladder section).
- **Timing:** 0.25 hour
- **Depends on:** 2, 3, 4, 5

- **Verification:**
  - All `diff -q` pairs clean (or reconciled for the implementer-hard touched region).
  - recovery.md referenced from all four consumer files.
  - index.json valid JSON with the new entry.

---

## Testing & Validation

- [ ] `python3 -c "import json; json.load(open('.claude/context/index.json'))"` succeeds and the
  recovery.md entry is present.
- [ ] `diff -q` clean for skill-orchestrate-hard, general-implementation-hard-agent, and
  error-handling.md dual pairs.
- [ ] skill-implementer-hard recovery-reference lines consistent across both copies.
- [ ] `grep -rn "contracts/recovery.md" .claude/` shows references from all four consumer files
  (both copies each).
- [ ] `grep "Recovery Discipline" ` present in both skill-orchestrate-hard copies.
- [ ] "Keep source unchanged" no longer present in either error-handling.md copy; "Fix forward"
  present in both.
- [ ] recovery.md contains the disambiguation statement and all three named rungs with real
  paths/commands.

## Artifacts & Outputs

- `.claude/context/contracts/recovery.md` (new contract file)
- `.claude/context/index.json` (updated: recovery.md contracts entry)
- `.claude/skills/skill-orchestrate-hard/SKILL.md` + core mirror (5th contract slot)
- `.claude/skills/skill-implementer-hard/SKILL.md` + core mirror (recovery.md reference)
- `.claude/agents/general-implementation-hard-agent.md` + core mirror (Context Ref + Recovery Ladder)
- `.claude/rules/error-handling.md` + core mirror (reworded Build Error Recovery)
- `specs/779_hardmode_fix_forward_recovery_contract/summaries/01_recovery-contract-fix-forward-summary.md` (on completion)

## Rollback/Contingency

All edits are additive documentation/prompt changes with no runtime code paths. If a change must be
reverted, apply fix-forward discipline first (per the very contract being authored): correct in
place. If a genuine rollback is required, snapshot first via `bash .claude/scripts/git-snapshot.sh`
then use the smallest revert scope (per-file). The new recovery.md is a standalone additive file
whose removal has no side effects beyond the four references pointing to it (which would then need
their added lines removed in the same revert). Because phases 2-5 touch disjoint files, any single
phase can be reverted independently without affecting the others.

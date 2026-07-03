# Implementation Plan: Harden Hard-Mode Research Verification (H4/H3)

- **Task**: 777 - Hard-mode research: more effort, higher quality and verification standards
- **Status**: [COMPLETED]
- **Effort**: ~7 hours
- **Dependencies**: None (companion to task 772 implementation leg, task 774 planning leg)
- **Research Inputs**: specs/777_hardmode_research_higher_standards/reports/01_hardmode_research_higher_standards.md
- **Artifacts**: plans/01_harden-research-verification.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md; artifact-formats.md; state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Strengthen `--hard` research so it is materially more rigorous than standard research by (1) creating a dedicated H4 contract file `adversarial-verification.md` (the one H-technique with no backing contract), (2) adding per-tier source-coverage minimums to the H3 `reference-grounding.md` contract, and (3) replacing the free-prose Stage 4.5 checklist duplicated across three research-hard agents with a pointer to the new contract plus a required, machine-checkable Claim Verification Table and Contradiction Log. Scope is hard-mode only: standard `skill-researcher` / `general-research-agent` and their contracts must not change. Definition of done: the new contract exists and is registered in the context index; all three research-hard agents (and both physical copies of the general agent) reference it and require the structured verification table; `skill-researcher-hard` lists the contract as MANDATORY; and every dual-copy file pair identified in research is updated in lockstep so nothing is lost on the next sync.

### Research Integration

Integrates report `01_hardmode_research_higher_standards.md`. Key findings applied:
- H4 is the only H-technique referenced by name (in `skill-researcher-hard`, `skill-orchestrate-hard`, and three agent files) with no `.claude/context/contracts/*.md` file — so the primary deliverable is that contract file (Recommendation 1).
- Enforceable contracts in this repo use structured tables/schemas (H2 Defect Bar, H9 handoff schema), not prose; the new contract mirrors that with a Claim Verification Bar, Confidence Level Taxonomy, and Contradiction Resolution Protocol (Recommendation 1).
- Source-coverage minimums belong in H3 `reference-grounding.md` (tier-dependent), cross-referenced from H4 (Recommendation 2, Decision 2).
- Research dispatch has NO orchestrator-side contract injection (`build_hard_mode_prompt_context` is implementation-only), so the agent-file + contract-file reading path is the only viable enforcement surface (Decision 4).
- Dual-copy / drift risk: enumerated file pairs must be updated together (Risks section of report).

### Prior Plan Reference

No prior plan. This is the first plan for task 777.

### Roadmap Alignment

No `roadmap_path` provided to this planning invocation and no ROADMAP.md consulted. Task 777 is self-described as the research leg of the three-leg `--hard` strengthening effort (772 implementation, 774 planning); this plan does not modify those sibling tasks.

## Dual-Copy / Canonical-Source Map

Several target files exist in BOTH a deployed `.claude/` copy AND a canonical extension-source copy. Verified during planning:

| Logical change | Files that MUST be edited together | Notes |
|----------------|------------------------------------|-------|
| New H4 contract | `.claude/context/contracts/adversarial-verification.md` (canonical; git-tracked directly, not provided by core ext) + `.claude/extensions/lean/context/contracts/adversarial-verification.md` (lean parity copy) | Lean bundles its own copies of the other two contracts; add a parity copy so lean-only deployments retain H4. Runtime `@`-reference resolves to the `.claude/context/contracts/` copy. |
| H3 coverage minimums | `.claude/context/contracts/reference-grounding.md` + `.claude/extensions/lean/context/contracts/reference-grounding.md` | The two copies already DIFFER (lean variant); apply the coverage subsection to each, adapting to its existing structure. |
| Index registration | `.claude/context/index.json` (git-tracked, canonical for core contract entries) + `.claude/extensions/lean/index-entries.json` (lean already carries anti-analysis + reference-grounding entries) | No generate-index script exists; index.json is maintained directly. Validate with `validate-index.sh` / `validate-context-index.sh`. |
| General agent Stage 4.5 | `.claude/agents/general-research-hard-agent.md` + `.claude/extensions/core/agents/general-research-hard-agent.md` | Currently byte-identical; keep in sync. |
| cslib agent Stage 4.5 | `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` | `.claude/agents/cslib-research-hard-agent.md` is a SYMLINK to this file — editing the extension file updates both automatically. |
| lean agent Stage 4.5 | `.claude/extensions/lean/agents/lean-research-hard-agent.md` | Single file; no deployed `.claude/agents/` copy. |
| skill Context References | `.claude/skills/skill-researcher-hard/SKILL.md` + `.claude/extensions/core/skills/skill-researcher-hard/SKILL.md` | The two copies DIFFER; apply the same Context-References addition to each. |
| (Optional) orchestrate-hard gate | `.claude/skills/skill-orchestrate-hard/SKILL.md` + `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` | Both contain the structural grep gate. |

## Goals & Non-Goals

**Goals**:
- Create `.claude/context/contracts/adversarial-verification.md` (H4) with a Claim Verification Bar, Confidence Level Taxonomy, Contradiction Resolution Protocol, Forbidden Verification Outputs, and a Domain Specialization section.
- Add per-tier source-coverage minimums (no single-source conclusions) to `reference-grounding.md` (H3).
- Replace the duplicated Stage 4.5 prose in all three research-hard agents with a contract pointer + a required Claim Verification Table and Contradiction Log.
- Add the contract to `skill-researcher-hard` Context References as MANDATORY.
- Register the new contract in the context index.
- Keep every dual-copy file pair in sync so no change is lost on sync.

**Non-Goals**:
- No changes to standard (non-hard) research skill/agent or their contracts.
- No new orchestrator-side research-dispatch injection mechanism (Decision 4: not needed).
- No script-level hard-enforcement in `validate-artifact.sh` beyond an optional non-blocking grep (kept minimal; primary enforcement is agent self-compliance + existing structural gate).
- No behavioral change to how planning (774) or implementation (772) legs work.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A dual-copy pair updated on only one side, silently lost on next sync | H | M | Phase 7 runs a grep-based parity sweep across every pair in the Dual-Copy Map; each editing phase updates both copies before the phase is marked complete. |
| Stricter contradiction-resolution causes agent stall (mini analysis-paralysis) | M | L | Contract explicitly permits `UNRESOLVED CONTRADICTION` as a valid terminal state when risk + next-check are stated (report Risks mitigation). |
| Contract diverges from the H2 template it is meant to mirror | M | L | Author `adversarial-verification.md` by structural analogy to `anti-analysis.md` (same section-type layout: bar, taxonomy, forbidden list, domain specialization). |
| Domain agents lose their existing specialization (cslib BibKey, lean `lean_hover_info`) during the rewrite | M | M | Preserve domain verification mechanics as the "Verification Method" column content, not as deleted logic (report Recommendation 4). |
| index.json edit breaks JSON / fails validation | M | L | Validate with `validate-index.sh` and `validate-context-index.sh` after the edit; mirror the exact structure of the existing `anti-analysis.md` entry. |
| Cross-reference between H4 and H3 points at a non-existent anchor | L | M | Sequence H3 (Phase 1) before H4 (Phase 2) so the contract references the finalized coverage-subsection heading. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5, 6 | 2 |
| 4 | 7 | 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Add source-coverage minimums to H3 reference-grounding.md [COMPLETED]

- **Goal:** Add a per-tier "Source-Coverage Minimums" subsection to the H3 contract forbidding single-source conclusions, in both the canonical and lean copies.
- **Tasks:**
  - [ ] Read `.claude/context/contracts/reference-grounding.md` to locate the three-tier structure and pick a stable heading anchor for the new subsection (e.g. `## Source-Coverage Minimums`).
  - [ ] Add Tier 1 rule: primary source citation mandatory; for safety/design-critical claims a second corroborating source (another passage or paper) is required — no single-passage conclusions for load-bearing theorems.
  - [ ] Add Tier 2 rule: official docs is the minimum; if official docs are ambiguous or silent, a second independent source (changelog, source code, or a second doc page) is required before concluding — single-page/single-search conclusions forbidden.
  - [ ] Add Tier 3 rule: reading an implementation without checking its test suite is insufficient; both required.
  - [ ] Add a tier-agnostic codebase-pattern rule (relevant to `meta` research): a "X is the convention" claim requires confirmation at 2+ independent call sites/files, not one.
  - [ ] Apply the same subsection (adapted to its existing structure) to `.claude/extensions/lean/context/contracts/reference-grounding.md`.
  - [ ] Note the new subsection heading for cross-reference by Phase 2.
- **Timing:** ~1 hour
- **Depends on:** none
- **Files to modify:**
  - `.claude/context/contracts/reference-grounding.md` — add Source-Coverage Minimums subsection
  - `.claude/extensions/lean/context/contracts/reference-grounding.md` — mirror subsection
- **Verification:**
  - `grep -n "Source-Coverage Minimums" .claude/context/contracts/reference-grounding.md .claude/extensions/lean/context/contracts/reference-grounding.md` returns a hit in both files.
  - Both files still describe the three tiers coherently (manual read).

### Phase 2: Create H4 contract adversarial-verification.md [COMPLETED]

- **Goal:** Create the dedicated H4 contract file mirroring the `anti-analysis.md` structure, plus a lean parity copy.
- **Tasks:**
  - [ ] Read `.claude/context/contracts/anti-analysis.md` as the structural template (Read Budget / Forbidden Conclusions / Defect Bar / Domain Specialization layout).
  - [ ] Create `.claude/context/contracts/adversarial-verification.md` with these sections:
    - [ ] **Claim Verification Bar** (4-element, modeled on H2 Defect Bar): a load-bearing claim ships as VERIFIED only when ALL of (a) claim stated verbatim, (b) concrete source quoted/cited OR a tested counterexample, (c) verification method named, (d) confidence level assigned. Missing any element downgrades to UNVERIFIED and must be caveated, not presented as settled.
    - [ ] **Confidence Level Taxonomy**: High (2+ independent sources agree, or a directly-read authoritative source with no conflicting evidence), Medium (single authoritative source, not cross-checked; or pattern in only one location), Low (inferred from convention, not directly verified). Every load-bearing claim carries one tag.
    - [ ] **Contradiction Resolution Protocol**: when independent sources disagree, attempt resolution via precedence (official docs > community; current code > stale docs/comments; test-suite behavior > assumed behavior — reusing H3's Authoritative resolution ranking) BEFORE writing the finding. Only if resolution genuinely fails may the report state `UNRESOLVED CONTRADICTION: <A> vs <B>` with stated downstream risk and the further check that would resolve it.
    - [ ] **Forbidden Verification Outputs** (modeled on H2 Forbidden Conclusions): "sources agree" without naming which; "well documented"/"commonly known" without citation; "no conflicting information found" without stating what was searched and how many independent sources; a contradiction noted with no resolution attempt.
    - [ ] **Domain Specialization**: note where cslib BibKey verification and lean `lean_hover_info`-confirmed type signatures plug in as domain-specific "Verification Method" values under the shared bar.
    - [ ] Cross-reference the H3 Source-Coverage Minimums subsection created in Phase 1 (use its finalized heading).
  - [ ] Create `.claude/extensions/lean/context/contracts/adversarial-verification.md` as a parity copy (mirroring core; lean domain note may be inlined) so lean-only deployments retain the contract.
- **Timing:** ~1.5 hours
- **Depends on:** 1
- **Files to modify:**
  - `.claude/context/contracts/adversarial-verification.md` — new file
  - `.claude/extensions/lean/context/contracts/adversarial-verification.md` — new parity file
- **Verification:**
  - Both files exist and contain the headings: `Claim Verification Bar`, `Confidence Level Taxonomy`, `Contradiction Resolution Protocol`, `Forbidden Verification Outputs`.
  - `grep -n "Source-Coverage Minimums" .claude/context/contracts/adversarial-verification.md` confirms the H3 cross-reference resolves to a real heading.

### Phase 3: Register the contract in the context index [COMPLETED]

- **Goal:** Add an index entry for the new contract so it loads for the three research-hard agents, mirroring the `anti-analysis.md` entry.
- **Tasks:**
  - [ ] Add an entry to `.claude/context/index.json` for `contracts/adversarial-verification.md` with `subdomain: "contracts"`, `domain: "core"`, keywords (`adversarial-verification`, `claim-verification-bar`, `confidence-taxonomy`, `contradiction-resolution`, `hard-mode`, `H4`), topics (`hard-mode`, `adversarial-verification`, `contracts`, `research`), a summary, an accurate `line_count`, and `load_when.agents: ["general-research-hard-agent", "cslib-research-hard-agent", "lean-research-hard-agent"]`.
  - [ ] Add a matching entry to `.claude/extensions/lean/index-entries.json` (lean already lists anti-analysis + reference-grounding contract entries) so the entry survives an index rebuild from extension sources.
  - [ ] Run `bash .claude/scripts/validate-index.sh` and `bash .claude/scripts/validate-context-index.sh` (and `validate-extension-index.sh` for the lean entry); resolve any reported issues.
- **Timing:** ~0.5 hour
- **Depends on:** 2
- **Files to modify:**
  - `.claude/context/index.json` — add adversarial-verification entry
  - `.claude/extensions/lean/index-entries.json` — mirror entry
- **Verification:**
  - `jq '.entries[] | select(.path == "contracts/adversarial-verification.md")' .claude/context/index.json` returns the entry with the three-agent `load_when.agents` list.
  - The context-index query for `general-research-hard-agent` (per CLAUDE.md Context Discovery snippet) now lists `contracts/adversarial-verification.md`.
  - Validation scripts exit 0.

### Phase 4: Rewrite general-research-hard-agent Stage 4.5 + skill-researcher-hard Context References [COMPLETED]

- **Goal:** Point the general agent (both copies) and the skill (both copies) at the new contract and require the structured verification table.
- **Tasks:**
  - [ ] In `.claude/agents/general-research-hard-agent.md`: add `@.claude/context/contracts/adversarial-verification.md` to `## Context References` as MANDATORY; replace the ad hoc Stage 4.5 checklist prose with an instruction to read the contract and internalize the Claim Verification Bar, Confidence Level Taxonomy, and Contradiction Resolution Protocol.
  - [ ] In Stage 3 of the same agent, add a no-single-source-conclusion rule cross-referencing the H3 coverage minimums ("do not proceed to Stage 4 synthesis with a load-bearing claim backed by only one source; run at least one cross-checking search/read first").
  - [ ] In Stage 4.5 of the same agent, make a required **Claim Verification Table** (`| Claim | Source/Counterexample | Verification Method | Confidence |`) the primary artifact of the stage, plus a **Contradiction Log** subsection (present only when contradictions were found).
  - [ ] Apply the byte-identical edits to `.claude/extensions/core/agents/general-research-hard-agent.md`.
  - [ ] In `.claude/skills/skill-researcher-hard/SKILL.md`: add `.claude/context/contracts/adversarial-verification.md` to `## Context References` as MANDATORY alongside anti-analysis.md and reference-grounding.md.
  - [ ] Apply the same Context-References addition to `.claude/extensions/core/skills/skill-researcher-hard/SKILL.md` (note: the two skill copies DIFFER; edit the corresponding section in each).
- **Timing:** ~1.5 hours
- **Depends on:** 2
- **Files to modify:**
  - `.claude/agents/general-research-hard-agent.md`
  - `.claude/extensions/core/agents/general-research-hard-agent.md`
  - `.claude/skills/skill-researcher-hard/SKILL.md`
  - `.claude/extensions/core/skills/skill-researcher-hard/SKILL.md`
- **Verification:**
  - `diff .claude/agents/general-research-hard-agent.md .claude/extensions/core/agents/general-research-hard-agent.md` reports no differences (still identical after edit).
  - `grep -n "adversarial-verification.md" .claude/agents/general-research-hard-agent.md .claude/skills/skill-researcher-hard/SKILL.md .claude/extensions/core/skills/skill-researcher-hard/SKILL.md` hits all three (four) files.
  - `grep -n "| Claim | Source/Counterexample | Verification Method | Confidence |" .claude/agents/general-research-hard-agent.md` confirms the table header is present.

### Phase 5: Rewrite Stage 4.5 in cslib and lean research-hard agents [COMPLETED]

- **Goal:** Replace the duplicated Stage 4.5 prose in the domain agents with the contract pointer + Claim Verification Table, preserving each agent's domain verification method.
- **Tasks:**
  - [ ] In `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (deployed `.claude/agents/cslib-research-hard-agent.md` is a symlink — no separate edit): add the contract to `## Context References` as MANDATORY; replace the Stage 4.5 checklist with the contract pointer + required Claim Verification Table + Contradiction Log; keep the cslib BibKey / reuse-completeness / zero-debt specializations as "Verification Method" column content and any domain-specific rows.
  - [ ] In `.claude/extensions/lean/agents/lean-research-hard-agent.md`: same rewrite, preserving the lean `lean_hover_info`-confirmed type-signature specialization as "Verification Method" content.
  - [ ] Ensure both domain agents add the Stage 3 no-single-source-conclusion rule consistent with the general agent.
- **Timing:** ~1.5 hours
- **Depends on:** 2
- **Files to modify:**
  - `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (updates the symlinked deployed copy too)
  - `.claude/extensions/lean/agents/lean-research-hard-agent.md`
- **Verification:**
  - `grep -n "adversarial-verification.md" .claude/extensions/cslib/agents/cslib-research-hard-agent.md .claude/extensions/lean/agents/lean-research-hard-agent.md` hits both.
  - `grep -n "| Claim | Source/Counterexample" .claude/extensions/cslib/agents/cslib-research-hard-agent.md .claude/extensions/lean/agents/lean-research-hard-agent.md` confirms the table in both.
  - Domain specializations (`BibKey`, `lean_hover_info`) still present via grep.
  - `readlink .claude/agents/cslib-research-hard-agent.md` confirms the symlink still points at the edited extension file.

### Phase 6: (Optional/secondary) Strengthen the orchestrate-hard H4 gate [COMPLETED]

- **Goal:** Optionally upgrade the structural grep gate so it also checks for the Claim Verification Table header, in both copies. Lower priority; the task's core goals are met without it.
- **Tasks:**
  - [ ] In `.claude/skills/skill-orchestrate-hard/SKILL.md`, extend the `grep -q "## Adversarial Self-Verification"` gate (State `researched`) to also require the table header (e.g. an additional non-fatal `grep -q "| Claim | Source/Counterexample"`), preserving current pass/dispatch-on-fail behavior.
  - [ ] Apply the identical change to `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`.
  - [ ] If, during implementation, this is judged out of the task's literal hard-mode-research scope, mark this phase [ABANDONED] with a one-line rationale rather than forcing the change.
- **Timing:** ~0.5 hour
- **Depends on:** 2
- **Files to modify:**
  - `.claude/skills/skill-orchestrate-hard/SKILL.md`
  - `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
- **Verification:**
  - `grep -n "Claim | Source/Counterexample" .claude/skills/skill-orchestrate-hard/SKILL.md .claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` hits both (if implemented).
  - Both copies remain structurally identical in the gate block (`diff` of the relevant region).

### Phase 7: Verification and dual-copy parity sweep [COMPLETED]

- **Goal:** Confirm every dual-copy pair is in sync, the contract is discoverable, and no standard-research file was touched.
- **Tasks:**
  - [ ] Run the parity checks from the Dual-Copy Map: `diff` the two general-agent copies (must be identical); confirm the cslib deployed path is still a symlink; confirm `adversarial-verification.md` exists in both the canonical and lean contract dirs.
  - [ ] `grep -rn "adversarial-verification" .claude/` and confirm every intended consumer (skill x2, general agent x2, cslib, lean, index.json, lean index-entries) references it and nothing else was missed.
  - [ ] Confirm NO standard-mode files changed: `git status` shows no edits to `general-research-agent.md`, `skill-researcher`, or standard contracts.
  - [ ] Run `bash .claude/scripts/validate-index.sh` and `validate-context-index.sh` a final time.
  - [ ] Optionally run `bash .claude/scripts/check-extension-docs.sh` to confirm no extension doc-lint regressions from the lean additions.
  - [ ] Re-read `adversarial-verification.md` and one agent Stage 4.5 to confirm the Claim Verification Bar, taxonomy, and table are internally consistent and the H3 cross-reference resolves.
- **Timing:** ~1 hour
- **Depends on:** 3, 4, 5, 6
- **Files to modify:** none (verification only)
- **Verification:**
  - All parity diffs report expected results (identical where required, both-present where required).
  - Validation scripts exit 0.
  - `git status` confirms scope is hard-mode-only.

## Testing & Validation

- [ ] `jq '.entries[] | select(.path == "contracts/adversarial-verification.md")' .claude/context/index.json` returns a well-formed entry.
- [ ] `bash .claude/scripts/validate-index.sh` and `bash .claude/scripts/validate-context-index.sh` exit 0.
- [ ] Context-discovery query for each of the three research-hard agents includes `contracts/adversarial-verification.md`.
- [ ] All three research-hard agents contain the Claim Verification Table header and a contract reference (grep).
- [ ] The two `general-research-hard-agent.md` copies are byte-identical (`diff` empty).
- [ ] Both `skill-researcher-hard/SKILL.md` copies list the contract in Context References.
- [ ] H3 `reference-grounding.md` (both copies) contains the Source-Coverage Minimums subsection.
- [ ] `git status` shows zero changes to standard-mode research files/contracts.

## Artifacts & Outputs

- `.claude/context/contracts/adversarial-verification.md` (new)
- `.claude/extensions/lean/context/contracts/adversarial-verification.md` (new, parity)
- `.claude/context/contracts/reference-grounding.md` (edited) + lean copy
- `.claude/context/index.json` (edited) + `.claude/extensions/lean/index-entries.json` (edited)
- `.claude/agents/general-research-hard-agent.md` + `.claude/extensions/core/agents/general-research-hard-agent.md` (edited)
- `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (edited; symlink-shared)
- `.claude/extensions/lean/agents/lean-research-hard-agent.md` (edited)
- `.claude/skills/skill-researcher-hard/SKILL.md` + `.claude/extensions/core/skills/skill-researcher-hard/SKILL.md` (edited)
- Optional: both `skill-orchestrate-hard/SKILL.md` copies (edited)
- `specs/777_hardmode_research_higher_standards/summaries/01_harden-research-verification-summary.md` (on completion)

## Rollback/Contingency

- All changes are additive edits to `.claude/` markdown/JSON plus two new files; revert with `git checkout -- <paths>` / `git clean` for the new files. No build artifacts or state migrations are involved.
- If the index.json edit fails validation and cannot be quickly fixed, revert only `.claude/context/index.json` and `.claude/extensions/lean/index-entries.json`; the contract file and agent edits remain valid (agents read the contract via `@`-path regardless of index registration, which affects only auto-load discovery).
- Phase 6 is optional: if it risks scope creep or breaks the orchestrate-hard gate, mark it [ABANDONED] and ship Phases 1-5 + 7, which fully satisfy the task's stated goals.

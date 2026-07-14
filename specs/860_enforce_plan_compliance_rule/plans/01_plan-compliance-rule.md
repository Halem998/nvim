# Implementation Plan: Task #860

- **Task**: 860 - enforce_plan_compliance_rule
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: `specs/860_enforce_plan_compliance_rule/reports/01_plan-compliance-rule.md`
- **Artifacts**: plans/01_plan-compliance-rule.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author a new, concise, firm rule enforcing strict plan compliance for agents editing formal
proof files, bind it by glob (`**/*.lean`) rather than by agent name, and — critically —
register it in the `lean` extension's `manifest.json` `provides.rules` array so it actually
propagates to consuming repos. The research established that registration, not file placement,
is the load-bearing step; a rule dropped into a `rules/` directory without a manifest entry
silently fails to sync. Work is four serial phases: author the rule, register it, update the
extension's documentation surfaces, then prove propagation end-to-end.

### Research Integration

The research report is authoritative and its findings are adopted wholesale. Key integrations:

- **Glob** (`paths: "**/*.lean"`, bare-string frontmatter) reuses the exact precedent at
  `.claude/extensions/lean/rules/lean4.md:2` and `.claude/extensions/cslib/rules/cslib.md:2`.
  `Theories/**` appears nowhere in `.claude/` and is explicitly rejected as non-portable.
- **Bind by role via glob, not agent name.** `lean-implementation-agent` is extension-source
  only in this repo; enumerating agent names would create a maintenance liability and bind to
  names that may not exist in a given consumer. The glob attaches the rule to whichever agent
  touches a `.lean` file.
- **Registration gap is a live, observed bug, not a theoretical one** (see Phase 4 evidence).
- **Overlap handling**: the rule narrows the sanctioned "Plan Deviations" mechanism
  (`.claude/agents/general-implementation-agent.md:180-186`,
  `.claude/agents/cslib-implementation-agent.md:99-104`) for `.lean` files only, and
  cross-references — but does not duplicate — Literature Fidelity (`lean4.md` §Literature
  Fidelity) and H2 anti-analysis (`.claude/context/contracts/anti-analysis.md`, `--hard`-only).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found. No roadmap phases included.

## Resolved Decisions

The research deliberately left extension placement open. Both open decisions are resolved here
against verified evidence, not assumption.

### Decision 1: Place the rule in the `lean` extension

**Chosen**: canonical source at `.claude/extensions/lean/rules/plan-compliance.md`, registered
in `.claude/extensions/lean/manifest.json` → `provides.rules`.

**Rejected**: `.claude/extensions/core/rules/` and `.claude/extensions/cslib/rules/`.

**Evidence gathered during planning** (every Lean-consuming repo on disk loads `lean` active):

| Consuming repo | `lean` active? | `cslib` active? | `lean4.md` in live `.claude/rules/`? |
|----------------|----------------|-----------------|--------------------------------------|
| `~/Projects/BimodalLogic` | yes | no | **yes** |
| `~/Projects/cslib` | yes | yes | (lean active) |
| `~/Projects/theorem_proving_in_lean4` | yes | no | (lean active) |

**Rationale**:
1. **Reach is proven, not assumed.** `lean4.md` is registered in lean's `provides.rules` and is
   physically present in BimodalLogic's live `.claude/rules/`. The exact mechanism this rule
   needs is already demonstrably working for a sibling file in the same directory.
2. **`cslib` gets it transitively.** `.claude/extensions/cslib/manifest.json` declares
   `"dependencies": ["core", "lean", "literature"]`, so any repo loading `cslib` auto-loads
   `lean`. A lean-scoped rule reaches `cslib`-consuming repos with no extra registration.
3. **Core placement would ship a dead rule.** The glob `**/*.lean` is inert outside Lean repos.
   Core is loaded by every consumer (including this nvim repo, `~/Projects/Literature`, etc.),
   none of which contain `.lean` files. Scoping to `lean` keeps the rule where it can fire.
4. **`cslib` placement would under-reach.** BimodalLogic — the repo whose failure history
   motivates this rule — does **not** load `cslib`. Placing it there would miss the primary
   intended consumer entirely.

### Decision 2: No live `.claude/rules/` copy, no `.claude/CLAUDE.md` edit

**No live copy.** This repo's active extensions are `nvim, filetypes, core, nix, memory,
literature` — `lean` is **not** active here, and this repo contains no `.lean` files. Writing
`.claude/rules/plan-compliance.md` directly would forge a deployment artifact the extension
loader did not produce, creating exactly the orphaned-file drift the research flagged around the
stale `cslib-*-agent.md` files. The loader copies extension rules into `.claude/rules/` on load;
that is its job, not the implementer's.

**No `.claude/CLAUDE.md` edit.** `.claude/CLAUDE.md` is generated (its own header: "This file is
generated automatically from loaded extensions. Do not edit directly"), and
`.claude/extensions/core/hooks/validate-meta-write.sh` guards writes to it. Its "Rules
References" section is sourced from `.claude/extensions/core/merge-sources/claudemd.md:441-452`
and lists **core** rules only, closing with: "**Extension Rules**: When extensions are loaded,
additional rules are added." A lean-scoped rule is covered by that existing note; adding it to
the core fragment would wrongly advertise a core rule.

**The correct CLAUDE.md surface is lean's own fragment.** `.claude/extensions/lean/manifest.json`
declares `merge_targets.claudemd = {source: "EXTENSION.md", target: ".claude/CLAUDE.md",
section_id: "extension_lean"}`. So `EXTENSION.md` **is** the lean CLAUDE.md source; editing it
(Phase 3) is the sanctioned, regeneration-safe way to surface the rule in consuming repos'
CLAUDE.md — mirroring how the nvim extension surfaces `neovim-lua.md` under a `### Rules`
heading.

### Decision 3: Deliberate, documented deviation from the literal task description

Requirement (5) of the task description asks the rule to "Reference the repeated failures in
BimodalLogic task 157 (8 plan versions, agents diverging every time) as motivation."

**The implementation will NOT do this literally.** `.claude/rules/no-task-references-in-
deliverables.md` prohibits task-number citations in any deliverable outside `specs/**`, and a
rule file under `.claude/extensions/lean/rules/` is precisely such a deliverable. Complying
literally with (5) would put the new rule in immediate violation of an existing rule — and the
cited number is exactly the kind of ephemeral identifier that vault renumbering invalidates.

**Substitute**: preserve the full substantive motivation via durable-anchor phrasing — repeated
plan-divergence across many successive plan versions in a formal-proof repository, where each
implementation dispatch re-derived its own decomposition instead of executing the existing
plan — with no task number. The motivation survives intact; only the renumbering-fragile
identifier is dropped. This deviation is deliberate, and this section is its documentation.

## Goals & Non-Goals

**Goals**:
- A concise, firm rule that treats the plan as a contract, covering task-description
  requirements (1), (2), and (3) verbatim in its forbidden-patterns list.
- Portable glob binding (`**/*.lean`) that generalizes across consuming repos — requirement (4).
- Requirement (5)'s motivation preserved via durable anchor, no task number.
- Manifest registration that demonstrably propagates, verified end-to-end.
- Explicit statement of the rule's interaction with the "Plan Deviations" mechanism, and
  cross-references to Literature Fidelity and H2 as adjacent-but-distinct.

**Non-Goals**:
- Fixing the pre-existing `pr-prohibition.md` / `no-task-references-in-deliverables.md` core
  registration gaps (research recommends a separate follow-up meta task; used here only as a
  counterexample fixture).
- Fixing the stale/orphaned `cslib-*-agent.md` files in this repo's live `.claude/agents/`.
- Editing `.claude/rules/`, `.claude/CLAUDE.md`, or core's `claudemd.md` (see Decision 2).
- Modifying `lean4.md`, agent definitions, or the Plan Deviations mechanism itself. The new
  rule narrows that mechanism by its own text and glob scope; the general policy stays intact
  for non-`.lean` files.
- Deploying/loading the `lean` extension in this repo.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rule authored but not registered → silently never propagates (the `pr-prohibition.md` failure mode) | H | M | Phase 2 `jq` assertion + Phase 4 disk-vs-manifest reconciliation over all lean rules |
| Rule cites a task number, violating `no-task-references-in-deliverables.md` | M | M | Decision 3 above; Phase 1 grep assertion greps for `task [0-9]` and fails on any hit |
| Rule reads as contradicting the sanctioned Plan Deviations mechanism | M | M | Mandatory `## Relationship to Plan Deviations` section; Phase 1 grep asserts its presence |
| Rule bloats into a duplicate of Literature Fidelity | M | L | Phase 1 line-count ceiling (100 lines) + cross-reference-not-restate instruction |
| Glob hard-codes one repo's layout | H | L | `paths: "**/*.lean"` verbatim; Phase 1 asserts the exact string and asserts absence of `Theories` |
| Doc-lint regression from README/manifest drift | L | M | Phase 3 updates README tree; Phase 2 and 4 run `check-extension-docs.sh` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |

Phases within the same wave can execute in parallel. This plan is intentionally serial: each
phase's verification depends on the prior phase's artifact existing.

---

### Phase 1: Author the rule file [COMPLETED]

**Goal**: Create the canonical rule source with correct glob, firm tone, and no task-number
citation.

**Tasks**:
- [x] Create `.claude/extensions/lean/rules/plan-compliance.md` *(completed)*
- [x] Frontmatter: exactly `paths: "**/*.lean"` (bare-string form, matching `lean4.md:2`) *(completed)*
- [x] `## Path Pattern` prose section: `Applies to: **/*.lean` *(completed)*
- [x] `## Core Principle`: plan-as-contract framing — when a plan exists, it is the contract;
      the agent executes it, it does not re-derive it *(completed)*
- [x] `## Forbidden Patterns`: cover task requirements (1)-(3) verbatim — "assessing what's
      truly minimal", inventing alternative approaches when a plan exists, skipping
      intermediate theorems, inlining proofs instead of following the plan's decomposition,
      routing through different helper lemmas than specified, "cleaner approach"
      rationalizations *(completed)*
- [x] `## Required Behavior`: follow the plan's exact task sequence step-by-step, in order *(completed)*
- [x] `## Relationship to Plan Deviations`: state that for files matching this glob, the
      skip/alter/defer annotation mechanism in `general-implementation-agent.md` /
      `cslib-implementation-agent.md` is NOT a substitute for compliance — a would-be
      deviation must be raised as a blocker, not silently annotated and passed *(completed)*
- [x] `## Related Context`: cross-reference `lean4.md` §Literature Fidelity (follow the
      *source*) and `anti-analysis.md` (pace/output, `--hard`-only) as adjacent-but-distinct;
      note this rule applies unconditionally, not gated behind `--hard` *(completed)*
- [x] Motivation via durable anchor per Decision 3 — no task number, no repo-specific number *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/rules/plan-compliance.md` - new file (canonical source)

**Verification**:
```bash
cd /home/benjamin/.config/nvim
F=.claude/extensions/lean/rules/plan-compliance.md
test -f "$F" || { echo "FAIL: rule file missing"; exit 1; }
# Exact glob, matching lean4.md precedent
grep -qx 'paths: "\*\*/\*\.lean"' "$F" || { echo "FAIL: frontmatter glob wrong"; exit 1; }
grep -q '^Applies to: \*\*/\*\.lean' "$F" || { echo "FAIL: Path Pattern prose missing"; exit 1; }
# No hard-coded repo layout
grep -q 'Theories' "$F" && { echo "FAIL: hard-codes Theories/"; exit 1; }
# No task-number citation (no-task-references-in-deliverables.md)
grep -Ein 'task[ -]+[0-9]+|tasks[ -]+[0-9]+' "$F" && { echo "FAIL: task-number citation"; exit 1; }
# Required sections
for s in "## Path Pattern" "## Core Principle" "## Forbidden Patterns" \
         "## Required Behavior" "## Relationship to Plan Deviations"; do
  grep -qF "$s" "$F" || { echo "FAIL: missing section: $s"; exit 1; }
done
# Requirement (3) divergence patterns present
for p in "truly minimal" "intermediate theorem" "inlin" "helper lemma" "cleaner approach"; do
  grep -qi "$p" "$F" || { echo "FAIL: missing banned pattern: $p"; exit 1; }
done
# Concise but firm: within observed rule length band
L=$(wc -l < "$F"); [ "$L" -ge 40 ] && [ "$L" -le 100 ] || { echo "FAIL: length $L outside 40-100"; exit 1; }
echo "PASS: Phase 1"
```

---

### Phase 2: Register the rule in the lean manifest [COMPLETED]

**Goal**: Make the rule actually propagate. This is the load-bearing phase.

**Tasks**:
- [x] Add `"plan-compliance.md"` to `.claude/extensions/lean/manifest.json` →
      `provides.rules` (currently `["lean4.md"]`) *(completed)*
- [x] Preserve JSON formatting/indentation consistent with the file's existing style *(completed)*
- [x] Run the doc-lint script and confirm no new failures *(completed: exit 0, only pre-existing
      "extension not installed" WARNs, no new FAILs)*

**Timing**: 20 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/lean/manifest.json` - append to `provides.rules` array

**Verification**:
```bash
cd /home/benjamin/.config/nvim
M=.claude/extensions/lean/manifest.json
jq -e . "$M" >/dev/null || { echo "FAIL: manifest is not valid JSON"; exit 1; }
# The new rule is registered
jq -e '.provides.rules | index("plan-compliance.md")' "$M" >/dev/null \
  || { echo "FAIL: plan-compliance.md not in provides.rules"; exit 1; }
# Pre-existing entry not clobbered
jq -e '.provides.rules | index("lean4.md")' "$M" >/dev/null \
  || { echo "FAIL: lean4.md registration lost"; exit 1; }
# Doc-lint: manifest entries must exist on disk (check-extension-docs.sh:98-101)
bash .claude/scripts/check-extension-docs.sh || { echo "FAIL: doc-lint"; exit 1; }
echo "PASS: Phase 2"
```

---

### Phase 3: Update lean extension documentation surfaces [COMPLETED]

**Goal**: Surface the rule in the CLAUDE.md fragment consuming repos actually receive, and keep
the README tree accurate.

**Tasks**:
- [x] Add a `### Rules` entry to `.claude/extensions/lean/EXTENSION.md` naming
      `plan-compliance.md` with a one-line description and its glob — this is lean's
      `merge_targets.claudemd` source (`section_id: extension_lean`), so it lands in consuming
      repos' generated `.claude/CLAUDE.md`. Mirror the nvim extension's `### Rules` style.
      If `EXTENSION.md` already lists `lean4.md`, extend that list rather than duplicating it.
      *(completed: EXTENSION.md had no prior `### Rules` section at all, so a new one was added
      listing both `lean4.md` and `plan-compliance.md`, mirroring nvim's `### Rules` style)*
- [x] Update the directory tree in `.claude/extensions/lean/README.md` (around line 101, which
      currently lists only `lean4.md`) to include `plan-compliance.md` *(completed)*
- [x] Do NOT touch `.claude/CLAUDE.md`, `.claude/extensions/core/merge-sources/claudemd.md`,
      or `.claude/rules/` (Decision 2) *(completed — confirmed via `git log -- .claude/CLAUDE.md`
      that its only pre-existing uncommitted diff predates this task (task 855's unrelated
      registration edit); this phase's own commit touches none of these three paths)*

**Timing**: 25 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/lean/EXTENSION.md` - add rule to `### Rules` section (CLAUDE.md fragment)
- `.claude/extensions/lean/README.md` - add rule to directory tree

**Verification**:
```bash
cd /home/benjamin/.config/nvim
grep -q 'plan-compliance.md' .claude/extensions/lean/EXTENSION.md \
  || { echo "FAIL: rule not in EXTENSION.md (CLAUDE.md fragment)"; exit 1; }
grep -q 'plan-compliance.md' .claude/extensions/lean/README.md \
  || { echo "FAIL: rule not in README.md tree"; exit 1; }
# Guard Decision 2: no live copy, no generated-file edits
test -f .claude/rules/plan-compliance.md && { echo "FAIL: forged live copy"; exit 1; }
grep -q 'plan-compliance' .claude/extensions/core/merge-sources/claudemd.md \
  && { echo "FAIL: leaked into core claudemd fragment"; exit 1; }
git diff --name-only | grep -qx '.claude/CLAUDE.md' && { echo "FAIL: edited generated CLAUDE.md"; exit 1; }
bash .claude/scripts/check-extension-docs.sh || { echo "FAIL: doc-lint"; exit 1; }
echo "PASS: Phase 3"
```

---

### Phase 4: Prove propagation end-to-end [COMPLETED]

**Goal**: Demonstrate the rule will actually reach consuming repos — the step the research
flagged as load-bearing and the one `pr-prohibition.md` failed.

**Tasks**:
- [x] Reconcile disk vs manifest for the lean extension: every `.md` in
      `.claude/extensions/lean/rules/` must appear in `provides.rules`. This is the reverse
      direction of the doc-lint check (which only validates manifest→disk) and is exactly the
      bug class that stranded `pr-prohibition.md`. *(completed: both `lean4.md` and
      `plan-compliance.md` on disk are registered in `provides.rules` — reconciled, zero gap)*
- [x] Confirm the counterexample to prove the mechanism is real and understood:
      `pr-prohibition.md` exists in `.claude/extensions/core/rules/`, is absent from core's
      `provides.rules`, and is correspondingly **absent** from BimodalLogic's live
      `.claude/rules/` — while `lean4.md`, which **is** registered, is **present** there.
      *(completed: verified directly — `pr-prohibition.md` absent from core's provides.rules
      AND absent from `~/Projects/BimodalLogic/.claude/rules/`; `lean4.md` present there;
      `lean` extension status is `"active"` in BimodalLogic's `extensions.json`)*
- [x] Record the propagation conclusion in the implementation summary: registered lean rules
      land in `~/Projects/BimodalLogic/.claude/rules/` on extension load; `plan-compliance.md`
      now satisfies the same precondition as `lean4.md`. *(completed — see summary)*
- [x] Do NOT modify any consuming repo, and do NOT fix the `pr-prohibition.md` gap (Non-Goal;
      read-only observation used as a fixture). *(completed — no writes to
      `~/Projects/BimodalLogic/`, no edit to `pr-prohibition.md` or core's manifest)*

**Timing**: 20 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (verification-only phase; findings recorded in the implementation summary)

**Verification**:
```bash
cd /home/benjamin/.config/nvim
M=.claude/extensions/lean/manifest.json
# 1. Reverse check: every rule on disk is registered (the pr-prohibition.md bug class)
for f in .claude/extensions/lean/rules/*.md; do
  b=$(basename "$f")
  jq -e --arg b "$b" '.provides.rules | index($b)' "$M" >/dev/null \
    || { echo "FAIL: $b on disk but unregistered"; exit 1; }
done
# 2. Counterexample holds: unregistered core rule did NOT propagate to BimodalLogic
B=~/Projects/BimodalLogic/.claude
if [ -d "$B" ]; then
  jq -e '.provides.rules | index("pr-prohibition.md")' .claude/extensions/core/manifest.json >/dev/null \
    && echo "NOTE: core gap fixed elsewhere; counterexample no longer applies"
  test -f "$B/rules/pr-prohibition.md" \
    && echo "NOTE: unexpected - unregistered rule present downstream"
  # 3. Positive control: a REGISTERED lean rule DID propagate
  test -f "$B/rules/lean4.md" \
    || { echo "FAIL: positive control broken - registered lean4.md absent downstream"; exit 1; }
  jq -e '.extensions.lean.status == "active"' "$B/extensions.json" >/dev/null \
    || { echo "FAIL: lean not active in BimodalLogic - placement premise broken"; exit 1; }
  echo "PASS: propagation premise verified (lean active + registered lean rule present)"
fi
echo "PASS: Phase 4"
```

## Testing & Validation

- [x] `.claude/extensions/lean/rules/plan-compliance.md` exists, 40-100 lines, firm imperative
      tone consistent with sibling rules *(verified: 60 lines)*
- [x] Frontmatter is exactly `paths: "**/*.lean"`; no `Theories/` or other repo-specific layout
- [x] Zero task-number citations anywhere in the rule (`no-task-references-in-deliverables.md`)
- [x] All five required sections present, including `## Relationship to Plan Deviations`
- [x] All five requirement-(3) divergence patterns explicitly banned
- [x] `plan-compliance.md` present in lean's `provides.rules`; `lean4.md` still present
- [x] `bash .claude/scripts/check-extension-docs.sh` exits 0
- [x] No `.md` file in `.claude/extensions/lean/rules/` is unregistered
- [x] No live `.claude/rules/plan-compliance.md`; `.claude/CLAUDE.md` untouched *(this task's own
      commits do not touch `.claude/CLAUDE.md`; a pre-existing unrelated uncommitted diff from
      task 855 exists on that file independent of this task — see Phase 3 deviation note)*
- [x] BimodalLogic positive control passes (`lean` active, `lean4.md` present downstream)

## Artifacts & Outputs

- `.claude/extensions/lean/rules/plan-compliance.md` (new — canonical rule source)
- `.claude/extensions/lean/manifest.json` (modified — `provides.rules` registration)
- `.claude/extensions/lean/EXTENSION.md` (modified — CLAUDE.md fragment `### Rules` entry)
- `.claude/extensions/lean/README.md` (modified — directory tree)
- `specs/860_enforce_plan_compliance_rule/summaries/01_plan-compliance-rule-summary.md`
  (implementation summary, including the Phase 4 propagation conclusion and a restatement of
  the Decision 3 deviation)

## Rollback/Contingency

All changes are additive and confined to `.claude/extensions/lean/`; no existing rule, agent, or
generated file is modified. Rollback is `git checkout -- .claude/extensions/lean/` plus removing
the new rule file — no consuming repo is touched, so no downstream cleanup is needed.

**Contingencies**:
- **Phase 2 doc-lint fails for unrelated pre-existing reasons**: capture the baseline by running
  `check-extension-docs.sh` on a clean tree first; only new failures block. Pre-existing
  failures are out of scope (Non-Goals).
- **Phase 4 positive control fails** (e.g. BimodalLogic absent or `lean` inactive): the
  placement premise in Decision 1 is broken. Do NOT silently proceed — mark the phase
  [BLOCKED], report that the lean-placement rationale no longer holds, and escalate for a
  placement re-decision rather than guessing at core placement.
- **`EXTENSION.md` has no existing `### Rules` section**: add one following the nvim
  extension's CLAUDE.md section as the structural template; do not restructure the file.

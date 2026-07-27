# Implementation Plan: Task #929

- **Task**: 929 - enforce_source_store_deploy_boundary
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/929_enforce_source_store_deploy_boundary/reports/01_source-store-boundary-enforcement.md
- **Artifacts**: plans/01_enforce-source-store-boundary.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`.claude/` under this repo is a gitignored, disposable deploy artifact regenerated from the source
store at `agent-system/extensions/**`. Hand-authored files landing in `.claude/` are silently wiped
by the next regeneration. Three coordinated changes close the gap: register the already-deployed
but never-wired `validate-meta-write.sh` hook so it actually fires; widen its path coverage to
`.claude/scripts/**` and `.claude/hooks/**` and rewrite its advisory message (which currently
grants `/implement` a blanket exemption -- exactly backwards); and encode the rule durably as ONE
core rule file referenced by a one-line MUST NOT bullet in each implementer-agent contract.

Definition of done: the hook fires on `.claude/**` writes including `scripts/` and `hooks/`, emits
a correct advisory naming `agent-system/extensions/<ext>/...` as the edit target, exits 0
(non-blocking); a new core rule file exists, deploys, and is registered in the Rules References
list; every implementer-agent contract carries a one-line pointer to it; and no second independent
prose copy of the rule exists anywhere in the tree.

### Research Integration

The research report confirmed both root causes against the live source tree with exact locations:

- `validate-meta-write.sh` is listed in `core/manifest.json`'s `provides.hooks` (so it deploys as
  a file) but is entirely absent from `core/merge-sources/settings-hooks.json`'s `PostToolUse`
  array. Deployed `.claude/settings.json` was diffed and matches the merge-source byte-for-byte,
  confirming deploy is a straight copy and the fix belongs exclusively in the merge-source.
- The `is_meta_path` case statement covers `commands/`, `skills/`, `agents/`, `rules/`,
  `context/`, `extensions/`, `*/CLAUDE.md` -- no `scripts/` or `hooks/` case.
- An in-repo precedent for the one-line rule-pointer pattern exists verbatim in two cslib
  implementation agents (the `no-task-references-in-deliverables.md` bullet). This is the shape to
  replicate.
- The report supplied a grep-verified, exhaustive 15-file list of implementer-agent contracts
  carrying a MUST NOT list. This plan treats that list as the authoritative checklist rather than
  re-deriving it, while still requiring implementation-time confirmation (see Scope Hypothesis
  lines on Phases 4 and 5).
- The report additionally identified two registration locations the task description did not name:
  `core/manifest.json`'s `provides.rules` array (without which the new rule file never deploys) and
  `core/merge-sources/claudemd.md`'s Rules References list (without which it is not discoverable
  through the documented auto-applied-rules mechanism). Both are folded into Phase 1.
- The report flagged that `meta-builder-agent.md` already carries a hand-written prose copy of this
  exact constraint ("Rule 2 (location-correctness)" plus a "Hook limitation" paragraph). Leaving it
  would create precisely the two-independent-copies problem the task warns against. Phase 4
  collapses it -- see the Decisions note below for how the genuinely agent-specific clause is
  preserved.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no ROADMAP.md consulted.

### Decisions Made During Planning

Two judgment calls the research report deliberately left to the planner:

1. **`meta-builder-agent.md`'s Rule 2 is collapsed, not deleted and not left intact.** Its general
   explanation of the source-store/deploy distinction and its "Hook limitation" paragraph move into
   the new rule file (the limitation text is accurate and directly reusable -- transcribe it rather
   than re-derive it). What stays inline is the one genuinely agent-specific obligation that has no
   home in a rule aimed at implementers: *the task descriptions this agent writes must name
   `agent-system/extensions/**` as their edit target*. That clause is about authoring task scope,
   not about where the agent itself writes, so a pointer alone would lose it.

2. **All 15 implementer-agent contracts are in scope, not only the 2 under `core/`.** The
   delegation's declared `file_scope` lists `agent-system/extensions/core/agents/`, which covers
   only `general-implementation-agent.md` and `general-implementation-hard-agent.md`. But REQUIRED
   WORK item 3 says "the implementer agent contracts" unqualified, and a rule that binds only the
   two core implementers while thirteen extension implementers write unbound is not the deliverable
   asked for. `file_scope` is a descriptive, anticipated field set at task-creation time and is not
   filesystem-validated (see `.claude/rules/state-management.md`), so this is treated as an
   under-specified estimate rather than a boundary. Phase 5 is separated from Phase 4 specifically
   so this widening is visible and separately committed rather than smuggled in.

## Goals & Non-Goals

**Goals**:
- Register `validate-meta-write.sh` in the `PostToolUse` `Write|Edit` matcher block so it executes
  at all, following the invocation form of its advisory sibling.
- Extend the hook's covered path set to `.claude/scripts/**` and `.claude/hooks/**`.
- Replace the hook's advisory message: state the source-store rule, name
  `agent-system/extensions/<ext>/...` as the correct edit target, drop the `/implement`-is-fine
  carve-out.
- Create ONE core rule file stating the boundary durably, registered so it both deploys and is
  discoverable.
- Add a single one-line MUST NOT bullet pointing at that rule file to every implementer-agent
  contract, reusing the existing in-repo phrasing template.
- Eliminate, not add to, existing duplicate prose statements of the same rule.

**Non-Goals**:
- Making the hook blocking. It stays advisory: emits `additionalContext`, exits 0.
- Impeding the deploy/reload process, which writes the entire `.claude/` tree by design.
- Removing or narrowing the hook's existing `specs/*|*/specs/*` skip -- legitimate
  `/meta`-lifecycle task creation under `specs/**` must remain exempt.
- Claiming the hook enforces the rule. It cannot; see Known Limitation below.
- Any edit to `.claude/**`. Every edit in this plan targets `agent-system/extensions/**`.
- Creating a `context/patterns/adding-a-core-rule.md` guide (the report's Context Extension
  Recommendation) -- out of scope, noted for a possible follow-up.

## Known Limitation (must be stated, not papered over)

A PostToolUse hook receives only a `file_path`. It cannot see task type, lifecycle, command
context, or which repository the path belongs to. It can therefore only ever be an advisory nudge
on path *shape*. The durable enforcement is the rule file plus the agent contracts; the hook is the
reminder, not the guarantee. The new rule file's own Enforcement section MUST state this limitation
rather than overclaim -- transcribe the framing near-verbatim; do not paraphrase it into a stronger
claim.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widened `is_meta_path` fires on the deploy/reload process | M | L | Deploy is a plain file copy, not a Claude Code Write/Edit tool call, so the hook structurally cannot observe it. Verify in Phase 6 by confirming no Write/Edit codepath drives deploy; no carve-out is added. |
| Advisory message grows long/prescriptive enough to read as blocking | L | M | Match the concision and closing sentence of `validate-no-task-references.sh`'s advisory ("This is advisory only and does not block the write."). Single message, no multi-paragraph text. |
| One of 15 near-identical agent-contract edits is missed | M | M | Phase 6 runs a grep sweep across every `*implementation*agent.md` under `agent-system/extensions/*/agents/` and `core/agents/` and asserts a hit in each; the count is confirmed at implementation time, not assumed. |
| New rule file authored but never deploys (missing from `provides.rules`) | H | M | Registration in `manifest.json` is in the same phase as authoring the file, and Phase 6 asserts all three registration locations. |
| Rewritten hook message and rule file drift into two divergent statements | M | M | Phase 3 depends on Phase 1: the rule file is the canonical statement and the hook message is derived from it, compressed to one sentence plus target. |
| Accidental edit to `.claude/**` while working on hook/rule files with near-identical paths | H | M | Every phase's verification includes `git status` confirming no `.claude/` path is modified. `.claude/` is gitignored, so also verify by direct `ls -la --time-style` / mtime check on the two hook files if in doubt. |
| Collapsing meta-builder Rule 2 loses the task-authoring obligation | M | M | Phase 4 explicitly preserves that clause inline and only replaces the general explanation; verification re-reads the section to confirm the clause survives. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author and Register the Core Rule File [COMPLETED]

**Goal**: The durable, canonical statement of the source-store/deploy boundary exists as one core
rule file, deploys with the core extension, and appears in the documented auto-applied rules list.

**Tasks**:
- [x] Create `agent-system/extensions/core/rules/source-store-deploy-boundary.md`, modeled
      structurally on the sibling `rules/no-task-references-in-deliverables.md` (prose
      `## Path Pattern` header style, not YAML `paths:` frontmatter -- both conventions coexist in
      this directory; match the named sibling).
- [x] Sections to include: `# Source Store / Deploy Boundary` (or equivalent title),
      `## Path Pattern`, `## Principle`, `## Correct Edit Target`, `## Exceptions`,
      `## Enforcement` (with the Known Limitation stated explicitly).
- [x] `## Path Pattern`: this is a *target-path* rule, not a content-scanning rule. Applies to any
      write whose target is `.claude/**` in a repository whose source store is
      `agent-system/extensions/**`.
- [x] `## Principle`: `.claude/` is a gitignored, disposable deploy artifact regenerated from the
      source store; hand-authored files there are silently wiped by the next regeneration.
- [x] `## Correct Edit Target`: `agent-system/extensions/core/**` for core system files, or
      `agent-system/extensions/<ext>/**` for extension-owned files. Include a short Before/After
      pair in the style of the sibling rule's Before/After.
- [x] `## Exceptions`: writes under `specs/**` (task-management artifacts) are unaffected; the
      deploy/reload process writes the whole `.claude/` tree by design and is not a violation.
- [x] `## Enforcement`: name the advisory `validate-meta-write.sh` hook (PostToolUse, non-blocking)
      and the agent-contract MUST NOT bullets as the two layers. Transcribe the hook-limitation
      framing near-verbatim from the existing `meta-builder-agent.md` "Hook limitation" paragraph
      (it is accurate and already written): a PostToolUse hook sees only a `file_path`, its
      `specs/*|*/specs/*` skip matches unconditionally regardless of repo, and it is NOT a backstop
      for target-root correctness. Do not overclaim enforcement.
- [x] Add `"source-store-deploy-boundary.md"` to `provides.rules` in
      `agent-system/extensions/core/manifest.json` (without this the file never deploys).
- [x] Add a bullet to the Rules References list in
      `agent-system/extensions/core/merge-sources/claudemd.md`, alongside the existing seven, in
      the same one-line form:
      `- @.claude/rules/source-store-deploy-boundary.md - .claude/** is a disposable deploy artifact; edit agent-system/extensions/** instead`

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` - NEW; the canonical rule
- `agent-system/extensions/core/manifest.json` - add rule to `provides.rules`
- `agent-system/extensions/core/merge-sources/claudemd.md` - add Rules References bullet

**Verification**:
- `jq . agent-system/extensions/core/manifest.json` parses and
  `jq -r '.provides.rules[]' ... | grep -x 'source-store-deploy-boundary.md'` returns a hit.
- The new rule file exists, is non-empty, and contains all six required section headings.
- `grep -c 'source-store-deploy-boundary' agent-system/extensions/core/merge-sources/claudemd.md`
  returns 1.
- The rule file contains no task-number citations (per
  `.claude/rules/no-task-references-in-deliverables.md` -- it is a deliverable outside `specs/**`).
- `git status --short` shows no modified path under `.claude/`.

---

### Phase 2: Register the Hook in the PostToolUse Matcher [COMPLETED]

**Goal**: `validate-meta-write.sh` actually executes. Without this, nothing else in this plan has
runtime effect.

**Tasks**:
- [x] In `agent-system/extensions/core/merge-sources/settings-hooks.json`, add a third command
      entry to the SAME `hooks` array as its two existing siblings under the first
      `"matcher": "Write|Edit"` block (not a new matcher block), so it fires in the same
      PostToolUse pass.
- [x] Use the invocation form of `validate-no-task-references.sh`, the advisory/exit-0 sibling:
      `{ "type": "command", "command": "bash .claude/hooks/validate-meta-write.sh 2>/dev/null || echo '{}'" }`
      Do NOT copy `validate-handoff-location.sh`'s form -- it deliberately omits the `|| echo '{}'`
      fallback because it uses exit 2 to surface a blocking error, which is not this hook's model.
- [x] Make no other change to the file: matcher strings, existing entries, and the second
      `Write|Edit` block (events-log-artifact.sh) stay byte-identical.

**Timing**: 15 minutes

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - add one hook command entry

**Verification**:
- `jq . agent-system/extensions/core/merge-sources/settings-hooks.json` parses.
- `jq -r '.hooks.PostToolUse[0].hooks[].command' ...` lists exactly three entries, the third being
  the `validate-meta-write.sh` line, and the first two unchanged.
- `git diff` on this file shows exactly one added line and zero modified lines.
- `git status --short` shows no modified path under `.claude/`.

---

### Phase 3: Widen and Re-Aim `validate-meta-write.sh` [COMPLETED]

**Goal**: The hook covers the paths where the incident actually landed, and its advisory text
states the source-store rule and names the correct target instead of exempting `/implement`.

**Tasks**:
- [x] Add two cases to the `is_meta_path` case statement, in the existing style:
      `.claude/scripts/*|*/.claude/scripts/*)` and `.claude/hooks/*|*/.claude/hooks/*)`.
- [x] Leave the existing seven cases and the `specs/*|*/specs/*` early-skip block untouched --
      the specs skip is a required non-goal-protected exemption.
- [x] Rewrite the `additionalContext` message. It must: (1) state that `.claude/` is a disposable
      deploy artifact regenerated from the source store and that edits there are silently wiped;
      (2) name `agent-system/extensions/<ext>/...` (or `agent-system/extensions/core/...`) as the
      correct edit target; (3) cite `.claude/rules/source-store-deploy-boundary.md` for the full
      rule; (4) close with an advisory-only sentence matching the sibling's tone.
- [x] DELETE the current trailing clause granting `/implement` (`general-implementation-agent`) a
      blanket exemption. An `/implement`-lifecycle write into `.claude/**` is precisely the failure
      mode this hook exists to flag.
- [x] Keep the message to roughly the length of `validate-no-task-references.sh`'s advisory --
      one compact paragraph, not multiple.
- [x] Preserve the hook's non-blocking contract exactly: single `additionalContext` JSON object on
      stdout, `exit 0` on every path. Do not introduce exit 2 or any blocking behavior.
- [x] Include no task-number citations in the message or comments.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-meta-write.sh` - widen `is_meta_path`, rewrite
  advisory message, remove `/implement` carve-out

**Verification**:
- `bash -n agent-system/extensions/core/hooks/validate-meta-write.sh` passes.
- Feed the hook synthetic stdin and check behavior for each case:
  - `{"tool_input":{"file_path":".claude/scripts/foo.sh"}}` -> non-empty `additionalContext`
  - `{"tool_input":{"file_path":".claude/hooks/foo.sh"}}` -> non-empty `additionalContext`
  - `{"tool_input":{"file_path":".claude/agents/foo.md"}}` -> still fires (no regression)
  - `{"tool_input":{"file_path":"specs/929_x/plans/01_y.md"}}` -> emits `{}` (specs skip intact)
  - `{"tool_input":{"file_path":"lua/neotex/init.lua"}}` -> emits `{}`
  - every invocation exits 0 (`echo $?` is 0 in all five cases)
- Each emitting case's output parses as JSON (`jq .`).
- `grep -c 'general-implementation-agent' agent-system/extensions/core/hooks/validate-meta-write.sh`
  returns 0 (carve-out removed).
- `git status --short` shows no modified path under `.claude/`.

---

### Phase 4: Core Agent Contracts and Duplicate-Prose Collapse [COMPLETED]

**Goal**: The two core implementer contracts carry the one-line rule pointer, and the pre-existing
duplicate prose copy of this rule in `meta-builder-agent.md` is collapsed rather than left to
diverge.

**Tasks**:
- [x] Append one bullet to the existing `**MUST NOT**:` list in
      `agent-system/extensions/core/agents/general-implementation-agent.md`, continuing that list's
      numbering, using the in-repo precedent shape:
      `Hand-author files under .claude/** -- see .claude/rules/source-store-deploy-boundary.md; edit the source store at agent-system/extensions/<ext>/** instead`
- [x] Append the identical bullet (renumbered to that file's list) to
      `agent-system/extensions/core/agents/general-implementation-hard-agent.md`.
- [x] In `agent-system/extensions/core/agents/meta-builder-agent.md`: replace the general
      explanation in the "Rule 2 (location-correctness)" bullet and the entire "Hook limitation"
      paragraph with a pointer to the new rule file. PRESERVE inline the agent-specific clause that
      has no home in an implementer-aimed rule: tasks this agent creates whose scope is an
      agent-system change must name `agent-system/extensions/core/**` (or the relevant extension's
      source directory) as their edit target, never `.claude/**`.
- [x] Leave "Rule 1 (actor/workflow)" untouched -- it is a distinct constraint about this agent
      creating tasks rather than implementing, unrelated to the location rule.
- [x] Before collapsing, confirm the hook-limitation text was carried into the Phase 1 rule file;
      if it was not, carry it there first rather than deleting it.
- [x] No task-number citations in any added or edited text.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly 3 files under `agent-system/extensions/core/agents/`
require edits (2 implementer contracts + 1 duplicate-prose collapse). Confirm at implementation
time with `ls agent-system/extensions/core/agents/` and
`grep -l '\*\*MUST NOT\*\*' agent-system/extensions/core/agents/*.md` -- if a core agent file with a
MUST NOT list and implementation authority exists beyond the two named, add the bullet there too and
record the correction in the summary rather than silently matching the asserted count.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - add MUST NOT bullet
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - add MUST NOT bullet
- `agent-system/extensions/core/agents/meta-builder-agent.md` - collapse Rule 2 prose to pointer,
  preserving the task-authoring clause

**Verification**:
- `grep -c 'source-store-deploy-boundary' <each of the 3 files>` returns >= 1 for each.
- `meta-builder-agent.md` still contains the task-authoring clause naming
  `agent-system/extensions/core/**` as the edit target for tasks it creates (read the section, do
  not infer from grep alone).
- `meta-builder-agent.md` no longer contains a standalone "Hook limitation" paragraph restating the
  rule (`grep -c 'Hook limitation'` returns 0), and that text is present in the Phase 1 rule file.
- The MUST NOT list numbering in each implementer file is contiguous.
- No task-number citations added: `grep -nE 'task [0-9]+|tasks [0-9]+' <each file>` shows no new
  hits versus the pre-edit state.
- `git status --short` shows no modified path under `.claude/`.

---

### Phase 5: Extension Implementer Contracts [COMPLETED]

**Goal**: Every remaining implementer-agent contract carries the same one-line rule pointer, so the
rule binds all implementers rather than only the two core ones.

**Tasks**:
- [x] Append the identical one-line MUST NOT bullet (same wording as Phase 4, renumbered per file)
      to each of the 13 extension implementer contracts identified by research:
      - `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
      - `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
      - `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md`
      - `agent-system/extensions/python/agents/python-implementation-agent.md`
      - `agent-system/extensions/web/agents/web-implementation-agent.md`
      - `agent-system/extensions/latex/agents/latex-implementation-agent.md`
      - `agent-system/extensions/lean/agents/lean-implementation-agent.md`
      - `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
      - `agent-system/extensions/typst/agents/typst-implementation-agent.md`
      - `agent-system/extensions/z3/agents/z3-implementation-agent.md`
      - `agent-system/extensions/email/agents/email-implementation-agent.md`
      - `agent-system/extensions/nvim/agents/neovim-implementation-agent.md`
      - `agent-system/extensions/nix/agents/nix-implementation-agent.md`
- [x] Append to each file's EXISTING MUST NOT list; do not create a new section, and do not add any
      prose beyond the single bullet. The whole point of the pointer shape is that the explanation
      lives in one place.
- [x] For extensions whose source directory does not exist in this tree, record it as a reasoned
      exclusion with evidence rather than silently skipping.
- [x] No task-number citations in any added text.

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly 13 extension implementer-agent contract files, each
already carrying a MUST NOT list. The list came from a grep sweep in the research report and is a
hypothesis, not a fact. Confirm at implementation time with
`grep -l '\*\*MUST NOT\*\*' agent-system/extensions/*/agents/*implementation*agent.md` and reconcile
against the 13 above (plus the 2 core files from Phase 4). If the live set differs -- a file added,
renamed, or lacking a MUST NOT list -- follow the live set and record the discrepancy in the
summary; do not force the count to 13.

**Files to modify**:
- The 13 files enumerated above - one appended MUST NOT bullet each

**Verification**:
- For every file in the confirmed live set:
  `grep -c 'source-store-deploy-boundary' <file>` returns >= 1.
- `git diff --stat` shows roughly one added line per file and zero deletions.
- Each file's MUST NOT list numbering is contiguous after the edit.
- `git status --short` shows no modified path under `.claude/`.

---

### Phase 6: End-to-End Verification and Anti-Duplication Sweep [NOT STARTED]

**Goal**: Confirm the three required changes are complete and mutually consistent, the hook remains
advisory, no `.claude/**` file was touched, and exactly one prose statement of the rule exists.

**Tasks**:
- [ ] Re-run the Phase 3 synthetic-stdin matrix end to end and confirm every invocation exits 0.
- [ ] Confirm all three rule-file registration locations: `provides.rules` in `manifest.json`, the
      Rules References bullet in `claudemd.md`, and the file itself under `core/rules/`.
- [ ] Run the exhaustive pointer sweep:
      `grep -L 'source-store-deploy-boundary' agent-system/extensions/*/agents/*implementation*agent.md agent-system/extensions/core/agents/general-implementation*.md`
      and confirm it lists nothing (every implementer contract has the bullet).
- [ ] Anti-copy-paste audit: `grep -rln 'disposable deploy artifact' agent-system/` should surface
      the new rule file and, at most, short one-line pointers -- NOT a second multi-paragraph prose
      copy. If a second full copy exists, collapse it to a pointer.
- [ ] Confirm the hook is still non-blocking: no `exit 2`, no `"decision"`/`"permissionDecision"`
      key, single `additionalContext` object, `exit 0` on every path.
- [ ] Confirm the `specs/*|*/specs/*` early skip is intact and unmodified.
- [ ] Confirm the deploy/reload path is unaffected: it writes `.claude/` by filesystem copy, not
      through the Write/Edit tool, so the widened hook cannot observe it. Note the reasoning in the
      summary rather than adding a carve-out.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` if present and confirm it does not fail on
      the new rule file or manifest entry.
- [ ] Confirm zero `.claude/**` modifications across the whole task: review the full `git status`
      and `git diff --stat` for the task's commits; every changed path must begin with
      `agent-system/extensions/` or `specs/`.
- [ ] Grep every file authored or edited outside `specs/**` for task-number citations; expect zero.

**Timing**: 30 minutes

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None (verification only); corrective edits land in the phase whose file they belong to

**Verification**:
- All checks above pass, or any failure is corrected and re-verified before the phase closes.
- A single consolidated pass/fail record for each bullet is captured in the implementation summary.

---

## Testing & Validation

- [ ] `jq .` parses `manifest.json` and `settings-hooks.json` after edits.
- [ ] `bash -n` passes on `validate-meta-write.sh`.
- [ ] Synthetic-stdin matrix: `.claude/scripts/*`, `.claude/hooks/*`, `.claude/agents/*` all emit
      advisory; `specs/**` and a plain source path emit `{}`; all five exit 0.
- [ ] The advisory message names `agent-system/extensions/` and does NOT contain
      `general-implementation-agent` as an exemption.
- [ ] The new rule file exists, is registered in `provides.rules`, and appears in the Rules
      References list.
- [ ] Every implementer-agent contract in the live confirmed set contains
      `source-store-deploy-boundary`.
- [ ] Exactly one multi-paragraph prose statement of the rule exists in the tree.
- [ ] No file under `.claude/` was created or modified by this task.
- [ ] No task-number citations in any file outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` (new)
- `agent-system/extensions/core/manifest.json` (modified -- `provides.rules`)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (modified -- hook registration)
- `agent-system/extensions/core/merge-sources/claudemd.md` (modified -- Rules References)
- `agent-system/extensions/core/hooks/validate-meta-write.sh` (modified -- path coverage + message)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified)
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` (modified)
- `agent-system/extensions/core/agents/meta-builder-agent.md` (modified -- prose collapse)
- 13 extension implementer-agent contracts (modified -- one bullet each)
- `specs/929_enforce_source_store_deploy_boundary/summaries/01_enforce-source-store-boundary-summary.md`

## Rollback/Contingency

Every change is additive and confined to git-tracked files under `agent-system/extensions/`, so
`git revert` of the task's commits fully restores the prior state; `.claude/` is regenerated from
the source store and needs no separate rollback.

Per-phase contingencies:
- If the widened hook proves noisy in practice, narrow the two new path cases (or drop
  `.claude/hooks/*`) in a follow-up rather than unregistering the hook -- registration (Phase 2) is
  the change with the most value and the least risk.
- If registering the hook surfaces an unexpected interaction with the sibling hooks in the same
  matcher block, move it to its own `"matcher": "Write|Edit"` block (the file already contains a
  second such block, so the pattern is proven) rather than removing it.
- The rule file, its registrations, and the agent-contract bullets are inert text with no runtime
  behavior; they carry no rollback risk independent of the commits.

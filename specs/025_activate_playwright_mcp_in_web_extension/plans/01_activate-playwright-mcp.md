# Implementation Plan: Task #25

- **Task**: 25 - Activate the already-designed but parked Playwright MCP integration in the web extension, and reconcile its drifted tool list against the live server.
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None (prerequisite MCP registration and `settings-fragment.json` allowlist work already committed)
- **Research Inputs**: specs/025_activate_playwright_mcp_in_web_extension/reports/01_activate-playwright-mcp.md
- **Artifacts**: plans/01_activate-playwright-mcp.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a **verify-and-close-gaps plan, not a from-scratch build plan**. The research dispatch
exceeded its role and performed the implementation edits during the research phase; those edits
are already committed as `1610a6a35`. This plan audits what actually landed against the task's
acceptance criteria, closes the two real gaps the audit found, and records an explicit decision
for the one open question. Definition of done: the extension doc-lint gate passes for the `web`
extension, every acceptance criterion is confirmed against the file contents on disk (not against
the research report's claims about them), and each criterion is recorded as either
"verified no-op" or "gap closed".

### Research Integration

The research report's findings were used as a starting hypothesis and then independently
re-verified. Two of its claims did not survive verification, and this plan is built against the
verified state rather than the report:

- **The report's one flagged "known gap" is false.** It claims `check-extension-docs.sh` "could
  not be run from the source-store tree". The deployed copy at
  `.claude/scripts/check-extension-docs.sh` exists, and the script's own `EXT_DIR` defaults to
  `$REPO_ROOT/agent-system/extensions` — it lints the **source store**, not the deploy tree. Its
  header documents an explicit escape hatch for exactly this case: *"any deliberate source-store
  invocation MUST pass an explicit `REPO_ROOT=$(pwd)` override"*. The gate is runnable and has
  been run during planning.
- **Running that gate surfaces a real FAIL caused by these edits.** `Rule R` reports
  `index-entries.json entry 'project/web/README.md' line_count mismatch: declared 110, actual 116`
  — the README edit added 6 lines without updating its `line_count`. This is precisely the drift
  class the task warned about, and the research report asserted no such drift existed.

The report's other substantive claims (Playwright section flipped to active, new guide file
created and registered, `web-research-agent.md` untouched) were spot-checked during planning and
appear to hold; Phase 3 confirms them formally rather than trusting the spot-check.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` in the delegation context, `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- Run the doc-lint gate that was never exercised on these changes, and record its output as
  evidence rather than as an assertion.
- Close the `line_count` drift so the `web` extension passes that gate.
- Confirm each acceptance criterion against file contents, marking verified criteria as no-ops
  instead of inventing rework.
- Record an explicit, evidenced decision about the stale invented tool name surviving in the
  git-tracked `.opencode/extensions/web/` copy.

**Non-Goals**:
- Re-authoring or restyling the already-committed guide, agent section, or README prose. If a
  criterion is met, it is met — do not rewrite working content.
- Widening `settings-fragment.json`'s 9-tool allowlist. The enumeration is deliberate; the
  escape-hatch exclusions are the point, not an oversight to fix.
- Fixing the pre-existing `core` and `literature` extension lint failures, or the
  `routing target not deployed` warnings for `skill-web-research` / `skill-web-implementation`.
  Those are unrelated to this task's edits (the web extension is not installed in this repo) and
  Phase 1 exists partly to prove they are pre-existing.
- Deploying/regenerating `.claude/**`. No edit in this plan targets a deployed tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer "fixes" the deliberate negative mentions of `browser_verify_text_visible` (the guide and agent both correctly say *"there is no `browser_verify_text_visible` tool"*) | M | M | Phase 3 states the distinction explicitly: a negative mention teaching that the tool does not exist is correct and MUST be preserved; only a mention that *presents it as usable* is a defect |
| Blanket `generate-context-line-counts.sh --write` rewrites `line_count` across all 20 extensions, producing an unreviewable diff far outside this task's scope | M | M | Phase 2 mandates a scoped single-value edit, using `--check` only as read-only confirmation |
| Implementer hand-edits `.opencode/**` or `.claude/**` to chase the stale tool name | H | M | Phase 4 is a decision-and-record phase with an explicit "do not edit without evidence" gate; the source-store rule is restated in Critical Constraints below |
| The lint gate's non-web failures are misread as caused by this task, triggering unscoped rework | M | L | Phase 1 captures the full baseline first and names `core`/`literature` as out of scope |
| Fixing `line_count` today, then a later prose edit re-drifts it | L | M | Phase 5 re-runs the gate as the final check, so drift is caught at close-out rather than after |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Establish the Doc-Lint Baseline [COMPLETED]

**Goal**: Run the gate the research phase claimed could not be run, and separate failures caused
by these edits from pre-existing ones.

**Tasks**:
- [x] Run the gate against the source store from the repo root:
      `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh` *(completed)*
- [x] Capture the `web` extension's stanza verbatim (the `[web]` block) and the per-extension
      Summary table. *(completed)*
- [x] Classify each `web` finding as **caused-by-these-edits** or **pre-existing**. Expected
      classification, to be confirmed not assumed: *(completed: classification confirmed exactly as expected)*
      - `FAIL: Rule R: index-entries.json entry 'project/web/README.md' line_count mismatch:
        declared 110, actual 116` -> caused by these edits (Phase 2 fixes it)
      - `rule not deployed, skipping drift check: web-astro.md` -> pre-existing (informational)
      - `WARN: routing target not deployed (extension not installed): skill-web-research` and
        `skill-web-implementation` -> pre-existing (web extension is not installed in this repo)
- [x] Confirm `core` and `literature` are the only other failing extensions and that neither
      failure names a `web` path. Record them as out of scope. *(completed: core FAIL is
      scripts/setup-lean-mcp.sh drift; literature FAIL is a separate line_count mismatch on
      project/literature/domain/literature-index.md; neither names a web path)*
- [x] Record the exact command used, so the summary can state the compensating-check question is
      closed by a real run rather than by an argument. *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The `web` stanza contains exactly one FAIL, and it is the `Rule R`
`line_count` mismatch above. Confirm by reading the full `[web]` block from the gate's own output
— do not assume the count from this plan. If a second FAIL appears, stop and widen Phase 2's
scope explicitly rather than fixing it silently.

**Files to modify**:
- None (read-only evidence-gathering phase)

**Verification**:
- The gate ran to completion and produced a per-extension Summary table.
- The `[web]` stanza is captured verbatim in the phase's notes.
- Every `web` finding carries a caused-by / pre-existing classification.

---

### Phase 2: Close the `line_count` Drift [COMPLETED]

**Goal**: Make the `web` extension pass the `Rule R` index-truth check.

**Tasks**:
- [x] Re-measure the truth directly:
      `wc -l agent-system/extensions/web/context/project/web/README.md` *(completed: 116)*
- [x] In `agent-system/extensions/web/index-entries.json`, update the `line_count` of the entry
      whose `path` is `project/web/README.md` from `110` to the measured value. Change **only**
      that one numeric field. *(completed: 110 -> 116)*
- [x] Confirm the file is still valid JSON (`python3 -c "import json;json.load(open(...))"` or
      `jq empty`). *(completed: valid)*
- [x] Confirm no other entry in that file drifted, read-only:
      `bash .claude/scripts/generate-context-line-counts.sh --check` — inspect its `web` findings
      only. **Do NOT run `--write`**: it rewrites every extension's counts and produces an
      out-of-scope diff. *(completed: "web: 24 entries, 24 exact, 0 mismatch")*
- [x] Re-run `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh` and confirm the
      `web` row now reads `PASS`. *(completed: web PASS)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly one `line_count` value in
`agent-system/extensions/web/index-entries.json` needs changing (the `project/web/README.md`
entry), and the new value is `116`. Confirm both by re-running `wc -l` at implementation time and
by reading the `--check` output; the file may have changed since planning. If `--check` reports
additional `web` drift, fix those entries too and note the widened scope in the summary.

**Files to modify**:
- `agent-system/extensions/web/index-entries.json` — one `line_count` numeric field

**Verification**:
- `check-extension-docs.sh` Summary table shows `web PASS`.
- `generate-context-line-counts.sh --check` reports no remaining `web` mismatches.
- The diff for this phase touches exactly one line of one file.

---

### Phase 3: Audit the Acceptance Criteria Against File Contents [COMPLETED]

**Goal**: Confirm each acceptance criterion against what is actually on disk. Criteria already
satisfied are recorded as **verified no-ops** — do not manufacture rework for them.

**Tasks**:
- [x] **Criterion: research agent's block is unchanged.** Confirm line 4 of
      `agent-system/extensions/web/agents/web-research-agent.md` still reads exactly
      `disallowedTools: mcp__playwright__*`, and that the file does not appear in commit
      `1610a6a35`'s changed-file list (`git show --stat 1610a6a35`). Also confirm the symmetric
      `disallowedTools: mcp__context7__*` on line 4 of `web-implementation-agent.md` survives.
      *(completed: verified no-op — both lines confirmed intact; web-research-agent.md absent
      from that commit's file list)*
- [x] **Criterion: no guidance depends on a prompting tool.** Extract every `browser_*` name that
      appears in an instruction-to-act position (a "use X", "combine X", "prefer X" sentence, or a
      Tasks/verification step) in both
      `agent-system/extensions/web/agents/web-implementation-agent.md` and
      `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md`. Every such
      name must fall inside the unprompted 9: `browser_navigate`, `browser_snapshot`,
      `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`,
      `browser_click`, `browser_type`, `browser_find`, `browser_wait_for`. Names appearing only in
      the 24-tool reference table or in a prohibition ("never depend on `browser_evaluate`") are
      correct and are NOT violations. *(completed: verified no-op — every instruction-position
      name falls inside the unprompted 9; the three escape hatches appear only in prohibitions)*
- [x] **Criterion: the 9-tool list matches the allowlist exactly.** Diff the "Unprompted tools"
      bullet in `web-implementation-agent.md`, the "Permission Tiers" list in
      `playwright-mcp-guide.md`, and the `permissions.allow` array in
      `agent-system/extensions/web/settings-fragment.json` (strip the `mcp__playwright__` prefix).
      All three must name the same 9 tools, no more and no fewer. The research report flags these
      three files as an intentional must-stay-in-sync trio. *(completed: verified no-op — all
      three name the identical 9 tools)*
- [x] **Criterion: the 24-tool reference is accurate.** Check the guide's tool table against the
      task description's authoritative 24-name list — every name present, none invented, none
      missing. Note in particular that both `browser_network_request` (singular) and
      `browser_network_requests` (plural) are real, distinct tools. *(completed: verified no-op —
      table's 8 category rows sum to exactly 24, matching the live tool surface)*
- [x] **Criterion: no invented tool name survives as usable guidance in the source store.**
      `grep -rn "browser_verify_text_visible" agent-system/extensions/web/`. The two expected hits
      (`web-implementation-agent.md` and `playwright-mcp-guide.md`) both state that the tool does
      **not** exist and map the intent onto `browser_find` / `browser_wait_for`. **These are
      correct and MUST be preserved** — a negative mention teaching that a name is fake is the fix,
      not the defect. Only a hit presenting the name as usable is a violation. *(completed:
      verified no-op — exactly 2 hits, both corrections, both preserved unedited)*
- [x] **Criterion: the deferred status is genuinely flipped.** Confirm no
      `deferred`/`not yet active`/`Deferred pending browser binary installation` phrasing remains
      in the Playwright subsection of `web-implementation-agent.md`, and that the preserved usage
      conditions (prefer snapshots over screenshots; do not use Playwright for what `pnpm build`
      verifies alone; only when the plan includes a visual/debug/e2e step) are all still present.
      *(completed: verified no-op — subsection reads "active"/"Status: Active", no deferred
      phrasing remains, all three usage conditions present)*
- [x] Confirm the guide's `@.claude/context/patterns/mcp-server-ownership.md` reference follows
      house convention. The source file exists at
      `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`; the deployed path
      is absent here only because that context is not deployed in this repo, exactly as the
      agent file's own `@.claude/context/project/web/...` references are. *(Expected: verified
      no-op — consistent with convention, not a dangling reference. Record the reasoning; do not
      rewrite the reference to a source-store path.)* *(completed: verified no-op — source file
      confirmed present, convention consistent)*
- [x] For every criterion above, write down **verified no-op** or **gap found: {description}**.
      *(completed: all seven criteria recorded as verified no-op; zero gaps found; zero file
      edits made in this phase — see phase-3-progress.json notes for full evidence)*

**Timing**: 35 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: All seven checks in this phase are expected to come back verified no-ops,
with zero file edits. Confirm each by reading the cited file region and quoting the evidence — an
unread criterion is not a verified one. If a check does find a gap, fix it in the source store
under `agent-system/extensions/web/**` and note the deviation on this phase's checklist item.

**Files to modify**:
- None expected. If a gap is found: `agent-system/extensions/web/agents/web-implementation-agent.md`
  and/or `agent-system/extensions/web/context/project/web/tools/playwright-mcp-guide.md`.

**Verification**:
- Each of the seven criteria has a recorded verdict with a quoted line or command output as
  evidence.
- Any edit made is confined to `agent-system/extensions/web/**`.

---

### Phase 4: Decide and Record the `.opencode` Stale-Copy Question [COMPLETED]

**Goal**: Resolve, with evidence and an explicit written decision, the one place where the
invented tool name genuinely survives as usable guidance — outside the source store.

**Context**: `.opencode/extensions/web/agents/web-implementation-agent.md` line 57 reads
``- `browser_verify_text_visible` -- Assert text is visible on page`` — presented as a usable
tool, not as a correction. That tree is **git-tracked** (34 tracked files under
`.opencode/extensions/web`), is **not** gitignored, and `.opencode/**` is named as a deliverable
tree in `.claude/rules/no-task-references-in-deliverables.md`. Complicating it: a prior commit is
titled `purge .opencode/extensions/{present,web}`, yet the directory is present and tracked today.

**Tasks**:
- [x] Determine whether `.opencode/extensions/web/` is generated from the source store or
      independently maintained. Evidence to gather: whether any deploy script writes
      `.opencode/extensions/` (planning found only a README mention and a `deprecated/` script);
      `git log --oneline -- .opencode/extensions/web/` and whether the purge commit was reverted
      or the tree re-added; whether the file's content is a stale copy of the pre-edit source
      (`diff .opencode/extensions/web/agents/web-implementation-agent.md
      agent-system/extensions/web/agents/web-implementation-agent.md`). *(completed: no live
      deploy script writes .opencode/extensions/ — only a deprecated script mentions it; the
      "purge" commit (80f967a7f) actually touched only 8 unrelated lines of this file, never
      deleting the tree; the file uses `@.opencode/context/...` references distinct from the
      source-store file's `@.claude/context/...` convention, and diverges in frontmatter/wording
      beyond the Playwright section — consistent with a hand-maintained parallel copy, not a
      stale generated snapshot)*
- [x] Apply this decision rule and record which branch was taken and why: *(completed: **Branch
      3 selected — independently-maintained live deliverable**. Updates land only via deliberate
      task-driven "mirror" commits — e.g. "task 167 phase 4: mirror changes to .opencode/",
      "task 395 phase 2: update opencode mirror references" — never via automated regeneration)*
      - **If it is a generated/deploy artifact** — record the finding, make NO edit, and note that
        the stale name resolves on the next regeneration. Hand-edits to a generated tree are
        silently wiped.
      - **If it is a stale, already-purge-intended copy** — record it as out of scope for this
        task and recommend a separate follow-up, rather than expanding this task into an
        `.opencode` tree cleanup. Do not delete a tracked tree as a side effect of this task.
      - **If it is an independently-maintained live deliverable** — record that the acceptance
        criterion "no invented tool names survive anywhere" is not fully met outside the source
        store, and recommend a scoped follow-up. Still make no edit under this plan, because the
        binding constraint for this task scopes all edits to
        `agent-system/extensions/web/**`.
- [x] Write the decision, its evidence, and its branch into the implementation summary so a
      reader can see the criterion was assessed rather than skipped. *(completed: recorded in
      phase-4-progress.json notes and carried into the closing summary's "Recorded decision"
      section)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- None. This phase produces a recorded decision, not an edit.

**Verification**:
- The summary contains a named decision branch with the evidence that selected it.
- `git status --short .opencode` is empty — this phase changed nothing there.

---

### Phase 5: Close Out and Record Compensating Evidence [NOT STARTED]

**Goal**: Re-run the gate after all changes and produce a summary that distinguishes gaps closed
from criteria verified as no-ops.

**Tasks**:
- [ ] Re-run `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh` and confirm
      `web PASS` in the Summary table, with the pre-existing `core` / `literature` failures
      unchanged from the Phase 1 baseline.
- [ ] Re-confirm `agent-system/extensions/web/index-entries.json` parses as valid JSON.
- [ ] Confirm the working-tree diff for this task touches only
      `agent-system/extensions/web/index-entries.json` (plus any Phase 3 gap fix under
      `agent-system/extensions/web/**`) and `specs/**`. Confirm `git status --short` shows no
      modification under `.claude/` or `.opencode/`.
- [ ] Write `specs/025_activate_playwright_mcp_in_web_extension/summaries/01_activate-playwright-mcp-summary.md`
      with these sections:
      - **Gaps closed**: the `line_count` drift, with before/after values and the gate output.
      - **Verified no-ops**: each Phase 3 criterion already satisfied by the committed work, with
        its evidence. State plainly that these required no rework.
      - **Research-report corrections**: the doc-lint gate *is* runnable from the source store via
        the documented `REPO_ROOT` override, and running it surfaced a real FAIL the report
        asserted did not exist. This closes the report's flagged "compensating check" question
        with a real run, not a substitute.
      - **Recorded decision**: the Phase 4 `.opencode` branch and its evidence.
      - **Deviations**: any phase that widened scope, or `- None`.

**Timing**: 25 minutes

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- `specs/025_activate_playwright_mcp_in_web_extension/summaries/01_activate-playwright-mcp-summary.md` (new)

**Verification**:
- `check-extension-docs.sh` shows `web PASS`.
- The summary distinguishes gaps-closed from verified-no-ops and includes the corrections above.
- No file under `.claude/` or `.opencode/` was modified.

---

## Critical Constraints (apply to every phase)

1. **Source-store rule (binding)**: every edit targets
   `/home/benjamin/.config/nvim/agent-system/extensions/web/**`. Never edit `.claude/**` — it is
   gitignored, disposable, and regenerated, so hand-edits there are silently wiped. Do not edit
   `.opencode/**` under this plan either (see Phase 4).
2. **Deliverable rule**: no task-number references ("task 25", "task N") in any file outside
   `specs/**`. Reference durable anchors — filenames, section headings — instead.
3. **Do not manufacture rework**: a criterion the committed work already satisfies is recorded as
   a verified no-op. Rewriting satisfactory prose is out of scope and burns the diff's signal.
4. **Preserve the deliberate negatives**: the `settings-fragment.json` 9-tool enumeration and the
   "there is no `browser_verify_text_visible` tool" corrections are intentional. Do not widen the
   allowlist and do not delete the corrections.

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash .claude/scripts/check-extension-docs.sh` reports `web PASS`.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no `web` mismatches.
- [ ] `agent-system/extensions/web/index-entries.json` is valid JSON.
- [ ] The three tool lists (`settings-fragment.json`, `playwright-mcp-guide.md`,
      `web-implementation-agent.md`) name the identical set of 9 unprompted tools.
- [ ] `agent-system/extensions/web/agents/web-research-agent.md` line 4 is unchanged.
- [ ] `git status --short` shows no modification under `.claude/` or `.opencode/`.
- [ ] No task-number reference was introduced outside `specs/**`.

## Artifacts & Outputs

- `specs/025_activate_playwright_mcp_in_web_extension/plans/01_activate-playwright-mcp.md` (this file)
- `specs/025_activate_playwright_mcp_in_web_extension/summaries/01_activate-playwright-mcp-summary.md`
- Modified: `agent-system/extensions/web/index-entries.json` (one `line_count` value)
- Recorded decision on `.opencode/extensions/web/` (in the summary; no file change)

## Rollback/Contingency

The only source-store change is a single numeric field in one JSON file, so rollback is
`git checkout agent-system/extensions/web/index-entries.json` (safe only on a clean tree — see
`.claude/rules/git-workflow.md`'s "No Destructive Git on Uncommitted Work"; snapshot first if the
tree is dirty). Reverting it restores the `Rule R` FAIL and nothing else; no behavior, routing, or
agent capability depends on it.

If Phase 3 uncovers a substantive gap in the committed guidance, the containing phase can be
marked `[PARTIAL]` and the fix scoped to `agent-system/extensions/web/**` without disturbing
Phases 1, 2, or 4. The already-committed work in `1610a6a35` is not reverted by this plan under
any branch — every phase here is additive or corrective on top of it.

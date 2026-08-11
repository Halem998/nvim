# Implementation Plan: Task #26

- **Task**: 26 - Migrate slidev deck screenshot verification from the standalone npm Playwright script to the live Playwright MCP server
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: 24 (scoped Playwright MCP permission allowlist) — completed
- **Research Inputs**: specs/026_migrate_slidev_verification_to_playwright_mcp/reports/01_slidev-verification-mcp-migration.md
- **Artifacts**: plans/01_slidev-verification-mcp-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research reached a deliberate partial-migration conclusion: `playwright-verify.mjs` stays as
the required batch verification gate, and Playwright MCP tools are **added** as a documented,
optional, ad hoc single-slide debugging capability. This plan implements exactly that outcome —
new permission plumbing for the `present` extension, an MCP Tools grant in
`slidev-assembly-agent`'s contract, a written justification for keeping the script, an ad hoc MCP
inspection workflow, and a consistency sweep across every referencing doc and index entry.
Definition of done: the acceptance criterion's "or its continued existence is explicitly
justified in writing" branch is discharged by a real deliverable in the source store, and no
document implies the script was migrated away or points at a removed path.

**Binding constraints for every phase**:
- **Source-store rule**: all edits target `/home/benjamin/.config/nvim/agent-system/extensions/present/**`
  and `/home/benjamin/.config/nvim/agent-system/extensions/founder/**`. Never edit any deployed
  `.claude/**` path — those are gitignored, regenerated, and hand-edits are silently wiped.
- **Deliverable rule**: no task-number references in any file outside `specs/**`. Cite durable
  anchors (filenames, section headings) instead.
- **No redeploy**: this plan does not run the deploy engine. Verification is structural
  (source-store contents, JSON validity, cross-reference consistency), not deployed-tree state.

### Research Integration

Findings from `reports/01_slidev-verification-mcp-migration.md` carried directly into this plan:

- **`playwright-chromium` has two independent consumers.** Slidev's own `slidev export` PDF
  pipeline needs it regardless of this task; only the `.mjs` script's independent
  `chromium.launch()`/`page.goto()`/`page.evaluate()` loop is the in-scope duplicate. The npm
  package pin therefore cannot be removed under any outcome, and no phase attempts it.
- **The blank/error-text check has no permissioned substitute.** The script's
  `page.evaluate(() => document.body.innerText...)` (`.includes('An error occurred on this
  slide')` plus `innerText.trim().length < 30`) maps only onto `browser_evaluate`, which is
  deliberately unpermissioned. `browser_snapshot`'s accessibility tree is a qualitative proxy,
  not a drop-in.
- **Cost and determinism.** A faithful MCP replication costs ~4 tool round-trips per slide
  (navigate, console_messages, snapshot, take_screenshot) against one `node` invocation; and the
  script's exit code is the only mechanism in the system that can gate a build with no agent or
  human in the loop. MCP tools structurally cannot offer a headless/CI entry point.
- **The permission gap is real.** `present` has no `settings-fragment.json` and no `settings`
  entry in `manifest.json`'s `merge_targets` (confirmed: it declares only `claudemd`, `index`,
  `opencode_json`). `founder`'s existing fragment grants only firecrawl/sec-edgar. Neither
  inherits `web`'s Playwright grant.
- **Enumeration, not wildcard.** Per `context/patterns/mcp-server-ownership.md`'s carve-out, a
  `mcp__playwright__*` wildcard would silently re-permit `browser_evaluate` /
  `browser_run_code_unsafe` / `browser_file_upload` — exactly the hole the prerequisite work
  closed. The 9-tool list is copied verbatim from `web/settings-fragment.json`.
- **Adding `web` to `present`'s dependencies was considered and rejected** — it would pull in
  `web`'s unrelated agents, skills, and the `web-astro.md` rule into every `present` deployment.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no `roadmap_flag` is set, so no
roadmap review/update phases are included. `specs/ROADMAP.md` was consulted read-only for
alignment: its only tangentially related item (manifest-driven README generation) is not
advanced by this plan, and no roadmap item is completed by it.

## Goals & Non-Goals

**Goals**:
- Give `present` its own scoped Playwright MCP permission grant (new `settings-fragment.json` +
  `manifest.json` `merge_targets.settings` entry), using the 9-tool enumeration.
- Authorize `slidev-assembly-agent` to call the specific MCP tools it needs, in its own contract.
- Produce the written justification for keeping `playwright-verify.mjs` as a durable deliverable
  in the source store, discharging the acceptance criterion's alternate branch.
- Document the ad hoc single-slide MCP inspection workflow as complementary to — explicitly not a
  replacement for — the batch verification gate.
- Leave every referencing doc and index entry consistent with the keep-plus-add outcome.
- Record the founder no-op as an explicit, evidenced assertion rather than a silent omission.

**Non-Goals**:
- Removing or rewriting `playwright-verify.mjs`, or changing its behavior in any way.
- Removing `playwright-chromium` from the Slidev project scaffold's `package.json` — Slidev's own
  `slidev export` needs it independently.
- Adding a wildcard `mcp__playwright__*` grant anywhere.
- Adding MCP plumbing to `founder` — it has no verification phase to attach it to.
- Adding `web` to any extension's `dependencies` array.
- Running the deploy engine or touching any `.claude/**` path.
- Extending `slide-critic-agent` to consume rendered screenshots (research flagged this as a
  future task proposal, explicitly out of scope).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer reads the task title literally and deletes `playwright-verify.mjs` | H | M | The task description sanctions the partial outcome; this plan's Non-Goals and Phase 3 state the keep decision explicitly, and Phase 5 verifies the file still exists |
| A wildcard grant is used instead of the 9-tool enumeration, silently re-permitting `browser_evaluate` | H | L | Phase 1 pins the exact 9 names and its verification diffs them against `web/settings-fragment.json` |
| `browser_console_messages` may not surface uncaught `pageerror` exceptions the way the script's `page.on('pageerror')` listener does | M | M | Not empirically verified in research. Phase 3 documents this as a stated caveat in the ad hoc section; the batch script remains the authoritative gate, so the ad hoc path is never load-bearing for coverage |
| Edits land in the deployed `.claude/**` tree and are wiped on next regeneration | H | L | Every phase's file list uses absolute `agent-system/extensions/**` paths; Phase 5 verifies `git status` shows no `.claude/**` modifications |
| Task-number references leak into deliverable files | M | L | Phase 5 runs the repo-wide task-reference lint |
| The 9-tool list now exists in two places (`web`, `present`) and can drift | L | M | Accepted, already-documented cost per `mcp-server-ownership.md`'s carve-out; Phase 5 records it in the summary so a future maintainer updating one list checks the other |
| Wording sweep in Phase 4 drifts from the framing settled in Phase 3 | M | M | Phase 4 depends on Phase 3, so the canonical framing exists before downstream wording is touched |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`present/agents/slidev-assembly-agent.md` vs.
`present/context/project/present/talk/patterns/slidev-pitfalls.md`) and are parallel-safe.

---

### Phase 1: Present Extension Playwright Permission Plumbing [COMPLETED]

**Goal**: Give `present` its own scoped Playwright MCP grant, mirroring `web`'s established
shape, so the ad hoc debugging capability runs without prompting.

**Tasks**:
- [x] Create `agent-system/extensions/present/settings-fragment.json` containing a single
      `permissions.allow` array with exactly these 9 entries, copied verbatim from
      `agent-system/extensions/web/settings-fragment.json`:
      `mcp__playwright__browser_navigate`, `mcp__playwright__browser_snapshot`,
      `mcp__playwright__browser_take_screenshot`, `mcp__playwright__browser_console_messages`,
      `mcp__playwright__browser_network_requests`, `mcp__playwright__browser_click`,
      `mcp__playwright__browser_type`, `mcp__playwright__browser_find`,
      `mcp__playwright__browser_wait_for` *(completed)*
- [x] Do NOT add an `mcpServers` block — the `playwright` server is registered in user scope
      (`~/.claude.json`), independent of any extension; `web`'s fragment likewise declares only
      `permissions` *(completed)*
- [x] Add a `"settings"` entry to `agent-system/extensions/present/manifest.json`'s
      `merge_targets`, matching `web`'s exactly:
      `{"source": "settings-fragment.json", "target": ".claude/settings.local.json"}` *(completed)*
- [x] Add a `settings-fragment.json` line to the Architecture tree in
      `agent-system/extensions/present/README.md`, with a comment matching `web/README.md`'s
      phrasing ("Scoped MCP permission grants (merged into .claude/settings.local.json)") *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The safe-tool grant is asserted to be exactly 9 tool names and no more.
Confirm at implementation time by diffing the new `present/settings-fragment.json`'s
`permissions.allow` array against `web/settings-fragment.json`'s — they must be set-equal. A
wildcard entry, or any tool name absent from `web`'s list, fails this phase.

**Files to modify**:
- `agent-system/extensions/present/settings-fragment.json` - NEW: 9-tool `permissions.allow`
- `agent-system/extensions/present/manifest.json` - add `merge_targets.settings`
- `agent-system/extensions/present/README.md` - Architecture tree entry

**Verification**:
- `jq empty agent-system/extensions/present/settings-fragment.json` exits 0
- `jq empty agent-system/extensions/present/manifest.json` exits 0
- `jq -r '.merge_targets.settings.source' agent-system/extensions/present/manifest.json` prints
  `settings-fragment.json`, and that file exists on disk (this is the exact pairing
  `check-extension-docs.sh`'s `check_settings_merge_source_coverage` advisory looks for)
- `diff <(jq -S '.permissions.allow' web/settings-fragment.json) <(jq -S '.permissions.allow' present/settings-fragment.json)`
  produces no output
- No `"mcp__playwright__*"` wildcard string appears in the new fragment

---

### Phase 2: Authorize MCP Tools in slidev-assembly-agent's Contract [COMPLETED]

**Goal**: Add an explicit "MCP Tools" subsection to the agent's Allowed Tools section — the
settings-fragment grant governs prompting, not whether the agent's own contract authorizes the
call.

**Tasks**:
- [x] In `agent-system/extensions/present/agents/slidev-assembly-agent.md`, add an `### MCP Tools`
      subsection under `## Allowed Tools`, placed after the existing `### Build Tools`
      subsection and matching the sibling subsections' bullet style (`- ToolName - purpose`)
      *(completed)*
- [x] List exactly the 4 tools needed for ad hoc single-slide inspection, each with a one-line
      purpose: `mcp__playwright__browser_navigate` (open a single slide URL on the running dev
      server), `mcp__playwright__browser_snapshot` (read the rendered accessibility tree),
      `mcp__playwright__browser_take_screenshot` (capture the rendered slide),
      `mcp__playwright__browser_console_messages` (read console output for the slide)
      *(completed)*
- [x] Add a one-sentence scope note under the subsection stating these are for optional ad hoc
      single-slide inspection and do not replace the batch verification phase, cross-referencing
      `slidev-pitfalls.md` by filename and section heading (never by task number) *(completed)*
- [x] Leave the `### File Operations` and `### Build Tools` subsections unchanged *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: Exactly 4 of the 9 granted tools are asserted to be needed by this agent
(navigate, snapshot, take_screenshot, console_messages). Confirm at implementation time that
every tool named in this subsection is a member of the Phase 1 grant list — a tool named here but
absent from `present/settings-fragment.json` would prompt at runtime and is a defect.

**Files to modify**:
- `agent-system/extensions/present/agents/slidev-assembly-agent.md` - new `### MCP Tools`
  subsection under `## Allowed Tools`

**Verification**:
- Diff read-through confirms every changed hunk is prose/markdown inside the Allowed Tools
  section; no frontmatter, routing, or stage-logic hunk is touched
- All 4 tool names in the new subsection appear in `present/settings-fragment.json`'s allow list
- The file's YAML frontmatter is unchanged (`git diff` shows no hunk above the frontmatter
  terminator)
- No task-number reference introduced

---

### Phase 3: Written Justification and Ad Hoc MCP Inspection Workflow [COMPLETED]

**Goal**: Produce the acceptance criterion's required written justification for keeping the batch
script, and document the additive ad hoc MCP workflow as explicitly complementary. This phase
produces the task's primary deliverable.

**Tasks**:
- [x] In `agent-system/extensions/present/context/project/present/talk/patterns/slidev-pitfalls.md`,
      add a "Why This Phase Uses a Script, Not MCP Tools" subsection inside the existing
      `## Required Final Phase: Playwright Verification` section, placed after the existing
      "What the Script Checks" subsection *(completed)*
- [x] State the three justifications in that subsection, in order of weight: (1) **determinism
      and CI capability** — the script's exit code is the only mechanism here that gates without
      an agent or human in the loop, and no MCP tool has a headless entry point; (2) **cost at
      scale** — a faithful replication is ~4 tool round-trips per slide against one `node`
      invocation, so a 30-40 slide deck costs 120-160 tool calls; (3) **check fidelity** —
      the blank/error-text check depends on in-page evaluation, whose only equivalent tool is
      deliberately unpermissioned, and the accessibility-tree snapshot is a qualitative proxy
      rather than a mechanical threshold *(completed)*
- [x] Add a `## Ad Hoc Single-Slide Inspection via MCP` section as a sibling of (and after) the
      `## Required Final Phase: Playwright Verification` section, describing the workflow: with
      the dev server already running, navigate to `localhost:{port}/{slideNumber}`, then take a
      screenshot or read the accessibility snapshot to confirm a just-applied fix, plus read
      console messages for that slide *(completed)*
- [x] State in that new section, explicitly, that this **complements and does not replace** the
      required batch phase, and that a deck is not verified until the batch script exits 0
      *(completed)*
- [x] Record the open caveat in that section: console-message reading is not confirmed equivalent
      to the script's separate uncaught-exception listener, so ad hoc console output must not be
      treated as equal error coverage to a batch run *(completed)*
- [x] Do not modify the existing phase template code fence, the "What the Script Checks" list, or
      the "NixOS Playwright Workaround" section *(completed — confirmed via diff read-through)*
- [x] Do not introduce any line beginning `### Phase ` outside the existing fenced code block
      *(completed — grep count unchanged at 2)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/present/context/project/present/talk/patterns/slidev-pitfalls.md` -
  new justification subsection + new ad hoc MCP section

**Verification**:
- Diff read-through confirms every changed hunk is prose; the existing phase-template code fence
  is byte-identical before and after
- The justification subsection names all three rationales (determinism/CI, cost, fidelity)
- The ad hoc section contains an explicit "complements, does not replace" statement and the
  console-coverage caveat
- `grep -c '^### Phase ' <file>` is unchanged from its pre-edit value
- No task-number reference introduced

---

### Phase 4: Downstream Reference and Index Consistency Sweep [COMPLETED]

**Goal**: Make every remaining pointer to the verification script consistent with the
keep-plus-add outcome — nothing implying the script was migrated away, nothing pointing at a
removed path.

**Tasks**:
- [x] `present/context/project/present/domain/talk-modes-and-library.md`: update the
      `talk/templates/` table row so the verification script is described as the batch
      verification mechanism rather than a bare "a Playwright verification script" *(completed)*
- [x] `present/context/project/present/talk/templates/slidev-project/README.md`: update the
      `package.json` row so `playwright-chromium`'s dual role is explicit — required by Slidev's
      own PDF export **and** used by the batch verification script — so a future reader does not
      mistake it for a removable duplicate *(completed)*
- [x] `present/context/project/present/talk/index.json`: update the `playwright-verify` entry's
      `description` to reflect its status as the required batch verification gate (keeping the
      existing "copy to scripts/verify-slides.mjs in each project" guidance) *(completed)*
- [x] `present/index-entries.json`: update the `project/present/talk/templates/playwright-verify.mjs`
      entry's `summary` to match, and confirm its keyword list still resolves for discovery
      *(completed — keyword list unchanged: playwright, verify, slides)*
- [x] Do not change any `path`, `file`, or `name` field in either index — no path is being removed
      *(completed — confirmed via diff and jq re-query)*
- [x] Do not change `line_count` fields (the `.mjs` file itself is untouched) *(completed — line_count still 127)*

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: Exactly 4 downstream reference sites are asserted to need wording updates
(the two prose files and the two index files above), derived from the research's enumeration.
Confirm at implementation time by re-running
`grep -rni "playwright" agent-system/extensions/present agent-system/extensions/founder --include="*.md" --include="*.json"`
and checking every hit against the final outcome. If the sweep surfaces a site not on this list,
handle it rather than deferring to the asserted count; if a listed site turns out to need no
change, record it as a reasoned exclusion.

**Files to modify**:
- `agent-system/extensions/present/context/project/present/domain/talk-modes-and-library.md`
- `agent-system/extensions/present/context/project/present/talk/templates/slidev-project/README.md`
- `agent-system/extensions/present/context/project/present/talk/index.json`
- `agent-system/extensions/present/index-entries.json`

**Verification**:
- `jq empty` exits 0 for both edited JSON files
- `jq -r '.[] | select(.path | test("playwright-verify")) | .path' present/index-entries.json`
  still prints the original path (unchanged)
- Full grep sweep shows no remaining text implying the script was replaced, migrated away, or
  removed
- No task-number reference introduced

---

### Phase 5: Founder No-Op Assertion and Final Consistency Gate [COMPLETED]

**Goal**: Record the founder no-op as an explicit evidenced assertion, and run the full gate set
confirming the keep-plus-add outcome landed consistently.

**Tasks**:
- [x] Confirm by inspection that `founder/agents/deck-builder-agent.md`'s only Playwright content
      is the CLI availability probe gating the non-blocking PDF export stage, and that
      `founder/context/project/founder/patterns/slidev-deck-template.md`'s mentions are all
      `slidev export` PDF-capability documentation *(completed)*
- [x] Confirm neither founder file references `playwright-verify.mjs` or any per-slide
      verification phase *(completed)*
- [x] Make **no functional edit** to either founder file; record the no-op assertion, with the
      grep evidence, in the implementation summary so the task's declared file scope is not read
      as an unfinished TODO *(completed — see summary Follow-ups)*
- [x] Record in the summary that `founder` intentionally receives no MCP permission plumbing under
      this scope, and that a future task adding visual verification to its deck pipeline would
      need the identical treatment (fragment entry + Allowed Tools addition) *(completed)*
- [x] Record in the summary that the 9-tool safe list now exists in two extension fragments
      (`web`, `present`) and that a change to Playwright's safe-tool surface must update both
      *(completed)*
- [x] Record in the summary which acceptance branch was satisfied ("continued existence is
      explicitly justified in writing") and where that justification now lives, by filename and
      section heading *(completed)*
- [x] Run the repo-wide gates below *(completed — see Verification below; one unplanned
      line_count-mismatch fix applied and recorded as a deviation)*

**Timing**: 0.5 hours

**Depends on**: 2, 4

**Verification Tier**: full

**Files to modify**:
- None in the source store. Summary artifact only (written under
  `specs/026_migrate_slidev_verification_to_playwright_mcp/summaries/`).

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh` produces no new failures relative to its
  pre-change baseline (capture the baseline before Phase 1 if not already known)
- `bash .claude/scripts/check-task-references.sh` exits 0
- `git status --short` shows modifications only under `agent-system/extensions/present/**` and
  `specs/026_migrate_slidev_verification_to_playwright_mcp/**` — zero `.claude/**` paths and zero
  `agent-system/extensions/founder/**` paths
- `agent-system/extensions/present/context/project/present/talk/templates/playwright-verify.mjs`
  still exists and is unmodified (`git diff --stat` shows no hunk for it)
- `git diff -- agent-system/extensions/founder` is empty

---

## Testing & Validation

- [ ] `jq empty` passes on `present/settings-fragment.json`, `present/manifest.json`,
      `present/index-entries.json`, and `present/context/project/present/talk/index.json`
- [ ] `present/settings-fragment.json`'s allow list is set-equal to `web/settings-fragment.json`'s,
      with no wildcard entry
- [ ] `present/manifest.json`'s `merge_targets.settings.source` names a file that exists
- [ ] Every MCP tool named in `slidev-assembly-agent.md` is present in the grant list
- [ ] `slidev-pitfalls.md` contains both the written justification and the ad hoc MCP section,
      with the "complements, does not replace" statement
- [ ] Full `grep -rni playwright` sweep across `present` and `founder` is consistent with the
      keep-plus-add outcome
- [ ] `check-extension-docs.sh` shows no new failures
- [ ] `check-task-references.sh` exits 0
- [ ] `git status --short` shows no `.claude/**` modification and no `founder/**` modification
- [ ] `playwright-verify.mjs` is byte-unchanged

## Artifacts & Outputs

- `agent-system/extensions/present/settings-fragment.json` (new)
- `agent-system/extensions/present/manifest.json` (modified — `merge_targets.settings`)
- `agent-system/extensions/present/README.md` (modified — Architecture tree)
- `agent-system/extensions/present/agents/slidev-assembly-agent.md` (modified — MCP Tools)
- `agent-system/extensions/present/context/project/present/talk/patterns/slidev-pitfalls.md`
  (modified — written justification + ad hoc MCP section; the task's primary deliverable)
- `agent-system/extensions/present/context/project/present/domain/talk-modes-and-library.md`
  (modified — wording)
- `agent-system/extensions/present/context/project/present/talk/templates/slidev-project/README.md`
  (modified — wording)
- `agent-system/extensions/present/context/project/present/talk/index.json` (modified — description)
- `agent-system/extensions/present/index-entries.json` (modified — summary)
- `specs/026_migrate_slidev_verification_to_playwright_mcp/summaries/01_slidev-verification-mcp-plan-summary.md`
  (new — including the founder no-op assertion, the two-place drift note, and the acceptance-branch
  record)

**Explicitly unchanged** (asserted, not omitted): `playwright-verify.mjs`,
`slidev-project/package.json`, `founder/agents/deck-builder-agent.md`, and
`founder/context/project/founder/patterns/slidev-deck-template.md`.

## Rollback/Contingency

Every change is additive text or a new JSON file in the source store; no behavior, script, or
deployed artifact is altered. To revert: `git checkout -- agent-system/extensions/present` and
delete the untracked `agent-system/extensions/present/settings-fragment.json`. Because no deploy
is run by this plan, reverting the source store fully restores the prior state — the deployed
`.claude/**` tree is regenerated from the source store and was never touched.

If Phase 1's grant is later found to be too broad or too narrow, the fragment is a single file
with one array and can be adjusted independently of every other phase; no other phase's edits
depend on the grant's contents beyond the tool names cross-checked in Phase 2.

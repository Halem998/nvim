# Research Report: Task #782

- **Task**: 782 - Formal-domain context hygiene: minimize goal-state context for lean4 agents
- **Started**: 2026-07-03T14:00:00Z
- **Completed**: 2026-07-03T14:45:00Z
- **Effort**: 2-4 hours (matches task estimate)
- **Dependencies**: None (pairs with task 781, not blocking)
- **Sources/Inputs**:
  - Codebase: `.claude/agents/`, `.claude/extensions/lean/`, `.claude/extensions/cslib/`, `.claude/extensions/formal/`, `.claude/context/contracts/`, `.claude/context/patterns/context-exhaustion-detection.md`
  - `specs/state.json` (task 781, 782 descriptions)
  - Sibling deployed repo `/home/benjamin/Projects/cslib/.claude/` (installed copy of these extensions) and its `.claude/extensions.json`
  - MCP server instructions block for `lean-lsp` (tool list, decision tree)
- **Artifacts**:
  - This report: `specs/782_formal_domain_goal_state_context_hygiene/reports/01_formal-domain-context-hygiene.md`
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The lean4/cslib agent system lives entirely **inside this repo** (`~/.config/nvim/.claude/extensions/{lean,cslib,formal}`), but it is **installed as a separate, disconnected copy into at least one other repo** (`/home/benjamin/Projects/cslib/.claude/`, confirmed via that repo's `extensions.json` `source_dir` field pointing back at this repo). The SCOPE NOTE's premise is confirmed: any new contract authored here requires an explicit **re-install/sync flag**, because the target repo's `.claude/` is `.git`-excluded and only updated by re-running the extension loader.
- A formal-domain "context contract," analogous to the existing lean4 H2 override, should be added at **`.claude/extensions/lean/context/contracts/context-hygiene.md`** (new file, no core baseline to override) and referenced from the **Context References** list of all four hard agents that touch Lean goal states: `lean-research-hard-agent`, `lean-implementation-hard-agent`, `cslib-research-hard-agent`, `cslib-implementation-hard-agent`. It should also be added to the two corresponding **base** agents as a lighter-weight recommendation (see Recommendations).
- Two currently-blocked MCP tools directly conflict with the task's literal wording: `lean_file_outline` is **BLOCKED** (pending verification per `blocked-mcp-tools.md`) in every hard agent's "BLOCKED TOOLS" table. The new contract must recommend `Read` with targeted line ranges as the *primary* file-read-discipline mechanism, not `lean_file_outline`, with a note to re-enable it once unblocked.
- `lean_minimal_hypotheses` and `lean_term_goal` are **not currently documented anywhere** in the repo's lean4/cslib agent or context files (only `lean_term_goal` appears, in tool allow-lists, with no usage guidance) even though both are live MCP tools. The new contract is the natural home for concrete usage guidance on these two tools.
- Gap found: **research** hard agents (`lean-research-hard-agent.md`, `cslib-research-hard-agent.md`) do not reference `context-exhaustion-detection.md` at all — only the **implementation** hard agents do. Since the motivating failure (overflow on Lean tableau proofs) can occur during research dispatches too, this gap should be closed alongside the new contract.
- `cslib-implementation-hard-agent.md` and `cslib-research-hard-agent.md` currently reference the **core** `@.claude/context/contracts/anti-analysis.md`, not the lean4 override — but in every *installed* target repo (verified in `/home/benjamin/Projects/cslib`) the lean extension's install process **overwrites the shared core path in place**, so the reference resolves to lean4-flavored content at runtime anyway. The new context-hygiene contract should follow this same "new file, explicit reference" pattern rather than the "clobber the core path" pattern, since there is no generic (non-lean) baseline for goal-state hygiene to override.

## Context & Scope

Task 782 asks for a formal-domain context contract that reduces per-step context consumption for
lean4/cslib agents, driven by a motivating failure: five dispatches on Lean tableau proofs
overflowed context because full goal states were repeatedly pulled into the transcript. The task
requires four discipline clauses (goal-state query discipline, file-read discipline, hypothesis
pruning, and packaging as a context contract) plus a scope note asking to determine whether the
lean/cslib extension is authored in this repo or a separate one, and whether a sync flag is
needed. This report investigates the existing agent/extension/contract architecture to answer
those questions and to specify exactly where the new contract should live, what its clauses should
say, who consumes it, and what the sync flag should look like.

Out of scope for this report: writing the actual contract content into the agent files (that is
implementation work), and the checkpoint-before-overflow mechanism itself (task 781, not started,
depends on task 780).

## Findings

### Where the lean/cslib agent system is authored (repo topology)

- **This repo is the canonical source.** `.claude/extensions/lean/`, `.claude/extensions/cslib/`,
  and `.claude/extensions/formal/` all live under `/home/benjamin/.config/nvim/.claude/extensions/`.
  Nothing under `.claude/extensions/` is a git submodule; it is ordinary tracked content in this
  repo (`git -C nvim rev-parse --show-toplevel` resolves to this repo; no `.git*` markers inside
  the extension dirs).
- **Extensions are loaded by copying files, not by referencing this repo at runtime.**
  `.claude/docs/architecture/extension-system.md` documents a file-copy model: an extension
  picker (or `install-extension.sh <ext-dir>`) merges `index-entries.json` into
  `.claude/context/index.json`, symlinks/copies agents into `.claude/agents/`, skills into
  `.claude/skills/`, and copies `manifest.json`'s declared `context` directories (`project/lean4`,
  `contracts`) into `.claude/context/...` of the **target** `.claude/` tree.
- **Confirmed live example of a separate consuming repo**: `/home/benjamin/Projects/cslib` (the
  actual CSLib Lean checkout, a fork target of `leanprover/cslib`, where `/pr` submits real PRs)
  has its own full `.claude/` tree. Its `.claude/extensions.json` records, for every extension
  including `lean` and `cslib`:
  ```json
  "lean": { "source_dir": "/home/benjamin/.config/nvim/.claude/extensions/lean", "status": "active", ... }
  ```
  i.e. this nvim-config repo is explicitly recorded as the **source of truth**, and the cslib
  repo's copy is a point-in-time install snapshot.
- **The target repo's `.claude/` is excluded from its own git history**
  (`/home/benjamin/Projects/cslib/.git/info/exclude` contains `/.claude`), so there is no
  version-control-based propagation path — updates only reach the target repo when the extension
  loader is re-run there.
- **Verified the override mechanism is "copy-clobber," not "reference-by-path."** The lean
  extension's `manifest.json` declares `"context": ["project/lean4", "contracts"]`. On install,
  its `context/contracts/anti-analysis.md` (the lean4 override) is copied to the *same* path as
  the core file, `.claude/context/contracts/anti-analysis.md`, overwriting it in the target repo.
  Diffing confirmed `/home/benjamin/Projects/cslib/.claude/context/contracts/anti-analysis.md`
  is byte-identical to this repo's `.claude/extensions/lean/context/contracts/anti-analysis.md`
  (the lean override), not the generic core version at `.claude/context/contracts/anti-analysis.md`
  in this repo. This explains why `cslib-implementation-hard-agent.md` can safely reference the
  generic core path (`@.claude/context/contracts/anti-analysis.md`) and still get lean4-flavored
  content in any repo where the lean extension has actually been loaded.
- **Conclusion for the SCOPE NOTE**: yes, a sync flag is required. The contract must be authored
  in this repo under `.claude/extensions/lean/context/contracts/`, and every repo with the lean
  extension installed (confirmed: at least `/home/benjamin/Projects/cslib`; likely
  `/home/benjamin/Projects/cslib-refactor-prop_logic` and similar checkouts too, unverified in
  this pass) needs `install-extension.sh` re-run (or the extension picker's reload/update action)
  against the `lean` extension after this contract lands, to actually copy the new file over.

### Where agents/cslib live in THIS repo

- `.claude/agents/cslib-*.md` and the extension source
  `.claude/extensions/cslib/agents/cslib-*.md` are identical content — `.claude/agents/` is the
  installed/merged copy inside this repo's own operational `.claude/` tree (this repo also
  "installs" its own extensions locally so that Claude Code operating in this repo can dispatch
  `cslib-implementation-agent` etc. directly, e.g. for meta-work on the agent system itself, or
  because this repo is also used as a staging area).
- Five lean-related agents/extension dirs exist: `.claude/extensions/lean` (core lean4 agents +
  contracts), `.claude/extensions/cslib` (CSLib-specific agents, depends on `lean`), and
  `.claude/extensions/formal` (math/logic/physics research agents — **no hard-mode agents exist
  in `formal` today**; it provides only `formal-research-agent`, `logic-research-agent`,
  `math-research-agent`, `physics-research-agent`, none of which have `-hard` variants). This
  means the task's phrase "formal hard agents" should be read as "hard agents in the
  formal-verification domains (lean4, cslib)," not literally the `formal` extension package.

### Existing context-contract structure and consumption pattern

- Contracts live in two tiers:
  - **Core** (`.claude/context/contracts/{anti-analysis,reference-grounding,convergence,territory,wrap-up}.md`)
    — domain-agnostic, referenced by `general-*-hard-agent`.
  - **Extension override** (`.claude/extensions/lean/context/contracts/{anti-analysis,reference-grounding}.md`)
    — each begins with an explicit "This file overrides the core `X.md` contract for Lean4
    tasks" preamble and a `Base contract:` back-reference, and is registered in the extension's
    `index-entries.json` with `load_when.agents` pointing at exactly the hard agents that consume
    it (`lean-research-hard-agent`, `lean-implementation-hard-agent`).
  - The core `anti-analysis.md` itself has a "## Domain Specialization" footer explicitly
    inviting per-domain overrides at `.claude/extensions/{domain}/context/contracts/anti-analysis.md`
    — this is the exact analogy the task references.
- Every hard agent file both (a) lists the contract path in a `## Context References` bullet list
  near the top, marked `(MANDATORY)`, and (b) **inlines a short internalization summary** of the
  contract's key rules directly in the agent body (e.g. `lean-implementation-hard-agent.md` has an
  "## Anti-Analysis Contract (H2 Lean4) — Mandatory" section repeating the read-budget bullets).
  A new context-hygiene contract should follow the same two-touch pattern: full contract as a
  separate file, referenced + summarized inline in each consuming agent.
- Hard agents in this domain are explicitly **self-contained** ("Do NOT @-reference
  lean-implementation-agent... All lean-specific sections are included inline below"), so wiring
  the new contract means editing four files directly (two lean, two cslib hard agents), not a
  single shared include.

### Goal-state / tool-usage gaps relevant to the four discipline clauses

1. **Targeted goal queries** (task clause 1): `lean_goal`, `lean_term_goal` are already documented
   and used ("MOST IMPORTANT — use constantly!") in all four hard agents' Allowed Tools lists.
   `lean_minimal_hypotheses` — the tool the task explicitly names for hypothesis pruning — **does
   not appear anywhere** in `.claude/` (confirmed via repo-wide grep). It is a live tool exposed
   by the `lean-lsp` MCP server (see the MCP server instructions available to this session) but
   is absent from every agent's Allowed Tools list, the `mcp-tools-guide.md` reference, and the
   Search Decision Tree. This is a direct, concrete gap the new contract should close.
2. **File-read discipline** (task clause 2): `lean_file_outline` — the tool the task explicitly
   names for outline-based targeted reads — is **currently BLOCKED** in every one of the four
   hard agents' "BLOCKED TOOLS" tables and in `blocked-mcp-tools.md` / `mcp-fallback-table.md`
   (status: blocked pending verification testing, no confirmed unblock date). The documented
   alternative repo-wide is `Read` + `lean_hover_info`. The new contract must therefore prescribe
   **`Read` with an explicit line-range/offset window around the active proof** as the primary
   file-read-discipline mechanism, and note `lean_file_outline` as a fast-path to adopt once
   unblocked (with a pointer to `blocked-mcp-tools.md`'s "Unblocking Procedure").
3. **Hypothesis pruning** (task clause 3): no existing guidance beyond the general "read budget"
   language in the core/lean anti-analysis contracts, which is about *when* to write code, not
   about *what proof-state content* to keep resident in context. This clause is wholly new.
4. **Context-hygiene as a formal contract** (task clause 4): confirmed no such contract or
   pattern currently exists (grep for "goal state" / "context-hygiene" / "hypothesis pruning"
   across `.claude/context/` and `.claude/extensions/{lean,cslib,formal}/` returned nothing).
   `context-exhaustion-detection.md` (core pattern, not lean-specific) is the closest relative —
   it is *reactive* (detect pressure -> write a handoff) whereas task 782's contract is
   *preventive* (query/read/prune so pressure accumulates more slowly in the first place). The
   two are complementary, matching the task's own framing ("hygiene lowers the baseline context;
   checkpointing [781] handles the residual").
5. **Coverage gap in existing wiring**: `context-exhaustion-detection.md` is referenced by
   `lean-implementation-hard-agent.md` and `cslib-implementation-hard-agent.md` but **not** by
   `lean-research-hard-agent.md` or `cslib-research-hard-agent.md`. Since goal-state dumps happen
   during research dispatches too (proof exploration, `lean_state_search`/`lean_hammer_premise`
   calls that surface large candidate lists), this omission should be fixed in the same pass as
   adding the new contract.

### Task 781 relationship (checkpoint-before-overflow)

- Task 781 (`agent_context_overflow_checkpoint_handoff`, status `not_started`, depends on task
  780) generalizes `context-exhaustion-detection.md` into dispatched hard agents and defines a
  CHECKPOINT-BEFORE-OVERFLOW procedure. Task 782 is explicitly scoped as complementary and
  domain-specific: 782 lowers the *rate* of context accumulation for lean4/cslib specifically;
  781 handles the *residual* overflow generically for all hard agents. Neither blocks the other
  in state.json (782 has `"dependencies": []`); they can be implemented independently, but the
  new context-hygiene contract in 782 should explicitly cross-reference
  `context-exhaustion-detection.md` (per the pattern already used by the anti-analysis lean4
  override, which cross-references it in a code comment) so a future task-781 implementation
  finds a ready-made domain-specific companion.

## Decisions

- **New contract file location**: `.claude/extensions/lean/context/contracts/context-hygiene.md`
  (sibling to `anti-analysis.md` and `reference-grounding.md` in the same directory). It is a
  *new* contract, not an override of an existing core file — there is no generic
  "goal-state-hygiene" baseline for non-formal domains, so it should read as a standalone
  contract (own H-less identity, e.g. title "Goal-State Context Hygiene Contract — Lean4/CSLib")
  rather than claim to override anything.
- **Registration**: add an entry to `.claude/extensions/lean/index-entries.json` (path
  `contracts/context-hygiene.md`) with `load_when.agents` listing all four consumers:
  `lean-research-hard-agent`, `lean-implementation-hard-agent`, `cslib-research-hard-agent`,
  `cslib-implementation-hard-agent`. Add `contracts/context-hygiene.md` to the lean extension's
  `manifest.json` only implicitly (the manifest already declares the whole `contracts` context
  directory, so no manifest edit is needed — confirmed by inspecting `manifest.json`'s
  `provides.context: ["project/lean4", "contracts"]`, a directory-level declaration).
- **Consumers to wire explicitly** (add a `Context References` bullet + a short inline
  internalization section, following the existing anti-analysis pattern):
  1. `.claude/extensions/lean/agents/lean-research-hard-agent.md`
  2. `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`
  3. `.claude/extensions/cslib/agents/cslib-research-hard-agent.md`
  4. `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`
  (These four are the literal "lean/formal research + implementation hard agents" the task
  names. Since these are self-contained agent files with no shared include, each of the four
  needs its own edit — this is implementation-plan-sized work, not a single shared file change.)
- **Base (non-hard) agents**: recommend a lighter-weight, optional reference (not MANDATORY) in
  `lean-research-agent.md`, `lean-implementation-agent.md`, `cslib-research-agent.md`,
  `cslib-implementation-agent.md`, since goal-state overflow is not exclusive to hard-mode
  dispatches — but this is secondary to the task's explicit hard-agent scope and can be deferred
  to a follow-up if the planner wants to keep phase 1 tight.
- **Cross-repo sync flag**: the implementation plan for this task must include an explicit final
  step/note (not an automated script, since none currently exists for cross-repo push) instructing
  the user to re-run `.claude/scripts/install-extension.sh .claude/extensions/lean` (and, if
  `cslib`'s own context files are touched, `.../extensions/cslib`) inside every consuming repo —
  confirmed at minimum `/home/benjamin/Projects/cslib` — after this task's changes land here.
  This should be surfaced as a **flagged manual step in the plan/summary**, not silently assumed.
- **Content for the four discipline clauses** (to hand to the planner):
  1. *Goal-state query discipline*: prefer `lean_goal` at a specific line/column over broad
     queries; use `lean_minimal_hypotheses` (newly documented) to fetch only the hypotheses
     relevant to the current tactic instead of the full local context; use `lean_term_goal` for
     expected-type-only checks; summarize the returned goal in <=3 lines in the transcript rather
     than pasting the raw MCP response verbatim on every subsequent reasoning step; re-query
     precisely (by exact line/column) rather than re-requesting a broad goal dump.
  2. *File-read discipline*: `Read` with an explicit `offset`/`limit` bounding the active proof's
     region (the enclosing declaration plus a small margin), not whole-file reads of large
     `Theories/`/`Cslib/` files; do not re-read a region already read in the same dispatch (tie
     into the existing re-read detection signal in `context-exhaustion-detection.md`);
     `lean_file_outline` remains listed as BLOCKED — do not recommend it until
     `blocked-mcp-tools.md` marks it unblocked.
  3. *Hypothesis pruning*: prefer `lean_minimal_hypotheses` results over the full hypothesis list
     from a raw `lean_goal` call; do not carry forward hypotheses irrelevant to the current tactic
     step into subsequent reasoning turns; when summarizing a goal for the transcript, list only
     hypotheses actually referenced by the planned tactic.
  4. *Formal-domain context contract*: package clauses 1-3 as MUST/SHOULD rules with a short
     "Enforcement" paragraph (mirroring the anti-analysis contract's style), and an explicit
     cross-reference to `context-exhaustion-detection.md` for the reactive/checkpoint half of the
     story (task 781).

## Risks & Mitigations

- **Risk**: `lean_file_outline` gets unblocked upstream and the new contract's guidance goes
  stale (still telling agents to avoid it). *Mitigation*: contract should point at
  `blocked-mcp-tools.md` as the single source of truth for blocked-tool status rather than
  hard-coding the block into its own text, so unblocking only requires updating one file.
- **Risk**: the cross-repo sync step is forgotten, so the contract exists in this repo but never
  reaches `/home/benjamin/Projects/cslib` (or sibling checkouts), and the motivating failure
  recurs in the repo where it actually happened. *Mitigation*: make the sync step an explicit,
  checked item in the implementation plan and the completion summary, not an assumption.
- **Risk**: editing four self-contained hard-agent files by hand risks drift between them (e.g.
  lean's wording diverges from cslib's). *Mitigation*: plan should specify the exact shared text
  block to paste into all four Context References/inline sections, minimizing paraphrase drift.
- **Risk**: adding a fifth mandatory contract further inflates already-large hard-agent context
  budgets, working against the task's own goal of reducing context pressure. *Mitigation*: keep
  the contract itself short (target similar length to `anti-analysis.md`'s ~70 lines) and put the
  inline agent-body summary at 5-8 lines, matching the existing anti-analysis inline block size.

## Context Extension Recommendations

- **Topic**: `lean_minimal_hypotheses` tool usage guidance.
  **Gap**: not documented in `mcp-tools-guide.md`'s tool reference or any agent's Allowed Tools
  section, despite being a live `lean-lsp` MCP tool.
  **Recommendation**: add it to `mcp-tools-guide.md`'s "Core Tools" section and to the Allowed
  Tools list of all four hard agents (and ideally the two base agents) as part of implementing
  this task's contract.
- **Topic**: research-hard-agent context-exhaustion coverage.
  **Gap**: `lean-research-hard-agent.md` and `cslib-research-hard-agent.md` do not reference
  `.claude/context/patterns/context-exhaustion-detection.md`, unlike their implementation
  counterparts.
  **Recommendation**: add the reference during this task's implementation, since it is a natural
  companion edit to the same four files already being touched for the new contract.

## Appendix

- Search queries / commands used: `find .claude/agents -iname '*lean*' -o -iname '*cslib*'`,
  `find .claude/extensions -maxdepth 1 -iname '*lean*' ...`, `grep -rn "lean_minimal_hypotheses"
  .claude/`, `diff` between this repo's and `/home/benjamin/Projects/cslib`'s installed
  `anti-analysis.md`, `jq` queries against both repos' `manifest.json`/`extensions.json`.
- Files read in full: `.claude/context/contracts/anti-analysis.md`,
  `.claude/extensions/lean/context/contracts/anti-analysis.md`,
  `.claude/extensions/lean/context/contracts/reference-grounding.md`,
  `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`,
  `.claude/extensions/lean/agents/lean-research-hard-agent.md` (partial),
  `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`,
  `.claude/extensions/cslib/agents/cslib-research-hard-agent.md` (partial),
  `.claude/extensions/lean/manifest.json`, `.claude/extensions/cslib/manifest.json`,
  `.claude/extensions/lean/EXTENSION.md`, `.claude/extensions/cslib/EXTENSION.md`,
  `.claude/extensions/lean/index-entries.json`,
  `.claude/context/patterns/context-exhaustion-detection.md`,
  `.claude/extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md`,
  `.claude/extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md`,
  `.claude/docs/architecture/extension-system.md`,
  `/home/benjamin/Projects/cslib/.claude/extensions.json` (external repo, read-only).

## CSLib Extension

This project includes CSLib Lean 4 computer science library support via the cslib extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `cslib` | WebSearch, WebFetch, Read, lean-lsp MCP (inherited) | Read, Write, Edit, Bash (lake build, lake test, lake lint, lake exe checkInitImports, lake exe lint-style, lake shake) |
| `pr` | gh api, python3 zulip client, Read, Bash | Read, Write, Edit, Bash (git, lake build, lake test) |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-cslib-research | cslib-research-agent | opus | CSLib formalization research with lean-lsp MCP |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | CSLib proof implementation with CI verification |
| skill-pr-implementation | cslib-implementation-agent | sonnet | PR description preparation only -- produces pr-description.md, transitions task to [PR READY]; branch creation and CI handled by /pr |
| skill-cslib-research-hard | cslib-research-hard-agent | opus | Hard-mode CSLib research: adversarial verification (H4), BibKey citation grounding (H3) |
| skill-cslib-implementation-hard | cslib-implementation-hard-agent | sonnet | Hard-mode CSLib proof implementation: anti-analysis (H2), sorry_inventory (H9), territory (H7) |
| skill-pr-review-research | pr-review-research-agent | sonnet | Fetch and synthesize GitHub PR and Zulip discussion for review tasks |
| skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose pr-response.md and zulip-response.md for pr-type review tasks; falls back to legacy pr-description workflow when sources are absent |
| skill-cslib-vet | cslib-vet-agent | sonnet | Vet CSLib tasks against standards; run CI; create fix tasks with user confirmation |

### When to Use --hard for CSLib Tasks

Use `/research N --hard`, `/plan N --hard`, or `/implement N --hard` when one or more of
the following apply to a CSLib task:

1. **Previous research produced analysis-only output** with no actionable proof direction
   (no Lean code sketches, no Mathlib lemma candidates, no reuse check results)
2. **Task involves faithful transcription of a published CS paper** into Lean 4
   (literature-backed: bisimulation theorems, operational semantics rules, type system proofs)
3. **Task has been in [IMPLEMENTING] for 2+ dispatch cycles** without completing any phase
4. **Proof requires BibKey citation traceability** against CSLib's `references.bib`
5. **Task involves multiple parallel proof obligations** requiring territory contracts (H7)
   to prevent file conflicts between agents

**Hard mode adds** (over standard cslib skills):
- H2: Strict read budget -- first proof write within 20% of tool calls
- H3: BibKey verification against `references.bib` for all cited theorems
- H4: Adversarial self-verification pass challenging every recommendation
- H7: Territory contracts for parallel implementation phases
- H9: `sorry_inventory` in every orchestrator handoff JSON

**Cost impact**: `--hard` multiplies token cost ~3-5x over standard cslib skills.
Use for formally complex or previously-deflected tasks only.

### MCP Integration

The `lean-lsp` MCP server is inherited from the lean extension dependency and provides:
- Goal state inspection (`lean_goal`)
- Proof search (`lean_state_search`, `lean_hammer_premise`)
- Mathlib/CSLib lookup (`lean_loogle`, `lean_leansearch`, `lean_leanfinder`)

### CI Verification Pipeline

CSLib implementations must pass:
- `lake test` - Run CslibTests suite
- `lake exe checkInitImports` - Verify Cslib.Init imports
- `lake exe lint-style` - Style linting
- `lake shake --add-public --keep-implied --keep-prefix` - Dependency analysis

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/pr` | `/pr <task_number\|path\|description> [--draft] [--dry-run]` | Submit CSLib PR: create branch, run CI, create PR on leanprover/cslib (user-only) |
| `/pr` | `/pr --review <sources...>` | Create pr-type review task from GitHub PR URLs, Zulip URLs, or descriptions |
| `/pr` | `/pr N` (when task is [PR READY] with sources) | Push changes, post GitHub PR comment, optionally send Zulip message |
| `/vet` | `/vet <task_numbers> [focus_prompt]` | Quality-gate: vet completed CSLib task(s) against CONTRIBUTING.md, NOTATION.md, ORGANISATION.md; run CI; create fix tasks |

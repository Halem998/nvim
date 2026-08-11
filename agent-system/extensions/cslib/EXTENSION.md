## CSLib Extension

CSLib Lean 4 computer science library support: formalization research, proof implementation,
PR submission, PR review, and quality vetting. Inherits `lean-lsp` MCP from the lean extension.

### Routing

| Task Type | Skill | Agent | Model | Purpose |
|-----------|-------|-------|-------|---------|
| `cslib` | skill-cslib-research | cslib-research-agent | opus | Formalization research with lean-lsp MCP |
| `cslib` | skill-cslib-implementation | cslib-implementation-agent | sonnet | Proof implementation with CI verification |
| `cslib` | skill-cslib-research-hard | cslib-research-hard-agent | opus | Hard-mode research: H4 verification, H3 BibKey grounding |
| `cslib` | skill-cslib-implementation-hard | cslib-implementation-hard-agent | sonnet | Hard-mode implementation: H2 anti-analysis, H9 sorry_inventory, H7 territory |
| `cslib` | skill-cslib-vet | cslib-vet-agent | sonnet | Vet tasks against standards; run CI; create fix tasks |
| `pr` | skill-pr-implementation | cslib-implementation-agent | sonnet | PR description only -- writes pr-description.md, moves task to [PR READY] |
| `pr` | skill-pr-review-research | pr-review-research-agent | sonnet | Fetch and synthesize GitHub PR and Zulip discussion |
| `pr` | skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose pr-response.md and zulip-response.md; falls back to pr-description |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/pr` | `/pr <task_number\|path\|description> [--draft] [--dry-run]` | Submit CSLib PR: create branch, run CI, create PR on leanprover/cslib (user-only) |
| `/pr` | `/pr --review <sources...>` | Create pr-type review task from GitHub PR URLs, Zulip URLs, or descriptions |
| `/pr` | `/pr N` (task is [PR READY] with sources) | Push changes, post GitHub PR comment, optionally send Zulip message |
| `/vet` | `/vet <task_numbers> [focus_prompt]` | Quality-gate completed CSLib task(s) against CONTRIBUTING/NOTATION/ORGANISATION; run CI; create fix tasks |

### Context

- `context/project/cslib/domain/hard-mode-selection.md` - When to use `--hard`, contracts, cost
- `context/project/cslib/standards/ci-pipeline.md` - Ordered CI verification pipeline
- `context/project/cslib/tools/lake-commands.md` - Lake build, test, lint, and shake commands
- `context/project/cslib/domain/contributing-standards.md` - CONTRIBUTING.md standards summary

# Task 534: Sync Extension Routing Tables Across Command Docs

## Problem

The `/implement`, `/research`, and `/plan` command documentation contains hardcoded Extension-Based Routing Tables that list only a subset of available extension languages. The tables include `founder`, `general`, `meta`, `markdown`, `formal`, `logic`, `math`, `physics` but omit `lean`, `lean4`, `nix`, `neovim`, `typst`, `latex`, and others.

When extension manifest discovery fails (e.g., due to working directory issues), agents fall back to these tables. If the task type is not listed, the agent must reason against the spec to pick the right skill, causing significant hesitation and potential mis-routing.

## Impact

- Task 107 (`type:lean4`) caused ~30 lines of reasoning in the agent trace before it selected `skill-lean-implementation`
- The Anti-Bypass Constraint reinforces the wrong default by mentioning only `skill-implementer` or `skill-team-implement`
- Future extension types will cause the same ambiguity

## Solution

Update the routing tables in:
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`

Add ALL extension languages that have corresponding skills:
- `lean` / `lean4` -> `skill-lean-implementation` / `skill-lean-research`
- `nix` -> `skill-nix-implementation` / `skill-nix-research`
- `neovim` -> `skill-neovim-implementation` / `skill-neovim-research`
- `typst` -> `skill-typst-implementation` / `skill-typst-research`
- `latex` -> `skill-latex-implementation` / `skill-latex-research`
- `formal`, `logic`, `math`, `physics` -> keep existing `skill-implementer` / `skill-researcher`

Also update the Anti-Bypass Constraint to reference all applicable skills, not just `skill-implementer`.

## Acceptance Criteria

- [ ] All three command docs list all extension languages in their routing tables
- [ ] The Anti-Bypass Constraint mentions the full set of skills
- [ ] A Lean 4 task routed when manifest discovery fails correctly selects `skill-lean-implementation` without hesitation

## Effort

< 1 hour

## Type

meta

## Dependencies

None

## Key Files

- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`

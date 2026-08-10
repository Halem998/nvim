# Task 538: Add Automated Routing Table Validation

## Problem

Extension routing tables in command docs (`/implement`, `/research`, `/plan`) are manually maintained. When a new extension is added or an existing one changes its supported types, the tables become stale. This happened with `lean4`, `nix`, `neovim`, and other extensions.

## Impact

- Manual maintenance is error-prone
- Stale tables cause routing ambiguity (as seen with Task 107)
- No automated check prevents drift

## Solution

Create `.opencode/scripts/validate-routing-tables.sh` that:
1. Parses all extension manifests under `.opencode/extensions/*/manifest.json`
2. Extracts all task types from `routing.implement`, `routing.research`, and `routing.plan`
3. Parses command docs and extracts the hardcoded routing tables
4. Reports any task types in manifests that are missing from the tables
5. Reports any task types in tables that have no corresponding manifest entry

Integrate into CI or pre-commit hooks to prevent future drift.

## Acceptance Criteria

- [ ] Script parses manifests and command docs correctly
- [ ] Script reports missing entries
- [ ] Script reports orphaned entries
- [ ] Integrated into pre-commit or CI

## Effort

2-3 hours

## Type

meta

## Dependencies

Task 534 (sync tables first, then validate)

## Key Files

- `.opencode/scripts/validate-routing-tables.sh` (new)
- `.opencode/extensions/*/manifest.json`
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`

# Phase 1 baseline: pre-fix routing matrix

## Suite result (unmodified source)

`bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` -> **18/18 PASS**
(matches research report).

## File shape confirmed at read time

`command-route-agent.sh` is 72 lines. Effort-flag branch: lines 51-55 (`_route_block` selection).
`routing_lookup` call: line 57. `unset` list: line 69. EDGE CASES header block: lines 29-35.

## Pre-fix resolution matrix (op=research, `ROUTE_MANIFEST_ROOT=agent-system`)

| task_type       | standard (no flag)        | hard (`--hard`, pre-fix)     |
|-----------------|----------------------------|-------------------------------|
| typst           | typst-research-agent       | general-research-hard-agent (DOWNGRADE) |
| neovim          | neovim-research-agent      | general-research-hard-agent (DOWNGRADE) |
| nix             | nix-research-agent         | general-research-hard-agent (DOWNGRADE) |
| python          | python-research-agent      | general-research-hard-agent (DOWNGRADE) |
| latex           | latex-research-agent       | general-research-hard-agent (DOWNGRADE) |
| web             | web-research-agent         | general-research-hard-agent (DOWNGRADE) |
| z3              | z3-research-agent          | general-research-hard-agent (DOWNGRADE) |
| formal:logic    | logic-research-agent       | general-research-hard-agent (DOWNGRADE, compound key) |
| lean4           | lean-research-agent        | lean-research-hard-agent (correct — genuine hard block) |
| zzz-unrouted-test-type | general-research-agent (default) | general-research-hard-agent (correct — total miss, caller default honored) |

Defect reproduces on both a simple task_type (`neovim`, `nix`, ...) and a compound-key task_type
(`formal:logic`). `lean4` and the unrouted control are the two rows expected to be unchanged by
the fix (already correct).

## Reuse note

This file is task-scoped scratch, not a declared artifact. It is folded into the implementation
summary in Phase 3 and then deleted.

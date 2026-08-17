# Research Report: Fix the agent-side hard-mode routing downgrade

- **Task**: 63 - Fix the agent-side hard-mode routing downgrade that discards declared domain agents
- **Started**: 2026-08-17T17:56:18Z
- **Completed**: 2026-08-17T17:59:03Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/command-route-agent.sh`
  - `agent-system/extensions/core/scripts/command-route-skill.sh`
  - `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`
  - `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`
  - All 19 `agent-system/extensions/*/manifest.json` files
  - Live test run: `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary
- Divergence confirmed against current source at the file's actual current line numbers (not the
  drifted `~62-68` cited in the task description — see Findings). The defect is real and exactly
  as described: hard mode computes only `routing_agents_hard`, and on a miss overwrites with
  `default_agent`, silently discarding a declared `routing_agents` entry.
- Fix belongs in the **consumer** (`command-route-agent.sh`), not the shared ladder
  (`manifest-routing-lib.sh`). The skill-side resolver's precedent for the identical class of bug
  already lives in ITS OWN consumer script, not the shared lib — `routing_lookup()` is a
  single-block primitive by design; composing multiple blocks into a ladder is each consumer's
  job.
- Confirmed the count: **14 of 19** extensions declare `routing_agents` but no
  `routing_agents_hard`: `email`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`,
  `memory`, `nix`, `nvim`, `present`, `python`, `typst`, `web`, `z3`. (`core`, `cslib`, `lean`
  declare both; the remaining manifests declare neither block.)
- Ran the existing test suite live: 18/18 assertions currently PASS, including Assert 3
  (semantic), which explicitly pins the defect as correct behavior for `neovim`/`nix`. That
  assertion must be rewritten, not just its expected values tweaked — its own comment currently
  asserts the fall-through is the SAFE direction, which is exactly backwards post-fix.
- Recommended ladder for `command-route-agent.sh` hard mode: `routing_agents_hard` (hit) →
  `routing_agents` (hit, `via="hard-miss-standard-fallback"`) → `default_agent`
  (`via="default"`). This exactly mirrors `command-route-skill.sh`'s composition shape, minus the
  skill side's extra `-hard`-suffix-on-disk probe, which has no agent-side analogue (agent names
  are always explicit manifest declarations, never string-derived).
- Recommend adopting the `hard-miss-standard-fallback` via-string verbatim on the agent side, so
  `routing_trace` output is diagnostically identical in shape between the two resolvers.

## Context & Scope

Scope is confined to the three files named in the task description; no other file needs to
change to satisfy the acceptance criteria. All findings below were verified directly against the
current source-store files (not `.claude/**`, which is the disposable deploy target) and against
a live run of the existing test suite with `ROUTE_MANIFEST_ROOT=agent-system`.

## Findings

### 1. The divergence is confirmed, current line numbers differ from the task description

`agent-system/extensions/core/scripts/command-route-agent.sh:46-65` (not `~62-68` as the task
description estimated — the file has grown by a few lines of comments since that estimate was
written):

```
_route_op="$1"
_route_task_type="$2"
_route_default_agent="$3"
_route_effort_flag="${4:-}"

if [ "$_route_effort_flag" = "hard" ]; then
  _route_block="routing_agents_hard"
else
  _route_block="routing_agents"
fi

routing_lookup "$_route_block" "$_route_op" "$_route_task_type"
_route_via="$_ROUTE_LAST_VIA"

if [ -n "$_ROUTE_LAST_VALUE" ]; then
  AGENT_NAME="$_ROUTE_LAST_VALUE"
else
  AGENT_NAME="$_route_default_agent"
  _route_via="default"
fi
```

Only ONE `routing_lookup` call is ever made, against whichever single block the effort flag
selects. On hard mode with no `routing_agents_hard` entry, `_ROUTE_LAST_VALUE` is empty and
`AGENT_NAME` falls straight to `$_route_default_agent` — the standard `routing_agents` block is
never consulted at all.

By contrast, `command-route-skill.sh:46-90` computes the standard block FIRST (unconditionally,
regardless of effort flag), and only on `effort_flag=hard` attempts an UPGRADE on top of that
already-resolved value:
1. `routing_lookup "routing" ...` → sets `SKILL_NAME` to the hit, or to `$_route_default_skill`
   on a miss (`via="default"`). This happens whether or not hard mode is active.
2. If hard: `routing_lookup "routing_hard" ...`. A hit overrides `SKILL_NAME`. A miss falls to a
   `-hard`-suffix candidate IF `.claude/skills/${candidate}-hard/SKILL.md` exists on disk
   (`via="hard-append-fallback"`); otherwise `SKILL_NAME` is left at whatever step 1 already
   resolved (`via="hard-miss-standard-fallback"`), never at some third value.

So the skill side literally cannot regress below its own standard resolution under `--hard` — the
standard value is computed first and only ever overridden by something at least as specific. The
agent side computes only the hard block and, on a miss, replaces whatever it might otherwise have
found with the generic default. This is not a difference in fallback *philosophy* — it is a
missing computation. The agent side never even runs the standard lookup in hard mode, so it has
no value to fall back to except the caller's default.

### 2. Fix location: consumer (`command-route-agent.sh`), not the shared ladder

`manifest-routing-lib.sh`'s `routing_lookup()` is intentionally a **single-block** primitive: it
takes one `$block` argument (`"routing"`, `"routing_hard"`, `"routing_agents"`,
`"routing_agents_hard"`) and runs the four-step non-core/core × exact/compound scan against just
that one block, per its own header ("the one five-step first-match-wins precedence ladder every
routing consumer now shares" — but that ladder is scoped to resolving ONE block, not to composing
several). Nothing in the library composes two blocks together with a hard→standard→default
fallback order; that composition already lives entirely inside `command-route-skill.sh` (see
Finding 1's step 1/step 2 walkthrough) and nowhere in the shared library.

This is directly informative for where the fix belongs: the precedent for "hard mode falls back
to standard mode, never past it" is a **consumer-level** concern in this codebase already, not a
library-level one. Making `command-route-agent.sh` do the same composition — call
`routing_lookup` twice (once against `routing_agents`, once against `routing_agents_hard` when
hard mode is active) and combine the two results with an explicit ladder — requires zero changes
to `manifest-routing-lib.sh`. The library's `routing_lookup()` already supports being called
twice per invocation (that's exactly what `command-route-skill.sh` does); no new library function
is needed.

**Blast radius argument**: a library-level change would affect both `command-route-skill.sh` and
`command-route-agent.sh` (and the two `lint-routing-wiring.sh`/`test-routing-resolution.sh`
validation callers) even though only the agent side has the defect. A consumer-level change
touches exactly the one file with the actual bug, leaving the already-correct skill-side resolver
provably untouched. Recommend a consumer-only fix.

Adding a shared helper (e.g. `routing_lookup_with_fallback`) was considered and rejected for now:
it would have exactly one call site (the agent script), since the skill side's composition is not
a simple two-block fallback — it has the extra on-disk `-hard`-suffix probe step with no
agent-side analogue. Introducing a shared abstraction for a single caller is premature
generalization; if a third consumer with the identical two-block-fallback shape appears later,
extracting the helper then is a small, low-risk refactor with two real call sites to prove the
abstraction against.

### 3. Extensions declaring `routing_agents` without `routing_agents_hard` — verified inventory

Verified via `jq 'has("routing_agents")'` / `jq 'has("routing_agents_hard")'` against all 19
`agent-system/extensions/*/manifest.json` files:

| Extension | `routing_agents` | `routing_agents_hard` |
|---|---|---|
| core | yes | yes |
| cslib | yes | yes |
| lean | yes | yes (research op only: `lean4` → `lean-research-hard-agent`) |
| email | yes | **no** |
| epidemiology | yes | **no** |
| filetypes | yes | **no** |
| formal | yes | **no** |
| founder | yes | **no** |
| latex | yes | **no** |
| memory | yes | **no** |
| nix | yes | **no** |
| nvim | yes | **no** |
| present | yes | **no** |
| python | yes | **no** |
| typst | yes | **no** |
| web | yes | **no** |
| z3 | yes | **no** |

**14 of 19** manifests declare `routing_agents` but no `routing_agents_hard` — confirms the task
description's count exactly. The remaining 2 manifests (out of 19 total) declare neither block
(no agent-level routing at all for those extensions; not part of this defect's blast radius).

### 4. Test suite currently pins the defect — verified live

Ran `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` against the
unmodified source store: **18/18 PASS**, including:

```
[PASS] Assert 3 (semantic): neovim has no routing_agents_hard entry, hard-mode falls through to
       the caller default (general-research-hard-agent), not the standard block
[PASS] Assert 3 (semantic): nix has no routing_agents_hard entry, hard-mode falls through to
       the caller default (general-research-hard-agent), not the standard block
```

This is `test-routing-resolution.sh:239-249` (`for tt in neovim nix`). Its comment at
`:236-238` states the fall-through is protecting against "a precedence-direction / fallback-source
regression" — i.e. it currently treats reuse of the standard block as the bug. After the fix,
reuse of the standard block is the CORRECT, intended behavior, and this comment/assertion must be
inverted, not merely have its expected string swapped.

Confirmed via direct manifest lookups (`agent-system/extensions/nvim/manifest.json`,
`agent-system/extensions/nix/manifest.json`) what the corrected values must be:
- `nvim` manifest: `routing_agents.research.neovim = "neovim-research-agent"`
- `nix` manifest: `routing_agents.research.nix = "nix-research-agent"`

So under the corrected ladder, `research`/`neovim`/hard must resolve to `neovim-research-agent`
(via `hard-miss-standard-fallback`), and `research`/`nix`/hard must resolve to
`nix-research-agent` (via `hard-miss-standard-fallback`) — NOT `general-research-hard-agent`.

The lean4 half of Assert 3 (`test-routing-resolution.sh:251-265`) needs no behavioral change: it
already asserts `lean4` standard (`lean-research-agent`) and hard (`lean-research-hard-agent`)
differ, which remains true and meaningful post-fix — it is still the one live proof that a
`routing_agents_hard` HIT is read from a genuinely distinct block, not just an alias of standard.

**No fixture exists today for the third, true-total-miss rung of the ladder** (neither
`routing_agents_hard` nor `routing_agents` declares the task_type at all, so resolution must
still land on `default_agent`). Recommend adding one: any never-declared `task_type` string
(e.g. `"zzz-unrouted-test-type"`) called with `effort_flag=hard` must resolve to whatever
`default_agent` was passed. This is the one rung the current fixtures (`neovim`, `nix`, `lean4`)
do not exercise, since all three are declared somewhere.

## Decisions

- **Fix site**: `command-route-agent.sh` only. `manifest-routing-lib.sh` needs no change — its
  `routing_lookup()` primitive already supports being called twice per invocation, which is all
  the fix requires (see Finding 2).
- **Corrected ladder** (hard mode only; standard mode is unaffected by this fix):
  1. `routing_lookup "routing_agents_hard" ...` — hit wins, `via` = whatever
     `routing_lookup` reports (`noncore-exact`/`noncore-compound`/`core-exact`/`core-compound`).
  2. Miss → reuse the standard-block lookup result (`routing_lookup "routing_agents" ...`,
     computed unconditionally up front, mirroring `command-route-skill.sh`'s structure) — hit
     wins, `via="hard-miss-standard-fallback"`.
  3. Miss on both → `AGENT_NAME="$_route_default_agent"`, `via="default"`.
  - Standard (non-hard) mode keeps its current single-lookup behavior unchanged: `routing_agents`
    hit, else `default_agent`.
- **Concrete diff shape** for `command-route-agent.sh` (illustrative; the implementer should
  re-verify exact current line numbers, which will have shifted again by implementation time —
  this report's own line citations already required correction from the task description's
  estimate):

  ```bash
  routing_lookup "routing_agents" "$_route_op" "$_route_task_type"
  _route_std_value="$_ROUTE_LAST_VALUE"
  _route_std_via="$_ROUTE_LAST_VIA"

  if [ "$_route_effort_flag" = "hard" ]; then
    routing_lookup "routing_agents_hard" "$_route_op" "$_route_task_type"
    if [ -n "$_ROUTE_LAST_VALUE" ]; then
      AGENT_NAME="$_ROUTE_LAST_VALUE"
      _route_via="$_ROUTE_LAST_VIA"
    elif [ -n "$_route_std_value" ]; then
      AGENT_NAME="$_route_std_value"
      _route_via="hard-miss-standard-fallback"
    else
      AGENT_NAME="$_route_default_agent"
      _route_via="default"
    fi
  else
    if [ -n "$_route_std_value" ]; then
      AGENT_NAME="$_route_std_value"
      _route_via="$_route_std_via"
    else
      AGENT_NAME="$_route_default_agent"
      _route_via="default"
    fi
  fi
  ```

  Remember to add `_route_std_value _route_std_via` to the trailing `unset` list alongside the
  existing `_route_op _route_task_type _route_default_agent _route_effort_flag _route_block
  _route_via SCRIPT_DIR_ROUTE_AGENT` — the script's own contract (its NOTE header) requires no
  state leak into the sourcing shell. Note `_route_block` becomes unused under this shape and can
  be dropped from both the body and the unset list.
- **Header comment**: the script's own "EDGE CASES" comment block
  (`command-route-agent.sh:29-35`) documents the CURRENT (defective) behavior as intentional
  ("deliberately NOT to the standard ... block ... matching the behavior of the case tables this
  script replaces"). This must be rewritten to describe the corrected three-rung ladder — leaving
  stale documentation that asserts the old behavior was deliberate would misdirect the next
  reader exactly the way it evidently already did once.
- **Trace vocabulary**: adopt `hard-miss-standard-fallback` verbatim (question 4) — reusing the
  skill side's exact string, not inventing an agent-specific synonym, keeps `routing_trace`
  output diagnostically comparable via grep/log-scanning across both resolvers. No other new via
  strings are needed; the hard-hit and total-miss cases already reuse `routing_lookup`'s own via
  vocabulary and `"default"` respectively, identically to the skill side.
- **Test amendment**: rewrite `test-routing-resolution.sh:236-249`'s comment and assertion body.
  New semantic content:
  - `neovim`/`nix`, hard mode, op=research → expect `neovim-research-agent` /
    `nix-research-agent` respectively, proving hard mode falls back to the extension's OWN
    standard agent, not the caller's generic hard default, when no `routing_agents_hard` entry
    exists.
  - Add an explicit code comment recording the coupling the task description asked for: `nix` is
    itself one of the 14 extensions currently lacking a `routing_agents_hard` block, so if a
    future task adds one for `nix`, this fixture's expected value must move from
    `nix-research-agent` (standard-fallback path) to whatever `nix`'s new
    `routing_agents_hard.research.nix` value is (hard-hit path) — the fixture is pinned to
    `nix`'s *current* absence of a hard block, not to `nix` as a stable "no-hard-block" example
    in perpetuity.
  - Add a fourth semantic case: a never-declared task_type with hard mode still resolves to the
    passed-in `default_agent` (true total-miss rung — see Finding 4's last paragraph).
  - Keep the lean4 assertion (`:251-265`) unchanged; it already validates the corrected contract
    (hard HIT differs from standard HIT) with no modification needed.

## Risks & Mitigations

- **Risk**: a caller elsewhere in the codebase relies on the current (defective) fall-through-to-
  default behavior as if it were intentional. **Mitigation**: grepped every `SKILL.md` for
  `command-route-agent.sh` call sites — only `skill-orchestrate` (standard, empty effort flag) and
  `skill-orchestrate-hard` (hard, `general-research-hard-agent`/`planner-hard-agent`/
  `general-implementation-hard-agent` defaults) call this script. Both defaults are exactly the
  values the corrected ladder's rung 3 (true total miss) preserves; rung 2 (standard-block
  fallback) only activates for task types that already have a MORE specific standard agent
  declared, which is strictly better than either caller's generic default. No caller is weakened.
- **Risk**: `_route_block` variable removal changes script structure enough to need re-review of
  the full file, not just the diff shown. **Mitigation**: flagged explicitly in Decisions above;
  the implementer should re-read the full current file rather than patch mechanically against
  this report's line numbers, which have already drifted once between the task description and
  this report.
- **Risk**: Assert 2 (agent existence) or Assert 1 (skill resolution) could be affected by this
  change. **Mitigation**: neither assertion touches `routing_agents`/`routing_agents_hard`
  fallback composition — Assert 1 only exercises `command-route-skill.sh` (unrelated file, not
  touched by this fix), and Assert 2 only checks that every manifest-declared agent name exists
  on disk (unaffected by fallback ORDER). Only Assert 3's semantic sub-checks need amendment.

## Context Extension Recommendations
- **Topic**: routing ladder composition conventions.
- **Gap**: `context/guides/manifest-routing-schema.md` and `context/guides/hard-mode-routing.md`
  (referenced from the project's root CLAUDE.md's "Routing Mechanism" section) describe the
  single-block `routing_lookup` ladder but do not document the two-block hard→standard→default
  composition pattern `command-route-skill.sh` already implements — which is exactly the pattern
  this fix replicates on the agent side. Not read directly in this research pass (out of the
  declared file scope), but worth a follow-up doc pass once this fix lands, so a future third
  consumer with the same shape has a documented pattern to follow instead of re-deriving it from
  `command-route-skill.sh`'s source.

## Appendix
- Search queries / commands used:
  - `jq 'has("routing_agents")'` / `jq 'has("routing_agents_hard")'` across all
    `agent-system/extensions/*/manifest.json`
  - `jq '.routing_agents' agent-system/extensions/{nvim,nix}/manifest.json`
  - `jq '.routing_agents, .routing_agents_hard' agent-system/extensions/lean/manifest.json`
  - `bash agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` (live run,
    18/18 PASS on unmodified source)
  - `grep -rn "command-route-agent.sh" agent-system/extensions/*/skills/*/SKILL.md`

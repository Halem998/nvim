# Teammate A Findings: Eager-Load Surface Measurement and Narrowing Approach

**Task**: 36 - Audit context loading efficiency
**Angle**: PRIMARY - measure and map the actual eager-load surface, propose concrete narrowing
**Date**: 2026-08-11
**Method**: Empirical - every number below is from `wc -l`/`wc -c` on this repo's deployed and source-store files, cross-checked against the context actually injected into this session at start.

## Key Findings

### 1. The eager-load channels, verified empirically

This session's own injected context (observable directly) consisted of exactly: 3 CLAUDE.md files, 5 nix context files, and 3 rules files. That set is fully explained by two harness mechanisms, and it falsifies/refines several assumptions:

**Channel A - CLAUDE.md `@`-imports, resolved relative to the importing file's directory.**
The generated `.claude/CLAUDE.md` contains 20+ `@`-references, but only the ones written in *relative* form (`@context/project/nix/...`) actually resolve, because resolution is relative to `.claude/` (the containing file's directory). References written as `@.claude/context/...` or `@specs/...` resolve to `.claude/.claude/...` / `.claude/specs/...`, which do not exist, and **silently load nothing**. Proof:

- Loaded this session: all 5 nix files referenced as `@context/project/nix/*` (relative form).
- NOT loaded: email domain files (`@.claude/context/project/email/...`), neovim context (`@.claude/context/project/neovim/...`), all 8 "Rules References" `@.claude/rules/*` lines, `@.claude/context/repo/project-overview.md`, `@README.md`, `@specs/TODO.md`, `@.claude/docs/docs-README.md` - every one uses the broken `.claude/`-prefixed or root-relative form.

So the repo currently has **accidental laziness**: most declared "imports" are broken and therefore free, while the nix extension's correctly-relative imports fire unconditionally in every session regardless of task type.

**Channel B - Rules files: `paths:` frontmatter gates loading; NO frontmatter = unconditional session-start load.**
Of 12 deployed rules, 9 have YAML `paths:` globs and load only when a matching path is touched (none loaded at session start, including `pr-prohibition.md` with `paths: "**/*"` - it fires on first touched path, not at t=0). The 3 rules with **no frontmatter at all** loaded unconditionally at session start:

| Rule (deployed) | chars | Body says it applies to | Frontmatter |
|---|---|---|---|
| `no-task-references-in-deliverables.md` | 8,821 | everything except specs/** | none -> always loads |
| `neovim-lua.md` | 2,620 | `lua/**/*.lua`, `after/**/*.lua`, `*.lua` | none -> always loads |
| `source-store-deploy-boundary.md` | 2,286 | writes targeting `.claude/**` | none -> always loads |

Each states its scope in prose ("## Path Pattern / Applies to:") but lacks the machine-readable frontmatter that would defer it.

**Channel C - Command-body `@`-refs, loaded at command invocation.** `/task`'s body (37,465 c) carries `@.claude/context/patterns/topic-assignment-pattern.md` (11,310 c), matching the task description's observation. Only 2 of 22 commands have `@`-refs (`task.md`: 1, `review.md`: 2). This channel is per-command (conditional), not session-start.

**Channel D - index.json `load_when` is advisory only.** `grep -rln load_when .claude/scripts .claude/skills` finds only validators/installers (`validate-wiring.sh`, `validate-index.sh`, `install-extension.sh`, lint/tests) - **no runtime consumer performs loading from it**. Only 3 of 190 entries have `always: true` (three core READMEs, 334 lines total). The index is a pull-based catalog for agents, not an eager channel. No optimization needed here.

### 2. Ranked table of the measured session-start eager surface (unconditional, every session)

| Rank | File | chars | ~tokens (c/4) | Channel |
|---|---|---:|---:|---|
| 1 | `.claude/CLAUDE.md` (generated) | 34,501 | 8,625 | native CLAUDE.md load |
| 2 | `.claude/rules/no-task-references-in-deliverables.md` | 8,821 | 2,205 | B: no frontmatter |
| 3 | `.claude/context/project/nix/domain/flakes.md` | 5,124 | 1,281 | A: relative @-import |
| 4 | `.claude/context/project/nix/tools/home-manager-guide.md` | 4,045 | 1,011 | A |
| 5 | `.claude/context/project/nix/tools/nixos-rebuild-guide.md` | 3,602 | 901 | A |
| 6 | `.claude/context/project/nix/README.md` | 3,227 | 807 | A |
| 7 | `CLAUDE.md` (nvim root) | 3,046 | 762 | native |
| 8 | `.claude/rules/neovim-lua.md` | 2,620 | 655 | B |
| 9 | `.claude/rules/source-store-deploy-boundary.md` | 2,286 | 572 | B |
| 10 | `.claude/context/project/nix/tools/mcp-nixos-integration.md` | 1,885 | 471 | A |
| 11 | `/home/benjamin/.config/CLAUDE.md` | 769 | 192 | native |
| | **TOTAL session-start** | **69,926** | **~17,482** | |

Per-`/task` invocation adds: `task.md` body 37,465 c + `topic-assignment-pattern.md` 11,310 c = 48,775 c (~12,194 tok). Session-start + first `/task` = ~29.7k tokens before any work - consistent with (larger than) the ~19k observation in the task description, which was taken with a different extension set loaded.

Generated-CLAUDE.md internal breakdown (largest sections, from awk over `## ` boundaries): Command Reference 5,523 c; Skill-to-Agent Mapping 5,494 c; Hard Mode 4,492 c; Memory Extension 4,055 c; Task Management 3,841 c; Email Extension 2,177 c. Core merge-source contributes 25,159 c of the 34,501 c; extension EXTENSION.md blocks the rest.

### 3. Mechanism behind the "unrelated literature/nix/present context" observation - confirmed

Extensions declare their CLAUDE.md section in `agent-system/extensions/<ext>/EXTENSION.md` (or `merge-sources/claudemd.md`), which is concatenated into the generated `.claude/CLAUDE.md`. Whether their context imports fire depends purely on the accidental path form used:

| Extension | Import form in source | Resolves? | Cost when extension loaded |
|---|---|---|---:|
| nix (`EXTENSION.md`) | `@context/project/nix/*` (relative) | **YES - fires every session** | 17,883 c (~4.5k tok) |
| present (`EXTENSION.md`) | `@context/project/present/*` (relative) | **YES when loaded** | 5 files |
| literature (`merge-sources/claudemd.md`) | `@context/project/literature/*` (relative) | **YES when loaded** | 22,903 c (~5.7k tok) |
| email (`EXTENSION.md`) | `@.claude/context/project/email/*` | no (silently broken) | 0 (would be 51,612 c!) |
| nvim (`EXTENSION.md`) | `@.claude/context/project/neovim/*` | no (silently broken) | 0 (would be 13,064 c) |

This is exactly why a `/task` invocation in a repo with literature/nix/present loaded saw all three extensions' context: **relative-form `@`-imports in EXTENSION.md/merge-sources fire unconditionally at session start for every command and task type**. There is no task-type or command gating anywhere in this channel.

**Critical warning**: the broken `@.claude/...` form is currently load-bearing. "Fixing" email/nvim imports to the relative form would ADD ~64.7k chars (~16k tokens) to every session. The fix must go the other direction (see below).

## Recommended Approach

All edit targets are **source-store paths** (`.claude/**` is a regenerated deploy artifact).

### P1 - Convert relative `@`-imports in extension sections to plain path mentions (cheapest, biggest win)

An `@path` in a loaded CLAUDE.md auto-resolves; the same path in backticks or prose loads nothing but remains discoverable. Change `@context/project/nix/README.md` -> `` `context/project/nix/README.md` `` (or "See `.claude/context/project/nix/README.md`"):

- `agent-system/extensions/nix/EXTENSION.md` - 5 lines. **Saves 17,883 c (~4.5k tok) per session, 26% of the session-start surface.**
- `agent-system/extensions/literature/merge-sources/claudemd.md` - 5 lines. Saves ~5.7k tok/session wherever literature is loaded.
- `agent-system/extensions/present/EXTENSION.md` - 5 lines. Same defect class.
- Also standardize the already-broken `@.claude/...` refs in `agent-system/extensions/email/EXTENSION.md`, `agent-system/extensions/nvim/EXTENSION.md`, and `agent-system/extensions/core/merge-sources/claudemd.md` (Rules References at line 301, Context Imports at line 330, Quick Reference `@specs/*` lines) to the same plain-path convention - zero token delta, but removes the trap where a future "path fix" silently adds 16k tokens.

The routing/agent system already loads domain context lazily per dispatch (skill preflight, index queries), so nothing is lost: nix research/implementation agents load `context/project/nix/*` on demand.

### P2 - Add `paths:` frontmatter to the three frontmatter-less rules

Each already states its scope in prose; encode it:

- `agent-system/extensions/nvim/rules/neovim-lua.md` -> `paths: ["lua/**/*.lua", "after/**/*.lua", "*.lua"]` (pure win: -655 tok from every non-Lua session)
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` -> `paths: [".claude/**", "agent-system/**"]` (-572 tok at session start; still fires exactly where it matters)
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` -> `paths: ["agent-system/**", "lua/**", ".memory/**", ".opencode/**", ".claude/**"]` - the four deliverable trees it names plus deploy tree (-2,205 tok at session start; enforcement is unaffected since the blocking PreToolUse hook + lint gate are the real guards)

Combined: defers 13,727 c (~3.4k tok) from session start to touch-time.

### P3 - Slim the generated `.claude/CLAUDE.md` (source: `agent-system/extensions/core/merge-sources/claudemd.md`)

The 34.5k-char generated file is the single largest unconditional load (~8.6k tok). Candidates: move Hard Mode routing-mechanism detail (~3k of its 4.5k c) into `context/guides/hard-mode-routing.md` (which it already cites) keeping a 10-line summary; compress the Skill-to-Agent tables (5.5k c) to the mapping rows only. Realistic saving: ~2-2.5k tok/session. Medium effort, needs care since orchestrator commands rely on this file.

### P4 (optional) - `/task` command body

`agent-system/extensions/core/commands/task.md` (37.5k c) + its `@topic-assignment-pattern.md` import (11.3k c) cost ~12.2k tok per invocation. The `@`-import is arguably justified (needed on every create path); the body itself is the outlier among commands (only `todo.md` at 49k and `orchestrate.md` at 42k are larger). Defer unless command-body slimming becomes a broader effort.

**Net effect of P1+P2 alone**: session-start surface drops from ~17.5k to ~9.5k tokens (-46%), via ~13 lines of source-store edits with zero behavior loss.

## Evidence / Examples

Commands run (from `/home/benjamin/.config/nvim`):

```bash
# Sizes of loaded files
wc -l -c /home/benjamin/.config/CLAUDE.md CLAUDE.md .claude/CLAUDE.md
wc -l -c .claude/context/project/nix/{README.md,domain/flakes.md,tools/*.md} .claude/rules/{source-store-deploy-boundary,no-task-references-in-deliverables,neovim-lua,pr-prohibition}.md
# -> 69,926 chars total session-start surface (table above)

# Rules frontmatter census
for f in .claude/rules/*.md; do echo "== $f"; sed -n '1,8p' "$f" | grep -E 'paths:|^---'; done
# -> exactly 3 rules lack frontmatter; exactly those 3 appear in this session's injected context

# @-ref resolution proof
grep -n '@' .claude/CLAUDE.md          # 20+ refs; only @context/project/nix/* (relative) loaded
ls .claude/.claude 2>/dev/null          # does not exist -> @.claude/... refs cannot resolve
# email/neovim/rules/README @-refs all use the non-resolving form; none appeared in session context

# Extension source forms
grep -oE '@[A-Za-z0-9._/-]+' agent-system/extensions/{nix,email,nvim,present}/EXTENSION.md agent-system/extensions/literature/merge-sources/claudemd.md
# -> nix/present/literature: relative (resolving); email/nvim: .claude-prefixed (broken)

# Command-body @-refs (all 22 commands)
for f in .claude/commands/*.md; do grep -oE '@[A-Za-z0-9._/-]+\.(md|json)' "$f"; done
# -> only task.md (1 ref) and review.md (2 refs)

# index.json load_when consumers
grep -rln 'load_when' .claude/scripts/ .claude/skills/
# -> only validators/installers/tests; no runtime loader
jq '[.entries[] | select(.load_when.always == true)] | length' .claude/context/index.json   # -> 3

# Generated CLAUDE.md section breakdown
awk '/^## /{if(name)print name": "sum; name=$0; sum=0}{sum+=length($0)+1}END{print name": "sum}' .claude/CLAUDE.md | sort -t: -k2 -rn
```

Ground truth cross-check: the complete list of files injected into this session at start (visible to the agent as its own loaded context) is exactly the 11 files in the ranked table - no more, no less - which independently validates the channel analysis.

## Confidence Level

**High** for: the ranked table (direct measurement); the relative-vs-`.claude/`-prefixed resolution behavior (double-confirmed: nix relative refs loaded while root-relative equivalents would not exist; `.claude/`-prefixed refs to existing files did not load); the rules frontmatter gating (exact 3/3 correspondence between no-frontmatter rules and session-loaded rules); index.json being advisory (grep over all consumers).

**Medium** for: the exact composition of the original ~19k `/task` observation (different extension set was loaded then; the mechanism is confirmed, the exact file list is reconstructed); P3 savings estimates (depend on how much Hard Mode/mapping detail orchestrator commands actually need inline).

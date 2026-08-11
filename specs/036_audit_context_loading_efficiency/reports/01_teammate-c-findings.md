# Teammate C (Critic) Findings: Context-Loading Efficiency Audit

**Task**: 36 - Audit context-loading efficiency across the agent system and its extensions
**Role**: Critic — interrogate the premise, harm model, assumptions, and scope of the audit itself
**Date**: 2026-08-11
**Method**: Direct measurement of the eager-load surface observed in this very session (a subagent
session in this repo), byte/token counts via `wc`, frontmatter inspection of all deployed rules,
@-reference extraction from generated CLAUDE.md and source-store merge sources.

## Key Findings

### 1. The premise is approximately reproducible — but under-specified and unstable

Measured eager-load surface of THIS session (extensions active: core, email, nvim, nix, memory):

| Component | Bytes | Est. tokens (chars/4) |
|---|---|---|
| `/home/benjamin/.config/CLAUDE.md` | 769 | ~190 |
| `nvim/CLAUDE.md` | 3,046 | ~760 |
| `.claude/CLAUDE.md` (generated) | 34,501 | ~8,600 |
| Nix context x5 (README, flakes, 3 tool guides) | 17,883 | ~4,470 |
| Rules lacking `paths:` frontmatter x3 | 13,727 | ~3,430 |
| **Total** | **69,926** | **~17,500** |

So "~19k" is the right order of magnitude for the session baseline (the delta is explained by a
different extension set at observation time — see finding 3). But the claim is under-specified in
three ways the audit must fix before "optimizing":

- **Unit unstated** (tokens? bytes? — 19k bytes would be trivially small; 19k tokens matches).
- **Extension-set-dependent**: literature and present are NOT active today (`.claude-extensions.json`
  shows core/email/nvim/nix/memory). The observed session had literature+present loaded. The number
  is not a property of the system; it is a property of the picker state at that moment.
- **Baseline vs per-command conflation**: the ~17.5k baseline is paid by EVERY session, `/task` or
  not. `/task` itself then adds `commands/task.md` (37,465 bytes, ~9.4k tokens) plus
  `topic-assignment-pattern.md` (11,310 bytes, ~2.8k tokens). If "before doing any work" includes
  the command body, the real pre-work injection is ~30k tokens, and the single largest line item is
  the command file — which the task framing never mentions.

**Relative scale**: ~17.5-30k tokens is <3% of a 1M-token window and ~10-15% of a 200k window. As a
raw-capacity problem it is negligible. The value proposition must rest on something other than
"context is filling up" — see finding 2.

### 2. The harm model in the task framing is mostly wrong; the real harms are different

Candidate harms, judged:

- **Token cost: largely neutralized by prompt caching.** This session's requests use a 1-hour
  prompt-cache TTL, and the eager CLAUDE.md tree sits in the cached prefix. Repeated invocations
  within TTL pay ~0.1x for that prefix. A *stable* 17.5k prefix is cheap; what is expensive is a
  *changing* prefix. This inverts the naive conclusion in one concrete place: the broken
  `@specs/TODO.md` / `@specs/state.json` / `@specs/errors.json` imports in the generated CLAUDE.md
  (they resolve to nonexistent `.claude/specs/...`, so they load nothing) are **accidentally
  protective** — if a well-meaning fix made them resolve, every task-status flip would rewrite the
  cached prefix and invalidate cache for every subsequent session and subagent. Any optimization
  task must carry an explicit "volatile files must never enter the eager surface" constraint, or
  the "fix" will cost more than the disease.
- **Latency**: reading ~20k cached tokens is a minor prefix cost. Not a defensible motivation.
- **Attention dilution: the one real harm, and it is multiplied by subagents, not by tokens.**
  Every dispatched agent re-receives the full baseline. This critic session — a meta-task research
  agent — carries ~4.5k tokens of `nixos-rebuild` and `home-manager` CLI tutorials that are pure
  noise for the work. An `/orchestrate` run with ~10 dispatches injects the baseline 10 times;
  cache blunts the *cost* multiplier but does nothing for the *dilution* multiplier, because each
  agent must attend past the same irrelevant material. If the audit wants a defensible metric, it
  is "fraction of eagerly injected instruction-bearing text irrelevant to the dispatched task
  type," not raw size.
- **Instruction-following degradation**: plausible (this session's system context contains 40+
  distinct instruction documents), but unquantified. The audit should not claim it without an
  experiment; it should claim relevance hygiene instead.

### 3. The audit's biggest blind spot: the eager surface is UNMANAGED, not merely large — roughly half the declared imports are silently broken

Empirically established in this session: `@`-imports in a CLAUDE.md resolve **relative to the file
containing them**. Two same-format list items in `.claude/CLAUDE.md` prove it:

- `@context/project/nix/README.md` (line 505) → resolves to `.claude/context/project/nix/README.md`
  → **loaded** (present in this session's context; the file exists nowhere else).
- `@.claude/rules/state-management.md` (line 313) → resolves to `.claude/.claude/rules/...` →
  **does not exist, silently not loaded** (absent from this session despite existing at
  `.claude/rules/state-management.md` from repo root).

Consequences, all verified against this session's actual injected context:

- The entire "Rules References" @-list (8 rules) is a dead loading path. CLAUDE.md's own text calls
  the list "a curated subset, not the sole loading path" — in reality it is **not a loading path at
  all**.
- "Context Imports" (`@.claude/context/repo/project-overview.md`, `@README.md`) load nothing;
  `project-overview.md` exists on disk but never auto-loads.
- The Email extension's five safety pointers (`@.claude/context/project/email/domain/safety-invariants.md`
  etc.) load nothing, though every target exists at `.claude/context/project/email/...`. If those
  were intended eager loads (the section says "non-negotiable... see before any email work"), a
  safety-relevant import is silently broken.
- The Neovim extension's three `@.claude/context/project/neovim/...` imports: same failure.
- Meanwhile nix (source: `agent-system/extensions/nix/EXTENSION.md`), literature
  (`agent-system/extensions/literature/merge-sources/claudemd.md`), and present
  (`agent-system/extensions/present/EXTENSION.md`) all use the *resolving* `@context/...` form —
  five files each, eagerly loaded into every session whenever the extension is active. This fully
  explains the observed "unrelated literature/nix/present context": ~15 files, none gated by task
  type, loaded because those authors happened to use the relative prefix.

So what loads eagerly today is an **accident of path-prefix style**, not a design. The task frames
this as "narrow the eager surface"; the prior question is "decide, per reference, whether `@` was
meant as an import directive or as a citation, then make resolution consistent and lint it." An
audit that only trims will canonize the accident.

### 4. Rules loading mechanics: verified, with a load-bearing-safety split the task must respect

Empirical result (deployed rules, this session): the three rules WITHOUT YAML `paths:` frontmatter
(`neovim-lua.md`, `no-task-references-in-deliverables.md`, `source-store-deploy-boundary.md`) are
exactly the ones injected at session start; all nine rules WITH `paths:` (including
`pr-prohibition.md`, whose glob is `"**/*"`) were NOT injected eagerly. So: no frontmatter =
unconditional eager load; `paths:` = deferred until a matching path is touched. The observed "four
rules files" cannot be reproduced against today's deploy (exactly three are paths-less); the fourth
presumably came from a then-active extension — the audit should re-count rather than trust the
observation.

Safety triage for any "add frontmatter / defer" recommendation:

- `neovim-lua.md`: eager load is a plain frontmatter-omission bug (body says "Applies to:
  `lua/**/*.lua`" but nothing machine-readable). Safe to gate. Source fix:
  `agent-system/extensions/nvim/rules/neovim-lua.md`.
- `source-store-deploy-boundary.md`: **MUST NOT be deferred.** Its own text states the durable
  enforcement is "this rule file plus the agent contracts; the hook is the reminder" — the hook is
  PostToolUse and advisory (never blocks). Deferring the rule until a `.claude/**` path is touched
  means the agent learns the rule at/after the violating write. Eager load here is load-bearing.
- `no-task-references-in-deliverables.md`: partially deferrable in principle — a *blocking*
  PreToolUse hook backstops it — but the hook fails open by design, and the rule is also the
  taxonomy source for two lint scripts. At 8.8KB it is the largest of the three; a split (short
  always-on principle + lazily-loaded exemption taxonomy) is a better shape than deferral.
- `pr-prohibition.md` is already deferred (glob-gated), contradicting any framing that treats all
  enforcement rules as eager.

### 5. Scope gaps in the task framing

1. **Command bodies dominate and are ignored.** `commands/task.md` alone (~9.4k tokens) exceeds the
   entire nix context and is 3x `topic-assignment-pattern.md`, the one file the task names. If
   per-invocation injection is the concern, command-file size is the biggest lever.
2. **Subagent multiplier** (baseline re-injected per dispatch) matters more than the single-session
   number for dilution, and less for cost (cache) — the task treats one invocation as the unit.
3. **MCP server instructions**: the lean-lsp instruction block is eagerly injected into every
   session in this repo from user-scope MCP config — outside the extension picker's control, and
   the lean extension is not even active. Any "eager surface" inventory that only scans
   `agent-system/` will miss it.
4. **`.opencode/` parallel tree** is unexamined (a sync-mechanism task directory exists in specs/);
   if it mirrors the same @-style inconsistency, fixes must land in the shared source store, not
   one deploy target.
5. **Skills/agents listings are cheap**: 31 skill descriptions ≈ 4.6KB and 16 agent descriptions
   ≈ 1.4KB (~1.5k tokens combined). Deprioritize; not worth an optimization task.
6. **@-import recursion depth is currently moot**: none of the files that actually resolve contain
   further `@`-refs of their own, so today's depth is 1. A lint should still guard this, since one
   added `@` in a hub file could silently chain.

### 6. Questions the task should ask but doesn't

- What is the intended semantics of `@` in generated CLAUDE.md — import or citation? Authors
  demonstrably use both; the harness treats every resolvable one as an import. Without a per-ref
  intent decision, "narrowing" and "fixing" are indistinguishable.
- Should `verify-deploy.sh` gain a broken-@-ref lint (every `@path` in generated CLAUDE.md must
  resolve, or be explicitly marked citation-only)? This converts finding 3 from a one-time cleanup
  into a durable invariant.
- What is the measurement protocol? "~19k" was not reproducible as stated; the audit should ship a
  small script that enumerates the eager surface (CLAUDE.md chain + resolving @-imports +
  paths-less rules) and reports bytes/est. tokens, so future regressions are measurable.
- Which eager loads are *volatile*? Cache economics make prefix stability, not prefix size, the
  cost variable. Anything regenerated per task (TODO.md, state.json, generated CLAUDE.md on
  extension toggle) must be classified before import fixes are attempted.

## Recommended Approach

The honest verdict: **as framed ("we load too much; narrow it"), the optimization is weakly
motivated — token cost is largely cache-absorbed and ~19k is <3% of the window. Reframed as
"the eager surface is unmanaged: half the declared imports are silently broken (including
safety-relevant ones), what does load is an accident of path style, and per-extension context
loads unconditionally regardless of task type," the audit is worth doing.** Optimization tasks it
spawns should be, in priority order:

1. Decide per-reference intent (import vs citation) and normalize @-path style in the source store
   (`agent-system/extensions/core/merge-sources/claudemd.md`, `agent-system/extensions/nix/EXTENSION.md`,
   `agent-system/extensions/present/EXTENSION.md`,
   `agent-system/extensions/literature/merge-sources/claudemd.md`), with an explicit
   no-volatile-files-in-prefix constraint.
2. Add a broken-@-ref / recursion lint to the deploy verification gates.
3. Add `paths:` frontmatter to `agent-system/extensions/nvim/rules/neovim-lua.md`; leave
   `source-store-deploy-boundary.md` eager (load-bearing); consider splitting
   `no-task-references-in-deliverables.md` into a short eager principle + lazy taxonomy.
4. Convert extension EXTENSION.md eager context imports to task-type-gated pointers (the context
   index already exists for lazy discovery) — this is the actual "unrelated extension context" fix.
5. Treat `commands/task.md` size as its own item; skip skills/agents listings (measured cheap).

## Evidence/Examples

- Size measurements: `wc -c` totals above; grand total 69,926 chars ≈ 17.5k tokens for the session
  baseline; `/task` adds 48,775 chars ≈ 12.2k tokens (`.claude/commands/task.md` +
  `.claude/context/patterns/topic-assignment-pattern.md`).
- Resolution asymmetry: `.claude/CLAUDE.md` lines 313-320 (`@.claude/rules/...`, none loaded) vs
  lines 505-509 (`@context/project/nix/...`, all five loaded); `ls .claude/.claude` → No such file.
- Broken-but-existing targets: `.claude/context/project/email/domain/safety-invariants.md`,
  `.claude/context/repo/project-overview.md`, `.claude/context/project/neovim/domain/neovim-api.md`
  all exist on disk; none were injected.
- Rules frontmatter census: 12 deployed rules; the 3 lacking `paths:` are exactly the 3 injected at
  session start; `pr-prohibition.md` (`paths: "**/*"`) not injected eagerly.
- Extension state: `.claude-extensions.json` → active: core, email, nvim, nix, memory; literature
  and present inactive today (hence the ~1.5k-token gap vs the reported ~19k).
- Source-store provenance of frontmatter gaps: `agent-system/extensions/core/rules/*.md` and
  `agent-system/extensions/nvim/rules/neovim-lua.md` lack the frontmatter in source, so this is a
  source bug, not a deploy artifact.

## Confidence Level

- **High**: size measurements; containing-file-relative @-resolution (two-way discriminating
  evidence); paths-less-rules-load-eagerly mechanic; extension @-style asymmetry; cache-inversion
  argument for volatile imports.
- **Medium**: attention-dilution as the dominant real harm (mechanistically sound, not
  experimentally quantified here); explanation of the 19k-vs-17.5k delta via extension set;
  "fourth rules file" attribution.
- **Low**: none of the load-bearing claims rest on low-confidence evidence; the one unverifiable
  detail (exact composition of the originally observed session) is flagged as such.

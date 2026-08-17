# Research Report: Audit Context-Loading Efficiency

- **Task**: 36 - Audit context loading efficiency
- **Started**: 2026-08-11T15:26:00Z
- **Completed**: 2026-08-11T15:45:00Z
- **Effort**: ~20 minutes wall-clock (4 parallel teammates + synthesis)
- **Dependencies**: None
- **Mode**: Team Research (4 teammates, Fable)
- **Sources/Inputs**:
  - Teammate findings: `01_teammate-a-findings.md` (primary measurement), `01_teammate-b-findings.md` (alternatives/prior art), `01_teammate-c-findings.md` (critic), `01_teammate-d-findings.md` (horizons)
  - Deployed tree: `.claude/CLAUDE.md`, `.claude/rules/*.md`, `.claude/context/index.json`, `.claude/context/project/nix/**`, `.claude/commands/*.md`
  - Source store: `agent-system/extensions/*/EXTENSION.md`, `*/merge-sources/claudemd.md`, `*/manifest.json`, `*/rules/*.md`
  - Config/state: `.claude-extensions.json`, `specs/ROADMAP.md`, `specs/TODO.md`
  - Live ground truth: the injected system context of four independent subagent sessions
- **Artifacts**: `specs/036_audit_context_loading_efficiency/reports/01_team-research.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- **The premise reproduces, but the diagnosis in the task description is wrong.** Three teammates independently measured the identical session-start eager surface: **69,926 bytes ≈ 17.5k tokens**. The `~19k` observation was sound; the delta is explained by a different loaded-extension set at observation time (literature and present were active then; today's set is core, email, nvim, nix, memory).
- **The single most important finding is not size — it is that the eager surface is an accident of path-prefix style, and roughly half the declared `@`-imports are silently broken.** `@`-references in a CLAUDE.md resolve relative to the *containing file's directory* (`.claude/`). So `@context/project/nix/README.md` resolves and loads; `@.claude/rules/state-management.md` resolves to `.claude/.claude/rules/...`, does not exist, and **loads nothing, silently**. All four teammates confirmed this, two with two-way discriminating evidence.
- **Consequences of that accident, both directions**: nix contributes **17,883 bytes (~4.5k tokens) of `nixos-rebuild`/`home-manager` CLI tutorial to every session in a Neovim config repo**, gated by nothing; while the email extension's five safety-invariant pointers — framed in its own section as "non-negotiable... see before any email work" — **load nothing at all**. The entire "Rules References" `@`-list (8 rules) is a dead loading path, contradicting CLAUDE.md's own claim that it is "a curated subset, not the sole loading path."
- **The naive fix is actively harmful, and two teammates independently flagged it.** "Repairing" the broken `@.claude/...` refs upward would add ~64.7k chars (~16k tokens) per session from email+nvim alone, and would pull *volatile* files (`@specs/TODO.md`, `@specs/state.json`) into the cached prompt prefix — invalidating cache on every task-status flip. The broken refs are accidentally protective. **The fix must go downward to plain, non-resolving path mentions, never upward.**
- **Three rules load unconditionally because they lack YAML `paths:` frontmatter** (`no-task-references-in-deliverables.md` 8,821 B, `neovim-lua.md` 2,620 B, `source-store-deploy-boundary.md` 2,286 B). Verified two-way: exactly those three appeared in session context; all nine rules *with* `paths:` did not — including `pr-prohibition.md`, whose `**/*` glob still defers to first path touch.
- **`index.json` is not an eager channel and needs no optimization.** No runtime consumer loads from `load_when`; only validators, installers, and tests read it. 3 of 190 entries are `always: true` (334 lines, all READMEs). The lazy machinery is already correct and already disciplined — the eager surface simply bypasses it.
- **Recommended shape: cheap wins now, then a harness and a budget gate.** P1+P2 cut the session-start surface from ~17.5k to ~9.5k tokens (**-46%**) via roughly 13 lines of source-store edits with no behavior loss. But a one-off trim decays with the next extension, so the durable deliverable is a measurement harness plus a `verify-deploy.sh` budget gate.

## Context & Scope

**Evaluated**: every mechanism that injects context before a command does work — the CLAUDE.md chain, `@`-import resolution, rules `paths:` globs, extension merge-sources, `index.json` `load_when`, command bodies, and preflight injection (memory/literature).

**Method**: empirical rather than inferential. Each of four teammate sessions was itself a specimen: its own injected system context is directly observable, giving ground truth against which the predicted channels were checked. Byte counts via `wc -c` on deployed and source-store files.

**Constraints**:
- `.claude/**` is a gitignored, disposable deploy artifact regenerated from `agent-system/extensions/**`. Every recommendation below names a **source-store** path. `.claude/**` was read for observation only.
- Measurements are a property of *(repo, loaded extension set, deploy freshness)*, not of the system in the abstract — which is itself an argument for a harness over a fixed number.

## Findings

### F1. Measured eager surface: 69,926 bytes ≈ 17.5k tokens (three-way independent agreement)

| Rank | Source | Bytes | ~Tokens | Channel |
|---|---|---:|---:|---|
| 1 | `.claude/CLAUDE.md` (generated) | 34,501 | 8,625 | native CLAUDE.md load |
| 2 | `rules/no-task-references-in-deliverables.md` | 8,821 | 2,205 | no `paths:` frontmatter |
| 3 | `context/project/nix/domain/flakes.md` | 5,124 | 1,281 | resolving `@`-import |
| 4 | `context/project/nix/tools/home-manager-guide.md` | 4,045 | 1,011 | resolving `@`-import |
| 5 | `context/project/nix/tools/nixos-rebuild-guide.md` | 3,602 | 901 | resolving `@`-import |
| 6 | `context/project/nix/README.md` | 3,227 | 807 | resolving `@`-import |
| 7 | `nvim/CLAUDE.md` (repo root) | 3,046 | 762 | native |
| 8 | `rules/neovim-lua.md` | 2,620 | 655 | no `paths:` frontmatter |
| 9 | `rules/source-store-deploy-boundary.md` | 2,286 | 572 | no `paths:` frontmatter |
| 10 | `context/project/nix/tools/mcp-nixos-integration.md` | 1,885 | 471 | resolving `@`-import |
| 11 | `~/.config/CLAUDE.md` | 769 | 192 | native (parent chain) |
| | **Total session-start** | **69,926** | **~17,482** | |

Generated CLAUDE.md internal split: core merge-source 25,159 B; loaded extensions' `EXTENSION.md` blocks the remainder (memory 4,054; email 2,180; nvim 1,488; nix 1,380). Largest sections: Command Reference 5,523 B; Skill-to-Agent Mapping 5,494 B; Hard Mode 4,492 B.

Additional per-invocation cost (**not** in the table, and absent from the task's framing): `/task` adds `commands/task.md` (37,465 B, ~9.4k tokens) plus its `@topic-assignment-pattern.md` import (11,310 B, ~2.8k tokens) = **~12.2k tokens**. Session-start plus first `/task` ≈ **29.7k tokens before any work**. The command body alone exceeds the entire nix eager block.

One teammate additionally observed that merely *reading* `specs/TODO.md` and `specs/ROADMAP.md` triggered glob-matched injection of four more rules (`git-workflow` 11,147 + `state-management` 5,148 + `pr-prohibition` 4,628 + `artifact-formats` 5,360 = **+26.3 KB**) — the deferred tier working as designed, but showing that "deferred" is not "free" for any task that touches `specs/**`.

### F2. `@`-imports resolve relative to the containing file's directory — this is the master finding

Two same-format list items in the same generated `.claude/CLAUDE.md` discriminate the rule cleanly:

| Reference (in `.claude/CLAUDE.md`) | Resolves to | Exists? | Loaded? |
|---|---|---|---|
| `@context/project/nix/README.md` | `.claude/context/project/nix/README.md` | yes | **yes** |
| `@.claude/rules/state-management.md` | `.claude/.claude/rules/state-management.md` | **no** | no |

`ls .claude/.claude` → No such file. Source-store census of the two styles:

| Form | Extensions using it | Effect |
|---|---|---|
| `@context/...` (resolves) | nix, present, literature, web, cslib | Full file contents inlined every session the extension is loaded |
| `@.claude/...` (broken) | email, nvim, formal, lean | Inert pointer text; zero cost |

**This fully explains the task's "unrelated literature/nix/present extension context" observation**: those three extensions happen to use the resolving form, so their domain context loads unconditionally at session start for every command and every task type. There is no task-type or command gating anywhere in this channel.

Four extensions have been running with de-facto pointer-only Context sections and **nothing broke** — direct empirical evidence that eager inlining of extension domain context is unnecessary, since agents pull those files by path or via the index on demand.

### F3. The broken imports include a safety-relevant one, and are simultaneously load-bearing protection

Two facts that must be held together:

- **Defect**: targets that exist but never load include `context/project/email/domain/safety-invariants.md` (and four sibling email safety pointers), `context/project/neovim/domain/*` (3 files), `context/repo/project-overview.md`, `@README.md`, and the whole 8-entry Rules References list. The email section calls its invariants "non-negotiable — see before any `email` work"; that import is silently dead.
- **Protection**: repairing these upward would add ~16k tokens/session (email 51,612 B + nvim 13,064 B if made to resolve), and the broken `@specs/TODO.md` / `@specs/state.json` / `@specs/errors.json` refs are *accidentally protective* — those files change on every task operation, and admitting them to the cached prefix would invalidate the prompt cache for every subsequent session and subagent.

**Resolution: normalize downward.** Convert every `@`-reference in generated-CLAUDE.md sources to plain backticked paths, and re-establish genuinely-needed eager loads (if any — email safety is the only candidate) by an explicit, deliberate decision rather than a path-string accident. Any optimization work must carry an explicit **"no volatile files in the eager prefix"** constraint.

### F4. Rules: three lack `paths:` frontmatter; safety triage splits them (CONFLICT — resolved)

Verified two-way: the three rules without `paths:` are exactly the three injected at session start; all nine with `paths:` were not injected eagerly (including `pr-prohibition.md` with `paths: "**/*"`, which still waits for first path touch). The frontmatter is missing **in the source store**, so this is a source bug, not a deploy artifact.

Teammates A, B, and D recommended adding globs to all three. Teammate C dissented on one, and **C's dissent is upheld**:

| Rule (source-store path) | Bytes | Verdict | Reasoning |
|---|---|---|---|
| `agent-system/extensions/nvim/rules/neovim-lua.md` | 2,620 | **Gate it** — `paths: ["lua/**/*.lua", "after/**/*.lua", "*.lua"]` | Pure frontmatter-omission bug; its own prose already declares exactly this scope. No enforcement role. Unanimous. |
| `agent-system/extensions/core/rules/source-store-deploy-boundary.md` | 2,286 | **Leave eager** | Its own text states durable enforcement is "this rule file plus the agent contracts; the hook is the reminder." `validate-meta-write.sh` is **PostToolUse and non-blocking** — it fires *after* the misdirected write. Deferring the rule until a `.claude/**` path is touched risks the agent learning the rule at or after the violating write. ~572 tokens is a poor price for a real correctness regression. |
| `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` | 8,821 | **Split, don't defer** | Largest of the three. A blocking PreToolUse hook backstops it, but that hook fails open by design and the rule is the taxonomy source for two lint scripts. Better shape: a short always-eager principle (~15 lines) plus a lazily-loaded 7-category exemption taxonomy. Captures most of the 2,205 tokens without weakening the norm. |

**Open question this audit could not close**: whether a `paths:`-gated rule fires *before* the matching write is evaluated or only after the path is first touched. That timing determines whether gating `source-store-deploy-boundary.md` would in fact be safe. It should be tested empirically before anyone revisits this decision.

### F5. `index.json` is advisory, not eager — no optimization available there (CONFLICT — resolved)

The "underused lazy machinery" hypothesis was tested and **rejected**. `grep -rln load_when .claude/scripts .claude/skills` finds only validators, installers, and tests — **no runtime consumer performs loading from the index**. Counts from the live index (190 entries, 48,084 lines):

| Class | Entries | Lines |
|---|---:|---:|
| `load_when.always: true` | 3 | 334 |
| `on_demand: true` | 56 | 16,936 |
| Hook-gated (agents/task_types/commands) | 131 | 30,814 |

Only 3 entries load "always," all READMEs — excellent existing discipline. **Flipping index entries would save approximately nothing, because no eager path goes through the index.** The strategic end-state the index already implies is the right one: CLAUDE.md as table of contents, `index.json` as card catalog, everything else lazy. Several eager blocks (the nix tool guides, 17.9 KB) already have index entries and lose nothing by demotion to pointers.

Similarly bounded and requiring no action: `memory-retrieve.sh` (hard `TOKEN_BUDGET=2000`, `--clean` suppression) and the skill/agent frontmatter roster (~1.5k tokens combined for 31 skills + 16 agents — measured cheap, deprioritize).

### F6. The harm model in the task framing is wrong; the real justification is different (CONFLICT — resolved in the critic's favor)

Teammate C challenged the premise directly, and the challenge holds:

- **Token cost is largely cache-absorbed.** ~17.5k is <3% of a 1M window (~10-15% of a 200k window). This session's requests use a 1-hour prompt-cache TTL and the eager CLAUDE.md tree sits in the cached prefix. **A stable large prefix is cheap; a changing prefix is expensive.** Prefix *stability* is the real cost variable, not prefix size — which is precisely why F3's volatile-file constraint matters more than raw trimming.
- **Latency**: minor for a cached prefix. Not a defensible motivation.
- **Attention dilution is the one real harm, and it multiplies by subagent dispatch, not by tokens.** Every dispatched agent re-receives the full baseline. Each of the four teammate sessions in this very research run carried ~4.5k tokens of `nixos-rebuild`/`home-manager` CLI tutorials irrelevant to a meta task. An `/orchestrate` run with ~10 dispatches injects the baseline 10 times; caching blunts the cost multiplier but does nothing for the dilution multiplier.

**The defensible metric is therefore relevance, not size**: "fraction of eagerly injected instruction-bearing text irrelevant to the dispatched task type." Instruction-following degradation is plausible (40+ distinct instruction documents in a session's context) but should not be claimed without an experiment.

**Reframed justification, which this report adopts**: the eager surface is *unmanaged* — half the declared imports are silently broken including a safety-relevant one, what does load is an accident of path style, per-extension context loads unconditionally regardless of task type, and nothing in the deploy pipeline can detect any of it. That is worth fixing. "We load too much" on its own is not.

### F7. The growth mechanism is structural, and nothing pushes back

Named causes, in leverage order:

1. **Unconditional per-extension append.** `manifest.json`'s `merge_targets.claudemd` splices each loaded extension's entire `EXTENSION.md` into the generated CLAUDE.md. 16 extensions exist in the source store (28,829 B of `EXTENSION.md` total); 5 are loaded here. Every future extension grows the eager surface linearly, regardless of task relevance.
2. **No budget, no gate.** `verify-deploy.sh` runs eleven gates (structure, parity, doc-lint, task references, state validation…). **None measures context bytes.** There is no number deploy can fail on.
3. **Unverified import semantics.** Nothing tests which `@`-references actually resolve, so an author cannot know whether a one-character path edit adds 18 KB to every session or does nothing.
4. **Unlinted rules frontmatter.** No lint checks `paths:` presence or breadth, even though `lint-agent-contracts.sh` already lints agent frontmatter.

**"Just trim it" addresses none of these; the surface regrows with the next extension.**

### F8. Mis-sited content and roadmap alignment

- **Mis-siting**: the `/literature` and `/cite` command rows and the `skill-literature` mapping row live in **core's** merge source (`agent-system/extensions/core/merge-sources/claudemd.md`), so they render in every deploy even though the literature extension is not loaded here. They belong in `agent-system/extensions/literature/merge-sources/claudemd.md`.
- **Roadmap alignment — this is not a side quest.** `specs/ROADMAP.md` Phase 2 lists **Context discovery caching** ("speed up agent spawn time") and Success Metrics include **"Time from /task creation to first artifact < 60 seconds."** The eager-load surface is a direct input to both; this audit is the measurement arm those roadmap lines lack. A context-budget gate is also the same enforcement philosophy as the Phase 1 "CI enforcement of doc-lint" item.
- **Wave-1 sequencing** (task 36 shares Wave 1 with 14, 16, 17, 18, 20, 22, 27, 28, 31, 33, 34):

| Task | Interaction | Nature |
|---|---|---|
| 29 (generate `.mcp.json` from manifests) | Sequencing | Both touch the manifest/deploy engine. Any `merge_targets` or budget-field schema change should land after or alongside 29 to avoid concurrent manifest-schema churn. |
| 18 (detect stale `.claude/` deploys) | Measurement validity | A harness must measure *source store + fresh regenerate*, never the live `.claude/` tree — 18 exists precisely because the deployed tree can be arbitrarily stale. |
| 32 (redeploy + remediate settings) | Delivery vehicle | Narrowing only takes effect at redeploy; 32 is the natural delivery point for these cheap wins. |
| 31 (opencode extensions sync) | Scope boundary | The `.opencode/` mirror has its own generation path; fixes must either explicitly mirror or declare themselves Claude-Code-only, or 31 will propagate/miss them nondeterministically. |
| 9 (deploy orphan parity, Wave 2) | Shared substrate | Orphan files inflate any naive on-disk measurement — another reason to predict from the source store. |

## Decisions

1. **Adopt the critic's reframing.** The justification is correctness and relevance hygiene (broken imports, unconditional cross-domain loading, no detection), not raw token savings. Token savings are a welcome side effect.
2. **Normalize `@`-references downward to plain paths, never upward.** Repairing broken refs would add ~16k tokens/session and admit volatile files to the cached prefix. Every optimization task carries an explicit no-volatile-files-in-prefix constraint.
3. **Do not gate `source-store-deploy-boundary.md`** (critic's dissent upheld over three teammates): its enforcement hook is PostToolUse and advisory, so deferral risks the agent learning the rule after the violating write. ~572 tokens is not worth a correctness regression.
4. **Split rather than defer `no-task-references-in-deliverables.md`**: short eager principle + lazy exemption taxonomy.
5. **No index.json work.** Empirically confirmed to have no runtime loading consumer; savings would be ~zero.
6. **Cheap wins now; harness and budget gate as the durable deliverable.** A one-off audit decays the moment an extension is added.
7. **Email's dead safety imports are a live defect, not merely an inefficiency**, and should be raised as its own item rather than folded into a cleanup.

## Recommendations

Priority order. All targets are source-store paths; `.claude/**` is regenerated.

**P1 — De-`@` the resolving extension context bullets** (~4.5k tokens/session, ~13 lines, zero behavior loss)
- `agent-system/extensions/nix/EXTENSION.md` — 5 bullets → plain backticked paths. **-17,883 B (~4.5k tokens), 26% of the session-start surface.**
- `agent-system/extensions/present/EXTENSION.md`, `agent-system/extensions/literature/merge-sources/claudemd.md` — same defect class; saves ~5.7k tokens wherever literature is loaded.
- Simultaneously normalize the *already-broken* `@.claude/...` forms in `agent-system/extensions/{email,nvim}/EXTENSION.md` and `agent-system/extensions/core/merge-sources/claudemd.md` (Rules References, Context Imports, `@specs/*` rows) to the same plain-path convention. **Zero token delta, but it disarms the trap** where a future "path fix" silently adds ~16k tokens and destabilizes the cache prefix.

**P2 — Rules frontmatter, per the F4 triage** (~2.9k tokens deferred)
- Add `paths:` to `agent-system/extensions/nvim/rules/neovim-lua.md`.
- Split `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` into eager principle + lazy taxonomy.
- Leave `source-store-deploy-boundary.md` eager. Decide `pr-prohibition.md`'s `**/*` glob deliberately.

**P1+P2 net: session-start surface ~17.5k → ~9.5k tokens (-46%).**

**P3 — Build `measure-eager-context.sh` before further trimming.** A sibling to `generate-context-line-counts.sh` (same source-store-first philosophy, same `--check`/`--write` split) that predicts the eager set from *source store + fresh regenerate*: parent CLAUDE.md chain + generated CLAUDE.md + `@`-imports that actually resolve + rules lacking `paths:` + rules with `**/*`. Emits bytes/est-tokens per contributing source, machine-diffable like `verify-deploy.sh --findings`.

**P4 — Wire gates into `verify-deploy.sh`**: (a) a **broken-`@`-ref lint** — every `@path` in generated CLAUDE.md must resolve or be explicitly marked citation-only (converts F2/F3 from one-time cleanup into a durable invariant, and would have caught the email safety defect); (b) a **context-budget gate**, warning-first, graduating to failing once under budget. Consider a per-extension `merge_targets.claudemd.max_bytes` so an oversized `EXTENSION.md` fails deploy like a doc-lint failure — the only shape that survives extensions 17, 18, 19…

**P5 — Raise the email dead-safety-import defect separately.** Five "non-negotiable" safety pointers silently load nothing. Decide deliberately whether they should be eager (and if so, accept the byte cost) or whether the wrapper contracts and agent definitions already carry the enforcement.

**P6 — Re-site literature rows** from `agent-system/extensions/core/merge-sources/claudemd.md` to `agent-system/extensions/literature/merge-sources/claudemd.md`.

**P7 — Treat `commands/task.md` (37,465 B, ~9.4k tokens) as its own item.** The largest single per-invocation contributor and entirely absent from the task's framing. Defer unless command-body slimming becomes a broader effort.

**Explicitly not recommended**: index-entry flips (F5), unloading extensions as an efficiency measure (sacrifices capability; P1 gets the same savings with the extension loaded), memory-injection changes (already budgeted), skills/agents listing trims (measured cheap).

**Sequencing**: P1, P2, P5, P6 can proceed now and deliver through task 32's redeploy. P3/P4 should declare a dependency on task 29 if they touch manifest schema, and must predict from the source store (task 18's staleness concern).

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| A future "path fix" repairs broken `@.claude/...` refs upward, adding ~16k tokens/session and admitting volatile files to the cached prefix | P1 normalizes all refs to plain paths so there is no broken-looking ref left to "fix"; P4's lint makes intent explicit per reference |
| Deferring an enforcement rule causes silent violations | F4 triage keeps `source-store-deploy-boundary.md` eager; the glob *timing* question is flagged as an explicit open test, not assumed |
| Measurement taken against a stale or orphan-polluted `.claude/` tree misreports the surface | P3 predicts from source store + fresh regenerate (task 18 / task 9 concerns) |
| Fixes land in Claude Code deploy but not `.opencode/` | Land in the shared source store; coordinate with task 31 or declare Claude-Code-only explicitly |
| One-off trim decays as extensions are added | P4's budget gate converts context discipline from a virtue into a contract |
| Eager savings silently respent by preflight injection growth | Budget ledger counts all three channels: static eager, rules-glob, preflight injection (memory/`--lit`) |

## Context Extension Recommendations

- **Topic**: `@`-reference resolution semantics in generated CLAUDE.md
  **Gap**: Nothing documents that `@`-refs resolve relative to the containing file's directory, that `@.claude/...` therefore fails silently from within `.claude/CLAUDE.md`, or that resolution is currently depth-1 by accident. The existing memory `MEM-insight-context-loading-by-at-reference.md` documents the sibling fact for agent bodies.
  **Recommendation**: Record in `context/architecture/context-layers.md` and `context/patterns/context-discovery.md`, and extend the existing memory rather than creating a new one.
- **Topic**: Eager-vs-lazy channel inventory and the volatility constraint
  **Gap**: No document enumerates the eager channels or states that volatile files must never enter the cached prefix.
  **Recommendation**: Add a channel inventory section to `context/architecture/context-layers.md`, co-located with the P3 harness output format.

## Appendix

### Teammate Contributions

| Teammate | Angle | Status | Confidence |
|---|---|---|---|
| A | Primary — measurement and narrowing | completed | High (measurement, resolution rule, rules gating); Medium (P3 savings estimates) |
| B | Alternatives and prior art | completed | High (index counts, resolution both directions, rules); Medium (stub savings, unload behavior) |
| C | Critic | completed | High (measurements, two-way resolution evidence, cache inversion); Medium (dilution as dominant harm — mechanistically sound, not experimentally quantified) |
| D | Horizons | completed | High (measurements, growth mechanism, sequencing); Medium (resolution causal rule — inferred; `max_bytes` design) |

### Synthesis: conflicts found and resolved

Four conflicts surfaced; all four resolved on evidence.

1. **Gate all three frontmatter-less rules (A, B, D) vs. keep `source-store-deploy-boundary.md` eager (C)** → **C upheld.** Decisive evidence is in the rule's own text: enforcement is the rule plus agent contracts, and `validate-meta-write.sh` is explicitly PostToolUse and non-blocking. A ~572-token saving does not justify a correctness regression. Residual uncertainty (glob fire timing) recorded as an open test rather than papered over.
2. **Add `paths:` to `no-task-references-in-deliverables.md` (A, B) vs. split it (C)** → **C's split adopted.** The hook fails open by design and the rule is a lint taxonomy source; splitting captures most of the 2,205 tokens without weakening the norm.
3. **Is the optimization worth doing? (C's challenge vs. A/B/D's implicit assumption)** → **C's reframing adopted**, and it now leads the report. Cost is cache-absorbed; the real harms are correctness (broken safety imports) and per-dispatch attention dilution. This changed the report's thesis, not merely its emphasis.
4. **Trim now (A, B) vs. build harness and gate first (D)** → **Not truly contradictory; sequenced.** Cheap wins are provably safe at ~13 lines of churn, so they proceed immediately; the harness and gate are what stop regrowth. D's constraint that the harness predict from the source store (never the live `.claude/` tree) is adopted.

### Gaps identified (carried forward, not closed by this audit)

- **Glob fire timing**: does a `paths:`-gated rule load before the matching write is evaluated, or only after first touch? Determines whether F4's decision on `source-store-deploy-boundary.md` is permanent.
- **MCP server instructions**: the lean-lsp instruction block is eagerly injected from user-scope MCP config in every session in this repo, though the lean extension is not loaded. Outside the extension picker's control; any inventory scanning only `agent-system/**` will miss it.
- **`.opencode/` parallel tree**: unexamined; may mirror the same `@`-style inconsistency.
- **Attention-dilution harm is unquantified**: mechanistically sound, but no experiment was run. Should not be claimed as measured.
- **Exact composition of the original ~19k observation**: not reproducible as stated (different extension set, unit unstated). The mechanism is confirmed regardless; the specific file list is reconstructed, not recovered.

### Key verification commands

```bash
wc -c .claude/CLAUDE.md CLAUDE.md ~/.config/CLAUDE.md .claude/rules/*.md
ls .claude/.claude                                     # No such file -> @.claude/... cannot resolve
for f in .claude/rules/*.md; do sed -n '1,8p' "$f" | grep -q '^paths:' || echo "NO FRONTMATTER: $f"; done
grep -oE '@[A-Za-z0-9._/-]+' agent-system/extensions/*/EXTENSION.md agent-system/extensions/*/merge-sources/claudemd.md
grep -rln 'load_when' .claude/scripts/ .claude/skills/  # validators/installers/tests only
jq '[.entries[] | select(.load_when.always == true)] | length' .claude/context/index.json   # -> 3
awk '/^## /{if(n)print n": "s; n=$0; s=0}{s+=length($0)+1}END{print n": "s}' .claude/CLAUDE.md | sort -t: -k2 -rn
```

### References

- Teammate findings: `01_teammate-a-findings.md`, `01_teammate-b-findings.md`, `01_teammate-c-findings.md`, `01_teammate-d-findings.md` (same directory)
- `specs/ROADMAP.md` (Phase 2 context discovery caching; <60s success metric)
- `.claude-extensions.json` (loaded set: core, email, nvim, nix, memory)
- `agent-system/extensions/*/manifest.json` (`merge_targets.claudemd` mechanism)

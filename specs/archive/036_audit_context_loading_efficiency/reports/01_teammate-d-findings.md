# Teammate D Findings: Horizons — Roadmap Alignment, Task Shape, and Growth Mechanism

**Task**: 36 - Audit context-loading efficiency across the agent system and its extensions
- **Started**: TBD
- **Completed**: TBD
- **Effort**: TBD
- **Dependencies**: TBD
- **Sources/Inputs**: TBD
- **Artifacts**: TBD
- **Standards**: TBD
**Role**: Horizons researcher (long-term alignment and strategic direction)
**Date**: 2026-08-11
**Status**: complete

## Key Findings

### F1. This session reproduced the defect live, with measurements

The researching agent's own spawn is a measured specimen of the problem. Eagerly injected
before any work, in this repository, for a meta task with zero Nix or Neovim content:

| Source | Bytes | Why it loaded |
|--------|-------|---------------|
| `~/.config/CLAUDE.md` | 769 | parent-dir CLAUDE.md chain |
| `nvim/CLAUDE.md` | 3,046 | project CLAUDE.md |
| `.claude/CLAUDE.md` (generated) | 34,501 | generated: core merge source (25,159) + EXTENSION.md of every loaded extension (email 2,180; memory 4,054; nix 1,380; nvim 1,488) |
| Nix context: `project/nix/README.md`, `domain/flakes.md`, `tools/nixos-rebuild-guide.md`, `tools/home-manager-guide.md`, `tools/mcp-nixos-integration.md` | 17,883 | `@context/project/nix/...` imports in the Nix section of generated CLAUDE.md |
| `rules/no-task-references-in-deliverables.md` | 8,821 | no `paths:` frontmatter → unconditional |
| `rules/source-store-deploy-boundary.md` | 2,286 | no `paths:` frontmatter → unconditional |
| `rules/neovim-lua.md` | 2,620 | no `paths:` frontmatter → unconditional |
| **Total eager, pre-work** | **~69.9 KB** | |

Then merely *reading* `specs/TODO.md` and `specs/ROADMAP.md` triggered glob-matched injection of
four more rules (`git-workflow.md` 11,147 + `state-management.md` 5,148 + `pr-prohibition.md`
4,628 + `artifact-formats.md` 5,360 = **+26.3 KB**) — for a research task that writes one report.
This matches the ~19 KB `/task` observation in the task description in kind; the exact figure
varies by repo and extension set, which is itself an argument for a per-repo measurement tool
(F4) rather than a one-off number.

### F2. Eager loading is partly *accidental*: two @-import styles behave differently

The generated CLAUDE.md contains @-imports in two path styles with observably different outcomes
in this session:

- The Nix section's `@context/project/nix/README.md` style (no `.claude/` prefix) **resolved and
  eagerly loaded** all five Nix files (17.9 KB).
- The Email section's `@.claude/context/project/email/domain/...` and the Neovim section's
  `@.claude/context/project/neovim/domain/...` style did **not** load. Neither did the
  "Rules References" `@.claude/rules/*` list (those rules arrived later via path-glob matching,
  or eagerly via missing frontmatter — not via the @-list), nor `@README.md` (27,053 bytes) nor
  `@.claude/context/repo/project-overview.md` from "Context Imports".

This is consistent with @-imports resolving relative to the containing file's directory
(`.claude/`), making `@.claude/...` references resolve to a nonexistent `.claude/.claude/...`
and fail silently. Two strategic consequences:

1. **The current eager surface is not the designed surface.** Nix context loads because of a
   path-style accident; the Email safety invariants — arguably the one context block that
   *should* be eager, given its "non-negotiable" framing — silently does not. Trimming without
   first establishing the actual resolution semantics would optimize noise.
2. **Several documented "imports" are decorative.** The Rules References list and Context
   Imports list in CLAUDE.md appear to have no loading effect in their current spelling. Any
   audit must classify every @-occurrence as (a) resolves-and-loads, (b) broken/decorative, or
   (c) intentional lazy pointer, before touching anything.

### F3. The growth mechanism is structural, and nothing pushes back

Named causes, in order of leverage:

1. **Unconditional per-extension append**: `manifest.json`'s
   `merge_targets.claudemd: {source: "EXTENSION.md", target: ".claude/CLAUDE.md"}` splices every
   loaded extension's full EXTENSION.md into the generated CLAUDE.md. 16 extensions exist in the
   source store (28,829 bytes of EXTENSION.md total); 5 are loaded here. Every future extension
   load grows the eager surface linearly, regardless of task relevance.
2. **No budget, no gate**: `verify-deploy.sh` runs eleven gates (structure, parity, doc-lint,
   task references, state validation...) — none measures context bytes. There is no number that
   deploy can fail on when the eager surface grows.
3. **Unverified import semantics**: nothing tests which @-references actually load (F2), so
   authors cannot know whether an edit adds 18 KB to every session or does nothing.
4. **Unlinted rules frontmatter**: three rules lack `paths:` entirely (unconditionally loaded);
   `pr-prohibition.md` declares `paths: "**/*"` (effectively unconditional, 4.6 KB). No lint
   checks `paths:` presence or breadth, even though `lint-agent-contracts.sh` already lints
   frontmatter for agents.

"Just trim it" addresses none of these; the surface regrows with the next extension.

### F4. A harness + gate is the right task shape; pure research-and-spawn is not

The task as written ("audit, then create optimization tasks") produces a snapshot that decays
immediately: the eager surface is a function of (repo, loaded extension set, deploy freshness),
all three of which are changing in the same Task Order wave (see F5). The durable deliverables
are:

- **(b) Measurement harness** — a `measure-eager-context.sh` sibling to
  `generate-context-line-counts.sh` that, for a given repo, computes the predicted eager-load
  set: parent CLAUDE.md chain + generated CLAUDE.md + @-imports that actually resolve (using
  empirically verified resolution rules) + rules lacking `paths:` + rules with `**/*` globs —
  and emits bytes/est-tokens per contributing source, machine-diffable like
  `verify-deploy.sh --findings`.
- **(c) Budget gate** — wire a threshold into `verify-deploy.sh` as a new gate (warning-first,
  then failing), in the same findings framework the existing eleven gates use.
- **(a) Cheap wins, small and immediate** — only the provably safe subset: add `paths:`
  frontmatter to the three frontmatter-less rules; decide `pr-prohibition.md`'s glob
  deliberately; normalize @-path style *after* semantics are established.

This ordering also fixes the "create optimization tasks" step: spawned tasks become data-driven
("source X contributes Y bytes eagerly; defer it") instead of impressionistic.

### F5. Roadmap alignment and Wave-1 sequencing interactions

**Alignment**: this is not a side quest. Roadmap Phase 2 lists **Context discovery caching**
("speed up agent spawn time") and the Success Metrics include **"Time from /task creation to
first artifact < 60 seconds"** — the eager-load surface is a direct input to both. The audit is
effectively the measurement arm those roadmap lines lack. It also serves the Phase 1 "CI
enforcement of doc-lint" pattern: a context-budget gate is the same enforcement philosophy
applied to context weight.

**Wave-1 tier interactions** (task 36 shares Wave 1 with 14, 16, 17, 18, 20, 22, 27, 28, 31,
33, 34; report lives in specs/**, so task numbers are permitted here):

| Task | Interaction | Nature |
|------|-------------|--------|
| 29 (generate .mcp.json from manifests) | **Overlap/sequencing** | Both extend the manifest/deploy engine. 29 adds a new generated-artifact mechanism; context-budget fields or `merge_targets` changes spawned by 36 should land after or alongside 29 to avoid two concurrent manifest-schema churns. |
| 18 (detect stale .claude/ deploys) | **Measurement validity** | The audit must measure the *source store plus a fresh regenerate*, not the live `.claude/` tree — 18 exists precisely because the deployed tree can be arbitrarily stale. A harness that measures `.claude/` directly inherits 18's defect. |
| 32 (redeploy + remediate settings) | **Delivery vehicle** | Any narrowing of generated CLAUDE.md or rules frontmatter only takes effect at redeploy; 32 (blocked on 28, 29, 30, 31) is the natural deployment point for 36's cheap wins. |
| 31 (opencode extensions sync) | **Scope boundary** | The `.opencode/` mirror has its own generation path; 36's optimizations should either explicitly mirror there or declare themselves Claude-Code-only, or 31's sync will propagate/miss them nondeterministically. |
| 9 (deploy orphan parity, Wave 2) | **Shared substrate** | Orphan files in `.claude/context/` inflate any naive on-disk measurement; another reason the harness should predict from the source store. |
| 22 (fragment validation spam) | Minor | Same extension-fragment machinery; no real conflict. |
| 28 [IMPLEMENTING], 16 [IMPLEMENTING] | None substantive | Different subsystems (MCP ownership doc; session-id parity). |

**Net sequencing recommendation**: 36's *research and harness* can proceed now (no
dependencies, correctly placed in Wave 1). Its *spawned implementation tasks* should declare
dependencies on 29 (if touching manifest schema) and be delivered through 32's redeploy.

### F6. Adjacent wins the audit can bank

- **`generate-context-line-counts.sh`**: already computes per-entry `line_count` for every
  extension's `index-entries.json` (`--check`/`--write` modes). The harness in F4 is its natural
  sibling — same source-store-first philosophy, same check/report split. Possibly extend it with
  byte counts rather than building parallel tooling.
- **`check-extension-docs.sh` / doc-lint**: the roadmap's "CI enforcement of doc-lint" item
  would carry the budget gate for free once it exists in `verify-deploy.sh`.
- **Memory and literature injection are sibling channels**: `memory-retrieve.sh` injects
  `<memory-context>` at preflight, `--lit` injects literature files. A context *budget ledger*
  should count all three channels (static eager, rules-glob, preflight injection) or the eager
  savings will be silently spent by injection growth.
- **Docs that must stay in sync**: `context/architecture/context-layers.md`,
  `context/patterns/context-discovery.md`, and the fresh memory
  `MEM-insight-context-loading-by-at-reference.md` (which already documents that agent-body
  @-references do not auto-resolve at spawn — the audit's findings on CLAUDE.md @-resolution
  should be recorded in the same place, not a new one).
- **index.json is the intended lazy tier and it works**: 98,919 bytes of index that is *queried*
  (jq) rather than loaded. The strategic end-state is "CLAUDE.md is a table of contents,
  index.json is the card catalog, everything else is lazy" — several eager blocks (Nix tool
  guides, 17.9 KB) already have index entries and lose nothing by demotion to pointers.

### F7. Outside-the-box: invert from trimming to budgeting

Rather than one round of cuts, give the deploy engine a **per-extension eager-context budget**:
e.g. a `merge_targets.claudemd.max_bytes` (or a global budget in core) enforced at deploy time.
An extension whose EXTENSION.md exceeds budget fails deploy with a finding, exactly like
doc-lint failures. This converts context discipline from a virtue into a contract, and it is the
only shape that survives the addition of extension 17, 18, 19... A complementary empirical tool:
a canary session that records *actually injected* context (as this session inadvertently did)
against the harness's *prediction*, closing the loop on harness-semantics assumptions that
documentation currently guesses at.

## Recommended Approach

1. Keep task 36 as research, but define its deliverable as (i) verified @-import resolution
   semantics with per-occurrence classification, (ii) the measurement harness spec, (iii) a
   spawned task set with explicit Wave-1 sequencing (after 29 for schema changes, delivered via
   32).
2. Build the harness (`measure-eager-context.sh`) before any trimming; predict from the source
   store + fresh regenerate, never the live `.claude/` tree.
3. Wire a warning-first budget gate into `verify-deploy.sh`; graduate to failing once the
   surface is under budget.
4. Implement only the provably safe cheap wins immediately (rules `paths:` frontmatter; the
   `pr-prohibition.md` glob decision).
5. Record the growth-mechanism findings (F3) in `context-discovery.md`/`context-layers.md` and
   the existing context-loading memory, so the *why* survives the audit.

## Evidence/Examples

- Byte measurements: `wc -c` over deployed and source files, 2026-08-11 (this session's tool
  log). Key figures: `.claude/CLAUDE.md` 34,501; core `merge-sources/claudemd.md` 25,159;
  16 EXTENSION.md files totaling 28,829; Nix eager context 17,883; 12 deployed rules totaling
  56,310; `index.json` 98,919; root `README.md` 27,053; `commands/task.md` 37,465;
  `topic-assignment-pattern.md` 11,310 (referenced 7 times from task.md).
- Live loading behavior: initial system context of this very session (F1 table) and the
  observed rules injection after first `specs/**` read.
- Rules frontmatter survey: `grep` of `paths:` across `.claude/rules/*.md` — three files with no
  `paths:` key; `pr-prohibition.md` with `"**/*"`.
- Manifest mechanism: `agent-system/extensions/nvim/manifest.json` `merge_targets` block.
- Roadmap: `specs/ROADMAP.md` lines 33 (context discovery caching) and 40 (<60s metric).
- Task Order and dependency waves: `specs/TODO.md` lines 7-50.
- Loaded-extension set: `.claude-extensions.json` (core, email, memory, nix, nvim).

## Confidence Level

- F1 measurements, F3 mechanism, F5 sequencing, F6 adjacencies: **high** (directly measured or
  read from source).
- F2 resolution-semantics explanation (relative-to-containing-file causing `@.claude/...` to
  break): **medium** — the load/no-load asymmetry is directly observed in one session, but the
  causal rule is inferred, not tested in isolation. Verifying it empirically should be the
  audit's first step; the recommendation (classify before trimming) is robust either way.
- F4/F7 shape recommendation: **high** confidence that a harness+gate outlasts a one-off sweep;
  **medium** on the specific `max_bytes` manifest field design (needs coordination with task
  29's schema work).

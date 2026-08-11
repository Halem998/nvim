# Teammate B Findings: Alternatives and Prior Art for Context-Loading Efficiency

**Angle**: Prior art inside the repo + alternative mechanisms, ranked by savings-per-unit-of-churn.
**Method**: Measurement over assertion — all counts below were taken live from the deployed
`.claude/` tree and the source store on 2026-08-11.

## Key Findings

### F1. The index machinery is already lazy and already correct — it is NOT the eager problem

The `index.json` / `load_when` system is pull-based. Nothing reads the index at session start;
entries load only when a consumer runs the adaptive jq query from
`context/patterns/context-discovery.md` or a command preflight pulls its command-gated entries.

Live counts from `.claude/context/index.json` (5 extensions loaded: core, email, nvim, nix, memory):

| Class | Entries | Lines |
|---|---|---|
| Total | 190 | 48,084 |
| `load_when.always: true` | 3 | 334 |
| `on_demand: true` (explicit pull-only marker) | 56 | 16,936 |
| Hook-gated (agents/task_types/commands) | 131 | 30,814 |

Only 3 entries (334 lines, all READMEs) are `always: true` — excellent discipline already.
The 56 `on_demand: true` entries are exactly the set with empty `load_when` hooks; the marker's
only mechanical consumer is `validate-context-budgets.sh`'s dead-entry check (line 241-252).
**Conclusion: flipping index entries yields near-zero savings because the eager load path
bypasses the index entirely.** The "underused machinery" hypothesis is half right: the machinery
is fine, but the eager surface lives in two layers the index does not govern (F2, F3).

### F2. The dominant eager mechanism is @-import inlining from the generated CLAUDE.md — and its behavior hinges on a path-resolution quirk

`merge_targets.claudemd` in each manifest merges the extension's `EXTENSION.md` into the
generated `.claude/CLAUDE.md` (core and literature use `merge-sources/claudemd.md` instead).
`@`-references inside that generated file resolve **relative to `.claude/` (the containing
file's directory)**, verified empirically this session:

- Nix's bullets use `@context/project/nix/...` → resolves to `.claude/context/project/nix/...`
  → **EXISTS → fully inlined into every session**, regardless of task type or command.
  Measured: 5 files, 857 lines, **17,883 bytes (~4.5k tokens) of Nix domain content eagerly
  loaded for a generic `/task`** in a Neovim config repo.
- Email/nvim/formal bullets use `@.claude/context/project/...` → resolves to
  `.claude/.claude/context/...` → **missing → silent no-op**; the bullets render as plain text
  pointers. Lean's `@.claude/extensions/lean/...` form breaks the same way.

Source-store census of `EXTENSION.md` `@`-import forms:

| Form | Extensions | Effect when loaded |
|---|---|---|
| `@context/...` (resolves → eager inline) | nix, web, present, cslib | Full file contents inlined every session |
| `@.claude/...` (broken → inert pointer) | email, nvim, formal, lean | Pointer text only; zero inline cost |

Two implications: (a) the observed literature/nix/present eager load is explained by which
extensions are loaded in a given deploy plus which `@` form their `EXTENSION.md` uses; (b) four
extensions have been operating with de-facto pointer-only Context sections **and nothing broke**
— empirical proof that eager inlining of extension domain context is unnecessary. Agents that
need those files pull them by path or via the index.

### F3. Second eager layer: rules files missing machine-readable `paths:` frontmatter load unconditionally

Rules with a YAML `paths:` glob load only on path match (verified: `nix.md` with
`paths: ["**/*.nix"]` did not load this session; `git-workflow`/`error-handling`/`workflows`
loaded only after the first `.claude/**` path was touched). Three deployed rules have a prose
"Applies to" line but **no YAML `paths:` frontmatter**, making them eager at session start:

| Rule (deploy path) | Bytes | Prose scope it declares |
|---|---|---|
| `no-task-references-in-deliverables.md` | 8,821 | everything except `specs/**` |
| `neovim-lua.md` | 2,620 | `lua/**/*.lua`, `after/**/*.lua`, `*.lua` |
| `source-store-deploy-boundary.md` | 2,286 | writes targeting `.claude/**` |

Total: ~13.7 KB (~3.4k tokens) per session. For no-task-references, the blocking PreToolUse hook
(`validate-no-task-references.sh`) enforces the rule mechanically whether or not the prose is in
context, so deferring the prose to a glob is safe.

### F4. The generated `.claude/CLAUDE.md` itself is 34.5 KB (~8.6k tokens) and carries mis-sited content

- Total eager CLAUDE.md tree: 38.3 KB (`~/.config/CLAUDE.md` 0.8k + repo root 3.0k +
  `.claude/CLAUDE.md` 34.5k) before any @-inlines or rules.
- **Mis-siting found**: the `/literature` and `/cite` command rows and the `skill-literature`
  mapping row live in *core's* merge source
  (`agent-system/extensions/core/merge-sources/claudemd.md` lines 114-122, 181), so they appear
  in every deploy even though the literature extension is NOT loaded here (loaded set:
  core, email, nvim, nix, memory). Literature already has its own `merge-sources/claudemd.md`;
  these rows belong there.
- Core's merge source (373 lines) carries deep operational prose (hard-mode routing ladder,
  full memory command table) that only specific commands need — candidates for summary-stub
  indirection (pointer to a context file).

### F5. Extension load gating already works; unloading is the wrong lever here

`.claude-extensions.json` tracks `installed_files` per extension and `merge_targets` sections
are keyed by `section_id`, so unloading genuinely removes an extension's context, rules, and
CLAUDE.md section. But unloading nix to save ~4.5k tokens sacrifices nix task capability —
a per-repo policy call, not a system fix. F2's de-@ change achieves the same savings with the
extension still loaded.

### F6. Bounded/well-behaved mechanisms (no action needed)

- `memory-retrieve.sh`: `TOKEN_BUDGET=2000`, `MAX_ENTRIES` greedy selection, suppressible via
  `--clean` — already the model citizen of context injection.
- Skill roster: 31 deployed skills, 4,582 bytes of eager frontmatter descriptions (~1.1k
  tokens) — modest; progressive disclosure is already how skills work (bodies are lazy).
- Command bodies are lazy until invoked, but `/task` itself is 944 lines and `@`-references
  `topic-assignment-pattern.md` (266 lines) plus 8 command-gated index entries totaling
  2,437 lines — this is the per-invocation half of the observed ~19k, owned by the primary
  teammate's angle.

## Recommended Approach (ranked by savings-per-unit-of-churn)

All edit targets are source-store paths per the source-store/deploy boundary rule.

1. **De-@ the resolving Context bullets in `EXTENSION.md` files** — change `- @context/...` to
   plain backtick paths in `agent-system/extensions/nix/EXTENSION.md` (and web, present, cslib
   for deploys that load them). ~4.5k tokens/session saved here; a few characters of churn per
   line; zero mechanism change; four extensions already prove pointer-only sections work.
   Simultaneously normalize the *broken* `@.claude/...` forms (email, nvim, formal, lean) to the
   same plain-path style — no savings, but it converts an accidental silent failure into an
   intentional convention.
2. **Add YAML `paths:` globs to the three glob-less rules** — sources:
   `agent-system/extensions/core/rules/no-task-references-in-deliverables.md` (glob the
   deliverable trees it names: `agent-system/**`, `lua/**`, `.memory/**`, `.opencode/**`),
   `agent-system/extensions/core/rules/source-store-deploy-boundary.md` (`.claude/**`,
   `agent-system/**`), `agent-system/extensions/nvim/rules/neovim-lua.md` (the globs its own
   prose declares). ~3.4k tokens/session; three small frontmatter edits; enforcement hooks
   keep working regardless.
3. **Re-site literature command rows from core's merge source to literature's** — move lines
   114-122 and 181 of `agent-system/extensions/core/merge-sources/claudemd.md` into
   `agent-system/extensions/literature/merge-sources/claudemd.md`. Small fixed savings, small
   churn, removes actively misleading dead prose in non-literature deploys.
4. **Summary-stub indirection inside core's merge source** — replace the hard-mode routing
   ladder and other deep prose with 2-3-line stubs pointing at existing context files. Largest
   single-file upside (could halve the 34.5 KB generated file) but highest editorial churn and
   review risk; do after 1-3.
5. **Do NOT pursue**: index-entry flips (F1 — no eager path goes through the index), extension
   unloading as an efficiency measure (F5), or memory-injection changes (F6).

## Evidence / Examples

- Resolution proof: `.claude/context/project/nix/README.md` exists;
  `.claude/.claude/context/project/neovim/domain/neovim-api.md` does not — and this session's
  own context contained the five nix files fully inlined while the email/nvim bullets appeared
  as bare text.
- Index counts: jq over `.claude/context/index.json` (table in F1); the 56 `on_demand` entries
  are exactly the 56 entries with all-empty `load_when` hooks.
- `@`-form census: grep over `agent-system/extensions/*/EXTENSION.md` (F2 table).
- Rules frontmatter scan: `head -6 | grep '^paths:'` over `.claude/rules/*.md` (F3 table).
- Byte counts: `wc -c` on deployed files (F2, F3, F4).

## Confidence Level

- **High**: F1 (counted), F2 (empirically verified in-session, both directions), F3 (verified
  by which rules did/did not load this session), F6 (read the script).
- **Medium**: F4's summary-stub savings estimate (editorial judgment, not measured); the exact
  token conversion (~4 bytes/token assumed); F5's unload behavior (inferred from
  `installed_files`/`section_id` bookkeeping, not exercised).
- **Caveat**: the original ~19k observation may have come from a deploy with a different
  loaded-extension set (literature/present are not loaded in this repo's `.claude/`); the
  mechanisms identified here explain that observation regardless of which extensions produced it.

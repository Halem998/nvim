# Research Report: Extension Manifest Quick-Fix Batch

**Task**: 977 - Extension manifest quick-fix batch (keyword_overrides shape, mcpServers casing, dead weight)
**Started**: 2026-07-29
**Completed**: 2026-07-29
**Effort**: XS-S per item, batched
**Dependencies**: None blocking (task lists dependency on 976 for sequencing only)
**Sources/Inputs**: Live repo inspection (jq, grep, du, bash), `check-extension-docs.sh`, `verify-deploy.sh`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All five work items verified true against the live repo. No claim in the delegation was found to be materially wrong; one number (item 3's "76%") is imprecise — actual is ~82% by directory-total or ~73% against a hypothetical rounded 4.0M — but the qualitative claim ("dominant majority of the extension's footprint") holds regardless.
- Item 1's jq crash was reproduced exactly (`jq: error (at .../manifest.json:84): Cannot index string with string "keywords"`, exit 5).
- Item 5's judgment call resolved: **founder, filetypes, memory** should get a real `settings-fragment.json` + `merge_targets.settings` (their MCP tools are actively referenced throughout each extension's own agents/skills/context); **present**'s `mcp_servers.superdoc` block should be **deleted** — it is referenced nowhere in present's own agents/skills/context/README (a copy-paste artifact, most plausibly from `filetypes`, which legitimately owns `superdoc`).
- Baseline confirmed clean: `check-extension-docs.sh` and `verify-deploy.sh` both currently PASS (exit 0) on this repo, matching the delegation's stated baseline.
- None of the five items touch `provides.scripts`; item 4 changes a `dependencies` array (deploy-cascade-affecting per the delegation's own flag, not a doc-lint concern) and item 3 removes a file from a recursively-copied `context` directory (deploy-footprint-affecting, not a `provides` schema change).

## Context & Scope

Verify, independently, each of five extension-manifest defects listed in the review's
extension-consistency section, determine the correct fix per item, and flag any item whose
stated remedy is wrong or riskier than described — per item, with special attention to item 5's
add-fragment-vs-delete-block judgment call across four extensions.

## Findings

### Item 1 — `literature/manifest.json` `keyword_overrides` wrong shape

**Verified exactly as described.** `literature/manifest.json` has:
```json
"keyword_overrides": {
  "literature": "meta",
  "zotero": "meta",
  "bibliography": "meta",
  "citation": "meta"
}
```
— string values, where the consumer in `agent-system/extensions/core/commands/task.md` (steps
4b and 4e) runs:
```
.keyword_overrides // {} | to_entries[] | select(.value.keywords[]? as $kw | ...)
```
which requires `.value` to be an object with a `keywords` array, exactly matching the shape
`cslib/manifest.json` and `email/manifest.json` correctly use (verified: both have
`{"<type>": {"keywords": [...], "aliases": [...]}}`).

Reproduced the crash directly:
```
$ jq -r --arg desc "i need to search zotero for a citation" '
    .keyword_overrides // {} | to_entries[] |
    select(.value.keywords[]? as $kw | ($desc | test("\\b" + $kw + "\\b"))) |
    .key' agent-system/extensions/literature/manifest.json
jq: error (at agent-system/extensions/literature/manifest.json:84): Cannot index string with string "keywords"
exit 5
```
Because `task.md`'s reference pattern pipes `2>/dev/null`, this failure is silent — the loop's
`matched=$(... 2>/dev/null | head -1)` simply gets nothing for this manifest and moves on,
meaning `literature`/`zotero`/`bibliography`/`citation` keywords have never routed a task to
`meta` via this mechanism. Additionally confirmed via a prior audit report
(`specs/archive/814_synthesize_improvement_roadmap/reports/01_improvement-roadmap.md`, finding
IN-02) that this exact defect was diagnosed once before and never applied — this is a
re-discovery, not new information, and the fix is uncontroversial.

**Fix**: reshape to
```json
"keyword_overrides": {
  "meta": {
    "keywords": ["literature", "zotero", "bibliography", "citation"]
  }
}
```
No `aliases` needed (none of the four terms need remapping from another resolved type).

**Deploy-affecting**: No `provides.*` change; pure data reshape inside an already-declared
manifest field. Not caught by any `check-extension-docs.sh` rule (A-Q) since none of those rules
inspect `keyword_overrides` shape. Re-verification should re-run the jq command above directly
against the manifest (assert exit 0) rather than relying on doc-lint.

### Item 2 — `epidemiology/settings-fragment.json` snake_case `mcp_servers`

**Verified exactly as described.** File contents:
```json
{
  "mcp_servers": {
    "rmcp": { "command": "uvx", "args": ["rmcp"] }
  }
}
```
`lean/settings-fragment.json` and `nix/settings-fragment.json` both correctly use `mcpServers`
(camelCase) at the top level, matching the documented contract in
`agent-system/extensions/core/docs/architecture/extension-system.md` ("Settings Merging"
section), which explicitly states: *"The `mcp_servers` top-level field that may appear in some
manifests is NOT directly consumed by the loader. All settings merging goes through the
`merge_targets.settings` mechanism"* — and that mechanism's example fragment uses `mcpServers`.
The loader's `merge_settings()` does a plain deep-merge (objects deep-merged, arrays appended,
scalars added-if-absent) with no key-name translation, so a `mcp_servers` key inside a
`settings-fragment.json` is merged into the deployed `.claude/settings.local.json` verbatim under
that wrong key name and Claude Code never reads it as an MCP server registration. The `rmcp`
server has therefore never installed via this path.

**Fix**: rename `mcp_servers` -> `mcpServers` in `epidemiology/settings-fragment.json`. One-word
fix as described.

**Deploy-affecting**: changes merge-source content only (not `provides.scripts`); the currently
*already-merged* `.claude/settings.local.json` (if any) would need a redeploy/re-merge to pick up
the corrected key, but that's the disposable deploy artifact regenerating normally, not a
lint-gate concern.

### Item 3 — Delete `UCSF_ZSFG_Template_16x9.pptx`

**Verified, with one imprecise number.** File exists at
`agent-system/extensions/present/context/project/present/talk/templates/pptx-project/UCSF_ZSFG_Template_16x9.pptx`,
exactly **3,046,296 bytes** (matches claim precisely). Total `present` extension directory size:
**3,723,821 bytes** (`du -sb`), so the file is **~81.8%** of the extension's total size, not the
claimed 76% — a real but minor imprecision in the review's percentage, not in the underlying fact
(the file is still the dominant majority of the extension's footprint either way).

Confirmed "referenced by nothing":
- `grep -rl "UCSF_ZSFG_Template_16x9" agent-system/` returns only the file itself — zero
  references anywhere else in the repo (docs, agents, skills, index entries).
- The sibling `present/context/project/present/talk/index.json` entry for `pptx-project`
  explicitly lists `"files": ["theme_mappings.json", "generate_deck.py", "README.md"]` — the
  `.pptx` is deliberately excluded from the index metadata.
- `pptx-assembly-agent.md`'s Context References section loads only
  `theme_mappings.json`, `generate_deck.py`, and `README.md` from that directory — never the
  `.pptx` file.
- The extension's `context` provides category is a recursive directory copy
  (`copy_context_dirs`), so this file is silently re-copied into `.claude/context/...` on every
  `present` load/reload regardless of whether anything reads it.

**Fix**: delete the file. No manifest or index edit is required (it was never declared as an
individually-tracked asset) — deletion alone shrinks what the recursive context copy carries.

**Deploy-affecting**: yes, in the sense the delegation itself flags — a `context` directory
recursive-copy payload shrinks by ~3MB. Not a `provides.*` schema change, so no manifest edit
accompanies it. `check-extension-docs.sh`'s context-orphan check (Rule L, "deployed context file
with no `provides.context` source") checks the reverse direction (deployed-but-undeclared) and is
unaffected by removing a file that was already excluded from any per-file declaration.

### Item 4 — Drop literature -> filetypes dependency

**Verified exactly as described.**
- `literature/manifest.json` declares `"dependencies": ["core", "filetypes"]`.
- `grep -rn filetypes agent-system/extensions/literature/` returns **exactly one hit** — the
  manifest's own dependency declaration. No literature agent, skill, script, or context file
  mentions `filetypes`, `superdoc`, `openpyxl`, `docx`, or `xlsx` (all zero-hit).
- `filetypes/manifest.json` declares only `"dependencies": ["core"]` and is **249,273 bytes
  (~380K measured via `du -sh`)** — matches the claimed size closely.
- Cascade confirmed: `cslib/manifest.json` depends on `["core", "lean", "literature"]`;
  `lean/manifest.json` depends on `["core", "literature"]`; `literature` depends on
  `["core", "filetypes"]`. Loading `cslib` (a routine dependency for any Lean task) therefore
  force-loads `filetypes` — an extension entirely about docx/xlsx/pptx/web-scraping editing,
  wholly unrelated to literature's PDF/DJVU-to-markdown pipeline — transitively and silently.

**Fix**: remove `"filetypes"` from `literature/manifest.json`'s `dependencies` array, leaving
`["core"]`.

**Deploy-affecting**: yes — this changes what cascades and gets deployed for any repo loading
`cslib`/`lean`/`literature`. It is a `dependencies` array edit, not a `provides.scripts` edit, so
`check-extension-docs.sh`'s script/agent/rule orphan checks (Rules A-Q) are not directly
implicated, but a full re-verify after the change should confirm no currently-loaded repo's
`.claude-extensions.json` state assumes `filetypes` is present *because of* literature (i.e., a
repo that loaded `literature` expecting `filetypes` features bundled along for free would need to
explicitly load `filetypes` itself going forward — a one-time, low-risk behavior change since
literature code never used it).

### Item 5 — Orphaned `mcp_servers` blocks and empty stub cleanup

**Orphaned top-level `mcp_servers` blocks — verified exactly as described (four extensions,
matching by name):**

| Extension | `mcp_servers` content | Has `merge_targets.settings`? | Has `settings-fragment.json`? | Referenced elsewhere in the extension? |
|---|---|---|---|---|
| founder | `sec-edgar`, `firecrawl` | No | No | **Yes** — `market-agent.md`, `analyze-agent.md`, `workflow-reference.md`, `README.md` all reference these tools |
| filetypes | `superdoc`, `openpyxl` | No | No | **Yes** — heavily used across nearly every file in the extension (agents, skills, commands, context, README) |
| memory | `obsidian-memory` | No | No | **Yes** — referenced across `skill-learn`, `commands/learn.md`, multiple context/README files |
| present | `superdoc` | No | No | **No** — zero references anywhere else in `present/` outside the manifest itself |

This confirms the documented "not consumed by the loader" gap in `extension-system.md` for all
four, and independently confirms the count (exactly these four, no others — every other manifest
with a non-empty `mcp_servers` block, `lean` and `nix`, already has a matching
`settings-fragment.json` + `merge_targets.settings` route that correctly uses `mcpServers`).

**Judgment call, resolved per extension**:
- **founder, filetypes, memory**: the declared MCP tools are genuinely, extensively used by each
  extension's own agents/skills/context — these are real capability gaps, not dead
  declarations. **Add** a `settings-fragment.json` (camelCase `mcpServers`, matching the working
  `lean`/`nix` pattern) plus a `merge_targets.settings` entry pointing at
  `.claude/settings.local.json` (the target every other extension with a working settings merge
  uses) for each.
- **present**: `superdoc` is not mentioned anywhere in present's own agents, skills, context, or
  README — this looks like a copy-paste artifact (most plausibly copied from `filetypes`, which
  legitimately owns `superdoc` for docx/xlsx work; `present` has no docx-editing feature). **Delete**
  the `mcp_servers` block from `present/manifest.json` rather than wiring it up — adding a
  settings fragment here would install a tool the extension never calls.

**Empty `mcp_servers: {}` stubs — verified count matches exactly.** Repo-wide scan of all
`manifest.json` files for a literal empty `mcp_servers` object:
```
python, web, cslib, latex, typst, z3, nvim   -> 7 manifests
```
Matches the claimed "seven empty `mcp_servers: {}`" exactly, with no exclusion needed (the two
manifests already handled by items 1/2 — `literature` and `epidemiology` — don't declare an
empty `mcp_servers` field at all, so they were never in this count to begin with).

**Empty `hooks: {}` stubs — count needs a documented exclusion to match the claim.** Repo-wide
scan found **16** manifests with a literal empty top-level `hooks` object:
```
python, web, cslib, founder, latex, formal, literature, lean, filetypes, typst,
memory, epidemiology, z3, slidev, present, core   -> 16 manifests
```
The claim states "thirteen." The exact reconciliation: excluding `core` (marked
`routing_exempt: true` — it is the always-loaded base system verified through a separate
advisory lane in `check-extension-docs.sh`, not a picker-selectable extension) and `literature` +
`epidemiology` (already being edited by items 1, 2, and 4 respectively, so not "the *other*
manifests") leaves exactly **13**: `python, web, cslib, founder, latex, formal, lean, filetypes,
typst, memory, z3, slidev, present`. This reconciliation is inferred, not stated verbatim in the
delegation — flagging it explicitly so the implementer doesn't chase a literal "13" against a
naive repo-wide `grep`/`jq` count and conclude the claim is wrong. Recommend the implementation
either (a) state the exclusion rule explicitly when reporting the fix, or (b) simply clean all 16
(including `core`, `literature`, `epidemiology`) for full consistency — both are safe; (b) is
slightly more thorough and costs nothing extra since items 1/2/4 already touch those three files.

**Deploy-affecting**: none of this is a `provides.*` schema change. Adding `settings-fragment.json`
+ `merge_targets.settings` for founder/filetypes/memory *does* change what those three extensions
merge into `.claude/settings.local.json` on (re)load — this is the intended fix, not a side
effect to guard against, and is exactly analogous to the already-working `lean`/`nix` pattern.

## Decisions

- Item 5: add real settings-fragments for founder, filetypes, memory; delete the block for
  present.
- Item 5 stub cleanup: recommend cleaning all 16 empty `hooks: {}` (including `core`,
  `literature`, `epidemiology`) rather than trying to hit a literal 13, since the distinction is
  an artifact of item-grouping, not a real difference in defect severity.
- No item requires a `provides.scripts` change, so none should perturb the currently-clean
  `verify-deploy.sh` gate structurally — re-running `check-extension-docs.sh` and
  `verify-deploy.sh` after implementation is still the correct verification step per the
  delegation's stated bar.

## Risks & Mitigations

- **Item 4 risk**: a repo that loaded `literature` and is unknowingly relying on `filetypes`
  agents/skills being cascade-installed alongside it would lose that after the dependency is
  dropped. Mitigation: zero evidence this reliance exists (confirmed zero content references);
  document the change in the extension's EXTENSION.md/README changelog note so any repo relying
  on the accidental cascade can explicitly `load filetypes` itself.
- **Item 5 risk (founder/filetypes/memory fragments)**: `founder`'s fragment introduces
  `FIRECRAWL_API_KEY` as an env var passthrough (`"env": {"FIRECRAWL_API_KEY": "${FIRECRAWL_API_KEY}"}`)
  — this is consistent with how the top-level `mcp_servers` block already declared it; no new
  secret-handling risk is introduced, just activation of a previously-inert declaration.
- **Item 3 risk**: none identified; deletion is a pure dead-weight removal with zero references.
- **Item 1/2 risk**: none identified; both are shape/casing corrections matching an established,
  working sibling pattern (`cslib`/`email` for item 1, `lean`/`nix` for item 2).

## Context Extension Recommendations

- **Topic**: `extension-system.md`'s "Note on `mcp_servers`" callout is currently informative but
  passive — it explains the field is unused without flagging that manifests declaring it need an
  active audit. Given this task found four real, silently-broken instances, a short
  "Verification" subsection cross-referencing `check-extension-docs.sh` (or a new dedicated
  check) would help catch future recurrences. Not required for this batch, but worth a follow-up
  meta task: extend `check-extension-docs.sh` with a new rule that fails when a manifest declares
  a non-empty top-level `mcp_servers` without a corresponding `merge_targets.settings` entry —
  this would have caught all four orphans in this batch automatically.

## Appendix

Key commands run (representative, not exhaustive):
```bash
jq '.keyword_overrides' agent-system/extensions/literature/manifest.json
jq -r --arg desc "..." '.keyword_overrides // {} | to_entries[] | select(...) | .key' \
  agent-system/extensions/literature/manifest.json   # reproduced exit 5 crash
cat agent-system/extensions/epidemiology/settings-fragment.json
cat agent-system/extensions/lean/settings-fragment.json    # comparison (correct camelCase)
stat -c '%s' agent-system/extensions/present/.../UCSF_ZSFG_Template_16x9.pptx
du -sb agent-system/extensions/present
grep -rln "UCSF_ZSFG_Template_16x9" agent-system/
grep -rn filetypes agent-system/extensions/literature/
jq '.dependencies' agent-system/extensions/{cslib,lean,literature,filetypes}/manifest.json
for f in .../manifest.json; do jq 'has("mcp_servers")' "$f"; done   # orphan/empty scans
grep -rli "sec-edgar|firecrawl|superdoc|openpyxl|obsidian" agent-system/extensions/{founder,filetypes,memory,present}/
bash .claude/scripts/check-extension-docs.sh --quiet   # baseline PASS, all 20 extensions
bash .claude/scripts/verify-deploy.sh                  # baseline PASS
```

# Research Report: Task #710 — Teammate B Findings
# Alternative Approaches for Centralized Literature Management

**Task**: 710 - research_centralized_literature_zotero
**Role**: Teammate B — Alternative Approaches and Prior Art
**Started**: 2026-06-15T03:52:00Z
**Completed**: 2026-06-15T04:30:00Z
**Effort**: ~3 hours (deep codebase + web research)
**Sources**: Codebase (BimodalLogic, cslib, nvim .claude), Web search, Zotero.bib analysis
**Artifacts**: This report

---

## Executive Summary

- The agent system already uses a **copy-based distribution model** for skills/scripts; the literature extension is no exception. Both BimodalLogic and cslib have verbatim copies of `literature-retrieve.sh` and `skill-literature/SKILL.md`.
- The `literature-retrieve.sh` script **hardcodes its path resolution** relative to `SCRIPT_DIR/../..` (the project root) and resolves `LIT_DIR` as `$PROJECT_ROOT/specs/literature`. Centralizing requires changing this path resolution, not just adding a new directory.
- **Concrete overlaps exist**: 3 author/year bases appear in both BimodalLogic and cslib (burgess_1984, gabbay_1994, reynolds_1992), but the sectioning schemes differ, so they are not byte-for-byte duplicates.
- The Zotero local API (port 23119) introduced in Zotero 7 is the cleanest alternative to BibTeX parsing — it provides structured JSON and is read-accessible without running Zotero in a special mode.
- The `~/Projects/Literature/` directory already exists as a bare git repo (no remote yet), making a **standalone git repo approach** the path of least resistance relative to starting from scratch.
- A **symlink-per-project approach** (`specs/literature -> ~/Projects/Literature/`) is the lowest-friction implementation that avoids changing any scripts, agent system, or environment setup.

---

## Key Findings

### 1. Current Architecture Analysis

**Path Resolution in `literature-retrieve.sh`**:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
```

This is **pure relative-path resolution** — the script infers project root from its own location (`.claude/scripts/`). To support a centralized directory, either:
(a) Override `LIT_DIR` via an environment variable before the assignment, or
(b) Make the script check for a `specs/literature` symlink that resolves to a central location, or
(c) Change the script to consult an environment variable `LITERATURE_DIR` with a fallback.

Option (c) is the cleanest extension because it preserves backward compatibility: projects that still want per-project `specs/literature/` continue to work unchanged.

**Skill and script distribution**: The system distributes skills and scripts as **copies**, not symlinks, during extension install. Both projects have verbatim copies of `SKILL.md` (21806 bytes, identical content). Any change to the literature skill requires re-running install-extension across all projects.

**Index schema differences**:
- BimodalLogic uses `token_budget: 40000` (10x higher than cslib's 4000)
- Both use `version: 1` with the same `entries[]` schema
- BimodalLogic has 113 entries; cslib has 76 entries
- Overlapping author/year bases: `burgess_1984`, `gabbay_1994`, `reynolds_1992` — but with different section IDs (BimodalLogic uses `_sec01` style; cslib uses `_ch00` style)

**Zotero.bib structure** (at `~/texmf/bibtex/bib/Zotero.bib`):
- 878 total entries, 746 with `file` field (85%), 132 without
- `file` field contains semicolon-separated absolute paths to `~/Documents/Zotero/storage/{8CHAR}/{filename}.pdf`
- Multiple files per entry are common (duplicates from different import sources)
- 870 total PDF files in Zotero storage directory
- Better BibTeX generates citation keys using configurable patterns; the current keys appear to be `AuthorYear` style (e.g., `Abasnezhad2020`, `Adams1974`)
- The Better BibTeX `read-only.json` contains an empty array `[]` (no cached export data presently)

**Existing Literature repo**: `~/Projects/Literature/` exists as a git repo (local only, no remote configured) with only a README (1 line, empty body). It is ready to be built out but has no content yet.

---

## Alternative Approaches

### Alternative 1: Symlinks from `specs/literature/` to `~/Projects/Literature/`

**Mechanism**: Each project's `specs/literature/` becomes a symlink pointing to `~/Projects/Literature/` (or a subdirectory of it).

```bash
# Per-project setup
cd ~/Projects/BimodalLogic
rm -rf specs/literature   # or mv specs/literature specs/literature.bak
ln -s ~/Projects/Literature specs/literature

cd ~/Projects/cslib
ln -s ~/Projects/Literature specs/literature
```

**Effect on the agent system**:
- `literature-retrieve.sh` follows symlinks transparently — `LIT_DIR` resolves to the real path
- `skill-literature` SKILL.md operates on `specs/literature` and sees the central content
- `/literature --scan`, `/literature --convert`, `/literature --validate` all work without modification
- `index.json` lives at `~/Projects/Literature/index.json`, shared by all projects

**Pros**:
- Zero changes to any script, skill, agent, or command file
- Backward compatible with existing tool invocations
- Gitignore patterns (`specs/literature/**/*.pdf`) may or may not follow symlinks depending on git config; may need `specs/literature` itself gitignored or git symlink tracking enabled
- The central repo can be a git repo — history is preserved

**Cons**:
- Git behavior with symlinks is non-trivial: `git add specs/literature` adds the symlink itself, not its contents. Projects must gitignore or handle the symlink explicitly.
- All projects see ALL literature, not just their relevant subset. The `literature-retrieve.sh` keyword scoring mitigates this (irrelevant entries score 0 and are excluded), but `token_budget` still constrains how many files are injected.
- Parallel agent invocations across projects could cause concurrent writes to `index.json` (race condition on the shared file)
- No per-project scoping of `/literature --convert` — converting a file for one project would appear in the shared index visible to all

**Git symlink handling specifics**:
```bash
# In each project .gitignore, add:
/specs/literature

# Or, to track the symlink itself but not follow it:
git config --global core.symlinks true
```

**Confidence**: High — this is architecturally the simplest approach and requires no code changes.

---

### Alternative 2: Git Submodule Pointing to Shared Literature Repo

**Mechanism**: Push `~/Projects/Literature/` to a remote (GitHub/GitLab/local gitolite), then add it as a submodule in each project at `specs/literature`.

```bash
# Set up remote
cd ~/Projects/Literature
git remote add origin <remote_url>
git push -u origin master

# Add to each project
cd ~/Projects/BimodalLogic
git submodule add <remote_url> specs/literature
git commit -m "Add centralized literature as submodule"

cd ~/Projects/cslib
git submodule add <remote_url> specs/literature
git commit -m "Add centralized literature as submodule"
```

**Effect on the agent system**:
- Same as the symlink approach from the script's perspective — `specs/literature` is just a directory
- Git submodule pins to a specific commit — updating literature requires `git submodule update --remote && git commit`
- The `/literature --convert` flow would write to the submodule directory, requiring a separate commit in the Literature repo

**Pros**:
- Version-controlled relationship between project and literature content
- Literature repo can have its own commit history, branches, and CI
- Cross-machine reproducibility: `git clone --recurse-submodules` fetches everything
- Literature content is committed (markdown), unlike PDFs (gitignored)

**Cons**:
- Two-step commit process when adding new literature: first commit in Literature repo, then update submodule pointer in project repo
- `git submodule update` is not automatic — easy for submodule to drift from intended version
- The skill writes to `specs/literature/index.json` — if the submodule is checked out read-only (detached HEAD), writes fail
- Requires network access to the Literature remote for new machine setup
- Cognitive overhead: developers must understand submodule semantics
- The agent system scripts do not explicitly handle submodule update workflows

**Confidence**: Medium — technically sound but operationally heavier. Better suited if the Literature repo needs to be independently versioned and shared across machines/users.

---

### Alternative 3: Environment Variable `LITERATURE_DIR` with Fallback

**Mechanism**: Modify `literature-retrieve.sh` (and potentially `skill-literature`) to check `$LITERATURE_DIR` environment variable before falling back to `$PROJECT_ROOT/specs/literature`.

```bash
# In literature-retrieve.sh, replace:
LIT_DIR="$PROJECT_ROOT/specs/literature"

# With:
LIT_DIR="${LITERATURE_DIR:-$PROJECT_ROOT/specs/literature}"
```

Set `LITERATURE_DIR` via Home Manager in `home.nix`:

```nix
home.sessionVariables = {
  LITERATURE_DIR = "/home/benjamin/Projects/Literature";
};
```

Or via `~/.config/fish/config.fish`, `~/.bashrc`, or NixOS module.

**Effect on the agent system**:
- Projects with no local `specs/literature/` automatically use the central repo
- Projects can still override by setting a project-local `LITERATURE_DIR` (not practical from within Claude Code without shell wrapper)
- `/literature` command and `--lit` flag both use `literature-retrieve.sh`, so both benefit

**Pros**:
- Clean separation: env var is configuration, script behavior is unchanged
- Minimal code change (one line in `literature-retrieve.sh`, which is distributed per-project)
- NixOS Home Manager makes this declarative and reproducible
- Allows per-project override: wrapper script can set `LITERATURE_DIR` before invoking Claude Code
- Compatible with the skill-literature SKILL.md without changes (it references `specs/literature` as a display path, not a hardcoded path)
- Works with all existing subcommands: `--scan`, `--convert`, `--validate`, `--index`

**Cons**:
- Requires updating `literature-retrieve.sh` in ALL projects (currently distributed as copies, not symlinks — manual re-run of `install-extension.sh` needed in each project)
- If `LITERATURE_DIR` is set globally, `/literature --convert` in any project writes to the central location — intended, but requires awareness
- The `skill-literature` SKILL.md hardcodes display text like `specs/literature/` in status messages — cosmetically incorrect but functionally harmless
- Environment variables are not visible to Claude Code agent subprocesses unless explicitly inherited through the shell that launches Claude Code

**Shell inheritance note**: Claude Code inherits the shell environment when launched from a terminal. If `LITERATURE_DIR` is set in `home.sessionVariables` (which propagates via PAM/systemd session), it will be available. The systemd user session variables (`systemd.user.sessionVariables`) are the most reliable path for NixOS users.

**Confidence**: High — this is architecturally the right abstraction for a cross-project tool.

---

### Alternative 4: XDG-Standard Location (`~/.local/share/literature/`)

**Mechanism**: Store the central literature at `~/.local/share/literature/` following the XDG Base Directory Specification. Set `LITERATURE_DIR` to this path.

```nix
# home.nix
home.sessionVariables = {
  LITERATURE_DIR = "${config.xdg.dataHome}/literature";
  # Or hardcoded:
  # LITERATURE_DIR = "/home/benjamin/.local/share/literature";
};
```

**Pros**:
- Follows XDG standard — the canonical location for per-user persistent application data
- `~/.local/share/` is already in `XDG_DATA_DIRS`, making it discoverable by other tools
- NixOS/Home Manager natively understands `xdg.dataHome`
- Avoids cluttering `~/Projects/` with what is conceptually user-level data, not a project

**Cons**:
- `~/.local/share/literature/` is NOT a git repo by default — needs explicit git init
- The existing `~/Projects/Literature/` git repo would be abandoned or moved
- Less visible to users who manage their projects under `~/Projects/`
- The Zotero storage is at `~/Documents/Zotero/storage/` — a different subtree than `~/.local/share/`. Symlinking PDFs from Zotero storage to `~/.local/share/literature/pdfs/` adds complexity.

**Confidence**: Medium — XDG is the "correct" standard, but `~/Projects/Literature/` as an explicit git project is more consistent with how the user already organizes work.

---

### Alternative 5: Nix Flake Input for Literature

**Mechanism**: Treat the Literature repo as a Nix flake input in each project's `flake.nix`. The literature content (markdown + index.json) is fetched at `nix flake update` time and made available via a derivation.

```nix
# In BimodalLogic/flake.nix
{
  inputs = {
    literature = {
      url = "github:benbrastmckie/Literature";
      flake = false;  # treat as raw source
    };
  };
  
  outputs = { self, nixpkgs, literature, ... }: {
    devShells.default = pkgs.mkShell {
      LITERATURE_DIR = "${literature}";
    };
  };
}
```

**Pros**:
- Fully reproducible: `flake.lock` pins the exact literature commit used by each project
- Literature updates are explicit (`nix flake update literature`)
- Nix store provides immutable content
- Works across machines with no manual setup after `nix develop`

**Cons**:
- Literature is read-only in the Nix store — `/literature --convert` and `/literature --index` cannot write to it
- Requires the Literature repo to be a public GitHub/GitLab repo (or use Nix flake with SSH)
- Nix store paths are non-deterministic across systems (`/nix/store/HASH-...`)
- `literature-retrieve.sh` runs outside `nix develop` when Claude Code is running
- Complexity disproportionate to the benefit for a single-user setup
- The `devShells.default` trick only sets `LITERATURE_DIR` inside `nix develop` shell, not in Claude Code's environment

**Confidence**: Low — elegant in principle but fundamentally incompatible with the write-based literature management workflow (`/literature --convert` needs to write to the directory).

---

## Alternative BibTeX Integration Patterns

### Pattern 1: Zotero Local API (Recommended Alternative)

Zotero 7 introduced a local REST API at `http://localhost:23119/api/`. Currently (as of mid-2026), it supports read requests only. This provides structured JSON access to the Zotero library without parsing BibTeX.

```bash
# List items with attachment paths
curl "http://localhost:23119/api/users/0/items?format=json&include=data,file" 2>/dev/null

# Get items by BibTeX key (requires Better BibTeX)
curl "http://localhost:23119/better-bibtex/item?key=Abasnezhad2020" 2>/dev/null
```

**Better BibTeX also exposes its own JSON API**:
```bash
# Get citation key for a given item
curl "http://localhost:23119/better-bibtex/cayw?format=pandoc" 2>/dev/null
```

**Use case for centralization**: A script that queries `http://localhost:23119/api/` to enumerate all items with PDF attachments, then copies or symlinks PDFs to `~/Projects/Literature/pdfs/{bib_key}.pdf`, is cleaner than parsing Zotero.bib. No BibTeX parsing required; metadata comes pre-structured as JSON.

**Constraint**: Requires Zotero to be running. Suitable for interactive import workflows, not for background/headless use.

**Confidence**: High (for interactive import) / Low (for background sync)

---

### Pattern 2: Better BibTeX CSL-JSON Auto-Export

Better BibTeX supports auto-exporting in CSL-JSON format (pandoc-compatible). This can be configured to auto-update when the Zotero library changes.

**CSL-JSON structure** (compared to BibTeX):
```json
[
  {
    "id": "Abasnezhad2020",
    "type": "article-journal",
    "title": "Leibnizian Identity and Paraconsistent Logic",
    "author": [{"family": "Abasnezhad", "given": "Ali"}],
    "issued": {"date-parts": [[2020, 7]]},
    "URL": "...",
    "note": "file: /home/benjamin/Documents/Zotero/storage/QYLBSWIN/..."
  }
]
```

**Advantages over BibTeX parsing**:
- JSON parsing is trivially reliable (`jq`); BibTeX parsing requires a proper parser (backslash escapes, encoding issues, multi-file separators)
- Authors are pre-structured as `[{family, given}]` arrays — no "Last, First" parsing needed
- Date parts are structured: `[[2020, 7]]` not a string

**Auto-export config**: In Zotero > Edit > Better BibTeX preferences > Automatic export, configure export to `/home/benjamin/Projects/Literature/zotero-library.json` in CSL-JSON format with "On change" trigger.

**Confidence**: High — this is the most reliable way to get structured Zotero metadata into the Literature repo.

---

### Pattern 3: Direct BibTeX Parsing

The current Zotero.bib at `~/texmf/bibtex/bib/Zotero.bib` is already auto-updated by Better BibTeX. The `file` field uses `{path}` (no escaping beyond LaTeX) and semicolon separation for multiple files.

**Parsing with bash** (for the first PDF in each entry):
```bash
# Extract bib_key -> first PDF path mapping
awk '
  /^@/ { key = $0; gsub(/^[^{]*\{/, "", key); gsub(/,.*/, "", key) }
  /^  file = \{/ {
    file = $0
    gsub(/^  file = \{/, "", file)
    gsub(/\}.*/, "", file)
    split(file, parts, ";")
    for (i in parts) {
      if (parts[i] ~ /\.pdf$/) { print key "\t" parts[i]; break }
    }
  }
' ~/texmf/bibtex/bib/Zotero.bib
```

**Reliability concern**: The file field occasionally has descriptors (`{Description:path:type}` format from some translators), not always bare paths. Zotero.bib generated by Better BibTeX uses bare paths, but this should be verified.

**Confidence**: Medium — works for this specific setup, but fragile across Zotero versions.

---

## PDF Storage Strategy Alternatives

### Strategy 1: Symlinks from `~/Projects/Literature/pdfs/` to Zotero Storage (Recommended)

```
~/Projects/Literature/
├── index.json
├── pdfs/
│   ├── Abasnezhad2020.pdf -> /home/benjamin/Documents/Zotero/storage/QYLBSWIN/Abasnezhad - 2020 -.pdf
│   ├── Adams1974.pdf -> /home/benjamin/Documents/Zotero/storage/79KBB6RH/Adams - 1974 -.pdf
│   └── ...
└── converted/
    ├── Abasnezhad2020.md
    └── ...
```

**Pros**: No duplication; Zotero remains the canonical PDF store; symlinks update automatically when Zotero moves files (though Zotero doesn't move files once stored).
**Cons**: Symlinks in the git repo require `git config core.symlinks true`; remotes may not preserve symlinks.

### Strategy 2: Copy to `~/Projects/Literature/pdfs/` on Import

When adding a new paper to the Literature repo, copy the PDF from Zotero storage:
```bash
cp "/home/benjamin/Documents/Zotero/storage/QYLBSWIN/Abasnezhad - 2020 -.pdf" \
   ~/Projects/Literature/pdfs/Abasnezhad2020.pdf
```

**Pros**: Decoupled from Zotero — PDFs exist in Literature even if Zotero is removed; portable to other machines.
**Cons**: Storage duplication (870 PDFs at average ~5MB = ~4.3GB); git would want to track or ignore them; gitignore for `pdfs/*.pdf` needed.

### Strategy 3: Content-Addressable Storage by SHA256 Hash

Store PDFs by their SHA256 hash, similar to Git's object model:
```
~/Projects/Literature/
├── objects/
│   ├── ab/
│   │   └── ab1234...pdf   # SHA256 of file content
│   └── ...
├── refs/
│   └── bib_keys.json       # bib_key -> sha256 mapping
└── index.json
```

**Pros**: True deduplication (multiple Zotero entries pointing to same PDF are stored once); efficient for large libraries.
**Cons**: Significant tooling overhead to build and maintain; no existing tool in the agent system uses this pattern; overkill for a single-user setup.

### Strategy 4: Markdown-Only, No PDFs (Current Per-Project Pattern)

Keep PDFs in Zotero storage only. The Literature repo contains only converted markdown. When needed, the `file` field in Zotero.bib provides the path to the original PDF.

**This is the current approach** for BimodalLogic and cslib — PDFs are gitignored and manually re-added after checkout.

**Recommendation**: For the centralized repo, this remains the right choice. The Literature repo should be markdown-only with a `gitignore` for `**/*.pdf`. The `index.json` can include a `zotero_pdf_path` field pointing into Zotero storage, enabling `/literature --convert` to re-convert from source.

---

## Prior Art and Existing Tools

### Academic Reference Management CLI Tools

- **Papis** (Python, active 2025): Full CLI bibliography manager with local file organization, BibTeX/CSL-JSON export, and document storage. Supports "linked" vs "copied" file storage. Would require migrating away from Zotero as the primary manager.
- **Zotcite/Zotero.vim**: Neovim plugins for Zotero integration (relevant given this is a neovim config repo). Reads from Zotero database directly.
- **BibTeX-Tool** / `bibtool`: Command-line BibTeX processing, useful for batch operations on Zotero.bib.
- **Pandoc + CSL-JSON**: Pandoc natively reads CSL-JSON for citations; a Literature repo exporting CSL-JSON could be used directly by pandoc for citation processing.

### Zotero MCP Server (Emerging Pattern, 2025-2026)

A Zotero MCP server (kujenga/zotero-mcp) appeared in late 2024/early 2025. It exposes the Zotero local API as MCP tools for LLMs, including Claude. This is the most forward-looking integration pattern:

```
Claude Code (agent) -> MCP tool -> Zotero local API -> library metadata + PDF paths
```

Rather than parsing Zotero.bib or maintaining a separate Literature repo, agents could query Zotero directly for "papers about temporal logic" and get back structured results including PDF paths. This would eliminate the need for the `index.json` system entirely for metadata queries.

**Caveat**: The MCP server still requires Zotero to be running. The `/literature --convert` workflow (PDF -> markdown chunks) would still be needed.

### Multi-Repo Shared Context in AI Coding Tools

The "Codified Context" pattern (2026) suggests three-tier architecture:
1. Hot-memory: per-project context (CLAUDE.md, `.memory/`)
2. Warm-memory: shared domain knowledge (`.claude/context/`)
3. Cold-memory: literature/spec documents (currently `specs/literature/`)

The shared `.config/.claude/` hierarchy already handles tiers 1 and 2 via the extension distribution system. The literature tier has not yet been centralized.

The agent system's current pattern — copying skill files during `install-extension` — creates drift between projects. A symlink-based approach at the literature directory level avoids this for the content (index.json, markdown) while not requiring changes to the skill distribution mechanism.

---

## Agent System Integration Analysis

### How Cross-Project Concerns Are Currently Handled

The shared `~/.config/.claude/` directory handles **code** (skills, scripts, agents, commands) via copy-on-install. It does NOT handle **data** (literature content, project memory). Each project has its own:
- `specs/literature/` — literature content
- `.memory/` — project-specific memories
- `specs/state.json` — task state

The literature extension manifest (`routing_exempt: true`) signals that literature management is not task-type-routed — it's always available globally.

**Key architectural observation**: The current agent system has no concept of shared data across projects. The extension system is for code, not content. A centralized Literature repo fills this gap for literature specifically.

### How `/literature` Command Should Discover Central Repo

Current flow:
```
/literature -> skill-literature -> literature-retrieve.sh
                                -> PROJECT_ROOT/specs/literature
```

Proposed flow with `LITERATURE_DIR` env var:
```
/literature -> skill-literature -> literature-retrieve.sh
                                -> ${LITERATURE_DIR:-PROJECT_ROOT/specs/literature}
```

The `--lit` flag in `/research`, `/plan`, `/implement` flows through the same `literature-retrieve.sh`. All three commands benefit from the change automatically.

**Display text in skill-literature SKILL.md**: The skill uses `specs/literature/` in user-facing messages (Status display, Scan display, etc.). If the actual directory is `~/Projects/Literature/`, these messages will be cosmetically wrong. Recommend either:
- Accept the cosmetic discrepancy (functionally harmless)
- Add a display variable that resolves to the actual path: `LIT_DISPLAY="${LITERATURE_DIR:-$PROJECT_ROOT/specs/literature}"`

---

## Recommended Architecture (Synthesis)

Based on all findings, the most pragmatic design minimizes code changes while delivering centralization. The recommendation:

**Phase 1 (immediate, no code changes)**:
1. Use `~/Projects/Literature/` as the central Literature repo (already exists)
2. Create symlinks: `specs/literature -> ~/Projects/Literature` in each project
3. Gitignore `specs/literature` in each project (to avoid tracking the symlink)
4. Unify the `index.json` — adopt cslib's schema (has `bib_key` field; BimodalLogic's doesn't always)

**Phase 2 (minimal code change)**:
1. Add `LITERATURE_DIR` env var support to `literature-retrieve.sh` (one-line change)
2. Set `LITERATURE_DIR=/home/benjamin/Projects/Literature` in `home.nix` `systemd.user.sessionVariables`
3. Remove symlinks; projects that don't want to contribute to central repo simply don't set `LITERATURE_DIR`
4. Re-distribute updated `literature-retrieve.sh` to all projects via `install-extension.sh`

**Phase 3 (Zotero integration)**:
1. Configure Better BibTeX auto-export to CSL-JSON at `~/Projects/Literature/zotero-library.json`
2. Add a `--import-from-zotero` mode to `/literature` that: reads CSL-JSON, finds PDF in Zotero storage, runs `/literature --convert` for the selected entry, adds `bib_key` to index entry
3. Or: integrate Zotero MCP server if it becomes stable enough

---

## Decisions

1. **Symlinks are the path of least resistance** — they work with zero code changes and the agent system's path resolution follows them transparently.
2. **`LITERATURE_DIR` env var is the right long-term abstraction** — it makes the centralization explicit and configurable without hardcoding paths.
3. **CSL-JSON > BibTeX parsing** — Better BibTeX's CSL-JSON export is more reliable and easier to process than BibTeX field parsing (semicolons, LaTeX encoding, multi-file entries).
4. **Markdown-only repo, PDFs stay in Zotero** — the gitignore-for-PDFs pattern already works in per-project setup; extend it to the central repo. Add `zotero_pdf_path` to index entries for traceability.
5. **No Nix flake input** — incompatible with write-based literature management. Use Home Manager `sessionVariables` instead for env var propagation.
6. **Git submodule is appropriate only if** the Literature repo needs to be shared across multiple machines or users. For a single-user single-machine setup, a symlink is simpler.

---

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Concurrent writes to central `index.json` from multiple agents | Medium | Use `--lit` (read) in parallel but serialize `/literature --index`/`--convert` (writes) |
| Git symlink behavior surprises (symlink tracked, not contents) | Low | Gitignore `specs/literature` in each project |
| Zotero storage paths change across machines | Medium | Use `LITERATURE_DIR` as the indirection; CSL-JSON export uses absolute paths that vary per machine |
| `token_budget` discrepancy (BimodalLogic uses 40000, cslib uses 4000) | Low | Unified central repo picks one value; recommend 8000 (current `literature-retrieve.sh` default) |
| Literature repo grows large (189 entries already) | Low | Keyword scoring already handles this — irrelevant entries excluded; `MAX_FILES=10` cap |
| `skill-literature` display text shows wrong path | Low | Cosmetic only; document the discrepancy |

---

## Context Extension Recommendations

- **Topic**: Cross-project shared data conventions
- **Gap**: The agent system documents how code (skills, scripts) is distributed across projects but has no pattern for shared data (literature, memory) across projects
- **Recommendation**: Create `.claude/context/patterns/cross-project-data.md` documenting the `LITERATURE_DIR` pattern and when to use symlinks vs env vars vs git submodules for shared data

---

## Appendix: Search Queries Used

- "Zotero Better BibTeX auto-export CSL-JSON format 2025 2026"
- "centralized academic literature git submodule shared repo multi-project 2025"
- "Zotero local API REST server pyzotero pybtex bibtex parsing 2025"
- "knowledge base as code AI agent shared context multi-repo literature 2025 2026"
- "content addressable storage PDF deduplication hash-based reference management 2025"
- "NixOS home-manager environment variable XDG data directory shared resources 2025"

## Sources

- [Better BibTeX for Zotero — Bundled Translators](https://retorque.re/zotero-better-bibtex/installation/bundled-translators/)
- [Better CSL JSON Translator](https://github.com/retorquere/zotero-better-bibtex/blob/master/translators/Better%20CSL%20JSON.ts)
- [Zotero Local API (pyzotero integration)](https://forums.zotero.org/discussion/116548/how-to-use-pyzotero-to-access-zotero-7-beta-local-api-server)
- [Zotero MCP Server](https://mcpservers.org/servers/kujenga/zotero-mcp)
- [Git Submodule Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [Managing Shared Data with Git Submodules](https://medium.com/@ankitdhaka4140/managing-shared-data-across-repos-with-git-submodules-f1a2659e0976)
- [XDG Configuration in Home Manager](https://deepwiki.com/nix-community/home-manager/4.7.2-xdg-configuration)
- [Home Manager xdg.dataHome](https://mynixos.com/home-manager/option/xdg.dataHome)
- [Codified Context: AI Agent Infrastructure](https://arxiv.org/html/2602.20478v1)

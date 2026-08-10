# Research Report: Task #710 — Teammate C (Critic) Findings

**Task**: 710 - Research architecture for centralizing literature management across repos with Zotero.bib integration
**Role**: Teammate C — Critic
**Started**: 2026-06-14T21:40:00Z
**Completed**: 2026-06-14T22:10:00Z
**Effort**: ~30 min (codebase + filesystem analysis)
**Sources/Inputs**: Codebase (skill-literature/SKILL.md, literature-retrieve.sh, skill-base.sh, literature.md command, literature-organization.md guide), filesystem (~/texmf/bibtex/bib/Zotero.bib, ~/Projects/BimodalLogic/specs/literature/, ~/Projects/cslib/specs/literature/, ~/Projects/Literature/)
**Artifacts**: This report

---

## Executive Summary

The centralization proposal is technically feasible but rests on several unvalidated assumptions
and introduces architectural risks the task description does not adequately address. The most
critical issues are: (1) `literature-retrieve.sh` has a hardcoded `SCRIPT_DIR/../..` path
resolution that cannot be overridden by environment variable without surgery on the script itself;
(2) the existing per-repo indexes use a legacy schema (v1 without `doc_type`/`source_format`)
while SKILL.md validate mode already treats these as required; (3) bib_key naming diverges
between repos AND between repos and Zotero.bib, making reliable Zotero-to-literature cross-
referencing fragile; (4) the `~/Projects/Literature/` repo already exists (git init, bare
README), meaning the design space is partly pre-committed. These gaps need explicit decisions
before any plan phase.

---

## Key Findings

### Finding 1: literature-retrieve.sh path resolution is hardcoded, not env-var-driven

The script at `.claude/scripts/literature-retrieve.sh` (and the per-project deployed copies)
derives PROJECT_ROOT using:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIT_DIR="$PROJECT_ROOT/specs/literature"
```

This is called from `skill-researcher/SKILL.md` as:

```bash
lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null)
```

The working directory at call time is the project root (e.g., `~/Projects/BimodalLogic/`).
`SCRIPT_DIR` resolves to `~/Projects/BimodalLogic/.claude/scripts/`, so `PROJECT_ROOT` is
`~/Projects/BimodalLogic/` and `LIT_DIR` is `~/Projects/BimodalLogic/specs/literature/`.

**There is currently no LITERATURE_DIR environment variable support.** The task description
assumes this feature will be added, but it is not present. Any centralization plan must actually
add this env-var override to literature-retrieve.sh. This is a code change, not just a
configuration change.

Additionally, the `skill-literature` (SKILL.md) similarly uses:

```bash
lit_dir="specs/literature"
index_file="$lit_dir/index.json"
```

This is a **relative path**, always resolving to `$PWD/specs/literature`. It cannot be
redirected to `~/Projects/Literature/` without changing either the working directory or the
script logic.

**Impact**: The entire centralization proposal depends on a code change that is not yet made.
The task description treats `LITERATURE_DIR` as an existing mechanism; it is not.

---

### Finding 2: ~/Projects/Literature/ already exists but is empty

The proposed central repo at `~/Projects/Literature/` already exists as a git repository
(initialized, one commit: "init commit", only a blank README.md). This is a positive signal
that the user has already conceptualized this location. However:

- It has no `.claude/` system, no `specs/literature/`, no `index.json`
- It has no defined directory structure beyond the README
- The README is empty (0 bytes)

This means the design is starting from a blank slate in a pre-existing repo, which avoids the
"should we create it?" question but immediately raises "what directory layout goes inside it?"

---

### Finding 3: Schema mismatch between existing indexes and current SKILL.md

The existing per-repo `index.json` files in BimodalLogic (111+ entries) and cslib (30+ entries)
use the original schema (v1):

```json
{"id", "bib_key", "title", "authors", "year", "section", "path", "page_range", "token_count", "keywords", "summary"}
```

The current `skill-literature/SKILL.md` validate mode already treats `doc_type` and
`source_format` as **required v2 fields** and will emit schema warnings for all existing entries:

```
### Schema Warnings ({count}) — entries missing required v2 fields
- entry_path (missing fields: doc_type, source_format)
```

Confirmed: neither BimodalLogic nor cslib index has any `doc_type` or `source_format` values:
- `cat .../index.json | jq '[.entries[].doc_type] | map(select(. != null)) | length'` → `0` for both

**Impact**: Migrating existing content to a centralized index requires a schema migration pass.
The plan must account for populating `doc_type` (paper/book/chapter/section) and `source_format`
(pdf/djvu/manual) for all ~141 existing entries before or during migration.

---

### Finding 4: bib_key naming is divergent across repos and does not match Zotero.bib

Confirmed key divergence:

| Paper | Zotero.bib key | BimodalLogic key | cslib key |
|-------|---------------|-----------------|-----------|
| Burgess 1982 "Since and Until" | `Burgess1982` | `Burgess1982` | `Burgess1982I` |
| Burgess 1982 "Time Periods" | `Burgess1982a` | `Burgess1982b` | `Burgess1982II` |
| Burgess 1984 | `Burgess1984` | `Burgess1984` | `Burgess1984` |
| Gabbay/Hodkinson/Reynolds 1994 | `GHR94` | `GHR94` | `GHR94` |

The cslib repo independently coined `Burgess1982I` / `Burgess1982II`, while Zotero uses
`Burgess1982` / `Burgess1982a` and BimodalLogic uses `Burgess1982` / `Burgess1982b`.

This means a Zotero.bib-to-literature lookup cannot use `bib_key` as a reliable join key
without normalization. Any auto-population of literature entries from Zotero.bib would need
to handle: (a) repo-local key divergence, (b) Zotero Better BibTeX key style vs. per-repo
ad-hoc keys.

**Additionally**: Only 3 papers overlap between BimodalLogic and cslib collections
(`Burgess1984`, `GHR94`, `Reynolds1994`), but the content is in different chunk granularities:
BimodalLogic has `burgess_1984/` with 7 sub-chunks; cslib has a flat `burgess_1984.md`. These
represent the same source paper but in incompatible chunk structures.

---

### Finding 5: Zotero.bib file field format has complicating factors

The `.bib` file contains 878 entries, 746 with `file` fields, 132 without.

Key format complications:
1. **Multiple files per entry**: 138 entries have semicolon-separated file lists (e.g.,
   `{path1.pdf;path2.pdf;path3.pdf}`). Any parser must handle multi-file entries.
2. **Paths are absolute and hardcoded to `/home/benjamin/`**: Every `file = {` value uses
   `/home/benjamin/Documents/Zotero/storage/XXXXXXXX/...`. This is not portable.
3. **Opaque storage directory names**: Zotero uses random 8-character IDs (e.g., `QYLBSWIN`)
   as subdirectory names. The human-readable filename is embedded in the path but the directory
   is not human-navigable.
4. **LaTeX character encoding in filenames**: Some filenames contain LaTeX-encoded characters
   (e.g., `Néti néti` with accented characters in the path string, `\={a}` sequences in
   abstracts). Path parsing must handle Unicode filenames.
5. **Missing `file` fields (132 entries)**: 15% of entries have no associated PDF. A Zotero
   integration must gracefully handle entries without local PDFs.

**Impact**: Parsing Zotero.bib to populate Literature/ is more complex than the task
description implies. A robust parser needs: multi-file splitting, path validation, Unicode
handling, and missing-file fallback.

---

### Finding 6: No concurrency protection exists or is planned

The current per-repo `specs/literature/index.json` modifications use a `mktemp` + `mv` pattern
(atomic write). However:
- Multiple Claude Code sessions working simultaneously in different repos could both write to
  a centralized `~/Projects/Literature/index.json` simultaneously
- The `mv` pattern prevents file corruption but does NOT prevent last-write-wins data loss
- Git conflicts would accumulate if both BimodalLogic and cslib tasks commit to Literature/
  in the same session

The task description mentions LITERATURE_DIR as a path variable but says nothing about locking
or commit serialization. For a shared repo, this is a real operational risk.

---

### Finding 7: The /literature command and skill operate on the CWD, not a global path

The `/literature` command dispatches to `skill-literature` which uses `lit_dir="specs/literature"`
(a CWD-relative path). Even if `--lit` injection is redirected to a central repo via env var,
the `/literature` command (`--scan`, `--convert`, `--validate`, `--index`) would still operate
on the current project's `specs/literature/`. These are two separate code paths that must both
be updated.

---

## Unvalidated Assumptions

The task description contains several assumptions that I have now either confirmed or identified
as false:

| Assumption | Status | Finding |
|-----------|--------|---------|
| `~/texmf/bibtex/bib/Zotero.bib` exists | CONFIRMED | 878 entries, 693KB |
| `~/Projects/BimodalLogic/specs/literature/` exists | CONFIRMED | 111+ index entries |
| `~/Projects/cslib/specs/literature/` exists | CONFIRMED | 30+ index entries |
| `~/Projects/Literature/` exists | CONFIRMED | Bare git repo, blank README |
| `LITERATURE_DIR` env var mechanism exists | FALSE | Not implemented |
| Existing indexes use unified schema | FALSE | Schema v1, missing doc_type/source_format |
| bib_keys are consistent across repos | FALSE | Divergent naming (Burgess1982 vs Burgess1982I) |
| PDF storage is portable | FALSE | Hardcoded /home/benjamin/ absolute paths |
| Literature content is cleanly duplicated | PARTIAL | Only 3/110+ entries overlap |

---

## Architecture Risks

### Risk 1: Single Point of Failure (HIGH)
Centralizing all literature into `~/Projects/Literature/` makes every project dependent on
that repo's availability and consistency. If the index.json becomes corrupted or out of sync,
ALL projects using `--lit` silently get no literature injection (the script exits 1). There is
no per-project fallback.

**Current behavior**: Each project's `specs/literature/` failing silently is scoped to that
project. Centralization propagates any failure globally.

**Mitigation needed**: Either keep per-project `specs/literature/` as fallback, or add
explicit error reporting when LITERATURE_DIR is set but unreachable.

### Risk 2: Zotero Auto-Export Schema Drift (MEDIUM)
The Zotero.bib is maintained by Better BibTeX auto-export. If the user changes Better BibTeX
settings, updates Zotero, or changes citation key format, the `.bib` schema can change.
Specific drift vectors:
- Better BibTeX citation key patterns are user-configurable (AuthorYear vs author_year etc.)
- Field names vary between BibTeX export profiles (`file` vs `pdf` vs attachment)
- Zotero 7 changed some export behaviors vs Zotero 6

Any integration that parses Zotero.bib should treat it as an external, non-controlled artifact
and be defensive about field name and format assumptions.

### Risk 3: Environment Variable Non-Propagation (HIGH)
If `LITERATURE_DIR` is set in `.bashrc`, it will NOT be available to:
- Claude Code sessions started from GUI (e.g., Neovim terminal without sourcing shell profile)
- Cron jobs or scheduled tasks
- SSH sessions that don't source `.bashrc` (many SSH configs use non-interactive shell)
- Subshells that don't inherit the environment if the agent system resets the shell environment

The task description says `~/Projects/Literature/` is the "default", implying the env var is
optional. But if the default is only a fallback for when the env var is absent, the detection
logic must be: "use LITERATURE_DIR if set and exists, else fall back to per-project
specs/literature/". This is a conditional that literature-retrieve.sh does not currently have
and must be explicitly specified.

### Risk 4: Git Conflict Surface in Shared Repo (MEDIUM)
Every `/literature --convert` or `/literature --index` in any project would commit to
`~/Projects/Literature/`. If two projects are being worked on simultaneously (two terminal
sessions, two Claude Code instances), both can:
1. Read index.json
2. Modify it
3. Commit independently

Without a locking mechanism, this creates git conflicts. The current per-project workflow
avoids this because projects are independent. Shared repos require explicit coordination.

### Risk 5: Per-Project Content Loses Project Context (MEDIUM)
The existing literature in BimodalLogic includes papers chunked specifically for that project's
tasks (e.g., `venema_1997/` has 3 sections covering exactly the parts needed for BimodalLogic
proofs). These chunks were curated for that project. A centralized store would need to decide:
- Does each paper get ONE canonical chunking for all projects?
- Or do projects get project-specific chunk granularity within the central store?
If one project needs chapters 1-3 of a book and another needs chapters 7-9, a shared store
forces one of them to load irrelevant content (or use a more granular chunking that satisfies
both).

### Risk 6: Migration Breaks --lit Flag for Existing Tasks (HIGH)
BimodalLogic and cslib currently have working `--lit` injection from their per-project
`specs/literature/`. If content is migrated to a central repo AND the per-project directories
are deleted (or emptied), existing tasks that rely on `--lit` will get empty injection until
the central repo is confirmed working.

The migration plan must include: (a) verify central repo injection works before removing
per-project content, (b) keep per-project dirs as read-only fallback during transition.

---

## Missing Questions

These are questions the task description does not answer that could significantly affect the
design:

**Q1: Is Literature/ meant to replace specs/literature/ entirely, or coexist?**
The task says "centralizing", which implies replacement, but the existing BimodalLogic content
has project-specific chunk granularity that cannot be trivially centralized.

**Q2: How should project-specific chunks be represented in a central store?**
If BimodalLogic needs Burgess1982 in 3 sections and cslib needs it as a flat file, the central
store cannot satisfy both without project-scoped metadata. The current index.json schema has
no concept of "intended for project X".

**Q3: Who "owns" the central Literature/ repo?**
Is it version-controlled and pushed to a remote? Who decides when to add or remove entries?
Can the agent system modify it autonomously (--convert, --index), or does it require human
approval for changes?

**Q4: What happens to papers only needed by one project?**
If a paper is only relevant to BimodalLogic (e.g., temporal logic completeness proofs), does
it go into the central repo anyway? The central repo would become a superset of all papers
from all projects, which may be desirable (Zotero is already a superset) but the keyword
scoring for --lit injection becomes less accurate when the pool is larger.

**Q5: How does the agent find Literature/ from inside a project?**
If LITERATURE_DIR is not set (new terminal, CI, SSH), where does it fall back? The answer
must be explicit in the implementation.

**Q6: What is the rollout strategy for existing content?**
Existing BimodalLogic content (111+ index entries, ~70 markdown files) and cslib content
(30+ entries) cannot be migrated in a single atomic operation without disrupting active work.
A phased migration plan is needed.

**Q7: Should Zotero.bib parsing be a one-time bootstrap or ongoing sync?**
If Zotero adds a new paper and exports Zotero.bib, should the Literature/ index auto-update?
Or is Zotero.bib only used for bootstrapping initial metadata?

**Q8: What about papers with no PDF in Zotero storage?**
132 of 878 Zotero entries (15%) have no `file` field. These exist in the .bib file but have
no local PDF to convert. Should they be in the Literature/ index with a null `source_format`?

---

## Scope Concerns

### Is This Task Too Large?

The task bundles 6 distinct engineering concerns:
1. Zotero.bib parsing (format analysis, field extraction, multi-file handling)
2. Per-repo content audit (overlap analysis, schema differences)
3. Central repo directory design (layout, index schema)
4. Cross-repo path resolution (env var mechanism, fallback logic)
5. /literature command adaptation (new CWD behavior)
6. PDF storage strategy (copy vs symlink decision)

Each of these is a design decision that affects the others. Attempting to research and plan
all six simultaneously risks producing a design that is internally inconsistent because the
decisions interact:
- The PDF strategy determines whether the central index needs to track absolute paths
- The env var mechanism determines whether literature-retrieve.sh needs surgery or can use a
  config file
- The schema enhancement affects the migration burden for existing content
- The /literature command adaptation scope depends on whether the command stays project-local
  or becomes globally aware

**Recommendation**: The research phase can cover all 6 areas (as tasked), but the plan phase
should sequence them in dependency order: (1) env var mechanism → (2) schema + migration →
(3) central repo layout → (4) PDF strategy → (5) command adaptation → (6) Zotero integration.

### Minimal Viable Change vs Full Vision

The minimal viable change is:
- Add `LITERATURE_DIR` env-var support to `literature-retrieve.sh` (fallback to
  `$PWD/specs/literature` if not set)
- Create `~/Projects/Literature/specs/literature/` or just `~/Projects/Literature/`
  with an `index.json`

The full vision adds Zotero.bib integration, schema migration, bib_key normalization,
cross-repo deduplication, and PDF storage management. These are separable concerns and the
plan should make this split explicit.

---

## Confidence Levels

| Finding | Confidence | Basis |
|---------|-----------|-------|
| literature-retrieve.sh has hardcoded paths | HIGH | Read the actual script |
| Literature/ exists as bare git repo | HIGH | Filesystem confirmed |
| Schema mismatch (missing doc_type/source_format) | HIGH | jq query on actual indexes |
| bib_key divergence across repos | HIGH | Enumerated actual keys |
| Zotero.bib multi-file entries (138) | HIGH | Counted from actual file |
| Zotero paths hardcoded to /home/benjamin/ | HIGH | Confirmed 746 entries |
| No concurrency protection | HIGH | Code review confirmed |
| /literature command operates on CWD | HIGH | Code review confirmed |
| Only 3 entries overlap between repos | HIGH | comm analysis |
| Migration would break --lit temporarily | MEDIUM | Inferred from code paths |
| Env var won't propagate to all contexts | MEDIUM | Standard shell behavior |
| Zotero schema drift risk | MEDIUM | Better BibTeX documentation |

---

## Summary of Critical Gaps

1. **Code change required, not just config**: The env-var mechanism does not exist. The plan
   must create it from scratch by modifying `literature-retrieve.sh` (and the per-project
   deployed copies).

2. **Schema migration is a real cost**: All 141+ existing index entries need `doc_type` and
   `source_format` fields added. This is a migration script task, not a checkbox.

3. **bib_key normalization is unsolved**: The Zotero.bib key for `Burgess1982a` vs the
   BimodalLogic key `Burgess1982b` vs the cslib key `Burgess1982II` are three different
   identifiers for the same paper. Any cross-repo deduplication needs a canonical key strategy.

4. **Per-project chunk granularity conflicts with centralization**: Some papers are chunked
   differently across repos. A single canonical chunking must be chosen, or the central store
   must support project-scoped views.

5. **Migration sequencing is unspecified**: The task does not address rollout order, fallback
   during migration, or how to handle the fact that two active projects would be disrupted
   during transition.

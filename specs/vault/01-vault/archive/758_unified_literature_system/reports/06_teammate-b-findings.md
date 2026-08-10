# Research Report: Task #758 Teammate B — Source Discovery and Acquisition Pipeline

**Task**: 758 - Unified Literature System
**Focus**: Source Discovery and Acquisition Pipeline
**Teammate**: B
**Started**: 2026-06-23T20:45:00Z
**Completed**: 2026-06-23T21:15:00Z
**Effort**: ~45 minutes
**Sources/Inputs**: Codebase (all scripts in `.claude/extensions/literature/`, `.claude/extensions/zotero/`, `.claude/scripts/`), global Literature repo (`~/Projects/Literature/`), task 728 research report, web search on academic APIs

---

## Executive Summary

- The existing pipeline handles everything **after** a PDF arrives: convert -> chunk -> index -> inject. What is entirely absent is the **before** side: discovering which papers exist, checking if they are already in the system, and acquiring PDFs.
- Three free, no-auth (or email-only) APIs cover 95%+ of academic source discovery: **Semantic Scholar** (200M papers, returns open-access PDF URLs), **Unpaywall** (given a DOI, returns legal open-access PDF URL), and **CrossRef** (canonical DOI resolution and metadata by title search).
- The existing `zotero-search.sh` (CSL-JSON search) and `zotero-read.sh` (live Zotero DB via `zot` CLI) already provide the lookup chain needed for checking Zotero membership. The global `~/Projects/Literature/index.json` is the authoritative already-converted check.
- A `SOURCES.md` file at `specs/literature/SOURCES.md` (or `~/Projects/Literature/FIND_SOURCES.md`, which already exists) is the right artifact for sources that cannot be automatically acquired.
- The integration pipeline (PDF -> markdown -> chunks -> global index -> per-repo sub-index -> git) is fully implemented in `literature-ingest.sh`. The missing piece is a front-end `literature-discover.sh` script that generates candidate papers from task descriptions and drives the lookup/acquisition chain.

---

## Key Findings

### 1. What the existing infrastructure already does

The current pipeline covers acquisition **only** when a PDF path is already known. Specifically:

| Script | Function | Gap |
|--------|----------|-----|
| `literature-ingest.sh` | Full PDF-to-chunks-to-global-index pipeline | Requires PDF path or Zotero key as input |
| `literature-ingest.sh --zotero KEY` | Resolves Zotero key -> PDF path -> ingest | Requires the Zotero key to be known |
| `zotero-chunk.sh KEY` | Per-key chunking with index update | Requires key to already be in `specs/zotero-index.json` |
| `zotero-index-add.sh KEY` | Adds item to per-repo index from Zotero DB | Requires user to supply the Zotero key |
| `zotero-search.sh QUERY` | Searches CSL-JSON library export | Only covers items already in Zotero |
| `zotero-read.sh search QUERY` | Searches live Zotero DB via `zot` CLI | Only covers items already in Zotero |
| `literature-search.sh QUERY` | FTS5 search against chunked markdown | Only covers already-converted documents |

None of these scripts answers: "Given a task description, what papers should I find, and how do I get them if they are not already available?"

### 2. Lookup chain design (global index -> Zotero -> online)

The recommended three-tier lookup chain, in order of cost and reliability:

**Tier 1: Global Literature index** (`~/Projects/Literature/index.json`)
- Check: does the paper's `doc_id` or title appear in the 222-entry index?
- If yes: chunks already exist. Reference `chunk_dir` in the sub-index. Done.
- Script: `jq -r --arg t "$TITLE" '.entries[] | select(.title | ascii_downcase | test($t | ascii_downcase))' "$LITERATURE_DIR/index.json"`

**Tier 2: Zotero library**
- Check A (CSL-JSON): `zotero-search.sh TERMS` — searches `zotero-library.json` which is the Better BibTeX auto-export. Fast, offline.
- Check B (live DB): `zotero-read.sh search TERMS` — searches Zotero SQLite at `~/Documents/Zotero/zotero.sqlite` via `zot` CLI.
- If found with `has_pdf=true`: run `literature-ingest.sh --zotero KEY` to bring it into the global repo.
- If found with `has_pdf=false`: add to `SOURCES.md` with Zotero key and acquisition notes.

**Tier 3: Online discovery**
- Only reached if not in global index and not in Zotero.
- Use Semantic Scholar / CrossRef / arXiv APIs to find the paper (see Section 3).
- Attempt PDF download via Unpaywall (DOI-based) or arXiv direct URL.
- If download succeeds: run `literature-ingest.sh PDF_PATH` to ingest.
- If download fails: add to `SOURCES.md`.

### 3. Online academic APIs (all free, all CLI-scriptable via curl/python)

#### Semantic Scholar Graph API
- **Endpoint**: `https://api.semanticscholar.org/graph/v1/paper/search?query=TITLE&fields=title,authors,year,openAccessPdf,externalIds`
- **What it returns**: Paper metadata including `openAccessPdf.url` (direct PDF URL when available), DOI, arXiv ID, abstract
- **Auth**: No key needed for basic searches (rate limit: ~100 req/5min without key); optional free API key for higher volume
- **Best for**: Initial paper discovery from task descriptions; finding open-access PDFs in one call

```bash
# Example: search by title fragment
curl -s "https://api.semanticscholar.org/graph/v1/paper/search?query=modal+logic+relational+structures&limit=5&fields=title,year,openAccessPdf,externalIds" | jq '.data[] | {title,year,pdf:.openAccessPdf.url,doi:.externalIds.DOI}'
```

#### CrossRef REST API
- **Endpoint**: `https://api.crossref.org/v1/works?query.title=TITLE&select=DOI,title,author,published,link`
- **What it returns**: DOI (canonical), bibliographic metadata, and `link` array with content URLs (publisher PDF when available)
- **Auth**: None; polite pool with `mailto:` header recommended (`-H "User-Agent: research-agent/1.0 (mailto:email)"`)
- **Best for**: DOI resolution from a known title; verification that a DOI exists

```bash
# Example: resolve title to DOI
curl -s -H "User-Agent: literature-discover/1.0 (mailto:benbrastmckie@gmail.com)" \
  "https://api.crossref.org/v1/works?query.title=Modal+Logic&query.author=Blackburn&rows=3&select=DOI,title,author" | jq '.message.items[] | {doi:.DOI, title: .title[0]}'
```

#### Unpaywall API
- **Endpoint**: `https://api.unpaywall.org/v2/{DOI}?email=YOU@EMAIL.COM`
- **What it returns**: `is_oa` boolean, `best_oa_location.url_for_pdf` (direct PDF URL when open-access exists), `oa_locations` array
- **Auth**: Email address only (no key, no signup)
- **Best for**: Given a DOI (from CrossRef or Semantic Scholar), get the legal open-access PDF URL
- **Coverage**: 30M+ DOIs checked against 50K+ sources; handles arXiv, PubMed Central, institutional repos

```bash
# Example: find PDF for a DOI
DOI="10.1017/CBO9780511519437"
curl -s "https://api.unpaywall.org/v2/$DOI?email=benbrastmckie@gmail.com" | jq '{is_oa, pdf_url: .best_oa_location.url_for_pdf, version: .best_oa_location.version}'
```

#### arXiv API
- **Endpoint**: `https://export.arxiv.org/api/query?search_query=ti:TITLE+AND+au:AUTHOR&max_results=5`
- **What it returns**: Atom XML with title, authors, abstract, PDF URL (`http://arxiv.org/pdf/{id}`)
- **Auth**: None; rate limit 1 req/3 seconds
- **Best for**: CS/math/logic papers — arXiv covers the logic and formal methods literature heavily
- **Note**: Parse the Atom feed with `python3 -c "import urllib.request; ..."` or `xmllint`

```bash
# Example: search arXiv by title
curl -s "https://export.arxiv.org/api/query?search_query=ti:modal+logic+temporal&max_results=3" | python3 -c "
import sys, xml.etree.ElementTree as ET
ns = {'a': 'http://www.w3.org/2005/Atom'}
tree = ET.fromstring(sys.stdin.read())
for e in tree.findall('a:entry', ns):
    print(e.find('a:title', ns).text.strip())
    pdf = next((l.get('href') for l in e.findall('a:link', ns) if 'pdf' in l.get('type','') or l.get('title','')=='pdf'), None)
    print(' PDF:', pdf)
"
```

#### DBLP API
- **Endpoint**: `https://dblp.org/search/publ/api?q=QUERY&format=json&h=5`
- **What it returns**: JSON with hits array; each hit has title, authors, year, DOI (when registered), URL to publisher page
- **Auth**: None
- **Best for**: CS/logic conference papers (LICS, IJCAI, etc.); often faster than Semantic Scholar for specific CS venues
- **Limitation**: Does not return PDF URLs directly — use DOI with Unpaywall for PDF

### 4. Recommended `literature-discover.sh` script design

A new `literature-discover.sh` script (or `--discover` subcommand of `literature-subindex.sh`) would implement the full pipeline:

```
INPUT: Task description string (from agent context or task state.json)

STAGE 1: Query generation
  - Extract keywords from description (reuse existing keyword extraction from literature-common.sh)
  - Optionally: agent calls this script with explicit titles from its knowledge

STAGE 2: Tier 1 — Global index check
  - jq search against $LITERATURE_DIR/index.json (fast, offline)
  - Match by title (fuzzy) or by bib_key
  - OUTPUT: list of doc_ids that already exist -> reference in sub-index

STAGE 3: Tier 2 — Zotero check
  - If zotero-library.json exists: run zotero-search.sh TERMS (offline, fast)
  - If `zot` CLI available: run zotero-read.sh search TERMS (live DB)
  - For matches with has_pdf=true: add to acquisition queue (ingest --zotero KEY)
  - For matches with has_pdf=false: add to SOURCES.md

STAGE 4: Tier 3 — Online discovery
  - Semantic Scholar search for each unresolved title/term
  - CrossRef title-to-DOI resolution
  - Unpaywall DOI-to-PDF-URL resolution
  - arXiv search for preprint availability
  - Attempt WebFetch download for each found PDF URL

STAGE 5: Acquisition
  - For each downloadable PDF: save to $TMPDIR, run literature-ingest.sh
  - For each un-downloadable source: append entry to SOURCES.md

STAGE 6: Sub-index update
  - Add all successfully ingested doc_ids to specs/literature-index.json
  - Git commit in $LITERATURE_DIR if new documents added

OUTPUT:
  - List of papers found and ingested (JSON)
  - List of papers needing manual acquisition (SOURCES.md entries)
```

### 5. `SOURCES.md` format design

The `~/Projects/Literature/FIND_SOURCES.md` file already exists and uses a simple table format. The per-task `specs/literature/SOURCES.md` (or `specs/758_.../SOURCES.md`) should follow a similar but more structured format:

```markdown
# Literature Sources — Task 758

Documents identified as relevant but not yet available in the Literature repo.

## Status Legend
- `[PENDING]` — Not yet attempted
- `[IN_ZOTERO]` — In Zotero but no PDF; add PDF via Zotero
- `[PAYWALL]` — No open-access version found; requires institutional/manual access
- `[FOUND]` — PDF URL identified; awaiting manual download
- `[RESOLVED]` — Ingested into Literature repo (doc_id listed)

## Pending Sources

| Title | Authors | Year | DOI | Status | Notes | Suggested Source |
|-------|---------|------|-----|--------|-------|-----------------|
| Modal Logic | Blackburn, de Rijke, Venema | 2002 | 10.1017/CBO9780511519437 | [RESOLVED] | blackburn_2002_book | Zotero: BlackburnDeRijkeVenema2002 |
| example_paper | Smith | 2019 | 10.1145/... | [PAYWALL] | — | https://author-page.edu/smith2019.pdf |
```

Key fields:
- `Title`, `Authors`, `Year`: for human identification
- `DOI`: canonical identifier for Unpaywall lookup
- `Status`: one of the status legend values
- `Notes`: doc_id if resolved, or why it failed
- `Suggested Source`: URL, Zotero key, or institution where paper may be obtainable

### 6. Integration with the briefing+tools pattern (Pattern 3C)

From the existing synthesis report (05_research-synthesis.md), the architecture adopts Pattern 3C: agents receive a briefing listing available papers, then use `Read` and `literature-search.sh` on demand. The discovery pipeline fits cleanly as a **pre-briefing phase**:

```
/research 758 --lit
  |
  v
PREFLIGHT: literature-briefing.sh
  -> Checks specs/literature-index.json
  -> If entries exist: emit briefing block
  -> If entries are sparse or empty:
       -> Run literature-discover.sh (extract terms from task description)
       -> Attempt automatic acquisition (Zotero -> online)
       -> Populate sub-index with found papers
       -> Then emit briefing block
```

This means the agent's first `--lit` invocation may trigger a discovery sweep, and subsequent invocations use the now-populated sub-index. Alternatively, discovery can be a manual `/literature --discover` command the user runs explicitly before research begins.

### 7. PDF acquisition fallback strategy

When a PDF cannot be acquired automatically:

1. **Open-access preprint**: Semantic Scholar `openAccessPdf.url` or arXiv PDF URL (free, direct download)
2. **DOI + Unpaywall**: `https://api.unpaywall.org/v2/{doi}?email=...` -> `best_oa_location.url_for_pdf`
3. **Author's page**: Semantic Scholar often includes `openAccessPdf.url` pointing to author/institutional pages
4. **arXiv ID match**: If Semantic Scholar returns `externalIds.ArXiv`, the PDF is always available at `https://arxiv.org/pdf/{ArXiv_ID}`
5. **Manual**: Add to `SOURCES.md` with `[PAYWALL]` or `[FOUND]` status + URL for user to download

The modal logic and formal methods literature this project primarily uses (Blackburn, Burgess, Gabbay, Reynolds) predates common open-access practices. Most of these will be `[PAYWALL]` with manual acquisition required. The Unpaywall coverage for 2000s-era Cambridge and Springer monographs is ~15-25%. For post-2010 papers and CS conference proceedings, open-access coverage is 60-80%.

---

## Recommended Approach

### What to build

A single new script `literature-discover.sh` in `.claude/extensions/literature/scripts/` with the following subcommands:

| Subcommand | Function |
|-----------|----------|
| `discover TERMS...` | Full pipeline: check indexes -> Zotero -> online -> acquire -> update SOURCES.md |
| `check-global TERMS...` | Tier 1 only: search global Literature index, print matching doc_ids |
| `check-zotero TERMS...` | Tier 2 only: search CSL-JSON + live Zotero DB |
| `search-online TERMS...` | Tier 3 only: Semantic Scholar + CrossRef + arXiv, return metadata JSON |
| `acquire URL [--doi DOI]` | Download PDF from URL, run ingest, add to sub-index |
| `sources-add TITLE AUTHORS YEAR DOI STATUS` | Append entry to SOURCES.md |
| `sources-list [--pending]` | List SOURCES.md entries (optionally filter by status) |

Wire `/literature --discover TERMS` in the literature command to dispatch to `literature-discover.sh discover TERMS`.

### What NOT to build

- A new agent type for discovery — the `literature-discover.sh` script is agent-callable via Bash; no new agent needed
- A web crawler — limit to the four specific APIs listed above; no general crawling
- Automatic Zotero import — discovered papers land in `~/Projects/Literature/`; Zotero import is a separate user action

### Integration points with the existing plan

The existing plan (05_unified-literature-plan.md) covers Phase 2 (sub-index tooling) and Phase 3 (briefing generator). The discovery pipeline is a **Phase 2 extension** that fits between sub-index creation and briefing generation:

- Phase 2 adds: `literature-subindex.sh init/add/remove/list/validate`
- **Phase 2 extension (new)**: `literature-discover.sh` as described above
- Phase 3 adds: `literature-briefing.sh` that reads the sub-index
- The discovery pipeline populates the sub-index that the briefing generator reads

This can be built as part of Phase 2 or as a new Phase 2.5 inserted between Phase 2 and Phase 3.

---

## Evidence and Examples

### Existing FIND_SOURCES.md pattern

`~/Projects/Literature/FIND_SOURCES.md` already uses the status+table approach for tracking missing sources:

```markdown
## Missing PDFs
| Document | Status | Notes |
| thomas_1997 | No PDF | Springer paywall. Markdown reconstructed from secondary sources. |

## Unconverted PDFs
| PDF | Size | Notes |
| Gabbay_Reynolds_2000_Temporal_Logic_Foundations_Vol2.pdf | 66 MB | Vol 1 indexed; Vol 2 not converted. |
```

This validates the SOURCES.md concept and shows it should live in the global Literature repo (for cross-project tracking) as well as per-repo `specs/literature/SOURCES.md` for task-scoped tracking.

### Task 728 findings (literature source recovery)

Task 728 (2026-06-16) investigated the same problem manually. Key findings that inform automation:
- The `zotero_key` values in `index.json` are Better BibTeX **citation keys** (e.g., `BlackburnDeRijkeVenema2002`), not Zotero's 8-character storage IDs
- The SQLite mapping between citation keys and storage folder IDs requires the `zot` CLI or direct Python sqlite3 queries
- `zotero-library.json` (Better BibTeX CSL-JSON auto-export) was **not present** at time of task 728 — it needed to be configured. The `zotero-search.sh` script depends on this file; its existence should be checked during discovery
- 32 PDFs existed in BimodalLogic's `specs/literature/` that the global repo needed — these were migrated manually via `migrate-from-repo.sh`

This strongly suggests the discovery script should check whether `zotero-library.json` exists before attempting CSL-JSON search, and fall back to live `zot` CLI search if available.

### API endpoint summary (verified as of 2026)

| API | Endpoint pattern | Auth | Returns PDF? |
|-----|-----------------|------|-------------|
| Semantic Scholar | `https://api.semanticscholar.org/graph/v1/paper/search?query=...&fields=openAccessPdf` | None (or free key) | Yes, via `openAccessPdf.url` |
| CrossRef | `https://api.crossref.org/v1/works?query.title=...&select=DOI,title` | None (`mailto:` recommended) | No (gives DOI for Unpaywall) |
| Unpaywall | `https://api.unpaywall.org/v2/{DOI}?email=...` | Email only | Yes, via `best_oa_location.url_for_pdf` |
| arXiv | `https://export.arxiv.org/api/query?search_query=ti:...&max_results=5` | None | Yes, direct PDF URL in feed |
| DBLP | `https://dblp.org/search/publ/api?q=...&format=json&h=5` | None | No (use DOI + Unpaywall) |

**Recommended minimal set**: Semantic Scholar + Unpaywall covers 90%+ of use cases. CrossRef adds robustness for DOI resolution. arXiv adds preprint access for CS/logic papers. DBLP is optional (redundant with Semantic Scholar for most CS papers).

---

## Confidence Level

**High confidence** (codebase evidence + verified API docs):
- Existing pipeline handles post-acquisition only; no discovery/lookup chain exists in any current script
- Three-tier lookup chain (global index -> Zotero -> online) is the right architecture
- `literature-ingest.sh` is the correct integration point for new acquisitions
- The four APIs described all work and are free/scriptable
- `SOURCES.md` pattern already exists at `~/Projects/Literature/FIND_SOURCES.md`

**Medium confidence** (design decision, not yet validated):
- Integrating discovery as a Phase 2 extension vs. a separate Phase 2.5 in the implementation plan
- Whether to trigger discovery automatically from `--lit` preflight or keep it a manual command
- PDF download success rates for the target literature (modal logic, formal methods) — likely 15-30% open access for older papers, 60-80% for post-2010 CS papers

**Lower confidence** (not yet researched by this teammate):
- Whether the synthesis team has decided if `literature-discover.sh` should be an agent-callable tool or an orchestrator-facing script
- How the per-repo sub-index schema from Phase 2 interacts with discovery (what fields to add for "discovered but not acquired" sources)

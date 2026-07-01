# Research Report — Task 797: Assisted Zotero Export Generation

**Task type**: meta | **Session**: sess_1782927693_833583

## Goal

When `$LITERATURE_DIR/zotero-library.json` is MISSING, `literature-discover.sh` Tier 2
must present an interactive offer to GENERATE the export automatically (superseding the
task-794 print-only hint), and on agreement ACTUALLY create the file in the Better CSL JSON
shape that `tier2_search` / `zotero-search.sh` already consume. Local Zotero only. Tier 3
API-dependent work is explicitly out of scope.

## 1. Current Tier 2 logic

**File**: `.claude/extensions/literature/scripts/literature-discover.sh` (canonical),
byte-identical flat copy at `.claude/scripts/literature-discover.sh` (dual-copy model from
task-793 intact, `diff` empty).

`tier2_search()` is lines **346–456**. Missing-export detection + current task-794
print-only hint is lines **349–353**:

```bash
tier2_search() {
  local zotero_library="$LITERATURE_DIR/zotero-library.json"
  if [ ! -f "$zotero_library" ]; then
    echo "Tier 2 (Zotero) skipped: no export found at $zotero_library" >&2
    echo "  To enable: in Zotero, File -> Export Library -> format \"Better CSL JSON\", check \"Keep updated\", save to $zotero_library" >&2
    return 0
  fi
  ...
```

After the guard it locates `zotero-search.sh` (flat sibling preferred, nested extension path
fallback — lines 360–368), invokes `--format=json --limit=N`, folds each hit into `$RESULTS`
(lines 385–455), tagging `tier: 2` and deriving `status` (`in_zotero` vs `in_zotero_no_pdf`)
from `pdf_paths` length.

Execution order (lines 608–615): tier1 → tier2 → tier3, each `|| true` (non-fatal). Final
stdout is ALWAYS a pure JSON array (line 628) — a hard contract new interactive output must
not break.

**Critical caller finding**: `.claude/extensions/literature/commands/literature.md` (lines
125–139) is the ONLY caller and invokes the script with `2>/dev/null` on all three variants.
So the existing task-794 stderr hint never reaches the user through `/literature` today.
Fixing that capture is out of scope. The 797 design must therefore NOT depend on that stderr
surfacing — use a separate invocation with its own capture (classifier pattern below).

## 2. CSL-JSON shape consumed (Better CSL JSON)

From `zotero-search.sh` lines 241–301. Fields read:

| Field | Type | Notes |
|---|---|---|
| `citation-key` | string | Better BibTeX-specific; NOT in vanilla Zotero CSL-JSON |
| `title` | string | |
| `author` | `[{family, given}]` | joined → `"Family, Given; ..."` |
| `issued.date-parts` | `[[year, month, day]]` | only `[0][0]` (year) used |
| `keyword` | string | tag string, scored +2/term |
| `abstract` | string | scored +1/term, snippet truncated 200 chars |
| `attachments` | `[{path, ...}]` | BBT attachment array |
| `attachment` | string | alternate single-attachment field |
| `PDF` | string | alternate PDF field |

`pdf_candidates()` (278–283) collects all three attachment representations;
`verify_pdf_paths()` (318–346) filters to on-disk paths. `tier2_search()` maps to:
`citation_key`, `title`, `authors` (array), `year`, `doc_id = citation_key`, `status`, `tier: 2`.

**Generation implication**: output must be a JSON array of objects with at least
`citation-key`, `title`, `author[]`, `issued.date-parts`, and one of
`attachments[].path`/`attachment`/`PDF`. `citation-key` is the one field plain Zotero export
does NOT produce — the crux of the generation design.

## 3. zotero-search.sh setup wording (must be matched)

Lines 143–169 — canonical manual-fallback text to mirror:

```
Error: Zotero library not found at: $LIBRARY_PATH
To set up Zotero CSL-JSON export:
1. Install the Better BibTeX plugin for Zotero: https://retorque.re/zotero-better-bibtex/
2. In Zotero, go to: File -> Export Library...
3. Choose format: "Better CSL JSON"  Check "Keep updated" for automatic re-export.
4. Save to one of: $ZOTERO_LIBRARY / ${LITERATURE_DIR}/zotero-library.json / ~/Projects/Literature/zotero-library.json
Or set ZOTERO_LIBRARY=/path/to/your/library.json
```

`resolve_library_path()` (120–135): `$ZOTERO_LIBRARY` → `$LITERATURE_DIR/zotero-library.json`
→ `~/Projects/Literature/zotero-library.json`. Note: literature-discover.sh tier2 only checks
`$LITERATURE_DIR/zotero-library.json` (line 347), not `$ZOTERO_LIBRARY` — latent inconsistency,
flag but not required to fix. Generation should write to the `resolve_library_path()` target.

## 4. AskUserQuestion-from-shell pattern (model to replicate)

`.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` is the direct precedent:
- Script NEVER calls `AskUserQuestion` (impossible from bash).
- Prints exactly one directive token on stdout (`LIT_DISABLED`, `SUBINDEX_PRESENT`,
  `GLOBAL_MISSING`, `PROMPT_NEEDED`, `AUTONOMOUS_GLOBAL`) + rationale on stderr.
- The calling skill (has `AskUserQuestion`) branches: interactive → 3-option prompt;
  `--orchestrator-mode true` → deterministic default + visible `[lit:auto]` notice, never silent.
- Companion `literature-create-setup-task.sh` shows the "do the actual work after agreement"
  half: pure bash+jq, atomic temp-file write, machine-readable stdout, errors to stderr.

**Recommended**: new classifier mode/script emits one directive
(`ZOTERO_EXPORT_PRESENT`, `ZOTERO_EXPORT_MISSING_RUNNING`, `ZOTERO_EXPORT_MISSING_NOT_RUNNING`)
+ rationale to stderr — never touching discover's JSON stdout contract. The skill/command
(`/literature`, run by Claude with `AskUserQuestion`) calls the status check BEFORE the main
discover call, presents the offer, and on agreement invokes the generator. Sidesteps the
`2>/dev/null` problem (separate invocation) without touching literature.md.

## 5. Three generation paths (findings)

Live test on this machine: Zotero NOT running (`curl http://127.0.0.1:23119/...` → refused).
`~/Zotero/zotero.sqlite` exists (1.1MB) but `items` table has 0 rows (empty library on this box
— schema present, data absent). Schema fully verified via `sqlite3 -readonly`.

**Path 1 — Zotero 7 built-in local API** (preferred, no plugin):
`http://127.0.0.1:23119/api/users/0/items?format=csljson` (userID 0 = local; requires "Allow
other applications on this computer to communicate with Zotero" in Advanced settings; no auth).
Returns CSL-JSON array directly. `id` shaped `"{userID}/{itemKey}"`, NO `citation-key`. Needs
pagination (`&limit=N&start=M`) and attachment/note filtering. Only path giving whole library
in one shot.

**Path 2 — Better BibTeX JSON-RPC** (`http://localhost:23119/better-bibtex/json-rpc`, needs BBT
plugin + Zotero running): NO bulk "export everything" method — `item.export`/`item.pandoc_filter`
require explicit `citekeys` array. Useful: `item.citationkey(item_keys)` → `{itemKey: citekey}`
read-only lookup; `item.search(terms)` for enumeration. **Combined flow**: Path 1 bulk-pull →
if BBT present, `item.citationkey()` backfills real `citation-key` using item keys from `id`;
else synthesize deterministic citekey (`lower(firstAuthorLast)+year+firstTitleWord`) so
`citation-key` is never null (tier2 uses it as `doc_id` for de-dup).

**Path 3 — direct sqlite read** (fallback, Zotero CLOSED — DB locked while running):
- `items(itemID, itemTypeID, key, ...)`; filter out attachment(3)/note(28)/annotation(1) via
  `itemTypes` (journalArticle=22, book=7, bookSection=8, conferencePaper=11, thesis=37,
  preprint=31, …).
- `itemData(itemID, fieldID, valueID)` → `itemDataValues(valueID, value)` → `fields(fieldID,
  fieldName)`. Field IDs: title=1, abstractNote=2, date=6, language=7, shortTitle=8, url=13,
  extra=16, volume=19, place=21, publisher=23, ISBN=25, pages=32, publicationTitle=38, DOI=59,
  issue=76, ISSN=79. Non-standard types alias via `baseFieldMappingsCombined` (defensive join
  optional).
- `itemCreators(itemID, creatorID, creatorTypeID, orderIndex)` → `creators(firstName, lastName,
  fieldMode)`, ordered by orderIndex. `creatorTypes.author = 8` (global); editor=10,
  bookAuthor=13, translator=11.
- `itemAttachments(itemID, parentItemID, linkMode, contentType, path)`; imported PDF path is
  `~/Zotero/storage/{attachmentItemKey}/{filename}` where attachmentItemKey is that attachment's
  own `items.key`. Filter `contentType='application/pdf'`.
- No citekey table in zotero.sqlite (BBT keeps its own DB) → Path 3 also synthesizes citekey.

A one-time pull via any path is a SNAPSHOT, not the auto-refreshing "Keep updated" export.
Design should write a `_generated` metadata stamp (timestamp + source path) into the output or a
sibling `.zotero-library.meta.json`, note staleness explicitly in messaging, and offer a re-pull
affordance (re-run the generator) rather than implying "Keep updated" equivalence.

## 6. Dual-copy sync model (task-793)

`.claude/extensions/literature/manifest.json` `provides.scripts` (19 entries) is flat-deployed
by the extension loader into `.claude/scripts/` of consuming repos. This repo hosts AND consumes
the extension, so it keeps a git-tracked flat copy in sync manually (per
`.claude/context/guides/extension-development.md` lines 135–140). Any new generation helper must:
(a) be added to `provides.scripts`, (b) authored under `.claude/extensions/literature/scripts/`,
(c) byte-identically re-synced to `.claude/scripts/`.

## 7. Non-interactive / orchestrator-mode detection

No existing orchestrator-mode plumbing into `/literature` or literature-discover.sh —
`/literature` is a plain user command, `/orchestrate` never calls it. The only `orchestrator_mode`
today is the `--lit` delegation-context field consumed by `literature-lit-flag-resolve.sh
--orchestrator-mode`. Since literature-discover.sh is a bare positional-arg CLI, add an explicit
`--orchestrator-mode true|false` flag to the new classifier/generator, default `false`
(interactive), always emit a visible non-silent rationale to stderr (mirror
literature-lit-flag-resolve.sh — never a silent no-op).

## 8. Do NOT conflate — second Zotero subsystem

`zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`,
`zotero-attach-chunks.sh` (task 750, "Category A: CLI Wrapper") shell out to an external `zot`
(zotero-cli-cc) Python tool, maintaining `specs/zotero-index.json` (NOT `zotero-library.json`).
`zot` not installed here; `.claude/commands/zotero.md` / `.claude/skills/skill-zotero` are
dangling symlinks to nonexistent `.claude/extensions/zotero/`. Orphaned/unloaded. Task 797 targets
ONLY the Better-CSL-JSON `$LITERATURE_DIR/zotero-library.json` subsystem — do not merge.

## 9. Recommended design summary

1. **New helper** `zotero-generate-export.sh` (dual-copy + manifest `provides.scripts`): probe
   `127.0.0.1:23119` for Zotero running, probe `/better-bibtex/json-rpc` for BBT; Path 1 pull
   (paginated), Path 2 citekey enrichment when available, Path 3 sqlite reconstruction when Zotero
   closed; always synthesize non-null `citation-key`; write exact Better-CSL-JSON shape + staleness
   stamp.
2. **New lightweight classifier** (`--zotero-status` mode on literature-discover.sh or tiny sibling)
   emitting one directive token + stderr rationale (literature-lit-flag-resolve.sh contract), so the
   calling skill decides `AskUserQuestion` (interactive) vs visible logged default "attempt live pull
   now" (orchestrator), never touching the JSON stdout contract.
3. **tier2_search()** (349–353) keeps silent/non-fatal skip for the main pass (safe under
   `2>/dev/null`), but update its stderr hint to also point at the assisted-generation entry point
   alongside the zotero-search.sh-matching manual instructions.
4. **Tier 3 untouched** per scope limit — no Semantic Scholar / API-dependent changes.

## Key file references (absolute)

- `.claude/extensions/literature/scripts/literature-discover.sh` (346–456, esp. 349–353)
- `.claude/scripts/literature-discover.sh` (byte-identical flat copy)
- `.claude/extensions/literature/scripts/zotero-search.sh` (CSL shape 241–301; wording 143–169; paths 120–135)
- `.claude/extensions/literature/scripts/literature-lit-flag-resolve.sh` (directive-token pattern)
- `.claude/extensions/literature/scripts/literature-create-setup-task.sh` (post-agreement work pattern)
- `.claude/extensions/literature/commands/literature.md` (125–139, the `2>/dev/null` caller)
- `.claude/extensions/literature/manifest.json` (`provides.scripts`)

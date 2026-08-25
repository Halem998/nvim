---
name: skill-literature
description: Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json. Invoke for /literature command.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Literature Skill (Direct Execution)

Direct execution skill for managing `specs/literature/` directories. Handles PDF/DJVU-to-markdown conversion, index.json maintenance, and filesystem validation. Runs inline using AskUserQuestion for interactivity.

**Key behavior**: Users see scan results and proposed keywords/summaries BEFORE any files are written. Users confirm chunk boundaries and metadata before conversion completes.

## Context References

Reference (do not load eagerly):
- Path: `@specs/literature/index.json` - Current literature index
- Path: `@specs/702_create_literature_command/reports/01_lit-command.md` - Research findings

---

## Execution

### Step 1: Parse Arguments

Extract mode, optional file, and optional query from skill args:

```bash
# Parse from skill args: "mode={mode} file={file}" or "mode=search query={query text}"
mode=$(echo "$ARGUMENTS" | grep -oP 'mode=\K\S+' | head -1)
file=$(echo "$ARGUMENTS" | grep -oP 'file=\K\S+' | head -1)

# Extract query: everything after "query=" (supports spaces in query text)
query=$(echo "$ARGUMENTS" | sed 's/.*query=//' | sed 's/^[[:space:]]*//')

# Default to status mode if not specified
if [ -z "$mode" ]; then
  mode="status"
fi

# Resolve file path (may be relative or absolute)
if [ -n "$file" ]; then
  if [[ "$file" != /* ]]; then
    file="specs/literature/$file"
  fi
fi
```

### Step 2: Generate Session ID

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
# Two-tier fallback: use LITERATURE_DIR if set and exists, otherwise use per-project specs/literature/
if [ -n "${LITERATURE_DIR:-}" ] && [ -d "$LITERATURE_DIR" ]; then
  lit_dir="$LITERATURE_DIR"
else
  lit_dir="specs/literature"
fi
index_file="$lit_dir/index.json"
# Determine sources/ prefix for centralized repo
if [ -n "${LITERATURE_DIR:-}" ] && [ "$lit_dir" = "$LITERATURE_DIR" ]; then
  sources_prefix="sources/"
else
  sources_prefix=""
fi
```

### Step 3: Check Tool Availability

Detect available conversion tools:

```bash
has_pdftotext=$(which pdftotext 2>/dev/null && echo "yes" || echo "no")
has_pdfinfo=$(which pdfinfo 2>/dev/null && echo "yes" || echo "no")
has_djvutxt=$(which djvutxt 2>/dev/null && echo "yes" || echo "no")
```

### Step 4: Dispatch to Mode Handler

Route to the appropriate mode:

```bash
case "$mode" in
  status)   handle_status ;;
  scan)     handle_scan ;;
  convert)  handle_convert ;;
  validate) handle_validate ;;
  index)    handle_index ;;
  search)   handle_search ;;
  ingest)   handle_ingest ;;
  rebuild)  handle_rebuild ;;
  *)
    echo "Error: Unknown mode '$mode'. Available: status, scan, convert, validate, index, search, ingest, rebuild"
    exit 1
    ;;
esac
```

---

## Mode: Ingest

Full pipeline ingestion: convert PDF/DJVU to markdown, chunk hierarchically, index in global SQLite FTS5 database, and optionally load into local specs/literature/.

### Ingest Step 1: Resolve Source Path

```bash
if [ -z "$file" ]; then
  echo "Error: --ingest requires a path or --zotero key."
  echo "Usage: /literature --ingest <path> | /literature --ingest --zotero <key>"
  exit 1
fi
```

### Ingest Step 2: Invoke literature-ingest.sh

Find the ingest script relative to the skill's script directory:

```bash
SCRIPT_DIR="$(dirname "$0")/../../scripts"
INGEST_SCRIPT="$SCRIPT_DIR/literature-ingest.sh"

if [ ! -x "$INGEST_SCRIPT" ]; then
  echo "Error: literature-ingest.sh not found at: $INGEST_SCRIPT"
  exit 1
fi

# Route to ingest script with appropriate flags
if [ -n "$zotero_key" ]; then
  "$INGEST_SCRIPT" --zotero "$zotero_key" "$@"
else
  "$INGEST_SCRIPT" "$file" "$@"
fi
```

Where:
- `$file` is the source path (PDF, DJVU, or directory)
- `$zotero_key` is the Zotero citation key (if using `--zotero`)
- Remaining `$@` may include `--no-local` or `--local` flags

### Ingest Step 3: Display Result

The `literature-ingest.sh` script outputs a summary to stdout on completion. Relay this output to the user verbatim, then add:

```
To search the ingested literature: /literature --search "query"
Or use --lit flag in research/plan/implement commands to enable agent search.
```

### Ingest Examples

```bash
# Ingest a single PDF
/literature --ingest ~/Papers/modal-logic.pdf

# Ingest all PDFs in a directory
/literature --ingest ~/Papers/modal-logic/

# Ingest from Zotero (requires zotero-library.json)
/literature --ingest --zotero "BlackburnDeRijkeVenema2001"

# Ingest and skip local loading prompt
/literature --ingest ~/Papers/modal-logic.pdf --no-local

# Ingest and automatically load into specs/literature/
/literature --ingest ~/Papers/modal-logic.pdf --local
```

---

## Mode: Status (Default)

Show health report: processed vs unprocessed files and index.json state.

### Status Step 1: Check Directory

```bash
if [ ! -d "$lit_dir" ]; then
  echo "## Literature Status"
  echo ""
  echo "No specs/literature/ directory found."
  echo "Create it and add PDF/DJVU files to get started."
  echo ""
  echo "**Tool Availability**:"
  echo "- pdftotext: $has_pdftotext"
  echo "- djvutxt: $has_djvutxt ($([ "$has_djvutxt" = "no" ] && echo 'install: nix-env -iA nixpkgs.djvulibre' || echo 'available'))"
  exit 0
fi
```

### Status Step 2: Scan for Files

```bash
# Find all PDF and DJVU source files
pdf_files=$(find "$lit_dir" -name "*.pdf" 2>/dev/null | sort)
djvu_files=$(find "$lit_dir" -name "*.djvu" 2>/dev/null | sort)
all_source_files="$pdf_files $djvu_files"

# Find all markdown files (excluding any in subdirectory source_files/)
md_files=$(find "$lit_dir" -name "*.md" -not -path "*/source_files/*" 2>/dev/null | sort)
```

### Status Step 3: Read Index

```bash
if [ -f "$index_file" ]; then
  entry_count=$(jq '.entries | length' "$index_file" 2>/dev/null || echo "0")
  indexed_paths=$(jq -r '.entries[].path' "$index_file" 2>/dev/null || echo "")
else
  entry_count=0
  indexed_paths=""
fi
```

### Status Step 4: Compute Counts

```bash
# Count source files
pdf_count=$(echo "$pdf_files" | grep -c "\.pdf$" 2>/dev/null || echo 0)
djvu_count=$(echo "$djvu_files" | grep -c "\.djvu$" 2>/dev/null || echo 0)
md_count=$(echo "$md_files" | grep -c "\.md$" 2>/dev/null || echo 0)

# Identify unprocessed source files (PDFs/DJVUs without corresponding .md)
unprocessed=()
for src in $pdf_files $djvu_files; do
  basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')
  # Check if any .md file starts with this basename
  if ! find "$lit_dir" -name "${basename_no_ext}*.md" -not -path "*/source_files/*" 2>/dev/null | grep -q .; then
    unprocessed+=("$src")
  fi
done
unprocessed_count=${#unprocessed[@]}
processed_count=$(( pdf_count + djvu_count - unprocessed_count ))
```

### Status Step 5: Display Report

```
## Literature Status

**Directory**: specs/literature/
**Source Files**: {pdf_count} PDFs, {djvu_count} DJVUs
**Converted**: {processed_count} processed, {unprocessed_count} unprocessed
**Markdown Files**: {md_count}
**Index Entries**: {entry_count}

**Tool Availability**:
- pdftotext: {has_pdftotext}
- djvutxt: {has_djvutxt} {install hint if no}

{if unprocessed_count > 0}
**Unprocessed Files** ({unprocessed_count}):
- {file1}
- {file2}
...

Run `/literature --convert` to convert all, or `/literature --scan` to see details.
{end if}

{if entry_count > 0 and md_count != entry_count}
**Index Health**: {entry_count} indexed entries, {md_count} markdown files — run `/literature --validate` to check consistency.
{end if}
```

---

## Mode: Scan

Find PDF/DJVU files lacking corresponding markdown conversions.

### Scan Step 1: Check Directory

Same as Status Step 1 — exit gracefully if directory missing.

### Scan Step 2: Find Unprocessed Files

```bash
unprocessed=()
for src in $(find "$lit_dir" -name "*.pdf" -o -name "*.djvu" 2>/dev/null | sort); do
  basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')
  if ! find "$lit_dir" -name "${basename_no_ext}*.md" -not -path "*/source_files/*" 2>/dev/null | grep -q .; then
    unprocessed+=("$src")
  fi
done
```

### Scan Step 3: Get Page Counts

For each unprocessed file, get page count via pdfinfo:

```bash
for src in "${unprocessed[@]}"; do
  ext="${src##*.}"
  if [ "$ext" = "pdf" ]; then
    if [ "$has_pdfinfo" = "yes" ]; then
      pages=$(pdfinfo "$src" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
    else
      pages="unknown"
    fi
  elif [ "$ext" = "djvu" ]; then
    if [ "$has_djvutxt" = "yes" ]; then
      # djvused can get page count: djvused -e n file.djvu
      pages=$(djvused -e n "$src" 2>/dev/null || echo "unknown")
    else
      pages="unknown (djvutxt not installed)"
    fi
  fi
  echo "- $src ($pages pages)"
done
```

### Scan Step 4: Display Results

```
## Literature Scan Results

**Unprocessed Files** ({count}):
- {file1} ({N} pages)
- {file2} ({N} pages)
...

**Tool Status**:
- pdftotext: {status}
- djvutxt: {status} {install hint if unavailable}

**Next Steps**:
- Convert all: `/literature --convert`
- Convert one: `/literature --convert path/to/file.pdf`
```

If no unprocessed files found:

```
## Literature Scan Results

All source files have been converted. No unprocessed PDFs or DJVUs found.

**Files**: {N} PDFs, {M} DJVUs — all converted
**Index**: {entry_count} entries in index.json

Run `/literature --validate` to check index.json consistency.
```

---

## Mode: Validate

Check index.json against the filesystem for stale entries, missing files, and token count drift.

### Validate Step 1: Load Index

```bash
if [ ! -f "$index_file" ]; then
  echo "## Literature Validation"
  echo ""
  echo "No index.json found at $index_file."
  echo "Run /literature to see status, or /literature --convert to convert files and create the index."
  exit 0
fi

# Iterate entries as WHOLE RECORDS (one compact-JSON object per line), never as bare
# `.path` strings. Driving the loop off `.entries[] | .path` collapses a `.path`-less
# entry (a schema-shape defect, e.g. a stub written by an older literature-ingest.sh)
# into the literal string "null" -- which then resolves to a nonexistent file
# "$lit_dir/null" and gets misreported as a missing FILE ("null (missing)") rather than
# surfaced as the schema defect it actually is. Reading each entry as a full record
# lets Step 2 below classify a path-less/id-less entry correctly before ever touching
# the filesystem.
entries=$(jq -c '.entries[]' "$index_file" 2>/dev/null)
```

### Validate Step 2: Check Each Entry

For each indexed entry, check:

1. Existence at `specs/literature/{entry.path}`: `-f` for file-path entries, `-d` for
   directory-path entries (book/parent-level records whose `path` ends in `/`)
2. Token count drift (recount vs stored, flag if >20% different) — applies to file-path entries
   only; directory-path entries have no single content file to recount against
3. Required schema fields present: `id`, `path`, `token_count`, `keywords`, `summary`, `doc_type`, `source_format`
4. `authors` field shape: present and an array, all elements are strings, and no element looks
   like an unsplit comma-joined multi-author string (see authors-shape check below). This catches
   regressions from any future writer that reintroduces the malformed schema this check guards against —
   see `.claude/context/project/literature/domain/literature-index.md` for the tooling ownership
   boundary and `.claude/scripts/literature-normalize-authors.sh` for the companion fix-up tool.

```bash
stale_entries=()
drift_entries=()
schema_warnings=()
authors_shape_warnings=()
schema_shape_defects=()

while IFS= read -r entry_json; do
  [ -z "$entry_json" ] && continue

  entry_id=$(echo "$entry_json" | jq -r '.id // .doc_id // empty')
  entry_path=$(echo "$entry_json" | jq -r '.path // empty')

  # --- Schema-shape bucket, reported separately from stale entries ---
  # An entry missing .id (and .doc_id), missing .path, or carrying a .path that is not
  # sources/-prefixed is a SCHEMA-SHAPE defect (the entry itself is malformed), not a
  # missing-file defect (the entry is well-formed but its target vanished). Classifying
  # it here, before any filesystem check runs, is what ends the old "null (missing)"
  # misreport: a .path-less entry never reaches the file-existence check below at all.
  shape_defects=()
  [ -z "$entry_id" ] && shape_defects+=("missing .id/.doc_id")
  if [ -z "$entry_path" ]; then
    shape_defects+=("missing .path")
  elif [[ "$entry_path" != sources/* ]]; then
    shape_defects+=("path not sources/-prefixed: $entry_path")
  fi
  if [ "${#shape_defects[@]}" -gt 0 ]; then
    label="${entry_id:-<no id>}"
    joined=$(IFS=", "; echo "${shape_defects[*]}")
    schema_shape_defects+=("$label ($joined)")
    # A path-less entry has no filesystem target to check and no .path to key the
    # existing per-path checks below on -- skip straight to the next entry rather than
    # falling through into checks that assume entry_path is usable.
    [ -z "$entry_path" ] && continue
  fi

  full_path="$lit_dir/$entry_path"

  # Directory-path entries (trailing slash, or resolves to a directory on disk) are a
  # legitimate second schema variant: parent-level records for a book split into many
  # semantic chunks (doc_type: "book", token_count: 0 by design). They have no single
  # content file to recount tokens against, so existence is the sufficient check.
  if [[ "$entry_path" == */ ]] || [ -d "$full_path" ]; then
    if [ ! -d "$full_path" ]; then
      stale_entries+=("$entry_path (missing directory)")
      continue
    fi
  elif [ ! -f "$full_path" ]; then
    stale_entries+=("$entry_path (missing)")
    continue
  else
    # Recount tokens (file-path entries only)
    char_count=$(wc -c < "$full_path" 2>/dev/null || echo 0)
    current_tokens=$(( char_count / 4 + 20 ))
    stored_tokens=$(echo "$entry_json" | jq -r '.token_count // 0')

    if [ -n "$stored_tokens" ] && [ "$stored_tokens" -gt 0 ]; then
      # Calculate drift percentage
      diff=$(( current_tokens - stored_tokens ))
      if [ "$diff" -lt 0 ]; then diff=$(( -diff )); fi
      drift_pct=$(( diff * 100 / stored_tokens ))
      if [ "$drift_pct" -gt 20 ]; then
        drift_entries+=("$entry_path (stored: $stored_tokens, actual: $current_tokens, drift: ${drift_pct}%)")
      fi
    fi
  fi

  # Check for required schema fields (new in schema v2). Reads the already-parsed
  # entry record directly (no re-query by path needed), so this runs for every entry
  # that resolves on disk -- directory-path entries included.
  missing_fields=$(echo "$entry_json" | jq -r '
    [
      (if .doc_type == null or .doc_type == "" then "doc_type" else empty end),
      (if .source_format == null or .source_format == "" then "source_format" else empty end),
      (if .authors == null then "authors" else empty end),
      (if .title == null or .title == "" then "title" else empty end)
    ] | join(", ")
  ' 2>/dev/null || echo "")
  if [ -n "$missing_fields" ]; then
    schema_warnings+=("$entry_path (missing fields: $missing_fields)")
  fi

  # Check authors field shape (catch non-array or comma-joined authors so any
  # future writer that reintroduces the malformed schema is caught by routine validation).
  # The "possibly-comma-joined" heuristic is conservative: it flags an array element only
  # when it contains 2+ ", " occurrences, or exactly one ", " followed by a second
  # non-initial capitalized name-like token (2+ letters). This avoids false positives on
  # legitimate single-author "Last, First" or "Last, First M." formatting (the pattern the
  # former zotero index-add script itself produced), while still catching packed multi-author strings
  # like "Patrick Blackburn, Maarten de Rijke, Yde Venema" or two-author strings like
  # "Patrick Blackburn, Maarten de Rijke". Mirror this same heuristic in
  # literature-normalize-authors.sh so validate and normalize stay consistent. Also reads
  # the already-parsed entry record directly, so this covers directory-path entries too.
  authors_shape=$(echo "$entry_json" | jq -r '
    def is_comma_joined:
      ( [scan(", ")] | length ) as $n
      | if $n >= 2 then true
        elif $n == 1 then
          ( (split(", ")[1]) | ([scan("[A-Z][a-zA-Z]+")] | length) ) >= 2
        else false
        end;
    [
      (if .authors != null and (.authors | type) != "array" then "authors:not-array" else empty end),
      (if (.authors | type) == "array" and (.authors | any(type != "string")) then "authors:non-string-element" else empty end),
      (if (.authors | type) == "array" and (.authors | any(type == "string" and is_comma_joined)) then "authors:possibly-comma-joined" else empty end)
    ] | join(", ")
  ' 2>/dev/null || echo "")
  if [ -n "$authors_shape" ]; then
    authors_shape_warnings+=("$entry_path ($authors_shape)")
  fi
done <<< "$entries"
```

### Validate Step 2b: Namespace Divergence Check (hard failure, with recorded exceptions)

Compares index.json's identity space against `.literature.db`'s `chunks_data.doc_id` space,
using the same path-derived bridge `literature-search.sh`'s `get_project_doc_ids()` and
`literature-doc-key.sh` already use (never `.id` alone — see that script's header for the full
invariant). The corpus-side residue was reconciled (17 new parent entries added under their
bare directory id, 2 duplicate ingest directories quarantined and their stub index entries
removed — see `context/project/literature/domain/literature-index.md`'s FTS-namespace
subsection for the invariant and corpus history). This check now **fails the command** on any
divergence entry outside the recorded known-exceptions list below; an empty divergence bucket
(modulo those exceptions) is the expected steady state, not an aspiration.

Known exceptions (carried forward with a recorded reason, never silently expanded — adding to
this list requires the same adjudication rigor as the original corpus reconciliation, not a
quick edit to silence a new failure):
- `gabbay_2000` (index-only: no FTS chunks) — conversion rejected; stamped
  `provenance_fidelity: not_yet_converted`. Not a defect to fix by this check; re-adjudicate by
  re-converting the source, not by editing this exceptions list.

```bash
# Validate mode can be invoked without passing through Convert mode's setup, so
# resolve SCRIPT_DIR defensively here rather than assuming it is already set.
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$0")/../../scripts}"
DOC_KEY_SCRIPT="$SCRIPT_DIR/literature-doc-key.sh"
DIVERGENCE_KNOWN_EXCEPTIONS_NOTE="known exceptions: gabbay_2000 (index-only, conversion rejected, provenance_fidelity: not_yet_converted) -- any other divergence entry fails this check"
# Bare directory ids carried as recorded exceptions to the hard-failure gate below.
# Format matches the "{id} (dir key: {dir_key})" label divergence_index_only entries use.
DIVERGENCE_KNOWN_EXCEPTION_IDS=("gabbay_2000")

divergence_fts_only=()
divergence_index_only=()
divergence_id_inconsistent=()

if [ -x "$DOC_KEY_SCRIPT" ] && [ -f "$lit_dir/.literature.db" ] && command -v sqlite3 >/dev/null 2>&1; then
  fts_ids=$(sqlite3 "$lit_dir/.literature.db" "SELECT DISTINCT doc_id FROM chunks_data;" 2>/dev/null | sort -u)
  index_keys=$("$DOC_KEY_SCRIPT" --list-keys "$index_file" 2>/dev/null | sort -u)

  # FTS doc_ids with no index coverage at all (neither .id nor path-derived key reaches them)
  while IFS= read -r fid; do
    [ -z "$fid" ] && continue
    if ! grep -qxF "$fid" <<< "$index_keys"; then
      divergence_fts_only+=("$fid")
    fi
  done <<< "$fts_ids"

  # Index dir keys (parent entries' path-derived key) with no FTS chunks under that key
  while IFS= read -r entry_json; do
    [ -z "$entry_json" ] && continue
    is_parent=$(echo "$entry_json" | jq -r 'if (.parent_doc == null or .parent_doc == "") then "yes" else "no" end')
    [ "$is_parent" != "yes" ] && continue
    p_id=$(echo "$entry_json" | jq -r '.id // .doc_id // empty')
    p_path=$(echo "$entry_json" | jq -r '.path // empty')
    [ -z "$p_id" ] && continue
    dir_key="$p_id"
    if [[ "$p_path" == sources/* ]]; then
      dir_key="${p_path#sources/}"
      dir_key="${dir_key%%/*}"
    fi
    dir_key_in_fts="no"
    grep -qxF "$dir_key" <<< "$fts_ids" && dir_key_in_fts="yes"
    if [ "$dir_key_in_fts" = "no" ]; then
      divergence_index_only+=("$p_id (dir key: $dir_key)")
    fi
    # Parent entries whose .id is neither its own path-derived key nor present in FTS
    # under EITHER lookup strategy -- i.e. completely unreachable, not merely a
    # curated-id-differs-from-FTS-id pairing. The `.id != dir_key` paired case (the 17
    # supported entries Decision C names) is deliberately NOT reported here: when
    # `dir_key` itself resolves in FTS, the path bridge already covers that entry, and
    # Decision C is explicit that a differing curated `.id` is a supported
    # configuration in that case, not a defect. Gating on `dir_key_in_fts == no` (in
    # addition to `.id` also not resolving) is what keeps this bucket at the expected
    # near-zero count on a corpus where the bridge is doing its job, rather than
    # re-flagging every one of those 17 supported pairings as broken.
    if [ "$p_id" != "$dir_key" ] && [ "$dir_key_in_fts" = "no" ] && ! grep -qxF "$p_id" <<< "$fts_ids"; then
      divergence_id_inconsistent+=("$p_id (path-derived key: $dir_key)")
    fi
  done <<< "$entries"
  divergence_check_skipped="no"
else
  echo "Warning: namespace-divergence check skipped (literature-doc-key.sh, .literature.db, or sqlite3 unavailable)" >&2
  divergence_check_skipped="yes"
fi

# --- Split divergence_index_only into recorded-known-exceptions vs. unexpected ---
# (divergence_fts_only and divergence_id_inconsistent have no recorded exceptions today --
# every entry in either bucket is unexpected and fails the check. gabbay_2000 is the sole
# recorded exception, and it only ever lands in divergence_index_only.)
divergence_index_only_known=()
divergence_index_only_unexpected=()
for item in "${divergence_index_only[@]:-}"; do
  [ -z "$item" ] && continue
  is_known="no"
  for exc in "${DIVERGENCE_KNOWN_EXCEPTION_IDS[@]}"; do
    case "$item" in
      "$exc "*) is_known="yes"; break ;;
    esac
  done
  if [ "$is_known" = "yes" ]; then
    divergence_index_only_known+=("$item")
  else
    divergence_index_only_unexpected+=("$item")
  fi
done

# --- Hard-failure gate: any unexpected divergence (in any of the three buckets), or the
# check being skipped entirely (tools unavailable -- cleanliness cannot be confirmed,
# which is not the same as clean), fails Validate mode. See Step 4 for how this combines
# with the other failure classes (schema-shape defects, etc.) into the final report verdict.
divergence_check_failed="no"
if [ "$divergence_check_skipped" = "yes" ] \
   || [ "${#divergence_fts_only[@]}" -gt 0 ] \
   || [ "${#divergence_id_inconsistent[@]}" -gt 0 ] \
   || [ "${#divergence_index_only_unexpected[@]}" -gt 0 ]; then
  divergence_check_failed="yes"
fi
```

### Validate Step 3: Find Unindexed Markdown Files

```bash
unindexed=()
while IFS= read -r md_file; do
  # Get path relative to lit_dir
  rel_path="${md_file#$lit_dir/}"
  if ! jq -e --arg p "$rel_path" '.entries[] | select(.path == $p)' "$index_file" >/dev/null 2>&1; then
    unindexed+=("$rel_path")
  fi
done < <(find "$lit_dir" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
```

### Validate Step 4: Display Report

```
## Literature Validation Report

**Index**: specs/literature/index.json
**Total Entries**: {N}

### Schema-Shape Defects ({count}) — malformed entries (missing .id/.doc_id, missing .path, or
### .path not sources/-prefixed) — reported separately from missing FILES below
{for each schema_shape_defect entry:}
- {label} ({defects})
  These entries are malformed records, not files that vanished; the fix is to repair or remove
  the entry, not to search the filesystem for a target.

### Stale Entries ({count}) — path in index but file missing
{for each stale entry:}
- {entry_path}

### Token Count Drift ({count}) — more than 20% change from stored count
{for each drift entry:}
- {entry_path}: stored {N}, actual {M} ({pct}% drift)

### Schema Warnings ({count}) — entries missing required v2 fields
{for each schema_warning entry:}
- {entry_path}: {missing_fields}
  Run: /literature --index {file_path} to update entry with missing fields

### Authors Shape Warnings ({count}) — non-array or comma-joined authors
{for each authors_shape_warning entry:}
- {entry_path}: {authors_shape}
  Run: bash .claude/scripts/literature-normalize-authors.sh {index_file} --apply to normalize,
  or run with no flag (dry-run is the default) first to preview the change.

### Namespace Divergence (hard failure — index.json vs. .literature.db chunks_data.doc_id)
{DIVERGENCE_KNOWN_EXCEPTIONS_NOTE}

#### FTS-only doc_ids with no index coverage ({count}) — always unexpected, always fails
{for each divergence_fts_only entry:}
- {doc_id}

#### Index dir keys with no FTS chunks — recorded known exceptions ({count}, does not fail)
{for each divergence_index_only_known entry:}
- {id} (dir key: {dir_key})

#### Index dir keys with no FTS chunks — unexpected ({count}, fails)
{for each divergence_index_only_unexpected entry:}
- {id} (dir key: {dir_key})

#### Parent entries whose .id is neither its own path-derived key nor present in FTS ({count}) — always unexpected, always fails
{for each divergence_id_inconsistent entry:}
- {id} (path-derived key: {dir_key})

{if divergence_check_skipped == "yes":}
**Namespace divergence check SKIPPED** (literature-doc-key.sh, .literature.db, or sqlite3
unavailable) — cleanliness cannot be confirmed. A skipped check counts as a failure below; it is
not treated as passing.

This section fails the command on any entry outside the recorded known-exceptions list above
(divergence_check_failed). The bridge (path-derived key resolution) already covers most
divergence at read time; a bucket entry that survives the bridge and is not a recorded exception
is exactly the residue this check exists to catch — it is not informational.

### Unindexed Files ({count}) — markdown files not in index.json
{for each unindexed file:}
- {file_path}
  Run: /literature --index {file_path}

{if all clean (zero schema-shape defects AND divergence_check_failed == "no" AND zero stale
entries AND zero unindexed files):}
### Validation Passed

All {N} index entries are valid. No schema-shape defects, no stale paths, no drift, no schema
warnings, no authors-shape warnings, no namespace divergence beyond the recorded known
exceptions, no unindexed files.

{else:}
### Validation FAILED

One or more checks above did not pass — see the sections with a non-zero unexpected count.
Namespace divergence beyond the recorded known exceptions is the specific defect class this
task exists to end; do not add an entry to the known-exceptions list to silence a new failure
without the same adjudication rigor the original corpus reconciliation used (provenance-based,
byte-identical-content verification, not a guess). Fix the underlying entry (add a missing
parent entry, quarantine a duplicate, or repair a schema-shape defect) and re-run.
```

---

## Mode: Convert

Convert unprocessed PDF/DJVU files to markdown with interactive confirmation.

### Convert Step 1: Determine Target Files

```bash
if [ -n "$file" ]; then
  # Convert specific file
  targets=("$file")
else
  # Find all unprocessed files
  targets=()
  for src in $(find "$lit_dir" -name "*.pdf" -o -name "*.djvu" 2>/dev/null | sort); do
    basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')
    if ! find "$lit_dir" -name "${basename_no_ext}*.md" -not -path "*/source_files/*" 2>/dev/null | grep -q .; then
      targets+=("$src")
    fi
  done
fi
```

### Convert Step 2: Check Tool Availability

```bash
if [ "$has_pdftotext" = "no" ]; then
  echo "Error: pdftotext not found. Install with: nix-env -iA nixpkgs.poppler_utils"
  exit 1
fi
```

### Convert Step 3: Process Each File

For each target file:

#### 3a: Get Page Count

```bash
src="$target_file"
ext="${src##*.}"
basename_no_ext=$(basename "$src" | sed 's/\.[^.]*$//')

if [ "$ext" = "djvu" ]; then
  if [ "$has_djvutxt" = "no" ]; then
    echo "Skipping $src: djvutxt not installed. Install with: nix-env -iA nixpkgs.djvulibre"
    continue
  fi
  # Get page count for DJVU
  page_count=$(djvused -e n "$src" 2>/dev/null || echo 1)
else
  # PDF: get page count
  if [ "$has_pdfinfo" = "yes" ]; then
    page_count=$(pdfinfo "$src" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
  else
    page_count=1
  fi
fi
```

#### 3b: Extract Full Text and Determine Chunking

First, extract the complete text from the source file (page-range extraction happens at 3d if
needed for page-range chunks; for content-aware chunking, extract all text first):

```bash
if [ "$ext" = "pdf" ]; then
  full_text=$(pdftotext -layout "$src" - 2>/dev/null)
elif [ "$ext" = "djvu" ]; then
  full_text=$(djvutxt "$src" 2>/dev/null)
fi

# Count total lines
total_lines=$(echo "$full_text" | wc -l)
LINE_THRESHOLD=4000
MERGE_MIN=500
```

**Content-aware chunking algorithm**:

```bash
# Step 1: Detect logical section boundaries using heading patterns
# Supported heading patterns (in priority order):
#   - "Chapter N" / "CHAPTER N"  -> chapter boundary
#   - "N  Title" (number + spaces + capitalized text) -> numbered section
#   - "Part I/V/X..." / "Part 1/2..." -> part boundary
#   - "## Heading" / "### Heading" (markdown headings) -> section heading

section_starts=()  # line numbers where sections begin
section_names=()   # human-readable name for each section

while IFS= read -r line_num_and_content; do
  line_num="${line_num_and_content%%:*}"
  content="${line_num_and_content#*:}"
  if echo "$content" | grep -qE '^(Chapter|CHAPTER)[[:space:]]+[0-9IVXivx]+'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)")
  elif echo "$content" | grep -qE '^[0-9]+[[:space:]]{2,}[A-Z]'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)")
  elif echo "$content" | grep -qE '^Part[[:space:]]+([IVXivx]+|[0-9]+)'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)")
  elif echo "$content" | grep -qE '^#{1,3}[[:space:]]+\S'; then
    section_starts+=("$line_num")
    section_names+=("$(echo "$content" | sed 's/^#{1,3}[[:space:]]*//' | cut -c1-60)")
  fi
done < <(echo "$full_text" | grep -n "")

# Step 2: If headings found, merge small adjacent sections
if [ "${#section_starts[@]}" -gt 0 ]; then
  # Build merged chunks: combine adjacent sections until total lines >= LINE_THRESHOLD
  merged_chunks=()   # array of "start_line:end_line:name" strings
  chunk_start="${section_starts[0]}"
  chunk_name="${section_names[0]}"
  chunk_lines=0
  
  for i in "${!section_starts[@]}"; do
    if [ "$i" -eq 0 ]; then continue; fi
    prev_start="${section_starts[$((i-1))]}"
    curr_start="${section_starts[$i]}"
    section_size=$(( curr_start - prev_start ))
    
    if [ "$(( chunk_lines + section_size ))" -lt "$MERGE_MIN" ] || \
       [ "$(( chunk_lines + section_size ))" -lt "$LINE_THRESHOLD" ]; then
      # Merge into current chunk
      chunk_lines=$(( chunk_lines + section_size ))
    else
      # Flush current chunk
      chunk_end=$(( curr_start - 1 ))
      merged_chunks+=("${chunk_start}:${chunk_end}:${chunk_name}")
      chunk_start="$curr_start"
      chunk_name="${section_names[$i]}"
      chunk_lines=0
    fi
  done
  # Flush last chunk
  merged_chunks+=("${chunk_start}:${total_lines}:${chunk_name}")

  # Build chunks and output_files arrays from merged_chunks
  chunks=()
  output_files=()
  chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"
  mkdir -p "$chunk_dir"
  
  for i in "${!merged_chunks[@]}"; do
    entry="${merged_chunks[$i]}"
    start_line="${entry%%:*}"
    rest="${entry#*:}"
    end_line="${rest%%:*}"
    name="${rest#*:}"
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
    nn=$(printf "%02d" $(( i + 1 )))
    chunks+=("lines:${start_line}-${end_line}")
    output_files+=("${sources_prefix}${basename_no_ext}/section${nn}_${slug}.md")
  done

# Step 3: Fallback — no headings detected, use mechanical 4000-line splits
else
  chunks=()
  output_files=()
  start=1
  part_num=1
  chunk_dir="$lit_dir/${sources_prefix}${basename_no_ext}"
  
  if [ "$total_lines" -le "$LINE_THRESHOLD" ]; then
    # Single file — no chunking needed
    chunks+=("lines:1-${total_lines}")
    output_files+=("${sources_prefix}${basename_no_ext}.md")
  else
    mkdir -p "$chunk_dir"
    while [ "$start" -le "$total_lines" ]; do
      end=$(( start + LINE_THRESHOLD - 1 ))
      if [ "$end" -gt "$total_lines" ]; then end=$total_lines; fi
      nn=$(printf "%02d" "$part_num")
      chunks+=("lines:${start}-${end}")
      output_files+=("${sources_prefix}${basename_no_ext}/${basename_no_ext}_part${nn}.md")
      start=$(( end + 1 ))
      part_num=$(( part_num + 1 ))
    done
  fi
fi
```

#### 3c: Confirm Chunk Boundaries with User

If multi-chunk (more than one output file), present proposed boundaries via AskUserQuestion:

Build a description showing detected sections or line ranges:
```bash
# Build display string from chunks and output_files arrays
chunk_preview=""
for i in "${!chunks[@]}"; do
  range="${chunks[$i]#lines:}"  # strip "lines:" prefix for display
  name=$(basename "${output_files[$i]}" .md)
  chunk_preview="${chunk_preview}\n  ${name}: lines ${range}"
done
approx_tokens=$(( total_lines * 15 / 10 ))  # rough estimate: 1.5 tokens/line
```

```json
{
  "question": "Convert '{basename}' ({total_lines} lines) into {N} chunks?",
  "header": "Chunk Boundaries for {basename}",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept proposed chunks ({N} files)",
      "description": "Detected sections:\n{chunk_preview}"
    },
    {
      "label": "Use single file (no chunking)",
      "description": "Convert all {total_lines} lines to one {basename}.md (~{approx_tokens} tokens)"
    },
    {
      "label": "Skip this file",
      "description": "Do not convert {basename} now"
    }
  ]
}
```

If user selects "Use single file": set `chunks=("lines:1-${total_lines}")`, `output_files=("${basename_no_ext}.md")`
If user selects "Skip this file": continue to next file

#### 3d: Write Chunk Files

For each chunk, extract the relevant lines from `full_text` and write to the output file:

```bash
for i in "${!chunks[@]}"; do
  chunk_range="${chunks[$i]#lines:}"  # strip "lines:" prefix
  start_line="${chunk_range%-*}"
  end_line="${chunk_range#*-}"
  output_md="$lit_dir/${output_files[$i]}"

  # Ensure parent directory exists (for chunked documents in subdirectory)
  mkdir -p "$(dirname "$output_md")"

  # Extract line range from full_text
  raw_text=$(echo "$full_text" | sed -n "${start_line},${end_line}p")

  # Check if text was extracted
  if [ -z "$(echo "$raw_text" | tr -d '[:space:]')" ]; then
    echo "Warning: No text in $src lines ${start_line}-${end_line}. File may be scanned/image-only and requires OCR."
    continue
  fi

  # Build title for this chunk
  doc_title=$(basename "$src" | sed 's/\.[^.]*$//' | tr '_-' '  ' | sed 's/\b\(.\)/\u\1/g')
  section_name=$(basename "$output_md" .md | sed 's/^[^_]*_//' | tr '-_' '  ')
  chunk_header=""
  if [ "${#chunks[@]}" -gt 1 ]; then
    chunk_header=" — ${section_name} (lines ${start_line}-${end_line})"
  fi

  markdown_content="# ${doc_title}${chunk_header}

${raw_text}"

  # Write to file
  echo "$markdown_content" > "$output_md"
done
```

#### 3e: Compute Token Count and Auto-Generate Metadata

After writing each chunk file:

```bash
output_md="$lit_dir/${output_files[$i]}"
char_count=$(wc -c < "$output_md" 2>/dev/null || echo 0)
token_count=$(( char_count / 4 + 20 ))

# Extract auto-generated keywords (word frequency, top 10 after stopword removal)
# Stopword list (minimal)
stopwords="the a an and or but in on at to of for is are was were be been being have has had do does did will would could should may might shall can"

# Get word frequencies, filter stopwords, take top 10
auto_keywords=$(echo "$raw_text" | \
  tr '[:upper:]' '[:lower:]' | \
  tr -cs 'a-z' '\n' | \
  grep -v '^$' | \
  grep -v -w -F "$(echo "$stopwords" | tr ' ' '\n')" | \
  grep -E '^[a-z]{4,}$' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{print $2}' | \
  jq -R . | jq -s . 2>/dev/null || echo '[]')

# Extract summary: look for Abstract, else use first 2-3 sentences
abstract_match=$(echo "$raw_text" | grep -i -A 5 "^[[:space:]]*abstract[[:space:]]*$" | head -6 | tail -5)
if [ -n "$abstract_match" ]; then
  auto_summary="$(echo "$abstract_match" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-300)"
else
  # First 2-3 sentences
  auto_summary=$(echo "$raw_text" | tr '\n' ' ' | sed 's/  */ /g' | grep -oP '^.{0,300}[.!?]' | head -1)
  if [ -z "$auto_summary" ]; then
    auto_summary=$(echo "$raw_text" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)
  fi
fi
```

#### 3f: Confirm Metadata with User

First prompt for bibliographic fields:

```json
{
  "question": "Enter bibliographic metadata for '{output_filename}' (or press Enter to skip each):",
  "header": "Document Metadata"
}
```

Prompt for each field in sequence using AskUserQuestion:
- `{"question": "Authors (comma-separated, e.g. 'Alice Smith, Bob Jones'):"}` -> parse into string array
- `{"question": "Title (full document title):"}` -> string
- `{"question": "Year (publication year, e.g. 2024):"}` -> integer or null
- `{"question": "Document type (paper/book/chapter/section) [default: paper]:"}`  -> one of `paper|book|chapter|section`
- `{"question": "Source format (pdf/djvu/manual) [auto-detected: {detected_format}]:"}`  -> one of `pdf|djvu|manual` (default to detected extension)

Then confirm keywords and summary:

```json
{
  "question": "Review auto-generated keywords and summary for '{output_filename}':",
  "header": "Keywords and Summary",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept auto-generated metadata",
      "description": "Keywords: {auto_keywords_preview}\nSummary: {auto_summary_preview}"
    },
    {
      "label": "Edit keywords",
      "description": "Keep summary, modify keyword list"
    },
    {
      "label": "Edit summary",
      "description": "Keep keywords, modify summary"
    },
    {
      "label": "Edit both",
      "description": "Modify both keywords and summary before indexing"
    }
  ]
}
```

If user selects "Edit keywords", prompt:
```json
{"question": "Enter keywords (comma-separated):"}
```
Parse response into JSON array.

If user selects "Edit summary", prompt:
```json
{"question": "Enter one-sentence summary:"}
```

#### 3g: Update index.json

```bash
# Generate entry ID from filename (lowercase, underscores)
# For chunked sections, include subdirectory prefix to ensure uniqueness
if [[ "${output_files[$i]}" == *"/"* ]]; then
  entry_id=$(echo "${output_files[$i]}" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]' | tr '/ -' '_')
else
  entry_id=$(basename "$output_md" .md | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
fi

# Determine source format from file extension
source_format="${ext}"  # "pdf" or "djvu"

# Determine doc_type, parent_doc, and page_range for chunked vs single-file entries
if [ "${#chunks[@]}" -gt 1 ] && [[ "${output_files[$i]}" == *"/"* ]]; then
  # Chunked section entry
  final_doc_type="section"
  parent_id=$(echo "$basename_no_ext" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
  parent_doc="$parent_id"
  chunk_range_display="${chunks[$i]#lines:}"
  page_range="lines:${chunk_range_display}"
else
  # Top-level (single file or user chose no-chunk) — use values from user prompt
  # final_doc_type already set from user prompt (default "paper")
  parent_doc=""
  page_range=""
fi

# Create or update index.json
if [ ! -f "$index_file" ]; then
  echo '{"token_budget": 4000, "entries": []}' > "$index_file"
fi

# Check if entry already exists
if jq -e --arg id "$entry_id" '.entries[] | select(.id == $id)' "$index_file" >/dev/null 2>&1; then
  # Update existing entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "${output_files[$i]}" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$source_format" \
     --arg parent_doc "$parent_doc" \
     --arg page_range "$page_range" \
     '.entries = [.entries[] | if .id == $id then . + {
       "path": $path,
       "token_count": $tc,
       "keywords": $kw,
       "summary": $sum,
       "authors": $authors,
       "title": $title,
       "year": (if $year == "null" then null else ($year | tonumber) end),
       "doc_type": $doc_type,
       "source_format": $source_format,
       "parent_doc": (if $parent_doc == "" then null else $parent_doc end),
       "page_range": (if $page_range == "" then null else $page_range end)
     } else . end]' \
     "$index_file" > "$tmp" && mv "$tmp" "$index_file"
else
  # Append new entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "${output_files[$i]}" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$source_format" \
     --arg parent_doc "$parent_doc" \
     --arg page_range "$page_range" \
     '.entries += [{
       "id": $id,
       "path": $path,
       "token_count": $tc,
       "keywords": $kw,
       "summary": $sum,
       "authors": $authors,
       "title": $title,
       "year": (if $year == "null" then null else ($year | tonumber) end),
       "doc_type": $doc_type,
       "source_format": $source_format,
       "parent_doc": (if $parent_doc == "" then null else $parent_doc end),
       "page_range": (if $page_range == "" then null else $page_range end)
     }]' \
     "$index_file" > "$tmp" && mv "$tmp" "$index_file"
fi
```

#### 3h: Chunk and Index

Immediately after Convert Step 3g writes `output_md` and its `index.json` entry for this output
file, chunk it so the document is searchable without a separate `--ingest`. Use the shared
per-document `basename_no_ext` as `--doc-id` for **every** output file of this source (not
Step 3g's per-section `entry_id`), so multi-section conversions land all sections under one
`doc_id` — matching Job 4's `doc_id = <sources/dir basename>` check.

```bash
# Resolve literature-chunk.sh via the same SCRIPT_DIR/scripts convention Ingest Step 2 uses.
SCRIPT_DIR="$(dirname "$0")/../../scripts"
CHUNK_SCRIPT="$SCRIPT_DIR/literature-chunk.sh"

# output_md and basename_no_ext are already set from Steps 3d/3a above for this output file.
# dirname "$output_md" is already sources/<dir>-prefixed by construction (Step 3d's mkdir -p
# "$(dirname "$output_md")") — never introduce a $LITERATURE_DIR/$DOC_ID/ top-level path here.
chunk_count=0
if [ -x "$CHUNK_SCRIPT" ]; then
  # Guarded assignment (mirrors literature-ingest.sh's CHUNK_COUNT pattern): a chunking
  # failure is logged but never aborts the rest of the convert loop.
  chunk_count=$("$CHUNK_SCRIPT" "$output_md" "$(dirname "$output_md")" --doc-id "$basename_no_ext" 2>/dev/null || echo 0)
  if [ "${chunk_count:-0}" -eq 0 ]; then
    echo "Warning: chunking produced 0 chunks for $output_md (non-fatal; index rebuild at Step 4 will not cover it)."
  fi
else
  echo "Warning: literature-chunk.sh not found at $CHUNK_SCRIPT — skipping chunk step for $output_md (non-fatal)."
fi
```

### Convert Step 4: Display Summary

After all target files have been processed (all Step 3 iterations, including 3h, complete),
rebuild the search index exactly once per invocation so every chunk written above is queryable.
Branch on the same condition Step 2 already used to set `sources_prefix`:

```bash
if [ -n "${LITERATURE_DIR:-}" ] && [ "$lit_dir" = "$LITERATURE_DIR" ]; then
  "$SCRIPT_DIR/literature-build-index.sh" --global 2>&1 | sed 's/^/[convert] /' >&2 || \
    echo "Warning: literature-build-index.sh --global failed (non-fatal; chunks are on disk, index rebuild can be retried via /literature --rebuild)."
else
  "$SCRIPT_DIR/literature-build-index.sh" --local 2>&1 | sed 's/^/[convert] /' >&2 || \
    echo "Warning: literature-build-index.sh --local failed (non-fatal; chunks are on disk, index rebuild can be retried)."
fi
```

```
## Conversion Complete

**Files Converted**: {N}

| Output File | Lines | Tokens | Chunks | Status |
|-------------|-------|--------|--------|--------|
| {file1.md}  | 1-4000      | 3,500  | {chunk_count1} | Written, indexed |
| {file2.md}  | 4001-8000   | 3,200  | {chunk_count2} | Written, indexed |
...

**Index Updated**: specs/literature/index.json ({entry_count} entries)
**Search Index**: rebuilt ({global|local}) — converted documents are immediately searchable via
`literature-search.sh` with no separate `--ingest` step required.

**Skipped Files**:
- {file.djvu} — djvutxt not installed (install: nix-env -iA nixpkgs.djvulibre)
- {scan.pdf} — No text extracted (OCR required for scanned PDFs)
```

---

## Mode: Index

Add or update an index.json entry for an existing markdown file.

### Index Step 1: Validate File Exists

```bash
if [ -z "$file" ]; then
  echo "Error: --index requires a FILE argument."
  exit 1
fi

if [ ! -f "$file" ]; then
  echo "Error: File not found: $file"
  exit 1
fi

# Get relative path within specs/literature/
if [[ "$file" == "$lit_dir/"* ]]; then
  rel_path="${file#$lit_dir/}"
else
  rel_path="$(basename "$file")"
fi
```

### Index Step 2: Compute Token Count

```bash
char_count=$(wc -c < "$file" 2>/dev/null || echo 0)
token_count=$(( char_count / 4 + 20 ))
```

### Index Step 3: Auto-Generate Metadata

Same word-frequency keyword extraction and summary extraction as Convert Step 3e.

### Index Step 4: Prompt User for Bibliographic Metadata

Auto-detect `source_format` from the file extension in the filename (if present), or default to `"manual"`.

Prompt for bibliographic fields in sequence using AskUserQuestion:
- `{"question": "Authors (comma-separated, e.g. 'Alice Smith, Bob Jones') [or Enter to skip]:"}` -> parse into string array
- `{"question": "Title (full document title) [or Enter to skip]:"}` -> string
- `{"question": "Year (publication year) [or Enter to skip]:"}` -> integer or null
- `{"question": "Document type (paper/book/chapter/section) [default: paper]:"}` -> one of `paper|book|chapter|section`
- `{"question": "Source format (pdf/djvu/manual) [auto-detected: {detected_format}]:"}` -> one of `pdf|djvu|manual`
- `{"question": "Parent document ID (for chunks/sections) [or Enter if top-level]:"}` -> string or null
- `{"question": "Page range in source document (e.g. '15-47') [or Enter if not applicable]:"}` -> string or null

Then confirm keywords and summary:

```json
{
  "question": "Confirm keywords and summary for '{rel_path}' ({token_count} tokens):",
  "header": "Keywords and Summary",
  "multiSelect": false,
  "options": [
    {
      "label": "Accept auto-generated metadata",
      "description": "Keywords: {auto_keywords_preview}\nSummary: {auto_summary_preview}"
    },
    {
      "label": "Enter custom keywords",
      "description": "Manually specify keyword list"
    },
    {
      "label": "Enter custom summary",
      "description": "Manually write summary"
    },
    {
      "label": "Enter both custom",
      "description": "Specify both keywords and summary"
    }
  ]
}
```

If custom keywords requested:
```json
{"question": "Enter keywords (comma-separated):"}
```

If custom summary requested:
```json
{"question": "Enter one-sentence summary:"}
```

### Index Step 5: Write to index.json

```bash
# Initialize index.json if it does not exist
if [ ! -f "$index_file" ]; then
  echo '{"token_budget": 4000, "entries": []}' > "$index_file"
fi

entry_id=$(basename "$file" .md | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

# Check if entry already exists
if jq -e --arg id "$entry_id" '.entries[] | select(.id == $id)' "$index_file" >/dev/null 2>&1; then
  # Update existing entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "$rel_path" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$final_source_format" \
     --arg parent_doc "$final_parent_doc" \
     --arg page_range "$final_page_range" \
     '.entries = [.entries[] | if .id == $id then . + {
       "path": $path,
       "token_count": $tc,
       "keywords": $kw,
       "summary": $sum,
       "authors": $authors,
       "title": $title,
       "year": (if $year == "null" then null else ($year | tonumber) end),
       "doc_type": $doc_type,
       "source_format": $source_format,
       "parent_doc": (if $parent_doc == "" then null else $parent_doc end),
       "page_range": (if $page_range == "" then null else $page_range end)
     } else . end]' \
     "$index_file" > "$tmp" && mv "$tmp" "$index_file"
  echo "Updated existing entry '$entry_id' in $index_file"
else
  # Append new entry
  tmp=$(mktemp)
  jq --arg id "$entry_id" \
     --arg path "$rel_path" \
     --argjson tc "$token_count" \
     --argjson kw "$final_keywords" \
     --arg sum "$final_summary" \
     --argjson authors "$final_authors" \
     --arg title "$final_title" \
     --argjson year "$final_year" \
     --arg doc_type "$final_doc_type" \
     --arg source_format "$final_source_format" \
     --arg parent_doc "$final_parent_doc" \
     --arg page_range "$final_page_range" \
     '.entries += [{
       "id": $id,
       "path": $path,
       "token_count": $tc,
       "keywords": $kw,
       "summary": $sum,
       "authors": $authors,
       "title": $title,
       "year": (if $year == "null" then null else ($year | tonumber) end),
       "doc_type": $doc_type,
       "source_format": $source_format,
       "parent_doc": (if $parent_doc == "" then null else $parent_doc end),
       "page_range": (if $page_range == "" then null else $page_range end)
     }]' \
     "$index_file" > "$tmp" && mv "$tmp" "$index_file"
  echo "Added new entry '$entry_id' to $index_file"
fi
```

### Index Step 6: Display Result

```
## Index Entry Added

**File**: {rel_path}
**Entry ID**: {entry_id}
**Token Count**: {token_count}
**Keywords**: {keywords}
**Summary**: {summary}

**Index**: specs/literature/index.json ({N} entries total)
```

---

## Mode: Search

Search the Zotero library and Literature/ index, present interactive multi-select results, and trigger import for selected entries.

### Search Step 1: Resolve zotero-search.sh Path

```bash
# Find zotero-search.sh. provides.scripts deploys flat into {base_dir}/scripts/ in every
# consuming repo (never into {base_dir}/extensions/{name}/scripts/, which only ever holds a
# copied manifest.json), so the flat sibling path is the primary candidate. The nested path is
# kept only as a defensive fallback for running directly from the extension source tree
# pre-deployment.
zotero_script=""
for candidate in \
  ".claude/scripts/zotero-search.sh" \
  "$(dirname "$0")/../../scripts/zotero-search.sh" \
  ".claude/extensions/literature/scripts/zotero-search.sh"; do
  if [ -f "$candidate" ]; then
    zotero_script="$candidate"
    break
  fi
done

# Validate query is not empty
if [ -z "$query" ]; then
  echo "Error: search mode requires a query. Usage: /literature --search \"modal logic\""
  exit 1
fi

# Split query into terms for scoring
IFS=' ' read -ra query_terms <<< "$query"
```

### Search Step 2: Run zotero-search.sh (with Graceful Degradation)

```bash
zotero_results=""
zotero_available=false
zotero_exit_code=0

if [ -n "$zotero_script" ] && [ -x "$zotero_script" ]; then
  # Run zotero-search.sh with JSON output format, limit 20 results
  zotero_results=$("$zotero_script" --format=json --limit=20 "${query_terms[@]}" 2>&1) || zotero_exit_code=$?

  case "$zotero_exit_code" in
    0)
      zotero_available=true
      ;;
    1)
      # Library not found — show setup instructions (zotero-search.sh prints them to stderr)
      echo "## Zotero Library Not Configured"
      echo ""
      echo "No zotero-library.json found. To enable Zotero search:"
      echo "1. Install Zotero with Better BibTeX plugin"
      echo "2. Export your library: File > Export Library > Better CSL JSON"
      echo "3. Save as: \$LITERATURE_DIR/zotero-library.json (default: ~/Projects/Literature/zotero-library.json)"
      echo ""
      echo "Falling back to Literature/ index search only..."
      zotero_results=""
      ;;
    2)
      # No results found — continue to index-only search
      echo "No Zotero results for query: $query"
      zotero_results=""
      ;;
  esac
else
  echo "Note: zotero-search.sh not found. Searching Literature/ index only."
fi
```

### Search Step 3: Cross-Reference Zotero Results with Literature/ Index

```bash
# Parse Zotero results (JSON array of entries)
declare -A result_status  # citation_key -> "already_converted" | "pdf_available" | "pdf_not_available"
declare -A result_paths   # citation_key -> path in Literature/ index (for already_converted)
declare -a result_keys    # ordered list of citation keys

if [ -n "$zotero_results" ] && [ "$zotero_available" = "true" ]; then
  # Extract citation keys from Zotero results
  while IFS= read -r ckey; do
    result_keys+=("$ckey")

    # Check if already in Literature/ index (match on bib_key or zotero_key == citation_key)
    if [ -f "$index_file" ]; then
      match_path=$(jq -r --arg ck "$ckey" '
        .entries[] | select(
          (.bib_key == $ck) or
          (.zotero_key == $ck) or
          (.id == $ck)
        ) | .path
      ' "$index_file" 2>/dev/null | head -1)

      if [ -n "$match_path" ] && [ "$match_path" != "null" ]; then
        result_status["$ckey"]="already_converted"
        result_paths["$ckey"]="$lit_dir/$match_path"
        continue
      fi
    fi

    # Check if PDF is available via Zotero
    pdf_paths=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '
      .[] | select(.citation_key == $ck) | .pdf_paths[]?
    ' 2>/dev/null)

    if [ -n "$pdf_paths" ]; then
      # Verify at least one PDF exists
      has_pdf=false
      while IFS= read -r pdf_path; do
        if [ -f "$pdf_path" ]; then
          has_pdf=true
          break
        fi
      done <<< "$pdf_paths"

      if [ "$has_pdf" = "true" ]; then
        result_status["$ckey"]="pdf_available"
      else
        result_status["$ckey"]="pdf_not_available"
      fi
    else
      result_status["$ckey"]="pdf_not_available"
    fi
  done < <(echo "$zotero_results" | jq -r '.[].citation_key' 2>/dev/null)
fi
```

### Search Step 4: Search Literature/ Index Directly

```bash
# Score index entries against query terms (keyword overlap scoring)
declare -A index_scores  # entry_id -> score
declare -a index_keys    # ordered list of index entry ids

if [ -f "$index_file" ]; then
  while IFS=$'\t' read -r entry_id entry_path entry_keywords entry_title; do
    score=0
    combined="${entry_keywords} ${entry_title}"
    combined_lower=$(echo "$combined" | tr '[:upper:]' '[:lower:]')

    for term in "${query_terms[@]}"; do
      term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
      if echo "$combined_lower" | grep -q "$term_lower"; then
        score=$(( score + 1 ))
      fi
    done

    if [ "$score" -gt 0 ]; then
      index_scores["$entry_id"]=$score
      index_keys+=("$entry_id")

      # Only add to results if not already present from Zotero search
      bib_key=$(jq -r --arg id "$entry_id" '.entries[] | select(.id == $id) | .bib_key // ""' "$index_file" 2>/dev/null)
      if [ -z "$bib_key" ] || [ -z "${result_status[$bib_key]+_}" ]; then
        if [ -z "${result_status[$entry_id]+_}" ]; then
          result_keys+=("$entry_id")
          result_status["$entry_id"]="already_converted"
          result_paths["$entry_id"]="$lit_dir/$entry_path"
        fi
      fi
    fi
  done < <(jq -r '.entries[] | [.id, .path, (.keywords // [] | join(" ")), (.title // "")] | @tsv' "$index_file" 2>/dev/null)
fi
```

### Search Step 5: Merge and Sort Results

```bash
# Build display array sorted by score (Zotero score + index keyword overlap)
declare -a display_entries  # "citation_key|title|authors|year|score|status" strings

for ckey in "${result_keys[@]}"; do
  # Get metadata from Zotero results or index
  if [ "$zotero_available" = "true" ] && echo "$zotero_results" | jq -e --arg ck "$ckey" '.[] | select(.citation_key == $ck)' >/dev/null 2>&1; then
    title=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .title' 2>/dev/null | head -1)
    authors=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .authors | join(", ")' 2>/dev/null | head -1)
    year=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .year' 2>/dev/null | head -1)
    score=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .score' 2>/dev/null | head -1)
  else
    # Get from Literature/ index
    title=$(jq -r --arg id "$ckey" '.entries[] | select(.id == $id) | .title // "Unknown"' "$index_file" 2>/dev/null)
    authors=$(jq -r --arg id "$ckey" '.entries[] | select(.id == $id) | (.authors // []) | join(", ")' "$index_file" 2>/dev/null)
    year=$(jq -r --arg id "$ckey" '.entries[] | select(.id == $id) | .year // "?"' "$index_file" 2>/dev/null)
    score="${index_scores[$ckey]:-0}"
  fi

  status="${result_status[$ckey]:-pdf_not_available}"
  display_entries+=("${ckey}|${title}|${authors}|${year}|${score}|${status}")
done

# Sort by score descending (simple bubble-pass sort on score field)
IFS=$'\n' display_entries=($(printf '%s\n' "${display_entries[@]}" | sort -t'|' -k5 -rn))
```

### Search Step 6: Present Multi-Select Results via AskUserQuestion

```bash
# Build options array for AskUserQuestion
options=()
for entry in "${display_entries[@]}"; do
  IFS='|' read -r ckey title authors year score status <<< "$entry"

  # Format availability tag
  case "$status" in
    already_converted) tag="[IMPORTED]" ;;
    pdf_available)     tag="[PDF AVAILABLE]" ;;
    pdf_not_available) tag="[NO PDF]" ;;
  esac

  label="${tag} ${title}"
  description="Authors: ${authors:-Unknown} | Year: ${year:-?} | Score: ${score} | Key: ${ckey}"
  options+=("{\"label\": \"${label}\", \"description\": \"${description}\"}")
done

# Add escape option
options+=("{\"label\": \"Done — no import\", \"description\": \"Exit search without importing\"}")
```

Present via AskUserQuestion:
```json
{
  "question": "Search results for '{query}' ({N} results). Select entries to import:",
  "header": "Literature Search Results",
  "multiSelect": true,
  "options": [
    {
      "label": "[IMPORTED] Title of Already-Converted Paper",
      "description": "Authors: Author Name | Year: 2023 | Score: 5 | Key: author2023_title"
    },
    {
      "label": "[PDF AVAILABLE] Title of Importable Paper",
      "description": "Authors: Author Name | Year: 2022 | Score: 3 | Key: author2022_title"
    },
    {
      "label": "[NO PDF] Title of Paper Without PDF",
      "description": "Authors: Author Name | Year: 2021 | Score: 2 | Key: author2021_title"
    },
    {
      "label": "Done — no import",
      "description": "Exit search without importing"
    }
  ]
}
```

### Search Step 7: Route Selected Entries

```bash
for selected in "${user_selections[@]}"; do
  ckey=$(extract_citation_key_from_selection "$selected")
  status="${result_status[$ckey]}"

  case "$status" in
    already_converted)
      # Show path info — already in Literature/
      path="${result_paths[$ckey]}"
      echo "Already imported: $ckey"
      echo "  Path: $path"
      ;;

    pdf_available)
      # Trigger import pipeline (Steps 8-12 below)
      handle_import "$ckey" "$zotero_results"
      ;;

    pdf_not_available)
      echo "No PDF available for: $ckey"
      echo "  Add the PDF to your Zotero library to enable import."
      ;;
  esac
done
```

**Edge case**: If both Zotero search fails (exit 1) and the index has no matching entries, display:
```
No results found for query: "{query}"

Zotero library not configured (or no matches). Literature/ index also returned no matches.
Suggestions:
  - Try broader search terms
  - Run /literature --convert to add local PDFs
  - Configure Zotero: set ZOTERO_LIBRARY or place zotero-library.json in $LITERATURE_DIR/
```

---

## Mode: Import Pipeline (Steps 8-12)

Import pipeline triggered from search selection for PDF-available entries. Invoked from Search Step 7 for each `pdf_available` entry.

### Import Step 8: Confirm Import

```bash
function handle_import() {
  local ckey="$1"
  local zotero_results="$2"

  # Extract Zotero metadata for this entry
  local title=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .title' 2>/dev/null)
  local authors=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .authors | join(", ")' 2>/dev/null)
  local year=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .year' 2>/dev/null)
  local pdf_path=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .pdf_paths[0]' 2>/dev/null)
  local abstract=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .abstract_snippet' 2>/dev/null)
```

Present confirmation:
```json
{
  "question": "Import '{title}' ({year}) by {authors}?",
  "header": "Confirm Import",
  "multiSelect": false,
  "options": [
    {
      "label": "Yes — import and convert",
      "description": "Symlink PDF, convert to markdown, update index with Zotero metadata"
    },
    {
      "label": "Skip this entry",
      "description": "Do not import '{title}'"
    }
  ]
}
```

If user selects "Skip this entry": return without importing.

### Import Step 9: Create PDF Symlink

```bash
  # Ensure pdfs/ directory exists in Literature/ repo
  mkdir -p "$lit_dir/pdfs"

  # Symlink path: $LITERATURE_DIR/pdfs/{citation_key}.pdf
  symlink_path="$lit_dir/pdfs/${ckey}.pdf"

  if [ -L "$symlink_path" ]; then
    echo "Symlink already exists: $symlink_path (skipping creation)"
  elif [ -f "$symlink_path" ]; then
    echo "File already exists at symlink path: $symlink_path (skipping)"
  else
    ln -s "$pdf_path" "$symlink_path"
    echo "Created symlink: $symlink_path -> $pdf_path"
  fi
```

### Import Step 10: Run Convert with Pre-Populated Zotero Metadata

```bash
  # Pre-populate metadata from Zotero to reduce user prompts during convert
  # Pass as environment variables read by handle_convert()
  export PREFILL_TITLE="$title"
  export PREFILL_AUTHORS="$authors"
  export PREFILL_YEAR="$year"
  export PREFILL_DOC_TYPE="paper"
  export PREFILL_SOURCE_FORMAT="pdf"

  # Call existing handle_convert() with the symlinked PDF path
  file="$symlink_path"
  handle_convert

  # Clear prefill variables
  unset PREFILL_TITLE PREFILL_AUTHORS PREFILL_YEAR PREFILL_DOC_TYPE PREFILL_SOURCE_FORMAT
```

**Note**: handle_convert() checks PREFILL_* variables before prompting the user for each field:
```bash
# In handle_convert Convert Step 3f (metadata prompts), check PREFILL_* first:
if [ -n "${PREFILL_TITLE:-}" ]; then
  final_title="$PREFILL_TITLE"
else
  # ... prompt user
fi
```

### Import Step 11: Patch Index Entry with Zotero-Specific Fields

```bash
  # After handle_convert() writes the index entry, patch it with Zotero-specific fields
  # The entry_id is derived from the symlink basename (citation_key)
  entry_id=$(echo "$ckey" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')

  # Get additional Zotero fields
  local zotero_key=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .zotero_key // ""' 2>/dev/null)
  local zotero_path="$pdf_path"
  local bib_key="$ckey"
  # project_tags: derive from Zotero collections if available, else empty array
  local project_tags=$(echo "$zotero_results" | jq -r --arg ck "$ckey" '.[] | select(.citation_key == $ck) | .collections // []' 2>/dev/null)

  # Patch index.json with Zotero-specific fields via jq
  if jq -e --arg id "$entry_id" '.entries[] | select(.id == $id)' "$index_file" >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg id "$entry_id" \
       --arg zotero_key "$zotero_key" \
       --arg zotero_path "$zotero_path" \
       --arg bib_key "$bib_key" \
       --argjson project_tags "$project_tags" \
       '.entries = [.entries[] | if .id == $id then . + {
         "zotero_key": (if $zotero_key == "" then null else $zotero_key end),
         "zotero_path": $zotero_path,
         "bib_key": $bib_key,
         "project_tags": $project_tags
       } else . end]' \
       "$index_file" > "$tmp" && mv "$tmp" "$index_file"
    echo "Patched index entry '$entry_id' with Zotero metadata"
  else
    echo "Warning: index entry '$entry_id' not found after convert — Zotero fields not patched"
  fi
```

### Import Step 12: Git Commit to Literature/ Repo

```bash
  # Non-blocking git commit in $LITERATURE_DIR — targeted staging (never a repo-wide add) so an
  # import only commits the files this import produced, not unrelated stray edits elsewhere in
  # the separate Literature/ repo. Mirrors .claude/context/standards/git-staging-scope.md's
  # under-stage direction, adapted to this import's own artifact set (symlink, converted
  # markdown, index.json) since Literature/ is a separate git repo with no task-dir concept.
  if [ -d "$lit_dir/.git" ]; then
    (
      cd "$lit_dir" && \
      git add "pdfs/${ckey}.pdf" "index.json" \
        $(find . -maxdepth 2 -name "${entry_id}*.md" -not -path "./source_files/*" 2>/dev/null) && \
      git commit -m "import: $title ($year)" 2>&1 | head -5
    ) || echo "Note: git commit in $lit_dir failed (non-blocking)"
  fi

  echo ""
  echo "Import complete: $ckey"
  echo "  Markdown: $lit_dir/{converted_path}"
  echo "  Index: $index_file (entry: $entry_id)"
}  # end handle_import()
```

**Processing order**: Import processes entries sequentially (one at a time) to support interactive convert prompts. Each entry completes its full import pipeline (steps 9-12) before the next entry begins.

---

## Mode: Rebuild

`handle_rebuild()` brings the per-repo sub-index (`specs/literature-index.json`) into
conformance with the global Literature corpus (`$LITERATURE_DIR/index.json` +
`$LITERATURE_DIR/.literature.db`). It offers four selectable jobs — Jobs 1, 2, and 4 are
**read-only and idempotent**; Job 3 is the **only writer**, and only after an explicit
confirm-after-diff `AskUserQuestion`. `--dry-run` is accepted uniformly but only meaningfully
changes Job 3's behavior (Jobs 1/2/4 never write regardless of `--dry-run`).

### Rebuild Step 1: Parse Args and Resolve Paths

```bash
function handle_rebuild() {
  # $mode is already "rebuild" (see Step 4 dispatch); dry_run comes from the skill args
  # ("mode=rebuild dry_run={true|false}"), parsed the same way as $mode/$file in Step 1.
  dry_run=$(echo "$ARGUMENTS" | grep -oP 'dry_run=\K\S+' | head -1)
  dry_run="${dry_run:-false}"

  sub_index="specs/literature-index.json"
  global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"
  literature_db="${LITERATURE_DIR:-$HOME/Projects/Literature}/.literature.db"
```

### Rebuild Step 2: Absent-Sub-Index Deferral (checked FIRST, before any job picker)

Mirrors the `--lit` flow's `PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL` precedent
(`literature-lit-flag-resolve.sh`, CLAUDE.md "Interactive Sub-Index Setup Detection") rather than
duplicating `literature-create-setup-task.sh`'s state.json-mutation logic inline.

```bash
  if [ ! -f "$sub_index" ]; then
    echo "## Rebuild: Sub-Index Absent"
    echo ""
    echo "No sub-index found at $sub_index — there is nothing to rebuild yet."
    echo ""
    setup_script=".claude/extensions/literature/scripts/literature-create-setup-task.sh"
    if [ -x "$setup_script" ] || [ -f "$setup_script" ]; then
      new_task=$("$setup_script" 2>/tmp/rebuild-setup-task-rationale.txt)
      setup_exit=$?
      if [ "$setup_exit" -eq 0 ] && [ -n "$new_task" ]; then
        echo "Created task #$new_task to populate $sub_index (see literature-create-setup-task.sh)."
        echo "Run /implement $new_task once ready, then re-run /literature --rebuild."
      else
        echo "Could not auto-create a setup task: $(cat /tmp/rebuild-setup-task-rationale.txt)"
        echo "Run .claude/extensions/literature/scripts/literature-create-setup-task.sh manually,"
        echo "or use /literature --lit on any command to trigger the same interactive setup flow."
      fi
    else
      echo "literature-create-setup-task.sh not found — use /literature --lit on any command"
      echo "to trigger the same interactive sub-index setup flow."
    fi
    return 0   # never error, never present the job picker with nothing to check
  fi
```

### Rebuild Step 3: Job Picker (AskUserQuestion, multiSelect)

Only reached when the sub-index exists. Jobs 1 & 2 are mechanical/read-only and pre-checked by
default; Jobs 3 (the only writer) & 4 (broader, corpus-wide scope) are left unchecked by default.

```json
{
  "question": "Which sub-index rebuild checks should run?",
  "header": "Sub-Index Rebuild Jobs",
  "multiSelect": true,
  "options": [
    {
      "label": "Dangling-ref lint (default on)",
      "description": "Mechanical, read-only. Flags doc_ids that no longer resolve in the global index."
    },
    {
      "label": "Schema conformance check (default on)",
      "description": "Mechanical, read-only. Checks structural minimums only (doc_id + relevance/reason present) — never flags or strips extra curation fields like hazard/citation_rule/known_corrections/audits."
    },
    {
      "label": "Coverage refresh",
      "description": "Requires judgment. Proposes newly-relevant docs from the global corpus; nothing is written without a follow-up confirm-after-diff. The only job that can write."
    },
    {
      "label": "Chunk/search-index coverage audit",
      "description": "Mechanical, read-only. Reports which sources/<dir>/ directories (and legacy chunks_dir entries) have zero FTS5 search coverage in chunks_data."
    }
  ]
}
```

Selections determine which of `run_job1`, `run_job2`, `run_job3`, `run_job4` are `true` for the
rest of `handle_rebuild()`.

### Rebuild Step 4: Report-Aggregation Shell

Each selected job appends its findings into a single multi-job report; nothing is printed
standalone. Jobs 1/2/4 bodies live in the "Job 1", "Job 2", "Job 4" subsections below (added in
later phases); Job 3 lives in its own "Job 3" subsection (also added in a later phase). This
shell is the only place that prints the report header/footer and the `dry_run` note.

```bash
  echo "## Sub-Index Rebuild Report — $(basename "$(pwd)")"
  echo ""
  if [ "$dry_run" = "true" ]; then
    echo "_dry-run active: Job 3 (coverage refresh), if selected, will print a proposed diff and write nothing. Jobs 1/2/4 never write regardless of --dry-run._"
    echo ""
  fi

  [ "$run_job1" = "true" ] && rebuild_job1_dangling_ref_lint
  [ "$run_job2" = "true" ] && rebuild_job2_schema_conformance
  [ "$run_job4" = "true" ] && rebuild_job4_coverage_audit
  # Job 3 always last: it is the only writer and its confirm-after-diff step should reflect the
  # read-only jobs' findings printed above it.
  [ "$run_job3" = "true" ] && rebuild_job3_coverage_refresh

}  # end handle_rebuild()
```

### Job 1: Dangling-Ref Lint (read-only, idempotent)

Reuses the "Sub-Index Management > Validate" block below almost verbatim (see that section's
note — this is the wiring that makes it reachable for the first time), shaped for the
multi-job report instead of a standalone command.

```bash
function rebuild_job1_dangling_ref_lint() {
  orphans=()
  valid=()

  while IFS= read -r doc_id; do
    [ -z "$doc_id" ] && continue
    if jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
      valid+=("$doc_id")
    else
      orphans+=("$doc_id")
    fi
  done < <(jq -r '.entries[].doc_id' "$sub_index" 2>/dev/null)

  echo "### Job 1: Dangling-Ref Lint"
  echo ""
  echo "Valid entries: ${#valid[@]}"
  echo "Dangling (orphaned) entries: ${#orphans[@]}"
  echo ""
  if [ "${#orphans[@]}" -gt 0 ]; then
    echo "Orphaned doc_ids (not found in $global_index):"
    for id in "${orphans[@]}"; do
      echo "  - $id"
    done
    echo ""
    echo "Removal is NOT automatic — dangling refs are reported only. To remove one, run the"
    echo "Sub-Index Management > Remove operation explicitly after review."
  else
    echo "All entries resolve in the global index."
  fi
  echo ""
}
```

### Job 2: Schema Conformance — Structural Minimum Only (read-only, idempotent)

**Critical**: this job does NOT enforce the nominal `{doc_id, relevance, source}` shape. Live
sub-indexes diverge from it in load-bearing ways — cslib omits `source` entirely; BimodalLogic
uses `reason` instead of `relevance` plus `hazard`/`citation_rule`/`known_corrections`/`audits`
fields documenting a real citation-fidelity issue on `rabinovich_2014`. Flagging or stripping
those fields would destroy human curation data. The check is a structural minimum only: every
entry must have a non-empty `doc_id` AND at least one of `relevance`/`reason` present. Extra
fields of any kind are never flagged, never stripped, never rewritten.

```bash
function rebuild_job2_schema_conformance() {
  violations=()
  chunk_id_violations=()

  while IFS=$'\t' read -r doc_id has_relevance_or_reason; do
    [ -z "$doc_id" ] && continue
    if [ -z "$doc_id" ] || [ "$has_relevance_or_reason" != "true" ]; then
      violations+=("$doc_id")
    fi
    # chunk-file-conventions.md: chunk_*.md files are index-only re-splits, never an
    # independently referenceable sub-index doc_id.
    if [[ "$doc_id" =~ ^chunk_[0-9]+$ ]]; then
      chunk_id_violations+=("$doc_id")
    fi
  done < <(jq -r '.entries[] | [
      (.doc_id // ""),
      ((((.relevance // "") | length) > 0) or (((.reason // "") | length) > 0) | tostring)
    ] | @tsv' "$sub_index" 2>/dev/null)

  echo "### Job 2: Schema Conformance (structural minimum only)"
  echo ""
  echo "Checked: doc_id non-empty AND (relevance OR reason) present. Extra fields (hazard,"
  echo "citation_rule, known_corrections, audits, source, added, ...) are never flagged or"
  echo "stripped — they are legitimate human curation data."
  echo ""
  if [ "${#violations[@]}" -gt 0 ]; then
    echo "Entries missing the structural minimum (${#violations[@]}):"
    for id in "${violations[@]}"; do
      echo "  - ${id:-<empty doc_id>}"
    done
  else
    echo "All entries meet the structural minimum."
  fi
  echo ""
  if [ "${#chunk_id_violations[@]}" -gt 0 ]; then
    echo "chunk_NNNN doc_ids referenced directly (${#chunk_id_violations[@]} — chunk files are"
    echo "index-only re-splits, never independently referenceable; see"
    echo ".claude/context/project/literature/patterns/chunk-file-conventions.md):"
    for id in "${chunk_id_violations[@]}"; do
      echo "  - $id"
    done
  else
    echo "No sub-index doc_id references a chunk_NNNN id directly."
  fi
  echo ""
}
```

### Job 4: Chunk/Search-Index Coverage Audit (read-only, idempotent)

Reports, per `sources/<dir>/` directory (plus every legacy top-level `chunks_dir`-schema
entry), whether the corpus's FTS5 search index (`chunks_data`) has any coverage at all. Queries
`chunks_data` exclusively — **never** `document_metadata`, which is currently empty (0 rows) in
this corpus and is not relied upon here (orphaned table, explicit non-goal).

**Expected-empty vs unexpected-empty**: `/literature --convert`
chunks and indexes every `.md` it writes (Convert Step 3h/Step 4), so a `sources/<dir>/` with a
valid `.md` and zero `chunks_data` rows is no longer explained by the old "`--convert` never
chunks" root cause — it now signals either a **regression** in the Step 3h/Step 4 wiring or a
**new, un-wired path** that writes `.md` files without going through `handle_convert()` or
`handle_ingest()`. Job 4 therefore cross-checks each `missing_dirs` entry against the filesystem
and buckets it as:
- **UNEXPECTED** — a valid `.md` exists (`find "$dirpath" -maxdepth 1 -name '*.md' -not -name
  'chunk_*.md'`, excluding `.md.bak-*` / `.md.rejected` by construction) but `chunks_data` has
  zero rows for it. A non-empty UNEXPECTED bucket is a regression signal worth investigating.
- **expected-empty (quarantined)** — no valid `.md` exists (only a `.pdf`/`.djvu` awaiting
  conversion, or only quarantine artifacts like `.md.bak-*` / `.md.rejected`, e.g.
  `gabbay_2000`, `negri_von_plato_2001`, `troelstra_schwichtenberg_2000`). This is the expected,
  correctly-excluded state — not a failure.

**Directory→doc_id resolution note**: unlike `literature-fidelity-audit.sh`'s "Target entry
resolution" (which stamps `provenance_fidelity` onto individual `index.json` chapter/section
entries via `parent_doc` fan-out), `chunks_data.doc_id` is keyed on the **`sources/<dir>/`
directory basename itself** (e.g. `blackburn_2002`, not `blackburn_2002_ch03_sec01-04` or
`blackburn_2002_book`) — confirmed by reading the live corpus. Job 4 therefore checks
`doc_id = <directory basename>` directly; it does not need the root/child fan-out logic that
provenance-stamping requires.

```bash
function rebuild_job4_coverage_audit() {
  echo "### Job 4: Chunk/Search-Index Coverage Audit"
  echo ""

  if [ ! -f "$literature_db" ]; then
    echo "Global literature database not found at $literature_db — cannot audit coverage."
    echo ""
    return 0
  fi

  echo "_Querying chunks_data (canonical FTS5 source). document_metadata is currently empty"
  echo "(0 rows) in this corpus and is intentionally NOT queried by this job._"
  echo ""

  missing_dirs=()
  covered_dirs=0
  quarantine_hits=()

  lit_dir="${LITERATURE_DIR:-$HOME/Projects/Literature}"
  if [ -d "$lit_dir/sources" ]; then
    while IFS= read -r dirpath; do
      dir=$(basename "$dirpath")
      count=$(sqlite3 "$literature_db" "SELECT count(*) FROM chunks_data WHERE doc_id='$dir';" 2>/dev/null || echo 0)
      if [ "${count:-0}" -eq 0 ]; then
        missing_dirs+=("$dir")
      else
        covered_dirs=$((covered_dirs + 1))
      fi
      # Defensive hazard-(b) check: quarantine artifacts must never be chunked. The chunker's
      # callers (literature-ingest.sh, handle_convert() as of #842) glob strictly on `*.md`,
      # which by construction excludes `*.md.bak-<UTC>` and `*.md.rejected` (neither filename
      # ends in exactly ".md"). Verify this holds against the real chunks.json manifest rather
      # than assuming it forever.
      if [ -f "$dirpath/chunks.json" ] && grep -qE '\.md\.(bak-|rejected)' "$dirpath/chunks.json" 2>/dev/null; then
        quarantine_hits+=("$dir")
      fi
    done < <(find "$lit_dir/sources" -mindepth 1 -maxdepth 1 -type d)
  fi

  # Classify each missing_dirs entry: UNEXPECTED (has a valid .md, wiring regressed) vs
  # expected-empty (quarantined: no valid .md, only source PDF/DJVU and/or .md.bak-*/.md.rejected).
  unexpected_dirs=()
  expected_empty_dirs=()
  for d in "${missing_dirs[@]}"; do
    valid_md=$(find "$lit_dir/sources/$d" -maxdepth 1 -name '*.md' -not -name 'chunk_*.md' 2>/dev/null | grep -vE '\.md\.(bak-|rejected)$')
    if [ -n "$valid_md" ]; then
      unexpected_dirs+=("$d")
    else
      expected_empty_dirs+=("$d")
    fi
  done

  # Legacy top-level chunks_dir-schema entries (no `path` field; live outside sources/).
  legacy_missing=()
  legacy_covered=0
  while IFS= read -r legacy_id; do
    [ -z "$legacy_id" ] && continue
    count=$(sqlite3 "$literature_db" "SELECT count(*) FROM chunks_data WHERE doc_id='$legacy_id';" 2>/dev/null || echo 0)
    if [ "${count:-0}" -eq 0 ]; then
      legacy_missing+=("$legacy_id")
    else
      legacy_covered=$((legacy_covered + 1))
    fi
  done < <(jq -r '.entries[] | select(has("chunks_dir")) | .doc_id' "$global_index" 2>/dev/null)

  echo "sources/<dir>/ directories audited: covered=$covered_dirs missing=${#missing_dirs[@]}"
  echo "  of which UNEXPECTED (valid .md, zero chunks_data — possible regression)=${#unexpected_dirs[@]}"
  echo "  of which expected-empty (quarantined, no valid .md)=${#expected_empty_dirs[@]}"
  if [ "${#unexpected_dirs[@]}" -gt 0 ]; then
    echo ""
    echo "UNEXPECTED — valid .md exists but chunks_data has zero rows (investigate: wiring"
    echo "regression in handle_convert()/handle_ingest(), or a new un-wired write path):"
    for d in "${unexpected_dirs[@]}"; do
      echo "  - $d"
    done
  fi
  if [ "${#expected_empty_dirs[@]}" -gt 0 ]; then
    echo ""
    echo "Expected-empty (quarantined — no valid .md; correctly excluded, not a failure):"
    for d in "${expected_empty_dirs[@]}"; do
      echo "  - $d"
    done
  fi
  echo ""
  echo "Legacy chunks_dir-schema entries audited: covered=$legacy_covered missing=${#legacy_missing[@]}"
  if [ "${#legacy_missing[@]}" -gt 0 ]; then
    echo ""
    echo "Legacy entries with zero FTS5 coverage:"
    for d in "${legacy_missing[@]}"; do
      echo "  - $d"
    done
  fi
  echo ""
  if [ "${#quarantine_hits[@]}" -gt 0 ]; then
    echo "WARNING: quarantine artifact (.md.bak-*/.md.rejected) found chunked in: ${quarantine_hits[*]}"
  else
    echo "No quarantine artifacts (.md.bak-*/.md.rejected) found chunked (glob-strictness assumption holds)."
  fi
  echo ""
  echo "/literature --convert chunks and indexes every .md it writes (Convert"
  echo "Step 3h/Step 4), so this job's UNEXPECTED bucket is the regression signal to watch —"
  echo "not a known root cause anymore. document_metadata remains an orphaned, always-empty"
  echo "table (explicit non-goal; not queried here)."
  echo ""
}
```

### Job 3: Coverage Refresh — the ONLY Writer (confirm-after-diff gated)

Proposes newly-relevant global-corpus documents that are absent from this repo's sub-index, and
appends them **only** after an explicit `AskUserQuestion` confirmation of a shown diff.
Additions only — never deletes or rewrites an existing entry (never touches BimodalLogic-style
rich curation fields, never uses the "Remove" block). `--dry-run` skips the confirm+write step
and only prints the proposed diff; Jobs 1/2/4 never write regardless of `--dry-run`.

**Rebuild Job 3 Step A — Candidate generation (LLM-driven matching)**:

This step requires judgment, not pure mechanical bash — no existing script performs this
matching. Determine this repo's domain signals (repo basename via `basename "$(pwd)"`, recent
task titles/descriptions from `specs/state.json` if present, README topic sentences), then scan
`$global_index`'s `entries[]` for candidates whose `project_tags`, `keywords`, or `summary`
plausibly match that domain:

```bash
# Read current sub-index doc_ids to exclude already-present entries
existing_ids=$(jq -r '.entries[].doc_id' "$sub_index" 2>/dev/null)

# Pull a lightweight candidate pool: entries whose project_tags array already names this repo,
# unioned with entries an LLM judges keyword/summary-relevant to the domain signals above.
# project_tags-based candidates are the highest-confidence signal (another repo's --lit or
# discover-mode run already tagged this doc as relevant to THIS project by name).
repo_name=$(basename "$(pwd)")
tag_candidates=$(jq -r --arg repo "$repo_name" \
  '.entries[] | select(.project_tags? and (.project_tags | index($repo))) | .id' \
  "$global_index" 2>/dev/null)
```

The agent then reviews `tag_candidates` (and any keyword/summary-matched candidates it
identifies by reading entry `keywords`/`summary`/`title` fields against the domain signals),
excludes anything already in `$existing_ids`, and drafts a `relevance` annotation per candidate
explaining why it belongs in this repo's sub-index.

**Rebuild Job 3 Step B — Validate candidates** (reuses the "Add" block's validation half only):

```bash
# For each candidate doc_id, confirm it still resolves in the global index before proposing it
# (mirrors the existing Sub-Index Management > Add block's validation, never its write).
for doc_id in $candidate_doc_ids; do
  if ! jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
    echo "Warning: candidate '$doc_id' no longer resolves in global index — dropping" >&2
    continue
  fi
done
```

**Rebuild Job 3 Step C — Confirm-after-diff gate** (always shown, even under `--dry-run`):

```json
{
  "question": "Add these documents to specs/literature-index.json?",
  "header": "Coverage Refresh — Proposed Additions",
  "multiSelect": true,
  "options": [
    {
      "label": "{doc_id} — {title}",
      "description": "Proposed relevance: {relevance}. Currently absent from your sub-index."
    }
  ]
}
```

If there are zero candidates, print `"No new coverage-refresh candidates found."` and skip the
gate entirely (nothing to confirm).

**Rebuild Job 3 Step D — Append-only write (skipped entirely under `--dry-run`)**:

```bash
function rebuild_job3_coverage_refresh() {
  echo "### Job 3: Coverage Refresh"
  echo ""

  # ... Steps A-C above produce $confirmed_doc_ids (only entries the user checked) ...

  if [ "$dry_run" = "true" ]; then
    echo "_dry-run: no write performed. Proposed additions were shown above for review only._"
    echo ""
    return 0
  fi

  if [ -z "${confirmed_doc_ids:-}" ]; then
    echo "No additions confirmed — sub-index unchanged."
    echo ""
    return 0
  fi

  today=$(date +%Y-%m-%d)
  for doc_id in $confirmed_doc_ids; do
    relevance="${candidate_relevance[$doc_id]:-}"
    tmp=$(mktemp)
    jq --arg id "$doc_id" \
       --arg rel "$relevance" \
       --arg today "$today" \
       '.entries += [{
         "doc_id": $id,
         "relevance": (if $rel == "" then null else $rel end),
         "added": $today,
         "source": "rebuild"
       }]' "$sub_index" > "$tmp" && mv "$tmp" "$sub_index"
    echo "Added '$doc_id' to $sub_index"
  done
  echo ""
  echo "Existing entries (including any BimodalLogic-style rich curation fields) were not"
  echo "touched — this job only ever appends new entries."
  echo ""
}
```

Dangling-ref removals are never performed by any rebuild job — a dangling ref found by Job 1
requires its own separate, explicitly confirmed removal action (Sub-Index Management > Remove),
never automatic cleanup.

---

## Sub-Index Management

Per-repo sub-index operations for `specs/literature-index.json`. These operations manage which documents from the global Literature/ repo are relevant to the current project. The sub-index is reference-only: it stores doc_ids and metadata is resolved at runtime from the global index.

All operations assume `$LITERATURE_DIR` is set (default: `~/Projects/Literature`) and the global index exists at `$LITERATURE_DIR/index.json`.

### Init: Create Empty Sub-Index

Creates `specs/literature-index.json` with empty entries. Safe to run in a project without an existing sub-index.

```bash
project_name=$(basename "$(pwd)")
today=$(date +%Y-%m-%d)

if [ -f "specs/literature-index.json" ]; then
  echo "Sub-index already exists at specs/literature-index.json"
  echo "Current entries: $(jq '.entries | length' specs/literature-index.json) entries"
else
  jq -n \
    --arg project "$project_name" \
    --arg today "$today" \
    '{
      "project": $project,
      "literature_dir": null,
      "created": $today,
      "entries": []
    }' > specs/literature-index.json
  echo "Created specs/literature-index.json for project: $project_name"
fi
```

### Add: Append a Document Entry

Validates that `doc_id` exists in the global index before appending. Idempotent: if the doc_id is already in the sub-index, reports a warning and skips.

```bash
# Usage: doc_id="blackburn_2002" relevance="Core reference for modal logic"
global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"
today=$(date +%Y-%m-%d)

# Validate doc_id exists in global index
if ! jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
  echo "Error: doc_id '$doc_id' not found in global index ($global_index)" >&2
  exit 1
fi

# Check if already present in sub-index
if jq -e --arg id "$doc_id" '.entries[] | select(.doc_id == $id)' specs/literature-index.json >/dev/null 2>&1; then
  echo "Warning: doc_id '$doc_id' already in sub-index — skipping" >&2
  exit 0
fi

# Append entry
tmp=$(mktemp)
jq --arg id "$doc_id" \
   --arg rel "${relevance:-}" \
   --arg today "$today" \
   '.entries += [{
     "doc_id": $id,
     "relevance": (if $rel == "" then null else $rel end),
     "added": $today,
     "source": "manual"
   }]' specs/literature-index.json > "$tmp" && mv "$tmp" specs/literature-index.json
echo "Added doc_id '$doc_id' to specs/literature-index.json"
```

### Remove: Delete a Document Entry

Removes an entry by doc_id. No-op if doc_id not present.

```bash
# Usage: doc_id="blackburn_2002"
tmp=$(mktemp)
before=$(jq '.entries | length' specs/literature-index.json)
jq --arg id "$doc_id" '
  .entries = [.entries[] | select(.doc_id == $id | not)]
' specs/literature-index.json > "$tmp" && mv "$tmp" specs/literature-index.json
after=$(jq '.entries | length' specs/literature-index.json)

if [ "$before" -eq "$after" ]; then
  echo "Warning: doc_id '$doc_id' not found in sub-index — no change"
else
  echo "Removed doc_id '$doc_id' from specs/literature-index.json"
fi
```

### List: Show Entries with Resolved Metadata

Resolves title, authors, and year from the global index for each sub-index entry.

```bash
global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"

entry_count=$(jq '.entries | length' specs/literature-index.json)
if [ "$entry_count" -eq 0 ]; then
  echo "Sub-index is empty. Run: /literature --subindex add <doc_id>"
  exit 0
fi

echo "## Sub-Index Entries ($entry_count)"
echo ""

while IFS=$'\t' read -r doc_id relevance added source; do
  # Resolve from global index
  title=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | .title // "?"' "$global_index" 2>/dev/null | head -1)
  authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | if (.authors|type)=="array" then (.authors|first) elif (.authors|type)=="string" then .authors else "?" end' "$global_index" 2>/dev/null | head -1)
  year=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.year // "?") | tostring' "$global_index" 2>/dev/null | head -1)
  chunk_count=$(jq --arg id "$doc_id" '[.entries[] | select(.parent_doc == $id)] | length' "$global_index" 2>/dev/null || echo 0)

  status_tag=""
  if [ "$title" = "?" ] || [ -z "$title" ]; then
    status_tag=" [NOT IN GLOBAL INDEX]"
  fi

  echo "- **$doc_id**${status_tag}"
  echo "  Title: $title ($year) by $authors"
  [ "$chunk_count" -gt 0 ] && echo "  Chunks: $chunk_count"
  [ -n "$relevance" ] && [ "$relevance" != "null" ] && echo "  Relevance: $relevance"
  echo "  Added: $added (source: ${source:-manual})"
  echo ""
done < <(jq -r '.entries[] | [.doc_id, (.relevance // ""), .added, (.source // "manual")] | @tsv' specs/literature-index.json 2>/dev/null)
```

### Validate: Check All doc_ids Exist in Global Index

**Migrated**: this dangling-ref check is now wired up and reachable as
**Job 1 (`rebuild_job1_dangling_ref_lint`)** under "Mode: Rebuild" above, invoked via
`/literature --rebuild`. It previously referenced a `--subindex` flag that was never parsed
anywhere in `literature.md` (dead documentation). This section is kept only as a pointer so the
Sub-Index Management catalogue stays complete; do not add a second, divergent implementation
here — edit `rebuild_job1_dangling_ref_lint` under "Mode: Rebuild" instead.

---

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **specs/literature/ missing**: Not an error for status/scan — report and suggest next steps
- **index.json missing**: Initialize with empty structure for convert/index modes; warn for validate
- **pdftotext missing**: Hard error for convert mode on PDF files — show install command
- **djvutxt missing**: Soft warning — skip DJVU files with message, continue processing PDFs
- **Empty pdftotext output**: Warn "no text extracted, OCR required", skip file, continue
- **jq failure**: Use two-step write pattern (write to tmp file, then mv) to avoid corruption
- **Git commit failure**: Non-blocking — log and continue
- **zotero-library.json not found**: Exit code 1 from zotero-search.sh — show setup instructions, fall back to index-only search
- **zotero-search.sh returns no results**: Exit code 2 — continue to index-only search; combine results
- **Broken PDF symlink**: Validate mode will detect broken symlinks in pdfs/ directory; non-blocking for import
- **Duplicate import**: Check index for existing bib_key/zotero_key match before importing; show [IMPORTED] tag

## Standards Reference

- Token counting: `chars / 4 + 20` (matches memory-harvest.sh pattern)
- Chunking: content-aware logical splitting at 4,000-line threshold — divide at chapter/section headings; merge small adjacent sections; fall back to mechanical 4,000-line splits when no headings detected
- Source file convention: PDF/DJVU source files are co-located with their converted markdown in the same `specs/literature/` directory or subdirectory. Source files are gitignored via `specs/literature/**/*.pdf` and `specs/literature/**/*.djvu` patterns. Users must add source files manually after checkout.
- Index schema: root `specs/literature/index.json` uses `entries[]` with enriched metadata fields (authors, title, year, doc_type, source_format, parent_doc, page_range, bib_key, zotero_key, zotero_path, project_tags)
- Drift threshold: >20% change in token count triggers validation warning
- Zotero search: invokes `.claude/extensions/literature/scripts/zotero-search.sh` with `--format=json --limit=20 {query_terms}`; handles exit codes 0 (success), 1 (library not found), 2 (no results)
- Import pipeline: symlink PDF to `$LITERATURE_DIR/pdfs/{citation_key}.pdf`, convert via handle_convert() with PREFILL_* env vars, patch index with Zotero fields, git commit (non-blocking)

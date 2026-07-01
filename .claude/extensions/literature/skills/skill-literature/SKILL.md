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
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
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
  *)
    echo "Error: Unknown mode '$mode'. Available: status, scan, convert, validate, index, search, ingest"
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

entries=$(jq -r '.entries[] | .path' "$index_file" 2>/dev/null)
```

### Validate Step 2: Check Each Entry

For each indexed entry, check:

1. File exists at `specs/literature/{entry.path}`
2. Token count drift (recount vs stored, flag if >20% different)
3. Required schema fields present: `id`, `path`, `token_count`, `keywords`, `summary`, `doc_type`, `source_format`

```bash
stale_entries=()
drift_entries=()
schema_warnings=()

while IFS= read -r entry_path; do
  full_path="$lit_dir/$entry_path"
  if [ ! -f "$full_path" ]; then
    stale_entries+=("$entry_path (missing)")
  else
    # Recount tokens
    char_count=$(wc -c < "$full_path" 2>/dev/null || echo 0)
    current_tokens=$(( char_count / 4 + 20 ))
    stored_tokens=$(jq --arg p "$entry_path" '.entries[] | select(.path == $p) | .token_count' "$index_file" 2>/dev/null || echo 0)

    if [ -n "$stored_tokens" ] && [ "$stored_tokens" -gt 0 ]; then
      # Calculate drift percentage
      diff=$(( current_tokens - stored_tokens ))
      if [ "$diff" -lt 0 ]; then diff=$(( -diff )); fi
      drift_pct=$(( diff * 100 / stored_tokens ))
      if [ "$drift_pct" -gt 20 ]; then
        drift_entries+=("$entry_path (stored: $stored_tokens, actual: $current_tokens, drift: ${drift_pct}%)")
      fi
    fi

    # Check for required schema fields (new in schema v2)
    missing_fields=$(jq -r --arg p "$entry_path" '
      .entries[] | select(.path == $p) |
      [
        (if .doc_type == null or .doc_type == "" then "doc_type" else empty end),
        (if .source_format == null or .source_format == "" then "source_format" else empty end),
        (if .authors == null then "authors" else empty end),
        (if .title == null or .title == "" then "title" else empty end)
      ] | join(", ")
    ' "$index_file" 2>/dev/null || echo "")
    if [ -n "$missing_fields" ]; then
      schema_warnings+=("$entry_path (missing fields: $missing_fields)")
    fi
  fi
done <<< "$entries"
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

### Unindexed Files ({count}) — markdown files not in index.json
{for each unindexed file:}
- {file_path}
  Run: /literature --index {file_path}

{if all clean:}
### Validation Passed

All {N} index entries are valid. No stale paths, no drift, no schema warnings, no unindexed files.
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

### Convert Step 4: Display Summary

```
## Conversion Complete

**Files Converted**: {N}

| Output File | Lines | Tokens | Status |
|-------------|-------|--------|--------|
| {file1.md}  | 1-4000      | 3,500  | Written |
| {file2.md}  | 4001-8000   | 3,200  | Written |
...

**Index Updated**: specs/literature/index.json ({entry_count} entries)

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
  # Non-blocking git commit in $LITERATURE_DIR
  if [ -d "$lit_dir/.git" ]; then
    (
      cd "$lit_dir" && \
      git add -A && \
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
  authors=$(jq -r --arg id "$doc_id" '.entries[] | select(.id == $id) | (.authors // []) | first // "?"' "$global_index" 2>/dev/null | head -1)
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

Reports orphaned entries (doc_ids that no longer exist in the global index). Does not modify the sub-index.

```bash
global_index="${LITERATURE_DIR:-$HOME/Projects/Literature}/index.json"

orphans=()
valid=()

while IFS= read -r doc_id; do
  if jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)' "$global_index" >/dev/null 2>&1; then
    valid+=("$doc_id")
  else
    orphans+=("$doc_id")
  fi
done < <(jq -r '.entries[].doc_id' specs/literature-index.json 2>/dev/null)

echo "## Sub-Index Validation"
echo ""
echo "Valid entries: ${#valid[@]}"
echo "Orphaned entries: ${#orphans[@]}"
echo ""

if [ "${#orphans[@]}" -gt 0 ]; then
  echo "### Orphaned doc_ids (not found in global index)"
  for id in "${orphans[@]}"; do
    echo "  - $id"
  done
  echo ""
  echo "To remove an orphan: /literature --subindex remove <doc_id>"
else
  echo "All entries valid."
fi
```

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

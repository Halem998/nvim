#!/usr/bin/env bash
# literature-convert.sh - Convert PDF or DJVU to structured markdown
#
# Usage:
#   literature-convert.sh <input.pdf|input.djvu> <output_dir>
#
# Output:
#   {output_dir}/{doc_id}.md  — markdown with heading markers from TOC
#
# Environment:
#   LITERATURE_CONVERTER — override tool preference: 'marker', 'pymupdf', 'pdftotext'
#                          Default: tries marker first, then pymupdf+pdftotext hybrid
#
# Exit codes:
#   0 — success
#   1 — input file missing or unsupported type
#   2 — all converters failed
#
# Quality metrics (reported to stderr):
#   Headings: count of # markers in output
#   Words: approximate word count
#   Math blocks: count of $$ or \begin{ environments

set -euo pipefail

# --- Arguments ---
INPUT="${1:-}"
OUTPUT_DIR="${2:-}"

if [ -z "$INPUT" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "[convert] Usage: $0 <input.pdf|input.djvu> <output_dir>" >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "[convert] Input file not found: $INPUT" >&2
  exit 1
fi

# --- Derive doc_id from filename ---
BASENAME=$(basename "$INPUT")
DOC_ID="${BASENAME%.*}"
DOC_ID=$(echo "$DOC_ID" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cs '[:alnum:]_.-' '_')
DOC_ID="${DOC_ID%_}"  # Remove trailing underscore

# --- Determine file type ---
EXT="${BASENAME##*.}"
EXT="${EXT,,}"  # lowercase

case "$EXT" in
  pdf) FILE_TYPE="pdf" ;;
  djvu) FILE_TYPE="djvu" ;;
  *)
    echo "[convert] Unsupported file type: $EXT (supported: pdf, djvu)" >&2
    exit 1
    ;;
esac

mkdir -p "$OUTPUT_DIR"
OUTPUT_MD="$OUTPUT_DIR/${DOC_ID}.md"
CONVERTER="${LITERATURE_CONVERTER:-auto}"

log() { echo "[convert] $*" >&2; }

# --- Conversion functions ---

# Try marker (best for academic PDFs with two-column layouts and math)
try_marker() {
  local input="$1" output="$2"
  if command -v marker_single >/dev/null 2>&1; then
    log "Trying marker_single..."
    if marker_single "$input" --output_dir "$(dirname "$output")" >/dev/null 2>&1; then
      # marker outputs to a subdirectory - find and move the result
      local marker_out
      marker_out=$(find "$(dirname "$output")" -name "*.md" -newer "$input" 2>/dev/null | head -1)
      if [ -n "$marker_out" ] && [ -f "$marker_out" ]; then
        mv "$marker_out" "$output"
        log "marker_single: success"
        return 0
      fi
    fi
    log "marker_single: failed"
  elif command -v marker >/dev/null 2>&1; then
    log "Trying marker..."
    if marker "$input" "$output" >/dev/null 2>&1 && [ -f "$output" ]; then
      log "marker: success"
      return 0
    fi
    log "marker: failed"
  fi
  return 1
}

# PyMuPDF + pdftotext hybrid conversion
# Produces markdown with proper # heading markers from embedded TOC
try_pymupdf() {
  local input="$1" output="$2"

  if ! python3 -c "import fitz" >/dev/null 2>&1; then
    log "PyMuPDF: not available"
    return 1
  fi

  log "Trying PyMuPDF+pdftotext hybrid..."

  python3 << PYEOF
import sys
import re
import subprocess
import os

pdf_path = "$input"
out_path = "$output"

try:
    import fitz
except ImportError:
    print("[convert] PyMuPDF not available", file=sys.stderr)
    sys.exit(1)

doc = fitz.open(pdf_path)

# Extract full text from pdftotext if available (better text extraction)
page_texts = {}
if subprocess.run(['which', 'pdftotext'], capture_output=True).returncode == 0:
    result = subprocess.run(
        ['pdftotext', '-layout', pdf_path, '-'],
        capture_output=True, text=True, errors='replace'
    )
    if result.returncode == 0:
        raw_pages = result.stdout.split('\x0c')
        for i, page_text in enumerate(raw_pages):
            page_texts[i + 1] = page_text.strip()

# Fall back to PyMuPDF text extraction if pdftotext not available
if not page_texts:
    for page_num, page in enumerate(doc):
        page_texts[page_num + 1] = page.get_text().strip()

# Extract TOC for heading structure
toc = doc.get_toc()

if toc:
    # Use embedded TOC to create markdown with proper headings
    md_lines = []

    # Build page-to-text mapping
    # Also extract title from metadata or first page
    meta = doc.metadata
    title = meta.get('title', '') if meta else ''
    author = meta.get('author', '') if meta else ''

    if title:
        md_lines.append(f"# {title}\n")
        if author:
            md_lines.append(f"**Author(s)**: {author}\n\n")

    # Map TOC entries to their page text
    toc_extended = []
    for i, entry in enumerate(toc):
        level, heading_title, start_page = entry
        end_page = toc[i+1][2] if i+1 < len(toc) else len(doc)
        toc_extended.append((level, heading_title, start_page, end_page))

    for level, heading_title, start_page, end_page in toc_extended:
        marker = '#' * min(level + 1, 4)  # TOC level 1 -> ##, level 2 -> ###
        md_lines.append(f"\n{marker} {heading_title}\n\n")

        # Collect text for this section (pages start_page to end_page-1)
        section_text_parts = []
        for pg in range(start_page, min(end_page, start_page + 3)):
            if pg in page_texts:
                text = page_texts[pg]
                # Remove the heading line if it appears verbatim at page start
                lines = [l for l in text.split('\n') if l.strip()]
                if lines and heading_title.strip() in lines[0]:
                    lines = lines[1:]
                section_text_parts.append('\n'.join(lines))

        if section_text_parts:
            # Join and clean up the text
            section_text = '\n\n'.join(section_text_parts)
            # Normalize whitespace
            section_text = re.sub(r'\n{3,}', '\n\n', section_text)
            md_lines.append(section_text)
            md_lines.append('\n\n')

    content = '\n'.join(md_lines)
else:
    # No embedded TOC - use heuristic heading detection via font size analysis
    # Fall back to page-by-page dump with detected headings
    md_lines = []

    # Collect font size statistics for heading detection
    all_sizes = []
    for page in doc:
        for block in page.get_text('dict')['blocks']:
            if 'lines' not in block:
                continue
            for line in block['lines']:
                for span in line['spans']:
                    if span['text'].strip() and len(span['text'].strip()) > 2:
                        all_sizes.append(span['size'])

    if all_sizes:
        from collections import Counter
        size_counts = Counter(all_sizes)
        body_size = max(size_counts.items(), key=lambda x: x[1])[0]
        heading_threshold = body_size * 1.1
    else:
        body_size = 10.0
        heading_threshold = 11.0

    for page_num, page in enumerate(doc):
        page_text = page_texts.get(page_num + 1, '')
        if not page_text:
            continue

        # Try to detect headings from font analysis on this page
        heading_texts = set()
        for block in page.get_text('dict')['blocks']:
            if 'lines' not in block:
                continue
            for line in block['lines']:
                line_text = ''.join(s['text'] for s in line['spans']).strip()
                has_large_font = any(s['size'] >= heading_threshold for s in line['spans'])
                if has_large_font and line_text and len(line_text) < 100:
                    heading_texts.add(line_text)

        # Process page text, inserting ## markers for detected headings
        for line in page_text.split('\n'):
            stripped = line.strip()
            if stripped in heading_texts:
                md_lines.append(f"\n## {stripped}\n")
            else:
                md_lines.append(line)
        md_lines.append('\n\n')

    content = '\n'.join(md_lines)

# Write output
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(content)

# Report quality metrics to stderr
heading_count = content.count('\n#')
word_count = len(content.split())
math_count = content.count(r'\$\$') + content.count(r'\\begin{')
print(f"[convert] Quality: headings={heading_count} words={word_count} math_blocks={math_count}", file=sys.stderr)
print(f"[convert] Output: {out_path}", file=sys.stderr)
PYEOF
  local exit_code=$?

  if [ "$exit_code" -eq 0 ] && [ -f "$output" ] && [ -s "$output" ]; then
    return 0
  fi
  log "PyMuPDF: failed (exit $exit_code or empty output)"
  return 1
}

# Plain pdftotext fallback (no heading markers, but full text)
try_pdftotext() {
  local input="$1" output="$2"

  if ! command -v pdftotext >/dev/null 2>&1; then
    log "pdftotext: not available"
    return 1
  fi

  log "Trying pdftotext (plain text fallback)..."
  if pdftotext -layout "$input" - 2>/dev/null > "$output"; then
    # Wrap in minimal markdown structure
    local title
    title=$(basename "$input" .pdf | tr '_' ' ')
    local tmp
    tmp=$(mktemp)
    { echo "# $title"; echo ""; cat "$output"; } > "$tmp"
    mv "$tmp" "$output"
    log "pdftotext: success (no heading detection)"
    return 0
  fi
  return 1
}

# DJVU conversion via djvutxt
try_djvu() {
  local input="$1" output="$2"

  if command -v djvutxt >/dev/null 2>&1; then
    log "Converting DJVU with djvutxt..."
    if djvutxt "$input" "$output" 2>/dev/null; then
      log "djvutxt: success"
      return 0
    fi
  fi

  # Fallback: djvups | ps2pdf | pdftotext chain
  if command -v djvups >/dev/null 2>&1 && command -v ps2pdf >/dev/null 2>&1; then
    local tmp_pdf
    tmp_pdf=$(mktemp --suffix=.pdf)
    log "Converting DJVU via djvups | ps2pdf..."
    if djvups "$input" | ps2pdf - "$tmp_pdf" 2>/dev/null; then
      if try_pymupdf "$tmp_pdf" "$output" || try_pdftotext "$tmp_pdf" "$output"; then
        rm -f "$tmp_pdf"
        return 0
      fi
    fi
    rm -f "$tmp_pdf"
  fi

  log "DJVU conversion: all methods failed"
  return 1
}

# --- Main conversion logic ---
log "Converting: $INPUT -> $OUTPUT_MD"

CONVERTED=0

if [ "$FILE_TYPE" == "djvu" ]; then
  if try_djvu "$INPUT" "$OUTPUT_MD"; then
    CONVERTED=1
  fi
else
  # PDF conversion: try in order of preference
  case "$CONVERTER" in
    marker)
      try_marker "$INPUT" "$OUTPUT_MD" && CONVERTED=1 || true
      ;;
    pymupdf)
      try_pymupdf "$INPUT" "$OUTPUT_MD" && CONVERTED=1 || true
      ;;
    pdftotext)
      try_pdftotext "$INPUT" "$OUTPUT_MD" && CONVERTED=1 || true
      ;;
    auto|*)
      # Try marker first, then pymupdf+pdftotext hybrid, then plain pdftotext
      if try_marker "$INPUT" "$OUTPUT_MD"; then
        CONVERTED=1
      elif try_pymupdf "$INPUT" "$OUTPUT_MD"; then
        CONVERTED=1
      elif try_pdftotext "$INPUT" "$OUTPUT_MD"; then
        CONVERTED=1
      fi
      ;;
  esac
fi

if [ "$CONVERTED" -eq 0 ]; then
  log "All converters failed for: $INPUT"
  exit 2
fi

# Report quality metrics
if [ -f "$OUTPUT_MD" ]; then
  HEADING_COUNT=$(grep -cE '^#{1,4} ' "$OUTPUT_MD" 2>/dev/null || echo 0)
  WORD_COUNT=$(wc -w < "$OUTPUT_MD" 2>/dev/null | tr -d ' ' || echo 0)
  MATH_COUNT=$(grep -cE '\$\$|\\begin\{' "$OUTPUT_MD" 2>/dev/null || echo 0)
  log "Metrics: headings=$HEADING_COUNT words=$WORD_COUNT math=$MATH_COUNT"
fi

log "Success: $OUTPUT_MD (doc_id: $DOC_ID)"
echo "$DOC_ID"  # stdout: the derived doc_id for use by caller
exit 0

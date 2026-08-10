#!/usr/bin/env python3
"""
Semantic splitter for literature markdown files.
Splits at semantic boundaries (chapters, sections) rather than OCR page markers.
"""

import re
import os
import sys
import argparse
import json


# Document profiles: each defines how to detect split boundaries.
# boundary_type: 'page_running_heads' means we use ## Page N markers + running header analysis
# Each profile has: boundary_type, section_table (explicit line-based boundaries)

PROFILES = {
    "blackburn_2002": {
        "description": "Blackburn, de Rijke, Venema (2002) Modal Logic",
        "boundary_type": "page_running_heads",
        # Chunks: (filename, start_line, end_line_exclusive, description)
        # Lines are 1-indexed as returned by detect_blackburn_2002_boundaries()
    }
}


def detect_blackburn_2002_boundaries(filepath):
    """
    Detect semantic boundaries in Blackburn 2002 using page running headers.
    Returns list of (filename, start_line_0indexed, end_line_0indexed_exclusive, desc).
    """
    with open(filepath, 'r', errors='replace') as f:
        lines = f.readlines()

    total = len(lines)

    # Find each section's first page via running headers
    section_starts = {}  # section_id -> line_0indexed

    for i, line in enumerate(lines):
        m = re.match(r'^## Page (\d+)$', line.strip())
        if m:
            pg = int(m.group(1))
            next1 = lines[i+1].strip() if i+1 < total else ''
            next2 = lines[i+2].strip() if i+2 < total else ''

            # Running header is either 'N.M Title' or 'M\nN Chapter Title'
            sec_match = re.match(r'^(\d+\.\d+)\s+(.+)$', next1)
            if not sec_match:
                sec_match = re.match(r'^(\d+\.\d+)\s+(.+)$', next2)

            if sec_match:
                sec_id = sec_match.group(1)
                if sec_id not in section_starts:
                    section_starts[sec_id] = i  # line index of ## Page N

            # Find appendices
            app_match = re.match(r'^Appendix ([A-D])\b', next1)
            if not app_match:
                app_match = re.match(r'^Appendix ([A-D])\b', next2)
            if app_match:
                app_id = f'app_{app_match.group(1)}'
                if app_id not in section_starts:
                    section_starts[app_id] = i

            # Find Bibliography
            if 'Bibliography' in next1 and 'bib' not in section_starts:
                # Only the first occurrence of Bibliography as primary header
                if pg >= 547:  # Bibliography starts at page 547
                    section_starts['bib'] = i

    # Preface starts at the beginning of the file (includes title, TOC, preface)
    section_starts['preface'] = 0

    # Sort section_starts by line number
    ordered = sorted(section_starts.items(), key=lambda x: x[1])

    # Chunking strategy: group sections to match ~33 files like blackburn_2001
    # Based on section sizes and blackburn_2001 naming convention:
    chunks = [
        # (filename, [section_ids])
        ("ch00_preface", ["preface"]),
        ("ch01_relational-structures", ["1.1", "1.2"]),
        ("ch01_models-and-frames", ["1.3"]),
        ("ch01_general-frames", ["1.4", "1.5", "1.6", "1.7", "1.8"]),
        ("ch02_invariance-results", ["2.1"]),
        ("ch02_bisimulations", ["2.2", "2.3"]),
        ("ch02_standard-translation", ["2.4", "2.5"]),
        ("ch02_characterization", ["2.6"]),
        ("ch02_simulation-safety", ["2.7", "2.8"]),
        ("ch03_frame-definability", ["3.1", "3.2", "3.3", "3.4"]),
        ("ch03_sahlqvist-formulas", ["3.5", "3.6"]),
        ("ch03_more-sahlqvist", ["3.7"]),
        ("ch03_advanced-frame-theory", ["3.8", "3.9"]),
        ("ch04_preliminaries-canonical", ["4.1", "4.2"]),
        ("ch04_applications", ["4.3", "4.4"]),
        ("ch04_transforming-canonical", ["4.5", "4.6"]),
        ("ch04_rules-finitary-i", ["4.7", "4.8"]),
        ("ch04_finitary-ii-summary", ["4.9", "4.10"]),
        ("ch05_logic-as-algebra", ["5.1", "5.2"]),
        ("ch05_jonsson-tarski", ["5.3"]),
        ("ch05_duality-theory", ["5.4"]),
        ("ch05_general-frames", ["5.5"]),
        ("ch05_persistence-summary", ["5.6", "5.7"]),
        ("ch06_satisfiability-decidability", ["6.1", "6.2", "6.3"]),
        ("ch06_quasi-models-tiling", ["6.4", "6.5"]),
        ("ch06_np-pspace", ["6.6", "6.7"]),
        ("ch06_exptime-summary", ["6.8", "6.9"]),
        ("ch07_logical-modalities", ["7.1", "7.2"]),
        ("ch07_since-until-hybrid", ["7.3"]),
        ("ch07_guarded-fragment", ["7.4"]),
        ("ch07_multi-dimensional", ["7.5"]),
        ("ch07_lindstrom-summary", ["7.6", "7.7"]),
        ("app_logical-toolkit", ["app_A"]),
        ("app_algebraic-computational", ["app_B", "app_C"]),
        ("app_guide-bibliography", ["app_D", "bib"]),
    ]

    # Build start line map
    sec_line = {sid: lineno for sid, lineno in ordered}

    # Generate boundary list
    boundaries = []
    for fname, sec_ids in chunks:
        # Find start: first section in the group
        start_line = None
        for sid in sec_ids:
            if sid in sec_line:
                if start_line is None:
                    start_line = sec_line[sid]
                else:
                    start_line = min(start_line, sec_line[sid])

        if start_line is None:
            print(f"WARNING: No start found for chunk {fname} (sections: {sec_ids})", file=sys.stderr)
            continue

        boundaries.append((fname, start_line, sec_ids))

    # Set end lines
    result = []
    for i, (fname, start, sec_ids) in enumerate(boundaries):
        end = boundaries[i+1][1] if i+1 < len(boundaries) else total
        result.append((fname, start, end, f"Sections: {', '.join(sec_ids)}"))

    return result, lines


def tokens_from_lines(lines, start, end):
    """Estimate token count from line slice (bytes / 4)."""
    content = ''.join(lines[start:end])
    return len(content.encode('utf-8')) // 4


def split_file(filepath, profile, output_dir, dry_run=False):
    """Split a file according to profile into output_dir."""
    if profile == "blackburn_2002":
        boundaries, lines = detect_blackburn_2002_boundaries(filepath)
    else:
        print(f"ERROR: Unknown profile '{profile}'", file=sys.stderr)
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    print(f"Source: {filepath}")
    print(f"Output: {output_dir}")
    print(f"Chunks: {len(boundaries)}")
    print()

    results = []
    for fname, start, end, desc in boundaries:
        content = ''.join(lines[start:end])
        token_count = len(content.encode('utf-8')) // 4
        byte_count = len(content.encode('utf-8'))
        out_path = os.path.join(output_dir, fname + ".md")

        status = "DRY-RUN" if dry_run else "WRITE"
        print(f"[{status}] {fname}.md")
        print(f"  Lines {start+1}-{end} | {byte_count:,} bytes | ~{token_count:,} tokens")
        print(f"  {desc}")

        if not dry_run:
            with open(out_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  -> {out_path}")

        results.append({
            "filename": fname + ".md",
            "path": out_path,
            "start_line": start + 1,
            "end_line": end,
            "byte_count": byte_count,
            "token_count": token_count,
            "sections": desc,
        })
        print()

    return results


def main():
    parser = argparse.ArgumentParser(description="Semantic literature splitter")
    parser.add_argument("filepath", help="Input markdown file")
    parser.add_argument("--profile", required=True, help="Document profile")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    args = parser.parse_args()

    results = split_file(args.filepath, args.profile, args.output_dir, args.dry_run)

    if args.json:
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()

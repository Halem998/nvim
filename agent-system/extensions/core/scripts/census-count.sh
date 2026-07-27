#!/usr/bin/env bash
# census-count.sh -- shared, subcommand-based census helper.
#
# Ships three subcommands, each addressing one of three named repo-wide-count bug classes, plus
# the cross-check discipline that catches all of them regardless of which one produced a bad
# number:
#
#   occurrences  (bug classes 1 and 3) -- count real occurrences of a caller-supplied ERE within
#                a path, excluding matches that fall inside comments or string literals, and
#                separately report the naive (unstripped) count so the gap is visible rather than
#                silently absorbed.
#   membership   (bug class 2) -- report the set difference between files present in a tree and
#                files declared by a caller-supplied declared-set command. Checks DECLARED
#                membership only, never transitive reachability -- this is not a build-graph
#                parser.
#   cross-check  -- run two independent caller-supplied count commands, print both counts and
#                both verbatim command strings, and report MATCH or MISMATCH. Exits non-zero on
#                MISMATCH so a caller cannot ignore a disagreement by accident.
#
# Every subcommand emits a fixed, greppable record block containing at minimum the count, the
# method name, and the verbatim command string that produced it -- see
# context/standards/census-methodology.md for the derive-once/record-the-command/cross-check
# discipline this record block exists to support mechanically.
#
# Reference example -- do not assume whitespace-only separators: the separator-alternation shape
# used in hooks/validate-no-task-references.sh's own citation-detection regex is
#   TASK_SEP='([[:space:]]+#?|[-_#])'
# i.e. an explicit alternation group covering whitespace, hyphen, underscore, and "#" -- never a
# bracket class containing "-" (a "-" inside a bracket class can silently be read as a range
# operator depending on position). Any --pattern passed to `occurrences` that needs to catch
# hyphenated/underscored/suffixed keyword variants should follow the same shape.
#
# Usage:
#   census-count.sh occurrences --pattern <ERE> --path <file-or-dir>
#                    [--comment-style hash|slash|dash|none] [--file-glob <glob>]
#   census-count.sh membership --tree-cmd <cmd> --declared-cmd <cmd>
#   census-count.sh cross-check --a-cmd <cmd> --b-cmd <cmd> [--a-label <label>] [--b-label <label>]
#
# occurrences:
#   --pattern <ERE>        Extended regular expression passed to `grep -oE`. Required.
#   --path <file-or-dir>   File or directory to scan. Required. Directories are scanned
#                          recursively via `find <path> -type f -name <file-glob>`.
#   --comment-style        One of: hash (# to end of line), slash (// to end of line, and
#                          non-nested /* ... */ blocks), dash (-- to end of line), none (no
#                          stripping at all -- the pre-stripped-input escape hatch for languages
#                          needing nesting-aware handling, e.g. Lean's `/- -/` block comments;
#                          see lean-sorry-census.sh for that case, which this tool deliberately
#                          does not reimplement). Default: none.
#   --file-glob <glob>     `find -name` glob used when --path is a directory. Default: "*".
#   Also masks double-quoted string-literal interiors (except under --comment-style none) so a
#   keyword appearing only as string text is excluded from the real count the same way a
#   commented-out keyword is.
#   Emits both naive_count (raw grep -oE match count, no stripping) and real_count (match count
#   after stripping) so the gap between them is visible.
#
# membership:
#   --tree-cmd <cmd>       Shell command (run via `bash -c`) whose stdout is one file path per
#                          line: the files actually present in the tree. Required.
#   --declared-cmd <cmd>   Shell command (run via `bash -c`) whose stdout is one file path per
#                          line: the files declared by some build/manifest/target list. Required.
#   Reports tree_count, declared_count, ONLY_IN_TREE (present but undeclared), and
#   ONLY_IN_DECLARED (declared but absent/nonexistent). Checks declared membership only.
#
# cross-check:
#   --a-cmd <cmd>          Shell command (run via `bash -c`). Required.
#   --b-cmd <cmd>          Shell command (run via `bash -c`). Required.
#   --a-label / --b-label  Labels for the record block. Default: A / B.
#   Each command's stdout is expected to contain a count; the LAST integer-looking token in the
#   combined stdout is taken as that command's count. Exits 0 on MATCH, 1 on MISMATCH.
#
# Exit codes: 0 on success (occurrences, membership always; cross-check only on MATCH); 1 on
# cross-check MISMATCH; 64 on usage error (missing subcommand, missing required flag, bad path).

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage:
  census-count.sh occurrences --pattern <ERE> --path <file-or-dir>
                   [--comment-style hash|slash|dash|none] [--file-glob <glob>]
  census-count.sh membership --tree-cmd <cmd> --declared-cmd <cmd>
  census-count.sh cross-check --a-cmd <cmd> --b-cmd <cmd> [--a-label <label>] [--b-label <label>]

Run with no arguments for this summary. See the script's own header comment for the full
subcommand contract (flags, defaults, record-block format).
USAGE
}

# strip_comments <file> <comment-style>
# Prints the file's content to stdout with line comments (per style), non-nested /* */ block
# comments (slash style only), and double-quoted string-literal interiors masked out, preserving
# newline positions so line numbers stay meaningful. --comment-style none is a byte-identical
# pass-through (the pre-stripped-input escape hatch).
strip_comments() {
  local file="$1" style="$2"
  python3 - "$file" "$style" <<'PYEOF'
import sys

def strip(text, style):
    if style == "none":
        return text
    out = []
    i, n = 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if not in_str:
            if style == "hash" and c == "#":
                j = text.find("\n", i)
                i = n if j == -1 else j
                continue
            if style == "dash" and text[i:i + 2] == "--":
                j = text.find("\n", i)
                i = n if j == -1 else j
                continue
            if style == "slash" and text[i:i + 2] == "//":
                j = text.find("\n", i)
                i = n if j == -1 else j
                continue
            if style == "slash" and text[i:i + 2] == "/*":
                j = text.find("*/", i + 2)
                if j == -1:
                    out.append("\n" * text[i:].count("\n"))
                    i = n
                else:
                    block = text[i:j + 2]
                    out.append("\n" * block.count("\n"))
                    i = j + 2
                continue
            if c == '"':
                in_str = True
                out.append(c)
                i += 1
                continue
            out.append(c)
            i += 1
        else:
            if c == "\\" and i + 1 < n:
                out.append("  ")
                i += 2
                continue
            if c == '"':
                out.append(c)
                in_str = False
                i += 1
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
    return "".join(out)


path, style = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8", errors="replace") as fh:
    text = fh.read()
sys.stdout.write(strip(text, style))
PYEOF
}

cmd_occurrences() {
  local pattern="" path="" comment_style="none" file_glob="*"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pattern) pattern="$2"; shift 2 ;;
      --path) path="$2"; shift 2 ;;
      --comment-style) comment_style="$2"; shift 2 ;;
      --file-glob) file_glob="$2"; shift 2 ;;
      *) echo "occurrences: unknown argument: $1" >&2; usage >&2; exit 64 ;;
    esac
  done

  if [[ -z "$pattern" || -z "$path" ]]; then
    echo "occurrences: --pattern and --path are required" >&2
    exit 64
  fi
  case "$comment_style" in
    hash|slash|dash|none) ;;
    *) echo "occurrences: --comment-style must be one of hash|slash|dash|none" >&2; exit 64 ;;
  esac

  local -a files=()
  if [[ -d "$path" ]]; then
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$path" -type f -name "$file_glob" -print0 | sort -z)
  elif [[ -f "$path" ]]; then
    files+=("$path")
  else
    echo "occurrences: path not found: $path" >&2
    exit 64
  fi

  local workdir
  workdir="$(mktemp -d)"

  local naive_total=0 real_total=0 naive_n real_n
  for f in "${files[@]}"; do
    naive_n="$(grep -oE "$pattern" "$f" 2>/dev/null | wc -l | tr -d ' ')"
    naive_total=$((naive_total + naive_n))

    strip_comments "$f" "$comment_style" > "$workdir/stripped.txt"
    real_n="$(grep -oE "$pattern" "$workdir/stripped.txt" 2>/dev/null | wc -l | tr -d ' ')"
    real_total=$((real_total + real_n))
  done

  rm -rf "$workdir"

  local produced_cmd="census-count.sh occurrences --pattern '${pattern}' --path '${path}' --comment-style ${comment_style} --file-glob '${file_glob}'"

  echo "=== census-count occurrences record ==="
  echo "method: occurrences"
  echo "pattern: ${pattern}"
  echo "path: ${path}"
  echo "comment_style: ${comment_style}"
  echo "files_scanned: ${#files[@]}"
  echo "naive_count: ${naive_total}"
  echo "real_count: ${real_total}"
  echo "command: ${produced_cmd}"
  echo "=== end record ==="
}

cmd_membership() {
  local tree_cmd="" declared_cmd=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tree-cmd) tree_cmd="$2"; shift 2 ;;
      --declared-cmd) declared_cmd="$2"; shift 2 ;;
      *) echo "membership: unknown argument: $1" >&2; usage >&2; exit 64 ;;
    esac
  done

  if [[ -z "$tree_cmd" || -z "$declared_cmd" ]]; then
    echo "membership: --tree-cmd and --declared-cmd are required" >&2
    exit 64
  fi

  local workdir
  workdir="$(mktemp -d)"

  bash -c "$tree_cmd" | sort -u > "$workdir/tree.txt"
  bash -c "$declared_cmd" | sort -u > "$workdir/declared.txt"

  local tree_count declared_count only_tree only_declared
  tree_count="$(wc -l < "$workdir/tree.txt" | tr -d ' ')"
  declared_count="$(wc -l < "$workdir/declared.txt" | tr -d ' ')"
  only_tree="$(comm -23 "$workdir/tree.txt" "$workdir/declared.txt")"
  only_declared="$(comm -13 "$workdir/tree.txt" "$workdir/declared.txt")"

  rm -rf "$workdir"

  echo "=== census-count membership record ==="
  echo "method: membership"
  echo "tree_count: ${tree_count}"
  echo "tree_command: ${tree_cmd}"
  echo "declared_count: ${declared_count}"
  echo "declared_command: ${declared_cmd}"
  echo "ONLY_IN_TREE:"
  [[ -n "$only_tree" ]] && echo "$only_tree"
  echo "ONLY_IN_DECLARED:"
  [[ -n "$only_declared" ]] && echo "$only_declared"
  echo "note: checks DECLARED membership only, never transitive reachability"
  echo "=== end record ==="
}

cmd_cross_check() {
  local a_cmd="" b_cmd="" a_label="A" b_label="B"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --a-cmd) a_cmd="$2"; shift 2 ;;
      --b-cmd) b_cmd="$2"; shift 2 ;;
      --a-label) a_label="$2"; shift 2 ;;
      --b-label) b_label="$2"; shift 2 ;;
      *) echo "cross-check: unknown argument: $1" >&2; usage >&2; exit 64 ;;
    esac
  done

  if [[ -z "$a_cmd" || -z "$b_cmd" ]]; then
    echo "cross-check: --a-cmd and --b-cmd are required" >&2
    exit 64
  fi

  local a_out b_out a_count b_count
  a_out="$(bash -c "$a_cmd")"
  b_out="$(bash -c "$b_cmd")"

  a_count="$(echo "$a_out" | grep -oE '[0-9]+' | tail -1)"
  b_count="$(echo "$b_out" | grep -oE '[0-9]+' | tail -1)"
  a_count="${a_count:-<none>}"
  b_count="${b_count:-<none>}"

  local status="MATCH" exit_code=0
  if [[ "$a_count" != "$b_count" ]]; then
    status="MISMATCH"
    exit_code=1
  fi

  echo "=== census-count cross-check record ==="
  echo "method: cross-check"
  echo "${a_label}_count: ${a_count}"
  echo "${a_label}_command: ${a_cmd}"
  echo "${b_label}_count: ${b_count}"
  echo "${b_label}_command: ${b_cmd}"
  echo "result: ${status}"
  echo "=== end record ==="

  exit "$exit_code"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 64
fi

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  occurrences) cmd_occurrences "$@" ;;
  membership) cmd_membership "$@" ;;
  cross-check) cmd_cross_check "$@" ;;
  -h|--help) usage; exit 0 ;;
  *)
    echo "Unknown subcommand: ${SUBCOMMAND}" >&2
    usage >&2
    exit 64
    ;;
esac
